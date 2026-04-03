import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'subscription.dart';

class CompressMixin {
  final compressProgress$ = ObservableBuilder<CompressProgress>();
  final _channel = const MethodChannel('video_compress');

  @protected
  void initProcessCallback() {
    _channel.setMethodCallHandler(_progressCallback);
  }

  MethodChannel get channel => _channel;

  bool _isCompressing = false;

  bool get isCompressing => _isCompressing;

  void setProcessingStatus(bool status) {
    _isCompressing = status;
  }

  Future<void> _progressCallback(MethodCall call) async {
    switch (call.method) {
      case 'updateProgress':
        if (call.arguments is Map) {
          String unique = call.arguments['unique'] ?? "";
          double progress = call.arguments['progress'] ?? 0;
          compressProgress$
              .next(CompressProgress(unique: unique, progress: progress));
        }
        break;
    }
  }
}

class CompressProgress {
  // 进度
  double progress;
  // 是否压缩完成
  String unique;

  CompressProgress({
    this.progress = 0,
    this.unique = '',
  });
}
