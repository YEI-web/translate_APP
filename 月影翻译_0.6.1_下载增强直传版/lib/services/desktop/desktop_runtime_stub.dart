import 'dart:async';

import 'package:flutter/foundation.dart';

import 'desktop_types.dart';

DesktopRuntime createDesktopRuntime() => _StubDesktopRuntime();

class _StubDesktopRuntime implements DesktopRuntime {
  final _actions = StreamController<DesktopAction>.broadcast();
  final _mode = ValueNotifier<DesktopWindowMode>(DesktopWindowMode.main);

  @override
  bool get isSupported => false;

  @override
  Stream<DesktopAction> get actions => _actions.stream;

  @override
  ValueListenable<DesktopWindowMode> get mode => _mode;

  @override
  List<String> get startupWarnings => const [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> perform(DesktopAction action) async {
    _actions.add(action);
  }

  @override
  Future<void> showMainWindow() async {
    _mode.value = DesktopWindowMode.main;
  }

  @override
  Future<void> showQuickPanel() async {
    _mode.value = DesktopWindowMode.quickPanel;
  }

  @override
  Future<void> hideWindow() async {}

  @override
  Future<void> exitApp() async {}
}
