import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart' show ProfileTabScroll;
import 'package:mywatchlist/services/api/Kitsu/kitsu_social.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// A profile tab (or a plain page body when [overlap] is false) that lists the items of a
/// [KitsuPager] lazily: the first page loads when the tab is first built and the next one when
/// the last built row comes into view. Loading, error and empty states are drawn here.
class KitsuPagedList<T> extends StatefulWidget {
  final String storageKey;
  final KitsuPager<T> Function() createPager;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyText;

  /// Slivers drawn above the rows (filters, a pinned post).
  final List<Widget> header;

  /// True inside a profile `NestedScrollView`; false in a page of its own.
  final bool overlap;

  const KitsuPagedList({
    super.key,
    required this.storageKey,
    required this.createPager,
    required this.itemBuilder,
    required this.emptyText,
    this.header = const [],
    this.overlap = true,
  });

  @override
  State<KitsuPagedList<T>> createState() => _KitsuPagedListState<T>();
}

class _KitsuPagedListState<T> extends State<KitsuPagedList<T>>
    with AutomaticKeepAliveClientMixin {
  late final KitsuPager<T> _pager = widget.createPager();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pager.loadMore();
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: _pager,
      builder: (context, _) {
        final s = S.of(context);
        final items = _pager.items;
        final Widget tail;
        if (items.isEmpty && _pager.loading) {
          tail = const SliverFillRemaining(
              hasScrollBody: false, child: ProfileLoading());
        } else if (items.isEmpty && _pager.error != null) {
          tail = SliverFillRemaining(
            hasScrollBody: false,
            child: ProfileMessage(
              icon: Icons.cloud_off_outlined,
              title: s.Prof_Error_Title,
              body: s.Prof_Error_Body,
              actionLabel: s.Prof_Retry,
              onAction: _pager.reload,
            ),
          );
        } else if (items.isEmpty && _pager.loaded) {
          tail = SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(widget.emptyText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            ),
          );
        } else {
          final footer = _pager.hasMore || _pager.error != null ? 1 : 0;
          tail = SliverList.builder(
            itemCount: items.length + footer,
            itemBuilder: (context, i) {
              if (i < items.length) return widget.itemBuilder(context, items[i]);
              return _Footer(pager: _pager);
            },
          );
        }
        final slivers = [...widget.header, tail];
        if (widget.overlap) {
          return ProfileTabScroll(storageKey: widget.storageKey, slivers: slivers);
        }
        return CustomScrollView(
          key: PageStorageKey<String>(widget.storageKey),
          slivers: slivers,
        );
      },
    );
  }
}

/// The last row: a spinner that asks for the next page the moment it is built, or a retry.
class _Footer extends StatefulWidget {
  final KitsuPager pager;

  const _Footer({required this.pager});

  @override
  State<_Footer> createState() => _FooterState();
}

class _FooterState extends State<_Footer> {
  @override
  void initState() {
    super.initState();
    if (widget.pager.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.pager.loadMore();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pager.error != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: TextButton(
            onPressed: widget.pager.loadMore,
            child: Text(S.of(context).Prof_Retry),
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}
