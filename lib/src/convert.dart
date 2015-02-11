part of crossbow;

abstract class Convert<F, T> extends Transformer {
  static ConvertObjectToJson toJson() {
    installJsonConverters();
    return new ConvertObjectToJson();
  }

  static ConvertJsonToObject jsonTo(Type type) {
    installJsonConverters();
    return new ConvertJsonToObject(type);
  }

  Message transformMessage(Message message) {
    message.body = message.body.then((value) => convert(value));
    return message;
  }

  T convert(F from);
}

class ConvertObjectToJson extends Convert<Object, String> {
  Message transformMessage(Message message) {
    message.headers['request'].response.headers.contentType = ContentType.JSON;
    return super.transformMessage(message);
  }

  String convert(object) {
    return Conversion.convert(object).to(Json).value;
  }
}

class ConvertJsonToObject extends Convert<String, Object> {
  TypeReflection type;

  ConvertJsonToObject(Type type) {
    this.type = new TypeReflection(type);
  }

  Object convert(String json) {
    return Conversion.convert(new Json(json)).to(type.type);
  }
}

class Ignore {
  const Ignore();
}

const Ignore ignore = const Ignore();