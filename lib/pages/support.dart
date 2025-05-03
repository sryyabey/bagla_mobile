import 'package:flutter/material.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Destek'),
      ),
      body: const Center(
        child: Text('Destek sayfası burada olacak.'),
      ),
    );
  }
}
