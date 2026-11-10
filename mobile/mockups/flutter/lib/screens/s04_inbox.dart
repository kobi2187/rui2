// 04 inbox -- app bar, a list of conversations, a FAB, bottom navigation.
// RUI twin: mobile/mockups/rui/screens/s04_inbox.nim
import 'package:flutter/material.dart';

const people = [
  ('Ada Lovelace', 'Notes on the analytical engine'),
  ('Alan Turing', 'Re: computable numbers'),
  ('Grace Hopper', 'Found a moth in relay 70'),
  ('Edsger Dijkstra', 'Goto considered harmful'),
  ('Barbara Liskov', 'Substitution, revisited'),
  ('Donald Knuth', 'Volume 4B is out'),
];

String initials(String name) =>
    name.split(' ').map((w) => w[0]).take(2).join();

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
          title: const Text('Inbox'),
        ),
        body: ListView(children: [
          for (final (name, line) in people)
            ListTile(
              leading: CircleAvatar(child: Text(initials(name))),
              title: Text(name),
              subtitle: Text(line),
            ),
        ]),
        floatingActionButton: FloatingActionButton(
            onPressed: () {}, child: const Icon(Icons.edit)),
        bottomNavigationBar: NavigationBar(destinations: const [
          NavigationDestination(
              icon: Badge(label: Text('3'), child: Icon(Icons.mail)), label: 'Mail'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Contacts'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ]),
      );
}
