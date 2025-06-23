import 'package:flutter/material.dart';
import '../routes.dart';

class SetupsListScreen extends StatelessWidget {
  const SetupsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Setups'),
      ),
      body: const Center(
        child: Text(
          'Lista de Setups',
          style: TextStyle(color: Colors.white),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.setupForm),
        backgroundColor: const Color(0xFF21CE99),
        child: const Icon(Icons.add),
      ),
    );
  }
} 