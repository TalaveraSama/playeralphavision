import 'package:flutter/foundation.dart';

/// Media3/custom native channels are Android-only. iOS uses MobileVLCKit.
String playerEngineForPlatform(String saved, TargetPlatform platform) =>
    platform == TargetPlatform.iOS ? 'vlc' : saved;
