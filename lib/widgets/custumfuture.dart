
import 'package:flutter/material.dart';

class CFutureBuilder<T> extends StatelessWidget {
  final Function(AsyncSnapshot<T>) done;
  final Widget loadingChild;
  final Future<T>? future;
  final ValueChanged<Object?>? onError;
  const CFutureBuilder({
    super.key,
    required this.future,
    required this.done,
    required this.loadingChild,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
        future: future,
        builder: (_, snapshot) {
          if (snapshot.hasError && onError != null) {
            onError!(snapshot.error);
            return done(const AsyncSnapshot.nothing());
          }
          if (snapshot.hasData &&
              snapshot.connectionState == ConnectionState.done) {
            return done(snapshot);
          } else {
            return loadingChild;
          }
        });
  }
}