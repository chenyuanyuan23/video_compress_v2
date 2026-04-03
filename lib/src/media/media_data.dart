abstract class Enum<T> {
  final T _value;

  const Enum(this._value);

  T get value => _value;
}

class MediaMetadataRetriever<T> extends Enum<T> {
  /// [Android] API level 10
  static const metadataKeyAlbum = MediaMetadataRetriever(1);
  static const metadataKeyAlbumartist = MediaMetadataRetriever(13);
  static const metadataKeyArtist = MediaMetadataRetriever(2);
  static const metadataKeyAuthor = MediaMetadataRetriever(3);
  static const metadataKeyBitrate = MediaMetadataRetriever(20);
  static const metadataKeyCaptureFramerate = MediaMetadataRetriever(25);
  static const metadataKeyCdTrackNumber = MediaMetadataRetriever(0);
  static const metadataKeyCompilation = MediaMetadataRetriever(15);
  static const metadataKeyComposer = MediaMetadataRetriever(4);
  static const metadataKeyDate = MediaMetadataRetriever(5);
  static const metadataKeyDiscNumber = MediaMetadataRetriever(14);
  static const metadataKeyDuration = MediaMetadataRetriever(9);
  static const metadataKeyExifLength = MediaMetadataRetriever(34);
  static const metadataKeyExifOffset = MediaMetadataRetriever(33);
  static const metadataKeyGenre = MediaMetadataRetriever(6);
  static const metadataKeyHasAudio = MediaMetadataRetriever(16);
  static const metadataKeyHasImage = MediaMetadataRetriever(26);
  static const metadataKeyHasVideo = MediaMetadataRetriever(17);
  static const metadataKeyImageCount = MediaMetadataRetriever(27);
  static const metadataKeyImageHeight = MediaMetadataRetriever(30);
  static const metadataKeyImagePrimary = MediaMetadataRetriever(28);
  static const metadataKeyImageRotation = MediaMetadataRetriever(31);
  static const metadataKeyImageWidth = MediaMetadataRetriever(29);
  static const metadataKeyLocation = MediaMetadataRetriever(23);
  static const metadataKeyMimetype = MediaMetadataRetriever(12);
  static const metadataKeyNumTracks = MediaMetadataRetriever(10);
  static const metadataKeyTitle = MediaMetadataRetriever(7);
  static const metadataKeyVideoFrameCount = MediaMetadataRetriever(32);
  static const metadataKeyVideoHeight = MediaMetadataRetriever(19);
  static const metadataKeyVideoRotation = MediaMetadataRetriever(24);
  static const metadataKeyVideoWidth = MediaMetadataRetriever(18);
  static const metadataKeyWriter = MediaMetadataRetriever(11);
  static const metadataKeyYear = MediaMetadataRetriever(8);

  const MediaMetadataRetriever(super.value);
}
