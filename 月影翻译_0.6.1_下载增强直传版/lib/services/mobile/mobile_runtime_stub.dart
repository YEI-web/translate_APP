import 'dart:typed_data';

import 'mobile_types.dart';

MobileRuntime createMobileRuntime() => _StubMobileRuntime();

class _StubMobileRuntime implements MobileRuntime {
  @override
  bool get isAndroid => false;

  @override
  Stream<MobileIncomingText> get incomingText => const Stream.empty();

  @override
  Stream<MobileAction> get actions => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<MobileIncomingText?> consumeInitialText() async => null;

  @override
  Future<MobileAction?> consumeInitialAction() async => null;

  @override
  Future<bool> hasOverlayPermission() async => false;

  @override
  Future<bool> requestOverlayPermission() async => false;

  @override
  Future<bool> isOverlayRunning() async => false;

  @override
  Future<bool> startOverlay() async => false;

  @override
  Future<void> stopOverlay() async {}

  @override
  Future<Uint8List?> captureScreen() async => null;

  @override
  Future<String?> recognizeTextLocal(Uint8List imageBytes) async => null;

  @override
  Future<String?> recognizeSpeech({String? languageTag}) async => null;

  @override
  Future<bool> speak(String text, {String? languageTag}) async => false;

  @override
  Future<void> stopSpeaking() async {}
}
