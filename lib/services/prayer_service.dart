// This file conditionally exports the correct implementation
// On Android/iOS: uses flutter_foreground_task for background playback
// On Windows/Linux: uses direct audio playback
export 'prayer_service_stub.dart'
  if (dart.library.android) 'prayer_service_mobile.dart';
