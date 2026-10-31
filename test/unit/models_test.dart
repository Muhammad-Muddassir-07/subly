import 'package:flutter_test/flutter_test.dart';
import 'package:subly/data/models/youtube_models.dart';

void main() {
  group('YouTubeSubscription.fromJson', () {
    test('parses channelId, title and thumbnail', () {
      final sub = YouTubeSubscription.fromJson({
        'snippet': {
          'title': 'Sample Channel',
          'resourceId': {'channelId': 'UC123'},
          'thumbnails': {
            'default': {'url': 'https://img/def.jpg'},
            'medium': {'url': 'https://img/med.jpg'},
          },
        },
      });
      expect(sub.channelId, 'UC123');
      expect(sub.title, 'Sample Channel');
      expect(sub.thumbnailUrl, 'https://img/med.jpg');
    });

    test('falls back safely when fields are missing', () {
      final sub = YouTubeSubscription.fromJson({'snippet': {}});
      expect(sub.channelId, '');
      expect(sub.title, 'Unknown channel');
      expect(sub.thumbnailUrl, isNull);
    });
  });

  group('YouTubeVideo', () {
    final playlistItem = {
      'snippet': {
        'title': 'Video A',
        'channelId': 'UC1',
        'channelTitle': 'Chan',
        'publishedAt': '2026-10-01T10:00:00Z',
        'resourceId': {'videoId': 'vid1'},
        'thumbnails': {
          'high': {'url': 'https://img/high.jpg'},
        },
      },
    };

    test('fromPlaylistItem parses core fields', () {
      final v = YouTubeVideo.fromPlaylistItem(playlistItem);
      expect(v.id, 'vid1');
      expect(v.channelId, 'UC1');
      expect(v.publishedAt.toUtc(), DateTime.utc(2026, 10, 1, 10));
      expect(v.thumbnailUrl, 'https://img/high.jpg');
    });

    test('withDetails merges duration and view count', () {
      final v = YouTubeVideo.fromPlaylistItem(playlistItem).withDetails({
        'contentDetails': {'duration': 'PT4M13S'},
        'statistics': {'viewCount': '12345'},
      });
      expect(v.durationIso, 'PT4M13S');
      expect(v.viewCount, 12345);
    });

    test('cache JSON round-trips', () {
      final v = YouTubeVideo.fromPlaylistItem(playlistItem).withDetails({
        'contentDetails': {'duration': 'PT1H2M3S'},
        'statistics': {'viewCount': '7'},
      });
      final back = YouTubeVideo.fromCacheJson(v.toJson());
      expect(back.id, v.id);
      expect(back.title, v.title);
      expect(back.publishedAt, v.publishedAt);
      expect(back.durationIso, v.durationIso);
      expect(back.viewCount, v.viewCount);
    });

    test('fromVideoItem parses full video details', () {
      final v = YouTubeVideo.fromVideoItem({
        'id': 'vid99',
        'snippet': {
          'title': 'Standalone Video',
          'channelId': 'UCstandalone',
          'channelTitle': 'Standalone Channel',
          'publishedAt': '2026-10-02T12:00:00Z',
          'thumbnails': {
            'high': {'url': 'https://img/v99.jpg'},
          },
        },
        'contentDetails': {'duration': 'PT10M'},
        'statistics': {'viewCount': '500'},
      });
      expect(v.id, 'vid99');
      expect(v.channelId, 'UCstandalone');
      expect(v.title, 'Standalone Video');
      expect(v.durationIso, 'PT10M');
      expect(v.viewCount, 500);
    });
  });

  group('YouTubeChannel.fromJson', () {
    test('derives uploads playlist from channelId when missing', () {
      final ch = YouTubeChannel.fromJson({
        'id': 'UC1234567890',
        'snippet': {'title': 'My Channel'},
        'contentDetails': {'relatedPlaylists': {}},
      });
      expect(ch.uploadsPlaylistId, 'UU1234567890');
    });

    test('preserves existing uploads playlist', () {
      final ch = YouTubeChannel.fromJson({
        'id': 'UC1234567890',
        'snippet': {'title': 'My Channel'},
        'contentDetails': {
          'relatedPlaylists': {'uploads': 'UUcustom_uploads'}
        },
      });
      expect(ch.uploadsPlaylistId, 'UUcustom_uploads');
    });
  });

  group('formatIsoDuration', () {
    test('minutes and seconds', () => expect(formatIsoDuration('PT4M5S'), '4:05'));
    test('hours', () => expect(formatIsoDuration('PT1H4M5S'), '1:04:05'));
    test('seconds only', () => expect(formatIsoDuration('PT45S'), '0:45'));
    test('null or empty returns null', () {
      expect(formatIsoDuration(null), isNull);
      expect(formatIsoDuration(''), isNull);
    });
  });
}
