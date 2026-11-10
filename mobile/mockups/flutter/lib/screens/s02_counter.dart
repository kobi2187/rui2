// 02 counter -- the Flutter starter app: an app bar, a count, a FAB.
// RUI twin: mobile/mockups/rui/screens/s02_counter.nim
import 'package:flutter/material.dart';

class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});
  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Counter')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('You have pushed the button this many times:',
                style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Text('$_count', style: const TextStyle(fontSize: 45)),
          ]),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => setState(() => _count++),
          child: const Icon(Icons.add),
        ),
      );
}
