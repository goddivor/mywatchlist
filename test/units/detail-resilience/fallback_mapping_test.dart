import 'package:flutter_test/flutter_test.dart';
import 'package:mwl_commons/mwl_commons.dart'
    show ContentCharacterHtml, ImageSet, ReviewHtml, StaffMemberHtml, VoiceActorHtml;
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';

void main() {
  test('a MAL page review becomes a Jikan review', () {
    final review = reviewFromHtml(const ReviewHtml(
      id: 42,
      username: 'alice',
      userPicture: ImageSet(large: 'https://cdn/a.jpg'),
      timeAdded: 'Oct 27, 2026',
      overallRating: '9',
      reviewText: 'Great',
      tags: ['Recommended', 'Preliminary'],
      reactions: {'Nice': 3, 'Love it': 2, 'Well-written': 1},
    ));
    expect(review.malId, 42);
    expect(review.user?.username, 'alice');
    expect(review.user?.images?.jpg?.imageUrl, 'https://cdn/a.jpg');
    expect(DateTime.parse(review.date!), DateTime(2026, 10, 27));
    expect(review.score, 9);
    expect(review.isPreliminary, isTrue);
    expect(review.reactions?.nice, 3);
    expect(review.reactions?.loveIt, 2);
    expect(review.reactions?.wellWritten, 1);
    expect(review.reactions?.overall, 6);
  });

  test('an unreadable date or score stays empty', () {
    final review = reviewFromHtml(const ReviewHtml(timeAdded: 'yesterday', overallRating: '?'));
    expect(review.date, isNull);
    expect(review.score, isNull);
  });

  test('a MAL forum topic becomes a Jikan topic', () {
    final topic = forumFromMal(ForumTopicsData(
      id: 7,
      title: 'Episode 1 discussion',
      createdAt: DateTime.utc(2026, 1, 2),
      createdBy: ForumUser(name: 'mod'),
      numberOfPosts: 120,
      lastPostCreatedBy: ForumUser(name: 'bob'),
      lastPostTimeText: '10 minutes ago',
    ));
    expect(topic.malId, 7);
    expect(topic.title, 'Episode 1 discussion');
    expect(topic.authorUsername, 'mod');
    expect(topic.comments, 120);
    expect(DateTime.parse(topic.date!), DateTime.utc(2026, 1, 2));
    expect(topic.lastComment?.authorUsername, 'bob');
    expect(topic.lastComment?.date, '10 minutes ago');
  });

  test('characters and staff of the MAL page become Jikan models', () {
    final character = characterFromHtml(const ContentCharacterHtml(
      id: 1,
      name: 'Hero',
      role: 'Main',
      favorites: 5,
      image: ImageSet(medium: 'https://cdn/c.jpg'),
      voiceActors: [VoiceActorHtml(id: 9, name: 'Actor', language: 'Japanese')],
    ));
    expect(character.character.malId, 1);
    expect(character.character.images?.jpg?.imageUrl, 'https://cdn/c.jpg');
    expect(character.role, 'Main');
    expect(character.favorites, 5);
    expect(character.voiceActors?.single.person?.name, 'Actor');
    expect(character.voiceActors?.single.language, 'Japanese');

    final staff = staffFromHtml(const StaffMemberHtml(id: 3, name: 'Director', role: 'Director, Storyboard'));
    expect(staff.person.malId, 3);
    expect(staff.positions, ['Director', 'Storyboard']);
  });
}
