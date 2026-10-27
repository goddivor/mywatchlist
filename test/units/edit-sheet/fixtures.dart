/// MAL `GET /anime|manga/{id}?fields=…` answers as the edit sheet requests them
/// (shape of the real API: partial dates, HTML in comments, tags list).

Map<String, dynamic> completedAnimeJson() => {
      'id': 5114,
      'title': 'Fullmetal Alchemist: Brotherhood',
      'num_episodes': 64,
      'status': 'finished_airing',
      'start_date': '2009-04-05',
      'start_season': {'year': 2009, 'season': 'spring'},
      'my_list_status': {
        'status': 'completed',
        'score': 10,
        'num_episodes_watched': 64,
        'is_rewatching': false,
        'updated_at': '2024-02-10T12:00:00+00:00',
        'priority': 2,
        'num_times_rewatched': 2,
        'rewatch_value': 4,
        'tags': ['shounen', 'Tom &amp; Jerry'],
        'comments': 'Great<br />\nshow &quot;FMA&quot;',
        'start_date': '2019-01-05',
        'finish_date': '2019-03',
      },
    };

Map<String, dynamic> readingMangaJson() => {
      'id': 2,
      'title': 'Berserk',
      'num_chapters': 0,
      'num_volumes': 0,
      'status': 'currently_publishing',
      'start_date': '1989-08-25',
      'my_list_status': {
        'status': 'reading',
        'score': 9,
        'num_chapters_read': 112,
        'num_volumes_read': 12,
        'is_rereading': true,
        'num_times_reread': 1,
        'reread_value': 0,
        'priority': 0,
        'tags': <String>[],
        'comments': '',
        'start_date': '2020-06-01',
        'updated_at': '2024-02-10T12:00:00+00:00',
      },
    };
