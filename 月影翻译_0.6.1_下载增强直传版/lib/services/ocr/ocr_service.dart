import 'dart:typed_data';

import '../../core/models.dart';
import '../app_settings_repository.dart';
import '../mobile/mobile_runtime.dart';
import 'vision_ocr_service.dart';

class OcrService {
  OcrService(this.settingsRepository);

  final AppSettingsRepository settingsRepository;

  Future<String> recognize(Uint8List imageBytes, AppSettings settings) async {
    Object? localError;

    if (mobileRuntime.isAndroid && settings.androidUseLocalOcr) {
      try {
        final local = await mobileRuntime.recognizeTextLocal(imageBytes);
        if (local != null && local.trim().isNotEmpty) return local.trim();
        localError = const OcrException('本地 OCR 没有识别到文字。');
      } catch (error) {
        localError = error;
      }

      if (!settings.androidAllowCloudOcrFallback) {
        if (localError is OcrException) throw localError;
        throw OcrException('Android 本地 OCR 失败：$localError');
      }
    }

    try {
      return await VisionOcrService(settingsRepository).recognize(imageBytes, settings);
    } on OcrException {
      if (localError != null) {
        throw OcrException('本地 OCR 失败（$localError），云端 OCR 也不可用。请检查 AI OCR 配置，或关闭云端回退。');
      }
      rethrow;
    }
  }
}
