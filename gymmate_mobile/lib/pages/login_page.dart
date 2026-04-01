import 'package:flutter/material.dart';
import 'package:gymmate_mobile/pages/gamified_entry_screen.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const GamifiedEntryScreen(initialState: EntryState.login);
  }
}
