import 'dart:async';

typedef dynamic Mapper(Map<String, dynamic> headers, dynamic body);

class Message {
  var body;
  var callback;
  Map<String, dynamic> headers;
  Future<Message> completed;

  Completer<Message> _completer = new Completer();

  Message(this.body, {this.callback, this.headers: const {}}) {
    _completer = new Completer();
    completed = _completer.future;
  }

  void doCallback() {
    if (callback != null) callback(this);
    _completer.complete(this);
  }

  Message cloneWithBody(dynamic newBody) {
    Message message = new Message(newBody, callback: callback, headers: new Map.from(headers));
    message._completer = _completer;
    message.completed = completed;
    _completer = new Completer();
    completed = _completer.future;
    return message;
  }
}

abstract class Consumer {
  Future consume(Message message);
}

abstract class Producer {
  Transformer pipe(Transformer transformer);

  Transformer operator |(Transformer transformer);

  Transformer map(Mapper m);

  Producer start();

  Producer stop();

  Producer produce(Message message);
}

class ProducerBase implements Producer {
  final List listeners = [];
  final defaultListener = (message) => message.doCallback();

  ProducerBase() {
    listeners.add(defaultListener);
  }

  Transformer map(Mapper m) {
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

  Future consume(Message message) {
    return transformMessage(message).listen(produce).asFuture();
  }

  Stream<Message> transformMessage(Message message);

  Transformer start() {
    if (upstream != null)
      upstream.start();
    return this;
  }

  Transformer stop() {
    if (upstream != null)
      upstream.stop();
    return this;
  }
}

class FunctionTransformer extends Transformer {
  Mapper m;

  FunctionTransformer(this.m);

  Stream<Message> transformMessage(Message message) {
    var newBody = m(message.headers, message.body);
    return new Stream.fromIterable([message.cloneWithBody(newBody)]);
  }

}