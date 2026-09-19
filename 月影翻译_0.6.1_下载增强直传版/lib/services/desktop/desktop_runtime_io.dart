import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_types.dart';

DesktopRuntime createDesktopRuntime() => _DesktopRuntimeIo();

class _DesktopRuntimeIo with TrayListener, WindowListener implements DesktopRuntime {
  final _actions = StreamController<DesktopAction>.broadcast();
  final _mode = ValueNotifier<DesktopWindowMode>(DesktopWindowMode.main);
  final List<String> _warnings = [];
  bool _initialized = false;
  bool _exiting = false;

  bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  bool get isSupported => _isDesktop;

  @override
  Stream<DesktopAction> get actions => _actions.stream;

  @override
  ValueListenable<DesktopWindowMode> get mode => _mode;

  @override
  List<String> get startupWarnings => List.unmodifiable(_warnings);

  @override
  Future<void> initialize() async {
    if (!_isDesktop || _initialized) return;
    _initialized = true;

    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    trayManager.addListener(this);

    const options = WindowOptions(
      size: Size(1120, 760),
      minimumSize: Size(520, 420),
      center: true,
      title: '月影翻译',
      skipTaskbar: false,
    );
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    });

    await _initTray();
    await _initHotKeys();
  }

  Future<void> _initTray() async {
    try {
      await trayManager.setIcon(Platform.isWindows ? 'assets/tray_icon.ico' : 'assets/tray_icon.png');
      if (!Platform.isLinux) await trayManager.setToolTip('月影翻译');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'quick_panel', label: '快速翻译'),
            MenuItem(key: 'clipboard_translate', label: '翻译剪贴板'),
            MenuItem(key: 'screen_translate', label: '截图翻译'),
            MenuItem.separator(),
            MenuItem(key: 'show_main', label: '打开主窗口'),
            MenuItem.separator(),
            MenuItem(key: 'exit', label: '退出 月影翻译'),
          ],
        ),
      );
    } catch (error) {
      _warnings.add('系统托盘初始化失败：$error');
    }
  }

  Future<void> _initHotKeys() async {
    try {
      await hotKeyManager.unregisterAll();
    } catch (_) {}

    await _registerHotKey(
      HotKey(key: PhysicalKeyboardKey.space, modifiers: [HotKeyModifier.alt]),
      DesktopAction.toggleQuickPanel,
      'Alt+Space',
    );
    await _registerHotKey(
      HotKey(key: PhysicalKeyboardKey.keyQ, modifiers: [HotKeyModifier.alt]),
      DesktopAction.translateClipboard,
      'Alt+Q',
    );
    await _registerHotKey(
      HotKey(key: PhysicalKeyboardKey.keyA, modifiers: [HotKeyModifier.alt]),
      DesktopAction.screenTranslate,
      'Alt+A',
    );
    await _registerHotKey(
      HotKey(key: PhysicalKeyboardKey.keyS, modifiers: [HotKeyModifier.alt]),
      DesktopAction.toggleSubtitles,
      'Alt+S',
    );
  }

  Future<void> _registerHotKey(HotKey hotKey, DesktopAction action, String label) async {
    try {
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (_) => perform(action),
      );
    } catch (error) {
      _warnings.add('$label 全局快捷键注册失败：$error');
    }
  }

  @override
  Future<void> perform(DesktopAction action) async {
    if (!_isDesktop) return;
    switch (action) {
      case DesktopAction.toggleQuickPanel:
        if (_mode.value == DesktopWindowMode.quickPanel) {
          await showMainWindow();
        } else {
          await showQuickPanel();
        }
        _actions.add(action);
        return;
      case DesktopAction.translateClipboard:
        await showQuickPanel();
        _actions.add(action);
        return;
      case DesktopAction.screenTranslate:
        await hideWindow();
        _actions.add(action);
        return;
      case DesktopAction.toggleSubtitles:
        _actions.add(action);
        return;
      case DesktopAction.showMainWindow:
        await showMainWindow();
        _actions.add(action);
        return;
    }
  }

  @override
  Future<void> showMainWindow() async {
    if (!_isDesktop) return;
    _mode.value = DesktopWindowMode.main;
    await windowManager.setSkipTaskbar(false);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(const Size(520, 420));
    await windowManager.setSize(const Size(1120, 760), animate: true);
    await windowManager.center(animate: true);
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> showQuickPanel() async {
    if (!_isDesktop) return;
    _mode.value = DesktopWindowMode.quickPanel;
    await windowManager.setSkipTaskbar(true);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setResizable(false);
    await windowManager.setMinimumSize(const Size(560, 480));
    await windowManager.setSize(const Size(560, 480), animate: true);
    try {
      final cursor = await screenRetriever.getCursorScreenPoint();
      await windowManager.setPosition(Offset(cursor.dx + 18, cursor.dy + 18), animate: true);
    } catch (_) {
      await windowManager.center(animate: true);
    }
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> hideWindow() async {
    if (_isDesktop) await windowManager.hide();
  }

  @override
  Future<void> exitApp() async {
    if (!_isDesktop || _exiting) return;
    _exiting = true;
    try {
      await hotKeyManager.unregisterAll();
    } catch (_) {}
    try {
      await trayManager.destroy();
    } catch (_) {}
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  @override
  void onWindowClose() async {
    if (_exiting) return;
    await hideWindow();
  }

  @override
  void onTrayIconMouseDown() {
    showQuickPanel();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'quick_panel':
        perform(DesktopAction.toggleQuickPanel);
        break;
      case 'clipboard_translate':
        perform(DesktopAction.translateClipboard);
        break;
      case 'screen_translate':
        perform(DesktopAction.screenTranslate);
        break;
      case 'show_main':
        perform(DesktopAction.showMainWindow);
        break;
      case 'exit':
        exitApp();
        break;
    }
  }
}
