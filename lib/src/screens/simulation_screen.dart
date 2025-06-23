import 'package:flutter/material.dart';
import '../routes.dart';

class SimulationScreen extends StatelessWidget {
  const SimulationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulación'),
      ),
      body: const Center(
        child: Text(
          'Pantalla de Simulación',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
} 