import 'package:flutter_test/flutter_test.dart';
import 'package:video_compress_v2/video_compress_v2.dart';

void main() {
  group('VideoQuality', () {
    test('枚举值', () {
      expect(VideoQuality.values.length, 8);
      expect(VideoQuality.values, contains(VideoQuality.defaultQuality));
      expect(VideoQuality.values, contains(VideoQuality.res1920x1080Quality));
    });
  });
}
