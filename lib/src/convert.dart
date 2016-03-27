import 'dart:async';
import 'dart:io';

import 'package:reflective/reflective.dart';

import 'core.dart';

abstract class Convert<F, T> extends Transformer {
  static ConvertObjectToJson toJson() {
    installJsonConverters();
    return new ConvertObjectToJson();
  }

  static ConvertJsonToObject jsonTo(Type type) {
    installJsonConverters();
    return new ConvertJsonToObject(type);
  }

  static ConvertYamlToObject yamlTo(Type type) {
    installYamlConverters();
    return new ConvertYamlToObject(type);
  }

  Stream<Message> transformMessage(Message message) {
    return new Stream.fromIterable(
        [ message.cloneWithBody(convert(message.body))]);
  }

  T convert(F from);
}

class ConvertObjectToJson extends Convert<Object, String> {
  Stream<Message> transformMessage(Message message) {
    return super.transformMessage(message).map((message) =>
    message.headers['request'].response.headers.contentType = ContentType.JSON);
  }

  String convert(object) {
    return Conversion
        .convert(object)
        .to(Json)
        .value;
  }
}

class ConvertJsonToObject extends Convert<String, Object> {
  TypeReflection type;

  ConvertJsonToObject(Type type) {
    this.type = new TypeReflection(type);
  }

  Object convert(String json) {
    return Conversion.convert(new Json(json)).to(type.rawType);
  }
}

class ConvertYamlToObject extends Convert<String, Object> {
  TypeReflection type;

  ConvertYamlToObject(Type type) {
    this.type = new TypeReflection(type);
  }

  Object convert(String yaml) {
    return Conversion.convert(new Yaml(yaml)).to(type.rawType);
  }
}

class Ignore {
  const Ignore();
}

const Ignore ignore = const Ignore();