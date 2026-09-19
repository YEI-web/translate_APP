# 月影翻译 desktop setup

Stage 2 adds real desktop integration for Windows, macOS and Linux.

## Features in this stage

- System tray menu
- Close-to-tray behavior
- Always-on-top quick translation panel
- Global hotkeys
- Clipboard translation
- Region screenshot capture
- Screenshot OCR through the configured AI/OpenAI-compatible vision model
- Translation of OCR text through the currently selected translation engine

## Hotkeys

| Shortcut | Action |
| --- | --- |
| `Alt + Space` | Toggle quick translation panel |
| `Alt + Q` | Translate clipboard text |
| `Alt + A` | Region screenshot -> OCR -> translate |
| `Alt + S` | Subtitle entry point; audio pipeline comes next |
| `Ctrl/Command + Enter` | Translate the current input |

If a shortcut is already reserved by the OS or another application, 月影翻译 keeps running and reports a startup warning. Configurable shortcut recording is planned for a later stage.

## Linux packages

`tray_manager` needs an AppIndicator implementation, and `hotkey_manager` uses keybinder.

On Debian/Ubuntu-family systems, install the equivalent of:

```bash
sudo apt-get install libayatana-appindicator3-dev keybinder-3.0
```

Depending on the desktop environment, the AppIndicator shell extension may also be needed.

## Windows screenshot dependency

`screen_capturer` uses native desktop capture. Its upstream package notes that the Visual Studio installation should include the ATL C++ component used by the current MSVC build tools.

## macOS screenshot permission

macOS may request Screen Recording permission the first time screenshot capture is used. If sandboxing is enabled, follow the `screen_capturer` entitlement guidance when generating the macOS host project.

## Screenshot OCR privacy

The current OCR implementation is a bootstrap path: the captured region is encoded as an image and sent to the AI/OpenAI-compatible endpoint configured in 月影翻译. The model must support image input.

The recognized text is then passed to the translation engine selected in the main UI. For example, OCR can use an AI vision model while the translation itself uses DeepL.

A future stage will add local/system OCR backends so sensitive screenshots can remain on-device.
