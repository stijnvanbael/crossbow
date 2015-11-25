import 'dart:async';
import 'package:box/box.dart';
import 'core.dart';

typedef Future Where(QueryStep step, Message message);

abstract class DB extends Transformer {
  static select({Type from, Where where}) {
    return new Query(from, where);
  }

  static final Save _save = new Save();

  static get save => _save;

  static Box box;

  static configure({String file}) {
    if (file != null) box = new FileBox(file);
  }

}

class Save extends DB {
  Message transformMessage(Message message) {
    message.body.then((entity) => DB.box.store(entity));
    return message;
  }
}

class Query extends DB {
  Type type;
  Where where;

  Query(this.type, this.where);

  Message transformMessage(Message message) {
    message.body = new Future(() => where(DB.box.query(type), message));
    return message;
  }
}