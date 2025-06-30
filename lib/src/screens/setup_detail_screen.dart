import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../routes.dart';
import '../services/setup_provider.dart';
import '../models/setup.dart';
import '../widgets/rule_card.dart';

class SetupDetailScreen extends StatelessWidget {
  const SetupDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SetupProvider>(
      builder: (context, setupProvider, child) {
        final setup = setupProvider.selectedSetup;
        
        if (setup == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Detalle del Setup'),
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
            ),
            body: const Center(
              child: Text(
                'Setup no encontrado',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(setup.name),
            backgroundColor: const Color(0xFF1A1A1A),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                onPressed: () => _editSetup(context, setup),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editar setup',
              ),
              IconButton(
                onPressed: () => _showDeleteDialog(context, setup),
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Eliminar setup',
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSetupHeader(setup),
              const SizedBox(height: 16),
              _buildSetupStats(setup),
              const SizedBox(height: 16),
              _buildRulesSection(setup),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSetupHeader(Setup setup) {
    return Card(
      color: const Color(0xFF2A2A2A),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        setup.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        setup.asset,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: setup.useAdvancedRules
                        ? const Color(0xFF21CE99).withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    setup.useAdvancedRules ? 'Avanzado' : 'Básico',
                    style: TextStyle(
                      color: setup.useAdvancedRules
                          ? const Color(0xFF21CE99)
                          : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Creado: ${_formatDate(setup.createdAt)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupStats(Setup setup) {
    return Card(
      color: const Color(0xFF2A2A2A),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.analytics,
                  color: Color(0xFF21CE99),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Configuración de Trading',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Tamaño de Posición',
                    setup.getPositionSizeDisplay(),
                    Icons.account_balance_wallet,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Stop Loss',
                    setup.getStopLossDisplay(),
                    Icons.trending_down,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Take Profit',
                    setup.getTakeProfitDisplay(),
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
         color: color.withValues(alpha: 0.1),
         borderRadius: BorderRadius.circular(8),
         border: Border.all(color: color.withValues(alpha: 0.3)),
       ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRulesSection(Setup setup) {
    if (!setup.useAdvancedRules || setup.rules.isEmpty) {
      return Card(
        color: const Color(0xFF2A2A2A),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.rule,
                    color: Color(0xFF21CE99),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Reglas de Trading',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.rule_outlined,
                      size: 48,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      setup.useAdvancedRules
                          ? 'No hay reglas configuradas'
                          : 'Este setup no usa reglas avanzadas',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: const Color(0xFF2A2A2A),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.rule,
                  color: Color(0xFF21CE99),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Reglas de Trading',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                                     decoration: BoxDecoration(
                     color: const Color(0xFF21CE99).withValues(alpha: 0.2),
                     borderRadius: BorderRadius.circular(12),
                   ),
                  child: Text(
                    '${setup.rules.length} reglas',
                    style: const TextStyle(
                      color: Color(0xFF21CE99),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...setup.rules.map((rule) => RuleCard(
              rule: rule,
              showDeleteButton: false,
            )),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Setup setup) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Eliminar Setup',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '¿Estás seguro de que quieres eliminar el setup "${setup.name}"? Esta acción no se puede deshacer.',
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                context.read<SetupProvider>().deleteSetup(setup.id);
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Setup eliminado'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _editSetup(BuildContext context, Setup setup) {
    Navigator.pushNamed(
      context,
      AppRoutes.setupForm,
      arguments: setup,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} a las ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
} 