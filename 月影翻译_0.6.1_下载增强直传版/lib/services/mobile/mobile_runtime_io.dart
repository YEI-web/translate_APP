import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'mobile_types.dart';

MobileRuntime createMobileRuntime() => _IoMobileRuntime();

class _IoMobileRuntime implements MobileRuntime {
  static const _channel = MethodChannel('com.omnitranslate/native');
  final _incomingText = StreamController<MobileIncomingText>.broadcast();
  final _actions = StreamController<MobileAction>.broadcast();
  bool _initialized = false;

  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  Stream<MobileIncomingText> get incomingText => _incomingText.stream;

  @override
  Stream<MobileAction> get actions => _actions.stream;

  @override
  Future<void> initialize() async {
    if (!isAndroid || _initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'incomingText':
          final args = call.arguments;
          if (args is! Map) return;
          final text = (args['text'] as String? ?? '').trim();
          if (text.isEmpty) return;
          _incomingText.add(
            MobileIncomingText(
              text: text,
              source: args['source'] as String? ?? 'android',
            ),
          );
          return;
        case 'mobileAction':
          final action = _parseAction(call.arguments as String?);
          if (action != null) _actions.add(action);
          return;
      }
    });
  }

  @override
  Future<MobileIncomingText?> consumeInitialText() async {
    if (!isAndroid) return null;
    final raw = await _channel.invokeMethod<dynamic>('getInitialText');
    if (raw is! Map) return null;
    final text = (raw['text'] as String? ?? '').trim();
    if (text.isEmpty) return null;
    return MobileIncomingText(
      text: text,
      source: raw['source'] as String? ?? 'android',
    );
  }

  @override
  Future<MobileAction?> consumeInitialAction() async {
    if (!isAndroid) return null;
    final raw = await _channel.invokeMethod<String>('getInitialAction');
    return _parseAction(raw);
  }

  @override
  Future<bool> hasOverlayPermission() async {
    if (!isAndroid) return false;
    return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
  }

  @override
  Future<bool> requestOverlayPermission() async {
    if (!isAndroid) return false;
    return await _channel.invokeMethod<bool>('requestOverlayPermission') ?? false;
  }

  @override
  Future<bool> isOverlayRunning() async {
    if (!isAndroid) return false;
    return await _channel.invokeMethod<bool>('isOverlayRunning') ?? false;
  }

  @override
  Future<bool> startOverlay() async {
    if (!isAndroid) return false;
    return await _channel.invokeMethod<bool>('startOverlay') ?? false;
  }

  @override
  Future<void> stopOverlay() async {
    if (!isAndroid) return;
    await _channel.invokeMethod<void>('stopOverlay');
  }

  @override
  Future<Uint8List?> captureScreen() async {
    if (!isAndroid) return null;
    return _channel.invokeMethod<Uint8List>('captureScreen');
  }

  @override
  Future<String?> recognizeTextLocal(Uint8List imageBytes) async {
    if (!isAndroid || imageBytes.isEmpty) return null;
    final text = await _channel.invokeMethod<String>('recognizeTextLocal', imageBytes);
    final trimmed = text?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<String?> recognizeSpeech({String? languageTag}) async {
    if (!isAndroid) return null;
    final raw = await _channel.invokeMethod<String>(
      'recognizeSpeech',
      {'languageTag': languageTag ?? ''},
    );
    final text = raw?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  @override
  Future<bool> speak(String text, {String? languageTag}) async {
    if (!isAndroid || text.trim().isEmpty) return false;
    return await _channel.invokeMethod<bool>(
          'speak',
          {'text': text, 'languageTag': languageTag ?? ''},
        ) ??
        false;
  }

  @override
  Future<void> stopSpeaking() async {
    if (!isAndroid) return;
    await _channel.invokeMethod<void>('stopSpeaking');
  }

  MobileAction? _parseAction(String? raw) {
    return switch (raw) {
      'screen_translate' => MobileAction.screenTranslate,
      'voice_translate' => MobileAction.voiceTranslate,
      'show_main_window' => MobileAction.showMainWindow,
      _ => null,
    };
  }
}
