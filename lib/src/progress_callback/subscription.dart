import 'dart:async';

import 'package:flutter/foundation.dart';

class ObservableBuilder<T> {
  StreamController<T> _observable = StreamController();
  bool notSubscribed = true;

  void next(T value) {
    _observable.add(value);
  }

  Subscription subscribe(void Function(T event) onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    notSubscribed = false;
    try {
      _observable.stream.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
    }
    catch (e) {
      debugPrint('subscription stream error: $e');
    }

    return Subscription(() {
      _observable.close();

      // Create a new instance to avoid errors
      _observable = StreamController();
    });
  }
}

class Subscription {
  final VoidCallback unsubscribe;
  const Subscription(this.unsubscribe);
}
