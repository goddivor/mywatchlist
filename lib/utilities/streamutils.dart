// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
// import 'dart:collection';

class StreamListener<T> {
  final T? _initialData;
  T? currentValue;
  final controller = StreamController<T>.broadcast();
  StreamListener([this._initialData]) {
    this.currentValue = this._initialData;
  }
  Stream<T> get stream {
    return controller.stream;
  }

  T? get initialData {
    return _initialData;
  }

  void update(T value) {
    currentValue = value;
    controller.add(value);
  }

  void dispose() {
    controller.close();
  }
}
