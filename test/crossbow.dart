library crossbow.test;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:box/box.dart';
import 'package:crossbow/crossbow.dart';
import 'package:reflective/reflective.dart';
import 'package:test/test.dart';

main() {
  group('Core', () {
    Producer start;

    setUp(() {
      start = new ProducerBase();
    });

    test('Simple pipe', () {
      Transformer transformer = new PTransformer();
      start | transformer;
      transformer.start();
      start.produce(new Message('Hello world!', callback: (message) {
        expect(message.body, 'Hepello world!');
      }));
    });
  });

  group('Http', () {
    test('Simple get', () {
      Transformer pipeline = Http.get('/hello')
          .map((headers, body) => 'Hello world!')
          .start();

      getAndExpect(pipeline, '/hello', 'Hello world!');
    });

    test('Path parameters', () {
      Transformer pipeline = Http.get('/hello/{who}')
          .map((headers, body) => 'Hello ' + headers.path('who'))
          .start();

      getAndExpect(pipeline, '/hello/Bob', 'Hello Bob');
    });

    test('Query parameters', () {
      Transformer pipeline = Http.get('/hello')
          .map((headers, body) => 'Hello ' + headers.query('who'))
          .start();

      getAndExpect(pipeline, '/hello?who=Bob', 'Hello Bob');
    });

    test('Body', () {
      Transformer pipeline = Http.post('/hello')
          .map((headers, body) => 'Hello ' + body)
          .start();

      postAndExpect(pipeline, '/hello', 'Jake', 'Hello Jake');
    });
  });

  group('Convert', () {
    test('Object to JSON', () {
      ConvertObjectToJson transformer = Convert.toJson();
      var employee = new Employee(
          'John', DateTime.parse('1970-01-01T00'), new Division('Marketing'));
      var json = transformer.convert(employee);
      expect(json,
          '{"retired":false,"division":{"name":"Marketing"},"dateOfBirth":"1970-01-01 00:00:00.000","name":"John"}');
    });
    test('JSON to Object', () {
      ConvertJsonToObject transformer = Convert.jsonTo(Employee);
      var json = '{"retired":false,"division":{"name":"Marketing"},"dateOfBirth":"1970-01-01 00:00:00.000","name":"John"}';
      var employee = transformer.convert(json);
      expect(employee, new Employee(
          'John', DateTime.parse('1970-01-01T00'), new Division('Marketing')));
    });
    test('YAML to Object', () {
      ConvertYamlToObject transformer = Convert.yamlTo(Employee);
      var yaml = r'''
retired: false
division:
  name: Marketing
dateOfBirth: 1970-01-01 00:00:00.000
name: John
''';
      var employee = transformer.convert(yaml);
      expect(employee, new Employee(
          'John', DateTime.parse('1970-01-01T00'), new Division('Marketing')));

    });
  });

  group('DB', () {
    test('Save', () async {
      resetDB();
      Transformer transformer = DB.store;
      Message message = new Message(new Employee(
          'John', DateTime.parse('1970-01-01T00'), new Division('Marketing')));
      transformer.consume(message);
      await message.completed;
      expect(await DB.box.find(Employee, 'John'), new Employee(
          'John', DateTime.parse('1970-01-01T00'), new Division('Marketing')));
    });

    test('Query', () async {
      resetDB();

      await DB.box.store(new Employee(
          'John', DateTime.parse('1970-01-01T00'),
          new Division('Marketing'))).then((v) =>
          DB.box.store(new Employee('Margaret', DateTime.parse('1975-08-23T00'),
              new Division('Marketing'))))
          .then((v) =>
          DB.box.store(new Employee('Daniel', DateTime.parse('1979-10-16T00'),
              new Division('Marketing'))))
          .then((v) =>
          DB.box.store(new Employee('Emma', DateTime.parse('1982-04-05T00'),
              new Division('Administration'))));

      var results = [];
      var message = new Message(null, callback: (message) => results.add(message.body), headers: {'division': 'Marketing'});
      Transformer transformer = DB.select(from: Employee, where: (query, message) =>
          query.where('division.name').equals(message.headers['division'])
              .orderBy('name').ascending()
              .list());
      await transformer.consume(message);
      expect(results, [
        new Employee('Daniel', DateTime.parse('1979-10-16T00'),
            new Division('Marketing')),
        new Employee(
            'John', DateTime.parse('1970-01-01T00'), new Division('Marketing')),
        new Employee('Margaret', DateTime.parse('1975-08-23T00'),
            new Division('Marketing'))
      ]);
    });
  });
}

void resetDB() {
  File file = new File('.box/test/crossbow.test.Employee');
  if (file.existsSync()) {
    file.deleteSync();
  }
  DB.configure(file: '.box/test');
}

class PTransformer extends Transformer {
  Stream<Message> transformMessage(Message message) {
    return new Stream.fromIterable(
        [message.cloneWithBody(message.body.replaceAll(r'e', 'epe'))]);
  }
}

void getAndExpect(Transformer pipeline, String url, String expected) {
  Future future = new HttpClient().get('localhost', 8080, url)
      .then((HttpClientRequest request) => request.close())
      .then((HttpClientResponse response) => response.transform(UTF8.decoder)
      .toList()
      .then((List list) => list.isNotEmpty ? list[0] : null))
      .then((result) {
    try {
      expect(result, expected);
    }
    finally {
      pipeline.stop();
    }
  });
  expect(future, completes);
}

void postAndExpect(Transformer pipeline, String url, String body,
    String expected) {
  Future future = new HttpClient().post('localhost', 8080, url)
      .then((request) {
    request.write(body);
    return request;
  })
      .then((request) => request.close())
      .then((HttpClientResponse response) => response.transform(UTF8.decoder)
      .toList()
      .then((List list) => list.isNotEmpty ? list[0] : null))
      .then((result) {
    try {
      expect(result, expected);
    }
    finally {
      pipeline.stop();
    }
  });
  expect(future, completes);
}

class Employee {
  @key
  String name;
  DateTime dateOfBirth;
  Division division;
  bool retired = false;
  @transient String ignoreMe = 'Ignore me';

  Employee([this.name, this.dateOfBirth, this.division]);

  bool operator ==(o) => o is Employee
      && name == o.name
      && dateOfBirth == o.dateOfBirth
      && division == o.division
      && retired == o.retired;

  int get hashCode => name.hashCode + dateOfBirth.hashCode + division.hashCode +
      retired.hashCode;
}

class Division {
  String name;

  Division([this.name]);

  bool operator ==(o) => o is Division && name == o.name;

  int get hashCode => name.hashCode;
}