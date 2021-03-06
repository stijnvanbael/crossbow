import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'core.dart';

abstract class Http extends ProducerBase {
  static int defaultPort = 8080;

  static HttpProducer get(String path, {int port}) {
    return new HttpProducer(HttpMethod.GET, path, port);
  }

  static HttpProducer put(String path, {int port}) {
    return new HttpProducer(HttpMethod.PUT, path, port);
  }

  static HttpProducer post(String path, {int port}) {
    return new HttpProducer(HttpMethod.POST, path, port);
  }

  static HttpProducer delete(String path, {int port}) {
    return new HttpProducer(HttpMethod.DELETE, path, port);
  }
}

class HttpHeaders extends MapView<String, dynamic> {
  const HttpHeaders(Map<String, dynamic> other) : super(other);

  String path(String name) {
    return this['pathParams'][name];
  }

  String query(String name) {
    return request.uri.queryParameters[name];
  }

  HttpRequest get request => this['request'];
}

class HttpProducer extends Http {

  static final NOT_FOUND = notFound();
  static final Map<int, Future<HttpServer>> SERVERS = {
  };
  static final Map<int, Set<HttpProducer>> PRODUCERS = {
  };
  static final PATH_PARAMETER = new RegExp(r'\{([\w\d]+)\}');

  static HttpProducer notFound() {
    HttpProducer notFound = new HttpProducer(HttpMethod.GET, '/404');
    notFound.map((Map<String, dynamic> headers, body) {
      headers['request'].response.statusCode = HttpStatus.NOT_FOUND;
      return '<html><head><title>404 Not Found</title></head><body><h1>404 Not Found</h1></body></html>';
    });
    return notFound;
  }

  final HttpMethod method;
  final RegExp path;
  final List<String> parameters;
  int port;

  HttpProducer(this.method, String path, [int port])
      :
        path = new RegExp(
            '^' + path.replaceAll(PATH_PARAMETER, '([^/]+)') + '\$'),
        parameters = new List.from(
            PATH_PARAMETER.allMatches(path).map((match) => match.group(1))) {
    if (port == null) port = Http.defaultPort;
    this.port = port;
    PRODUCERS.putIfAbsent(port, () => new Set());
    PRODUCERS[port].add(this);
  }

  HttpProducer start() {
    SERVERS.putIfAbsent(port, () => createServer());
    return this;
  }

  HttpProducer stop() {
    PRODUCERS[port].remove(this);
    if (PRODUCERS[port].isEmpty) {
      SERVERS[port].then((server) {
        server.close();
      });
      SERVERS.remove(port);
    }
    return this;
  }

  Future<HttpServer> createServer() {
    return HttpServer.bind(InternetAddress.ANY_IP_V6, port).then((server) {
      server.listen((request) => dispatch(request));
      return server;
    });
  }

  void dispatch(HttpRequest request) {
    request.response.headers.contentType = ContentType.HTML;
    HttpProducer producer = PRODUCERS[port]
        .firstWhere((producer) => producer.canHandle(request),
        orElse: () => NOT_FOUND);
    request.transform(UTF8.decoder)
        .toList()
        .then((List list) {
      var body = list.isNotEmpty ? list[0] : null;
      producer.produce(new Message(body, callback: (message) {
        request.response.write(message.body);
        request.response.close();
      }, headers: new HttpHeaders({
        'request' : request,
        'pathParams' : producer.pathParameters(request)
      })));
    });
  }

  Map<String, String> pathParameters(HttpRequest request) {
    Match match = path.firstMatch(request.uri.path);
    if (match == null) {
      return {
      };
    }
    return new Map.fromIterable(parameters,
        key: (parameter) => parameter,
        value: (parameter) => match.group(parameters.indexOf(parameter) + 1));
  }

  bool canHandle(HttpRequest request) {
    return path.hasMatch(request.uri.path) && method.name == request.method;
  }

}

class HttpMethod {
  static const GET = const HttpMethod._('GET');
  static const PUT = const HttpMethod._('PUT');
  static const POST = const HttpMethod._('POST');
  static const DELETE = const HttpMethod._('DELETE');

  static get values => [GET, PUT, POST, DELETE];

  final String name;

  const HttpMethod._(this.name);

  toString() {
    return name;
  }
}
