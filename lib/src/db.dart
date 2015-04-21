part of crossbow;

typedef Future Where(QueryStep step, Message message);

abstract class DB extends Transformer {
  static query(Type type, Where where) {
    return new Query(type, where);
  }

  static final Save _save = new Save();

  static get save => _save;

  static Box box;

  static configure({String file}) {
    if(file != null) box = new FileBox(file);
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