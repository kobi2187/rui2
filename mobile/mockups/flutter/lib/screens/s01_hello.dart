// 01 hello -- one line of text and one button, centred.
// RUI twin: mobile/mockups/rui/screens/s01_hello.nim
import 'package:flutter/material.dart';

class HelloScreen extends StatelessWidget {
  const HelloScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Hello, RUI', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 16),
            FilledButton(onPressed: () {}, child: const Text('Tap me')),
          ]),
        ),
      );
}
