import 'desktop_types.dart';
import 'desktop_runtime_stub.dart'
    if (dart.library.io) 'desktop_runtime_io.dart' as implementation;

export 'desktop_types.dart';

final DesktopRuntime desktopRuntime = implementation.createDesktopRuntime();
