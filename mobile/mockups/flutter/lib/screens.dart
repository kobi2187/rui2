// The Flutter side of the mobile mockup ladder (mobile/README.md). Each entry
// has an RUI twin of the same name in mobile/mockups/rui/screens/.
import 'package:flutter/material.dart';
import 'screens/s01_hello.dart';
import 'screens/s02_counter.dart';
import 'screens/s03_login.dart';
import 'screens/s04_inbox.dart';

final screens = <String, Widget Function()>{
  '01_hello': () => const HelloScreen(),
  '02_counter': () => const CounterScreen(),
  '03_login': () => const LoginScreen(),
  '04_inbox': () => const InboxScreen(),
};

/// Material 3 baseline, Roboto: what `ThemeData()` gives a new app on Android.
ThemeData mockupTheme() => ThemeData(useMaterial3: true, fontFamily: 'Roboto');
