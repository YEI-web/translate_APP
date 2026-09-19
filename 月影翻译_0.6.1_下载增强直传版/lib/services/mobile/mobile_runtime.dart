import 'mobile_types.dart';
import 'mobile_runtime_stub.dart'
    if (dart.library.io) 'mobile_runtime_io.dart' as implementation;

export 'mobile_types.dart';

final MobileRuntime mobileRuntime = implementation.createMobileRuntime();
