import 'package:flutter/material.dart';
import '../routes.dart';

class SimulationSummaryScreen extends StatelessWidget {
  const SimulationSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen de Simulación'),
      ),
      body: const Center(
        child: Text(
          'Resumen de Simulación',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
} 