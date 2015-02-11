part of crossbow;

typedef mapper(Map<String, dynamic> headers, body);

class Message {
  Future body;
  var callback;
  Map<String, dynamic> headers;

  Message([this.body, this.callback, this.headers = const {}]);
}

abstract class Consumer {
  void consume(Message message);
}

abstract class Producer {
  Transformer pipe(Transformer transformer);

  Transformer operator |(Transformer transformer);

  Transformer map(mapper m);

  Producer start();

  Producer stop();

  Producer produce(Message message);
}

class ProducerBase implements Producer {
  final List listeners = [];
  final defaultListener = (Message message) {
    message.callback(message);
  };

  ProducerBase() {
    listeners.add(defaultListener);
  }

  // TODO: change signature to (Map headers, body)
  Transformer map(mapper m) {
    return pipe(new FunctionTransformer(m));
  }

  Transformer operator |(Transformer transformer) => pipe(transformer);

  Transformer pipe(Transformer transformer) {
    if (listeners.contains(defaultListener)) {
      listeners.remove(defaultListener);
    }
    listeners.add(transformer.consume);
    transformer.upstream = this;
    return transformer;
  }

  Producer start() {
    return this;
  }

  Producer stop() {
    return this;
  }

  Producer produce(Message message) {
    listeners.forEach((listener) => listener(message));
    return this;
  }
}

abstract class Transformer extends ProducerBase implements Consumer {
  Producer upstream;

  void consume(Message message) {
    new Future(() => produce(transformMessage(message)));
  }

  Message transformMessage(Message message);

  Transformer start() {
    upstream.start();
    return this;
  }

  Transformer stop() {
    upstream.stop();
    return this;
  }
}

class FunctionTransformer extends Transformer {
  mapper m;

  FunctionTransformer(this.m);

  Message transformMessage(Message message) {
    message.body = message.body.then((body) => m(message.headers, body));
    return message;
  }

}