# Desktop overlay module

Implemented in Stage 2:

- System tray lifecycle
- Close-to-tray behavior
- Main window / compact quick-panel switching
- Always-on-top quick panel
- Cursor-adjacent quick-panel placement
- Global shortcuts
- Clipboard translation command
- Region screenshot capture command

Still planned:

- True selected-text capture and popup positioning
- Floating orb mode
- Click-through subtitle strip
- Adjustable overlay opacity
- Per-application blacklist
- Local/system OCR
- Streaming subtitle rendering

Desktop infrastructure lives in `lib/services/desktop/`; region capture lives in `lib/services/capture/`.
