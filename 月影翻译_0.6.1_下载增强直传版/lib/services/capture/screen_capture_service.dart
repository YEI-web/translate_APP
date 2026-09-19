import 'capture_types.dart';
import 'screen_capture_stub.dart'
    if (dart.library.io) 'screen_capture_io.dart' as implementation;

export 'capture_types.dart';

final ScreenCaptureService screenCaptureService = implementation.createScreenCaptureService();
