// Opening the RUI version of a screen from Flutter: a method channel to the
// Android side (android/app/src/main/kotlin/.../MainActivity.kt), which starts
// RuiActivity. Only on Android; elsewhere `available` is false.
import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class RuiBridge {
  static const _channel = MethodChannel('dev.rui/rui');

  static bool get available => Platform.isAndroid;

  static Future<void> open(String screen, {String? theme}) =>
      _channel.invokeMethod('open', {'screen': screen, 'theme': theme});
}
