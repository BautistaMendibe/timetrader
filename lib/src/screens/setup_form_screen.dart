import 'package:flutter/material.dart';
import '../routes.dart';

class SetupFormScreen extends StatelessWidget {
  const SetupFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Setup'),
      ),
      body: const Center(
        child: Text(
          'Formulario de Setup',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
} 