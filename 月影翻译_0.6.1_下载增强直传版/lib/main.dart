import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/desktop/desktop_runtime.dart';
import 'services/mobile/mobile_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await desktopRuntime.initialize();
  await mobileRuntime.initialize();
  runApp(const ProviderScope(child: MoonShadowTranslateApp()));
}
