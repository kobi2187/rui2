import 'package:flutter/material.dart';
import 'rui_bridge.dart';
import 'screens.dart';

/// Lists the mockup screens; tapping one opens the Flutter version, the
/// button beside it the RUI version (on Android).
void main() => runApp(MaterialApp(
      title: 'RUI mockups (Flutter)',
      theme: mockupTheme(),
      home: const ScreenList(),
    ));

class ScreenList extends StatelessWidget {
  const ScreenList({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mockups')),
        body: ListView(children: [
          for (final entry in screens.entries)
            ListTile(
              title: Text(entry.key),
              trailing: RuiBridge.available
                  ? TextButton(
                      onPressed: () => RuiBridge.open(entry.key),
                      child: const Text('RUI'))
                  : null,
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => entry.value())),
            ),
        ]),
      );
}
