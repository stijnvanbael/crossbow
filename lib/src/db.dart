import 'dart:async';

import 'package:box/box.dart';
import 'package:reflective/reflective.dart';

import 'core.dart';

typedef dynamic Where(QueryStep step, Message message);

abstract class DB extends Transformer {
  static select({Type from, Where where}) {
    return new DBSelect(from, where);
  }

  static final DBStore _store = new DBStore();

  static get store => _store;

  static Box _box = new Box();

  static Box get box => _box;

  static configure({String file}) {
    if (file != null) _box = new FileBox(file);
  }

}

class DBStore extends DB {
  Stream<Message> transformMessage(Message message) {
    return new Stream.fromFuture(DB._box.store(message.body)
        .then((v) => message));
  }
}

class DBSelect extends DB {
  Type _type;
  Where _where;

  DBSelect(this._type, this._where);

  Stream<Message> transformMessage(Message message) {
    var result = _where(DB._box.selectFrom(_type), message);
    if (result is Stream) {
      return result.map((item) {
        return message.cloneWithBody(item);
      });
    } else if (result is Future) {
      return new Stream.fromFuture(
          result.then((item) => message.cloneWithBody(item)));
    } else {
      var instance = new TypeReflection.fromInstance(result);
      throw new UnsupportedError(
          'Unsupported query result type "' + instance.name +
              '". Did you forget to call list() or unique()?');
    }
  }
}