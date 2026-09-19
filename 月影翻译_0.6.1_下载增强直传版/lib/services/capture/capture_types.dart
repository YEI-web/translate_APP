import 'dart:typed_data';

class ScreenCaptureResult {
  const ScreenCaptureResult({required this.bytes, this.path});

  final Uint8List bytes;
  final String? path;
}

abstract class ScreenCaptureService {
  bool get isSupported;
  Future<ScreenCaptureResult?> captureRegion();
}
