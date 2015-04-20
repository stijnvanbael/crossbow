part of crossbow;

typedef where(QueryStep step);

abstract class DB extends Transformer {
  static query(Type type, where(QueryStep)) {

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