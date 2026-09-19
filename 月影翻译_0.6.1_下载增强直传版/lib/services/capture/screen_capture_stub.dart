import 'capture_types.dart';

ScreenCaptureService createScreenCaptureService() => _StubScreenCaptureService();

class _StubScreenCaptureService implements ScreenCaptureService {
  @override
  bool get isSupported => false;

  @override
  Future<ScreenCaptureResult?> captureRegion() async => null;
}
