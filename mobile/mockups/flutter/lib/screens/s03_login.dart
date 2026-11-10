// 03 login -- a form: two fields, a checkbox, a full-width button, a link.
// RUI twin: mobile/mockups/rui/screens/s03_login.nim
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sign in')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Welcome back', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(
                hintText: 'Email', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            const TextField(obscureText: true, decoration: InputDecoration(
                hintText: 'Password', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            Row(children: [
              Checkbox(value: true, onChanged: (_) {}),
              const Text('Remember me'),
            ]),
            const SizedBox(height: 16),
            FilledButton(onPressed: () {}, child: const Text('Sign in')),
            const SizedBox(height: 16),
            Center(child: TextButton(
                onPressed: () {}, child: const Text('Forgot password?'))),
          ]),
        ),
      );
}
