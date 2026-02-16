import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:mywatchlist/constants/constants.dart' hide myAnimeStatusMap;
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/models/my_anime_list_status.dart'
    as enriched;
import 'package:mywatchlist/services/api/MAL/models/my_manga_list_status.dart'
    as enriched_manga;
import 'package:mywatchlist/widgets/loading/expandedwidget.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart';

class ContentEditWidget extends StatefulWidget {
  final int id;
  final MalAnime? contentDetailed;
  final String category;
  final ValueChanged<bool>? onUpdate;
  final ValueChanged<dynamic>? onListStatusChange;
  final VoidCallback? onDelete;

  const ContentEditWidget({
    super.key,
    required this.id,
    this.contentDetailed,
    required this.category,
    this.onUpdate,
    this.onListStatusChange,
    this.onDelete,
  });

  @override
  State<ContentEditWidget> createState() => _ContentEditWidgetState();
}

class _ContentEditWidgetState extends State<ContentEditWidget> {
  // Loading flags per field
  bool modifyStatus = false;
  bool modifyStars = false;
  bool modifyEpisodes = false;
  bool modifyChapters = false;
  bool modifyVolumes = false;
  bool _loading = false;

  // Data
  String? statusValue;
  int? starValue;
  late TextEditingController episodeController;
  late TextEditingController chapterController;
  late TextEditingController volumesController;

  // UI toggles
  bool showAdvancedEdit = false;
  bool showAddOptions = false;
  bool animationPending = false;

  // Advanced sub-section toggles
  bool isReStatusOpen = true;
  bool isDatesOpen = false;
  bool isOthersOpen = false;

  // Advanced field state
  bool? _isRewatching;
  int? _timesRewatched;
  int? _rewatchValue;
  DateTime? _startDate;
  DateTime? _finishDate;
  int? _priority;
  late TextEditingController _commentsController;
  late TextEditingController _tagsController;

  // Advanced loading flags
  bool _modifyReStatus = false;
  bool _modifyStartDate = false;
  bool _modifyFinishDate = false;
  bool _modifyPriority = false;
  bool _modifyComments = false;
  bool _modifyTags = false;

  // Score scroll controller
  final ItemScrollController _scoreScrollController = ItemScrollController();

  bool get isAnime => widget.category == 'anime';

  MalAnime? get content => widget.contentDetailed;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadFromContent();
  }

  void _initControllers() {
    episodeController = TextEditingController(text: '0');
    chapterController = TextEditingController(text: '0');
    volumesController = TextEditingController(text: '0');
    _commentsController = TextEditingController();
    _tagsController = TextEditingController();
  }

  void _loadFromContent() {
    final c = content;
    if (c == null) return;
    final mls = c.myListStatus;
    if (mls != null) {
      statusValue = mls.status;
      starValue = mls.score;
      episodeController.text = mls.numEpisodesWatched.toString();
      _isRewatching = mls.isRewatching;
      showAddOptions = true;
    }
    // For manga, read numChaptersRead/numVolumesRead from the enriched my_list_status
    // The basic MyListStatus only has numEpisodesWatched, so check the raw JSON fields
    // via the enriched status if available. For the initial load, set to 0 if not present.
    if (!isAnime) {
      // These will be populated once the user interacts or via the enriched response
      chapterController.text = '0';
      volumesController.text = '0';
    }

    // Schedule auto-scroll to score after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToScore();
    });
  }

  @override
  void didUpdateWidget(covariant ContentEditWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentDetailed != widget.contentDetailed &&
        widget.contentDetailed != null) {
      _loadFromContent();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    episodeController.dispose();
    chapterController.dispose();
    volumesController.dispose();
    _commentsController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _scrollToScore() {
    if (!_scoreScrollController.isAttached) return;
    final keys = myStarMap.keys.toList();
    final idx = keys.indexOf(starValue ?? 0);
    if (idx >= 0) {
      try {
        _scoreScrollController.scrollTo(
          index: idx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
        );
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // API: Update watching/reading status
  // ---------------------------------------------------------------------------
  Future<void> updateWatchingStatus(String value) async {
    if (value == statusValue) return;
    if (mounted) setState(() => modifyStatus = true);

    bool result = false;
    int? episodes;
    String? startDateStr;
    String? finishDateStr;
    final now = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (isAnime) {
      // Auto-complete episodes
      if (value == 'completed' &&
          content != null &&
          (content!.numEpisodes ?? 0) > 0) {
        episodes = content!.numEpisodes;
      }
      // Auto-dates
      if (value == 'watching') startDateStr = now;
      if (value == 'completed') finishDateStr = now;

      try {
        final status = await MalApi().updateMyAnimeListStatus(
          animeId: widget.id,
          status: value,
          numWatchedEpisodes: episodes,
          startDate: startDateStr,
          finishDate: finishDateStr,
        );
        if (status != null) {
          result = true;
          widget.onListStatusChange?.call(status);
          if (mounted) {
            setState(() {
              modifyStatus = false;
              statusValue = status.status;
              if (status.numEpisodesWatched != null) {
                episodeController.text =
                    status.numEpisodesWatched.toString();
              }
              _startDate = status.startDate;
              _finishDate = status.finishDate;
            });
          }
        } else {
          _onUpdateError();
        }
      } catch (_) {
        _onUpdateError();
      }
    } else {
      // Manga
      if (value == 'reading') startDateStr = now;
      if (value == 'completed') finishDateStr = now;

      try {
        final status = await MalApi().updateMyMangaListStatus(
          mangaId: widget.id,
          status: value,
          startDate: startDateStr,
          finishDate: finishDateStr,
        );
        if (status != null) {
          result = true;
          widget.onListStatusChange?.call(status);
          if (mounted) {
            setState(() {
              modifyStatus = false;
              statusValue = status.status;
              _startDate = status.startDate;
              _finishDate = status.finishDate;
            });
          }
        } else {
          _onUpdateError();
        }
      } catch (_) {
        _onUpdateError();
      }
    }
    if (mounted && modifyStatus) setState(() => modifyStatus = false);
    widget.onUpdate?.call(result);
  }

  void _onUpdateError() {
    showToast(S.current.Couldnt_Update);
    if (mounted) setState(() => modifyStatus = false);
  }

  // ---------------------------------------------------------------------------
  // API: Update episode count
  // ---------------------------------------------------------------------------
  Future<void> updateEpisodeCount({int? episodes, int? add}) async {
    int ep = episodes ?? (int.tryParse(episodeController.text) ?? 0);
    ep += add ?? 0;
    if (ep < 0) {
      showToast(S.current.Negative_episode_not_allowed);
      return;
    }
    final maxEp = content?.numEpisodes ?? 0;
    if (maxEp > 0 && ep > maxEp) {
      showToast(S.current.Maximum_reached);
      return;
    }

    String? watchStatus;
    if (maxEp > 0 && ep == maxEp) {
      watchStatus = 'completed';
    }

    if (mounted) setState(() => modifyEpisodes = true);
    bool result = false;

    try {
      final status = await MalApi().updateMyAnimeListStatus(
        animeId: widget.id,
        numWatchedEpisodes: ep,
        status: watchStatus,
      );
      if (status != null) {
        result = true;
        widget.onListStatusChange?.call(status);
        if (mounted) {
          setState(() {
            modifyEpisodes = false;
            episodeController.text =
                (status.numEpisodesWatched ?? ep).toString();
            if (status.status != null) statusValue = status.status;
          });
        }
      } else {
        showToast(S.current.Couldnt_Update);
        if (mounted) setState(() => modifyEpisodes = false);
      }
    } catch (_) {
      showToast(S.current.Couldnt_Update);
      if (mounted) setState(() => modifyEpisodes = false);
    }
    widget.onUpdate?.call(result);
  }

  // ---------------------------------------------------------------------------
  // API: Update chapter count
  // ---------------------------------------------------------------------------
  Future<void> updateChapterCount({int? chapters, int? add}) async {
    int ch = chapters ?? (int.tryParse(chapterController.text) ?? 0);
    ch += add ?? 0;
    if (ch < 0) {
      showToast(S.current.Negative_chapters_not_allowed);
      return;
    }
    final maxCh = content?.numChapters ?? 0;
    if (maxCh > 0 && ch > maxCh) {
      showToast(S.current.Maximum_reached);
      return;
    }

    if (mounted) setState(() => modifyChapters = true);
    bool result = false;

    try {
      final status = await MalApi().updateMyMangaListStatus(
        mangaId: widget.id,
        numChaptersRead: ch,
      );
      if (status != null) {
        result = true;
        widget.onListStatusChange?.call(status);
        if (mounted) {
          setState(() {
            modifyChapters = false;
            chapterController.text =
                (status.numChaptersRead ?? ch).toString();
          });
        }
      } else {
        showToast(S.current.Couldnt_Update);
        if (mounted) setState(() => modifyChapters = false);
      }
    } catch (_) {
      showToast(S.current.Couldnt_Update);
      if (mounted) setState(() => modifyChapters = false);
    }
    widget.onUpdate?.call(result);
  }

  // ---------------------------------------------------------------------------
  // API: Update volume count
  // ---------------------------------------------------------------------------
  Future<void> updateVolumeCount({int? volumes, int? add}) async {
    int vol = volumes ?? (int.tryParse(volumesController.text) ?? 0);
    vol += add ?? 0;
    if (vol < 0) {
      showToast(S.current.Negative_volumes_not_allowed);
      return;
    }
    final maxVol = content?.numVolumes ?? 0;
    if (maxVol > 0 && vol > maxVol) {
      showToast(S.current.Maximum_reached);
      return;
    }

    if (mounted) setState(() => modifyVolumes = true);
    bool result = false;

    try {
      final status = await MalApi().updateMyMangaListStatus(
        mangaId: widget.id,
        numVolumesRead: vol,
      );
      if (status != null) {
        result = true;
        widget.onListStatusChange?.call(status);
        if (mounted) {
          setState(() {
            modifyVolumes = false;
            volumesController.text =
                (status.numVolumesRead ?? vol).toString();
          });
        }
      } else {
        showToast(S.current.Couldnt_Update);
        if (mounted) setState(() => modifyVolumes = false);
      }
    } catch (_) {
      showToast(S.current.Couldnt_Update);
      if (mounted) setState(() => modifyVolumes = false);
    }
    widget.onUpdate?.call(result);
  }

  // ---------------------------------------------------------------------------
  // API: Update rating/score
  // ---------------------------------------------------------------------------
  Future<void> updateRatingStatus(int value) async {
    if (value == starValue) return;
    if (mounted) setState(() => modifyStars = true);
    bool result = false;

    try {
      dynamic status;
      if (isAnime) {
        status = await MalApi().updateMyAnimeListStatus(
          animeId: widget.id,
          score: value,
        );
      } else {
        status = await MalApi().updateMyMangaListStatus(
          mangaId: widget.id,
          score: value,
        );
      }
      if (status != null) {
        result = true;
        widget.onListStatusChange?.call(status);
        if (mounted) {
          setState(() {
            modifyStars = false;
            starValue = status.score;
          });
        }
      } else {
        showToast(S.current.Couldnt_Update);
        if (mounted) setState(() => modifyStars = false);
      }
    } catch (_) {
      showToast(S.current.Couldnt_Update);
      if (mounted) setState(() => modifyStars = false);
    }
    widget.onUpdate?.call(result);
  }

  // ---------------------------------------------------------------------------
  // API: Update advanced fields (single call with all non-null params)
  // ---------------------------------------------------------------------------
  Future<void> updateAdvancedStatus({
    bool? isRewatching,
    bool? isRereading,
    int? timesRewatched,
    int? timesReread,
    int? rewatchValue,
    int? rereadValue,
    String? startDate,
    String? finishDate,
    int? priority,
    String? comments,
    String? tags,
    required VoidCallback onDone,
  }) async {
    if (mounted) setState(() {});
    FocusScope.of(context).unfocus();
    bool result = false;

    try {
      dynamic status;
      if (isAnime) {
        status = await MalApi().updateMyAnimeListStatus(
          animeId: widget.id,
          isRewatching: isRewatching,
          numTimesRewatched: timesRewatched,
          rewatchValue: rewatchValue,
          startDate: startDate,
          finishDate: finishDate,
          priority: priority,
          comments: comments,
          tags: tags,
        );
      } else {
        status = await MalApi().updateMyMangaListStatus(
          mangaId: widget.id,
          isRereading: isRereading,
          numTimesReread: timesReread,
          rereadValue: rereadValue,
          startDate: startDate,
          finishDate: finishDate,
          priority: priority,
          comments: comments,
          tags: tags,
        );
      }
      onDone();
      if (status != null) {
        result = true;
        widget.onListStatusChange?.call(status);
        // Update local advanced state from response
        if (status is enriched.MyAnimeListStatus) {
          _isRewatching = status.isRewatching ?? _isRewatching;
          _timesRewatched = status.numTimesRewatched ?? _timesRewatched;
          _rewatchValue = status.rewatchValue ?? _rewatchValue;
          _startDate = status.startDate ?? _startDate;
          _finishDate = status.finishDate ?? _finishDate;
          _priority = status.priority ?? _priority;
        } else if (status is enriched_manga.MyMangaListStatus) {
          _isRewatching = status.isRereading ?? _isRewatching;
          _timesRewatched = status.numTimesReread ?? _timesRewatched;
          _rewatchValue = status.rereadValue ?? _rewatchValue;
          _startDate = status.startDate ?? _startDate;
          _finishDate = status.finishDate ?? _finishDate;
          _priority = status.priority ?? _priority;
        }
      } else {
        showToast(S.current.Couldnt_Update);
      }
    } catch (_) {
      onDone();
      showToast(S.current.Couldnt_Update);
    }
    if (mounted) setState(() {});
    widget.onUpdate?.call(result);
  }

  // ---------------------------------------------------------------------------
  // API: Delete from list
  // ---------------------------------------------------------------------------
  Future<void> deleteFromList() async {
    final confirmed = await showConfirmationDialog(
      context: context,
      alertTitle: S.current.Item_delete_confi,
      desc: S.current.Item_delete_desc,
    );
    if (!confirmed) return;

    if (mounted) setState(() => _loading = true);

    try {
      if (isAnime) {
        await MalApi().deleteAnimeFromList(widget.id);
      } else {
        await MalApi().deleteMangaFromList(widget.id);
      }
      showAdvancedEdit = false;
      showAddOptions = false;
      statusValue = null;
      starValue = null;
      episodeController.text = '0';
      chapterController.text = '0';
      volumesController.text = '0';
      widget.onDelete?.call();
      widget.onUpdate?.call(true);
    } catch (_) {
      showToast(S.current.Couldnt_Delete);
      widget.onUpdate?.call(false);
    }

    if (mounted) setState(() => _loading = false);
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (content == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        elevation: 6,
        color: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (statusValue == null && !showAddOptions)
                      _addToListButton()
                    else
                      _contentStatusWidget(),
                  ],
                ),
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // "Add to List" button (shown when not on list)
  // ---------------------------------------------------------------------------
  Widget _addToListButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: PlainButton(
        onPressed: () {
          final defaultStatus =
              isAnime ? 'plan_to_watch' : 'plan_to_read';
          showAddOptions = true;
          updateWatchingStatus(defaultStatus);
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          S.current.Add_to_List,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main edit content (status, episodes, score, advanced)
  // ---------------------------------------------------------------------------
  Widget _contentStatusWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle bar
        _dragHandle(),
        // Status + episodes/chapters/volumes
        if (isAnime) _animeStatusWidget() else _mangaStatusWidget(),
        // Advanced section
        ExpandedSection(
          expand: showAdvancedEdit,
          child: _advancedWidget(),
        ),
        // Delete button — always visible when entry exists
        _deleteButtonWidget(),
        SB.h10,
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Drag handle
  // ---------------------------------------------------------------------------
  Widget _dragHandle() {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (animationPending) return;
        animationPending = true;
        Future.delayed(const Duration(milliseconds: 300))
            .then((_) => animationPending = false);
        if (mounted) {
          setState(() {
            if (details.delta.dy < 0) {
              showAdvancedEdit = true;
            } else {
              showAdvancedEdit = false;
            }
          });
        }
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (mounted) {
            setState(() => showAdvancedEdit = !showAdvancedEdit);
          }
        },
        child: SizedBox(
          width: double.infinity,
          height: 24,
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ANIME status widget
  // ---------------------------------------------------------------------------
  Widget _animeStatusWidget() {
    final totalEp = content?.numEpisodes ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _fieldColumn(
                  S.current.Status,
                  _statusDropdownWidget(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _fieldColumn(
                  '${S.current.Episodes}${totalEp > 0 ? ' ($totalEp)' : ''}',
                  _episodesWidget(),
                ),
              ),
            ],
          ),
          _scoreBarWidget(),
          SB.h10,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MANGA status widget
  // ---------------------------------------------------------------------------
  Widget _mangaStatusWidget() {
    final totalCh = content?.numChapters ?? 0;
    final totalVol = content?.numVolumes ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          _fieldColumn(
            S.current.Status,
            _statusDropdownWidget(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _fieldColumn(
                  '${S.current.Chapters}${totalCh > 0 ? ' ($totalCh)' : ''}',
                  _chaptersWidget(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _fieldColumn(
                  '${S.current.Volumes}${totalVol > 0 ? ' ($totalVol)' : ''}',
                  _volumesWidget(),
                ),
              ),
            ],
          ),
          _scoreBarWidget(),
          SB.h10,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status dropdown (uses bottom sheet)
  // ---------------------------------------------------------------------------
  Widget _statusDropdownWidget() {
    final Map<String, String> statusMap =
        isAnime ? myAnimeStatusMap : myMangaStatusMap;
    if (modifyStatus) {
      return SizedBox(height: 50, child: Center(child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
    }
    final displayValue = statusMap[statusValue] ?? S.current.Select;
    final statusColor = getAnimeStatusColor(statusValue);

    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ShadowButton(
        onPressed: () => _showStatusBottomSheet(statusMap),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: statusColor, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                displayValue,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: statusColor),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 20, color: statusColor),
          ],
        ),
      ),
    );
  }

  void _showStatusBottomSheet(Map<String, String> statusMap) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: title(S.current.Status,
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Divider(height: 1),
              ...statusMap.entries.map((entry) {
                final isSelected = entry.key == statusValue;
                final color = getAnimeStatusColor(entry.key);
                return ListTile(
                  leading: CircleAvatar(
                    radius: 6,
                    backgroundColor: color,
                  ),
                  title: Text(
                    entry.value,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: color)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    updateWatchingStatus(entry.key);
                  },
                );
              }),
              SB.h10,
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Episodes +/- widget (anime)
  // ---------------------------------------------------------------------------
  Widget _episodesWidget() {
    return SizedBox(
      height: 50,
      child: ShadowButton(
        onPressed: () {},
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                if (!modifyEpisodes) updateEpisodeCount(add: -1);
              },
              icon: const Icon(Icons.remove),
            ),
            Flexible(
              child: modifyEpisodes
                  ? Center(child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  : TextFormField(
                      keyboardType: TextInputType.number,
                      onFieldSubmitted: (value) {
                        updateEpisodeCount(episodes: int.tryParse(value));
                      },
                      controller: episodeController,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                if (!modifyEpisodes) updateEpisodeCount(add: 1);
              },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Chapters +/- widget (manga)
  // ---------------------------------------------------------------------------
  Widget _chaptersWidget() {
    return SizedBox(
      height: 50,
      child: ShadowButton(
        onPressed: () {},
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                if (!modifyChapters) updateChapterCount(add: -1);
              },
              icon: const Icon(Icons.remove),
            ),
            Flexible(
              child: modifyChapters
                  ? Center(child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  : TextFormField(
                      keyboardType: TextInputType.number,
                      onFieldSubmitted: (value) {
                        updateChapterCount(chapters: int.tryParse(value));
                      },
                      controller: chapterController,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                if (!modifyChapters) updateChapterCount(add: 1);
              },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Volumes +/- widget (manga)
  // ---------------------------------------------------------------------------
  Widget _volumesWidget() {
    return SizedBox(
      height: 50,
      child: ShadowButton(
        onPressed: () {},
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                if (!modifyVolumes) updateVolumeCount(add: -1);
              },
              icon: const Icon(Icons.remove),
            ),
            Flexible(
              child: modifyVolumes
                  ? Center(child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  : TextFormField(
                      keyboardType: TextInputType.number,
                      onFieldSubmitted: (value) {
                        updateVolumeCount(volumes: int.tryParse(value));
                      },
                      controller: volumesController,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                if (!modifyVolumes) updateVolumeCount(add: 1);
              },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Score bar (horizontal scrollable 0-10)
  // ---------------------------------------------------------------------------
  Widget _scoreBarWidget() {
    final value = myStarMap[starValue];
    final keys = myStarMap.keys.toList();
    return Column(
      children: [
        SB.h20,
        Text('${S.current.Score}${value == null ? '' : ' - $value'}'),
        SB.h10,
        SizedBox(
          height: 45,
          child: modifyStars
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : ScrollablePositionedList.builder(
                  itemScrollController: _scoreScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  initialAlignment: 0.5,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 140, vertical: 2),
                  initialScrollIndex: keys.indexOf(starValue ?? 0),
                  itemCount: keys.length,
                  itemBuilder: (context, index) {
                    final scoreValue = keys[index];
                    final isSelected = scoreValue == starValue;
                    final theme = Theme.of(context);
                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5),
                      child: ShadowButton(
                        onPressed: () {
                          _scoreScrollController.scrollTo(
                            index: index,
                            alignment: 0.5,
                            duration: const Duration(milliseconds: 200),
                          );
                          updateRatingStatus(scoreValue);
                        },
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                          side: isSelected
                              ? BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 2.0,
                                )
                              : BorderSide.none,
                        ),
                        child: Text(
                          scoreValue == 0
                              ? S.current.Select
                              : scoreValue.toString(),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Field column helper
  // ---------------------------------------------------------------------------
  Widget _fieldColumn(String label, Widget child) {
    return Column(
      children: [
        SB.h10,
        Text(label),
        SB.h10,
        SizedBox(width: double.infinity, child: child),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ADVANCED EDIT WIDGET
  // ---------------------------------------------------------------------------
  Widget _advancedWidget() {
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          // Rewatch / Reread Status
          _sectionHeading(
            isAnime
                ? '${S.current.Rewatch} ${S.current.Status}'
                : '${S.current.Reread} ${S.current.Status}',
            isOpen: isReStatusOpen,
            onChange: () {
              if (mounted) setState(() => isReStatusOpen = !isReStatusOpen);
            },
          ),
          ExpandedSection(
            expand: isReStatusOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: _rewatchWidget(),
            ),
          ),
          // Dates & Priority
          _sectionHeading(
            S.current.Dates_Priority,
            isOpen: isDatesOpen,
            onChange: () {
              if (mounted) setState(() => isDatesOpen = !isDatesOpen);
            },
          ),
          ExpandedSection(
            expand: isDatesOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: _datesWidget(),
            ),
          ),
          // Others
          _sectionHeading(
            S.current.Others,
            isOpen: isOthersOpen,
            onChange: () {
              if (mounted) setState(() => isOthersOpen = !isOthersOpen);
            },
          ),
          ExpandedSection(
            expand: isOthersOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: _othersWidget(),
            ),
          ),
          SB.h10,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section heading with expand/collapse icon
  // ---------------------------------------------------------------------------
  Widget _sectionHeading(
    String heading, {
    bool isOpen = false,
    VoidCallback? onChange,
  }) {
    return InkWell(
      onTap: onChange,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            if (onChange != null)
              Icon(
                isOpen
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                size: 24,
              ),
            const SizedBox(width: 4),
            title(heading, fontSize: 16, fontWeight: FontWeight.w600),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rewatch / Reread widget
  // ---------------------------------------------------------------------------
  Widget _rewatchWidget() {
    final myListStatus = content?.myListStatus;
    final bool rewatchingValue = _isRewatching ??
        (isAnime
            ? (myListStatus?.isRewatching ?? false)
            : false);
    final int timesValue = _timesRewatched ?? 0;
    final int reValue = _rewatchValue ?? 0;

    final List<String> reValueLabels = [
      S.current.Select,
      S.current.Very_Low,
      S.current.Low,
      S.current.Medium,
      S.current.High,
      S.current.Very_High,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Rewatching / Rereading toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isAnime ? S.current.Rewatching : S.current.Rereading),
              _modifyWidget(
                _modifyReStatus,
                Switch(
                  value: rewatchingValue,
                  onChanged: (val) {
                    _modifyReStatus = true;
                    if (isAnime) {
                      updateAdvancedStatus(
                        isRewatching: val,
                        onDone: () => _modifyReStatus = false,
                      );
                    } else {
                      updateAdvancedStatus(
                        isRereading: val,
                        onDone: () => _modifyReStatus = false,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          SB.h5,
          // Times rewatched / reread
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isAnime
                  ? S.current.Times_Rewatched
                  : S.current.Times_Reread),
              _modifyWidget(
                _modifyReStatus,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (timesValue <= 0) return;
                        _modifyReStatus = true;
                        if (isAnime) {
                          updateAdvancedStatus(
                            timesRewatched: timesValue - 1,
                            onDone: () => _modifyReStatus = false,
                          );
                        } else {
                          updateAdvancedStatus(
                            timesReread: timesValue - 1,
                            onDone: () => _modifyReStatus = false,
                          );
                        }
                      },
                      icon: const Icon(Icons.remove, size: 20),
                    ),
                    Text(timesValue.toString()),
                    IconButton(
                      onPressed: () {
                        _modifyReStatus = true;
                        if (isAnime) {
                          updateAdvancedStatus(
                            timesRewatched: timesValue + 1,
                            onDone: () => _modifyReStatus = false,
                          );
                        } else {
                          updateAdvancedStatus(
                            timesReread: timesValue + 1,
                            onDone: () => _modifyReStatus = false,
                          );
                        }
                      },
                      icon: const Icon(Icons.add, size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SB.h5,
          // Rewatch / Reread value dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${isAnime ? S.current.Rewatch : S.current.Reread} ${S.current.Value}',
              ),
              _modifyWidget(
                _modifyReStatus,
                DropdownButton<int>(
                  value: reValue.clamp(0, 5),
                  underline: const SizedBox(),
                  items: List.generate(6, (i) {
                    return DropdownMenuItem<int>(
                      value: i,
                      child: Text(
                        reValueLabels[i],
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }),
                  onChanged: (val) {
                    if (val == null) return;
                    _modifyReStatus = true;
                    if (isAnime) {
                      updateAdvancedStatus(
                        rewatchValue: val,
                        onDone: () => _modifyReStatus = false,
                      );
                    } else {
                      updateAdvancedStatus(
                        rereadValue: val,
                        onDone: () => _modifyReStatus = false,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dates & Priority widget
  // ---------------------------------------------------------------------------
  Widget _datesWidget() {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Start / Finish date row
          Row(
            children: [
              Expanded(
                child: _datePickerField(
                  label: S.current.Start_Date,
                  date: _startDate,
                  isLoading: _modifyStartDate,
                  onPicked: (date) {
                    _modifyStartDate = true;
                    updateAdvancedStatus(
                      startDate: dateFormat.format(date),
                      onDone: () => _modifyStartDate = false,
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _datePickerField(
                  label: S.current.Finish_Date,
                  date: _finishDate,
                  isLoading: _modifyFinishDate,
                  onPicked: (date) {
                    _modifyFinishDate = true;
                    updateAdvancedStatus(
                      finishDate: dateFormat.format(date),
                      onDone: () => _modifyFinishDate = false,
                    );
                  },
                ),
              ),
            ],
          ),
          SB.h15,
          // Priority
          Row(
            children: [
              Flexible(
                child: title(S.current.Priority_level_qn, fontSize: 13),
              ),
              const SizedBox(width: 8),
              _modifyWidget(
                _modifyPriority,
                DropdownButton<int>(
                  value: (_priority ?? 0).clamp(0, 2),
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(value: 0, child: Text(S.current.Low)),
                    DropdownMenuItem(
                        value: 1, child: Text(S.current.Medium)),
                    DropdownMenuItem(value: 2, child: Text(S.current.High)),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    _modifyPriority = true;
                    updateAdvancedStatus(
                      priority: val,
                      onDone: () => _modifyPriority = false,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _datePickerField({
    required String label,
    DateTime? date,
    required bool isLoading,
    required ValueChanged<DateTime> onPicked,
  }) {
    final displayText = date != null
        ? DateFormat('yyyy-MM-dd').format(date)
        : S.current.Select;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title(label, fontSize: 13),
        SB.h5,
        SizedBox(
          height: 44,
          width: double.infinity,
          child: isLoading
              ? Center(child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : ShadowButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(
                        const Duration(days: 365),
                      ),
                    );
                    if (picked != null) {
                      onPicked(picked);
                    }
                  },
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          displayText,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Others widget (Comments, Tags)
  // ---------------------------------------------------------------------------
  Widget _othersWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comments
          title(S.current.Comments, fontSize: 13),
          SB.h5,
          _modifyWidget(
            _modifyComments,
            TextFormField(
              controller: _commentsController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: S.current.Comments,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
              ),
              onFieldSubmitted: (value) {
                _modifyComments = true;
                updateAdvancedStatus(
                  comments: value,
                  onDone: () => _modifyComments = false,
                );
              },
            ),
          ),
          SB.h15,
          // Tags
          title(S.current.Tags, fontSize: 13),
          SB.h5,
          _modifyWidget(
            _modifyTags,
            TextFormField(
              controller: _tagsController,
              decoration: InputDecoration(
                hintText: S.current.Tags,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
              ),
              onFieldSubmitted: (value) {
                _modifyTags = true;
                updateAdvancedStatus(
                  tags: value,
                  onDone: () => _modifyTags = false,
                );
              },
            ),
          ),
          SB.h10,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Delete button
  // ---------------------------------------------------------------------------
  Widget _deleteButtonWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: ShadowButton(
          onPressed: deleteFromList,
          backgroundColor: Colors.red.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.delete_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                S.current.Delete_from_List,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Modify wrapper: shows loading or child
  // ---------------------------------------------------------------------------
  Widget _modifyWidget(bool isModifying, Widget child) {
    if (isModifying) {
      return SizedBox(
        height: 40,
        child: Center(child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return child;
  }
}
