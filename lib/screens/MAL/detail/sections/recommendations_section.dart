import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, TabType, gotoPage, nullOrEmpty;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/screens/MAL/detail/pages/full_recommendations_page.dart';
import 'package:mywatchlist/services/api/MAL/web/recommendation_write_api.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/MAL/content/recommanimewidget.dart';

/// Recommendations; arrow opens the page with the users' comments. With a MyAnimeList account
/// the title row also offers MAL's own form to recommend a similar title.
DetailSection? recommendationsSection(DetailData data) {
  final recommendations = data.content?.recommendations;
  if (nullOrEmpty(recommendations)) return null;
  return DetailSection(
    TabType.Recommendations,
    RecommendedAnimeWidget(
      category: data.category,
      horizPadding: detailHorizPadding,
      recommAnime: recommendations!,
    ),
    trailing: _RecommendButton(category: data.category, id: data.id),
    onViewAll: (context) => gotoPage(
      context: context,
      newPage: Scaffold(
        appBar: AppBar(title: Text(S.current.Recommendations)),
        body: ContentFullRecommendation(id: data.id, category: data.category),
      ),
    ),
  );
}

class _RecommendButton extends StatelessWidget {
  const _RecommendButton({required this.category, required this.id});

  final String category;
  final int id;

  @override
  Widget build(BuildContext context) {
    final AccountBloc bloc;
    try {
      bloc = context.read<AccountBloc>();
    } on Object {
      return const SizedBox.shrink();
    }
    return BlocBuilder<AccountBloc, AccountState>(
      bloc: bloc,
      buildWhen: (a, b) => _isMal(a) != _isMal(b),
      builder: (context, state) {
        if (!_isMal(state)) return const SizedBox.shrink();
        return IconButton(
          tooltip: S.current.Mww_Recommend_Make,
          icon: const Icon(Icons.add_comment_outlined),
          onPressed: () => launchWebView(
            RecommendationWriteApi.pageUrl(category: category, id: id),
            context: context,
          ),
        );
      },
    );
  }

  static bool _isMal(AccountState state) =>
      state is AccountLoaded && state.selectedAccountType == AccountType.myanimelist;
}
