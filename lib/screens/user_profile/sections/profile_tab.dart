import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// The scrollable body of one profile tab. It sits under the pinned header of the profile's
/// `NestedScrollView`, so it starts with the overlap injector; the [storageKey] keeps its
/// scroll position when the user swipes away and back.
class ProfileTabScroll extends StatelessWidget {
  final String storageKey;
  final List<Widget> slivers;

  const ProfileTabScroll({super.key, required this.storageKey, required this.slivers});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: PageStorageKey<String>(storageKey),
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

/// A tab that loads one [T] when first shown (tabs are built lazily), keeps its state while
/// the user swipes around, and shows loading, error and empty states.
class AsyncProfileTab<T> extends StatefulWidget {
  final String storageKey;
  final Future<T> Function() loader;
  final bool Function(T data) isEmpty;
  final Widget Function(BuildContext context) emptyBuilder;
  final List<Widget> Function(BuildContext context, T data) slivers;

  const AsyncProfileTab({
    super.key,
    required this.storageKey,
    required this.loader,
    required this.isEmpty,
    required this.emptyBuilder,
    required this.slivers,
  });

  @override
  State<AsyncProfileTab<T>> createState() => _AsyncProfileTabState<T>();
}

class _AsyncProfileTabState<T> extends State<AsyncProfileTab<T>>
    with AutomaticKeepAliveClientMixin {
  late Future<T> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  void _retry() => setState(() => _future = widget.loader());

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ProfileTabScroll(
            storageKey: widget.storageKey,
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: ProfileLoading(label: S.of(context).Prof_Loading),
              ),
            ],
          );
        }
        if (snapshot.hasError) {
          return ProfileTabScroll(
            storageKey: widget.storageKey,
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: ProfileErrorView(
                  error: snapshot.error!,
                  onRetry: _retry,
                  onSignIn: () => AppRoutes.signInAgain(context, AccountType.myanimelist),
                ),
              ),
            ],
          );
        }
        final data = snapshot.data as T;
        if (widget.isEmpty(data)) {
          return ProfileTabScroll(
            storageKey: widget.storageKey,
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: widget.emptyBuilder(context),
              ),
            ],
          );
        }
        return ProfileTabScroll(
          storageKey: widget.storageKey,
          slivers: widget.slivers(context, data),
        );
      },
    );
  }
}
