import 'package:flutter/material.dart';

class ThemesPage extends StatelessWidget {
  const ThemesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Temalar'),
      ),
      body: const Center(
        child: Text('Tema seçimi yakında eklenecek.'),
      ),
    );
  }
}
