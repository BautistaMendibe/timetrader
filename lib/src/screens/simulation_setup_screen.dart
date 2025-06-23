import 'package:flutter/material.dart';
import '../routes.dart';

class SimulationSetupScreen extends StatelessWidget {
  const SimulationSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Simulación'),
      ),
      body: const Center(
        child: Text(
          'Configuración de Simulación',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
} 