import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:screen_capturer/screen_capturer.dart';

import '../mobile/mobile_runtime.dart';
import 'capture_types.dart';

ScreenCaptureService createScreenCaptureService() => _IoScreenCaptureService();

class _IoScreenCaptureService implements ScreenCaptureService {
  bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  bool get _isAndroid => Platform.isAndroid;

  @override
  bool get isSupported => _isDesktop || _isAndroid;

  @override
  Future<ScreenCaptureResult?> captureRegion() async {
    if (_isAndroid) {
      final bytes = await mobileRuntime.captureScreen();
      return bytes == null ? null : ScreenCaptureResult(bytes: bytes);
    }
    if (!_isDesktop) return null;
    final temp = await getTemporaryDirectory();
    final path = '${temp.path}${Platform.pathSeparator}omnitranslate_capture_${DateTime.now().microsecondsSinceEpoch}.png';
    final captured = await screenCapturer.capture(
      mode: CaptureMode.region,
      imagePath: path,
      copyToClipboard: false,
    );
    if (captured == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return ScreenCaptureResult(bytes: await file.readAsBytes(), path: path);
  }
}
