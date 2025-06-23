import 'package:flutter/material.dart';
import '../routes.dart';

class SetupDetailScreen extends StatelessWidget {
  const SetupDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Setup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.setupForm),
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Detalle del Setup',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
} 