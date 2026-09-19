#!/usr/bin/env python3
from pathlib import Path
import re, sys
ROOT = Path(__file__).resolve().parents[1]
checks = []

def require(path, label):
    ok = (ROOT/path).exists()
    checks.append((ok, label, str(path)))

require(Path('pubspec.yaml'), 'Flutter 配置')
require(Path('assets/icons/app_icon.jpg'), 'APP 图标')
require(Path('android_patch/app/src/main/AndroidManifest.xml'), 'Android Manifest 补丁')
require(Path('android_patch/app/src/main/kotlin/com/omnitranslate/omnitranslate/MainActivity.kt'), 'Android 原生桥接')
require(Path('tooling/apply_android_patch.py'), 'Android 补丁脚本')
require(Path('tooling/build_android_release.ps1'), 'Windows 一键构建脚本')
require(Path('tooling/build_android_release.sh'), 'macOS/Linux 一键构建脚本')

pubspec=(ROOT/'pubspec.yaml').read_text(encoding='utf-8')
m = re.search(r'^version:\s*([^\s]+)', pubspec, re.M)
version = m.group(1) if m else ''
checks.append((bool(re.fullmatch(r'0\.6\.1\+\d+', version)), '版本号', version or '未找到'))
checks.append(('flutter_launcher_icons' in pubspec, '跨平台图标生成配置', 'flutter_launcher_icons'))
checks.append(('tray_manager: ^0.5.3' in pubspec, 'tray_manager 依赖版本', '^0.5.3'))
checks.append(('llama_flutter_android: ^0.2.6' in pubspec, '本地 llama.cpp Flutter 插件', '^0.2.6'))
manager=(ROOT/'lib/services/local_model/local_ai_model_manager_io.dart').read_text(encoding='utf-8')
checks.append(('connectTimeout: const Duration(seconds: 90)' in manager, '模型下载连接超时配置', '90s'))
checks.append(('modelMirrorUrl' in manager and 'FileAccessMode.append' in manager, '模型镜像与断点续传', 'enabled'))
checks.append(('importLocalAiModel' in manager, '本地 GGUF 手动导入', 'enabled'))
router=(ROOT/'lib/services/engine_router.dart').read_text(encoding='utf-8')
checks.append(("local_qwen" in router, '本地 AI 翻译引擎', 'local_qwen'))
checks.append(("EngineOption('mock'" not in router, '演示引擎已移除', 'mock removed'))
models=(ROOT/'lib/core/models.dart').read_text(encoding='utf-8')
checks.append(('enum TranslationStyle { natural, formal, academic }' in models, '翻译风格数量', '自然/正式/学术'))
patch=(ROOT/'tooling/apply_android_patch.py').read_text(encoding='utf-8')
checks.append(("com.google.mlkit:translate" not in patch and "language-id" not in patch, 'ML Kit Translation 已移除', '仅保留 OCR'))
checks.append(('minSdk = 26' in patch and '27.2.12479018' in patch, '本地 AI Android 运行要求', 'minSdk 26 + NDK r27c'))
manifest=(ROOT/'android_patch/app/src/main/AndroidManifest.xml').read_text(encoding='utf-8')
checks.append(('android:label="月影翻译"' in manifest, 'Android 显示名称', '月影翻译'))

failed=False
for ok,label,detail in checks:
    print(('OK  ' if ok else 'FAIL') + f' {label}: {detail}')
    failed |= not ok
if failed:
    print('\n预检失败。')
    sys.exit(1)
print('\nAndroid APK 源码预检通过。注意：仍需 Flutter/Android SDK 执行真实编译。')
