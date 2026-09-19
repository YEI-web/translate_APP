import 'package:flutter/foundation.dart';

enum DesktopAction {
  toggleQuickPanel,
  translateClipboard,
  screenTranslate,
  toggleSubtitles,
  showMainWindow,
}

enum DesktopWindowMode { main, quickPanel }

abstract class DesktopRuntime {
  bool get isSupported;
  Stream<DesktopAction> get actions;
  ValueListenable<DesktopWindowMode> get mode;
  List<String> get startupWarnings;

  Future<void> initialize();
  Future<void> perform(DesktopAction action);
  Future<void> showMainWindow();
  Future<void> showQuickPanel();
  Future<void> hideWindow();
  Future<void> exitApp();
}
