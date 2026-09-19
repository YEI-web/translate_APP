import 'dart:typed_data';


class MobileIncomingText {
  const MobileIncomingText({required this.text, required this.source});

  final String text;
  final String source;
}

enum MobileAction {
  screenTranslate,
  voiceTranslate,
  showMainWindow,
}

abstract class MobileRuntime {
  bool get isAndroid;

  Stream<MobileIncomingText> get incomingText;
  Stream<MobileAction> get actions;

  Future<void> initialize();

  Future<MobileIncomingText?> consumeInitialText();
  Future<MobileAction?> consumeInitialAction();

  Future<bool> hasOverlayPermission();

  Future<bool> requestOverlayPermission();

  Future<bool> isOverlayRunning();

  Future<bool> startOverlay();

  Future<void> stopOverlay();

  Future<Uint8List?> captureScreen();

  /// Returns recognized text without sending the image to a network service.
  Future<String?> recognizeTextLocal(Uint8List imageBytes);


  /// Opens the Android speech recognition UI and returns one recognized utterance.
  Future<String?> recognizeSpeech({String? languageTag});

  /// Speaks text using the device text-to-speech engine.
  Future<bool> speak(String text, {String? languageTag});

  Future<void> stopSpeaking();
}
