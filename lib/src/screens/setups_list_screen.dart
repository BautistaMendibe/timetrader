import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../routes.dart';
import '../services/setup_provider.dart';
import '../models/setup.dart';
import '../models/rule.dart';
import '../widgets/top_snack_bar.dart';

class SetupsListScreen extends StatefulWidget {
  const SetupsListScreen({super.key});

  @override
  State<SetupsListScreen> createState() => _SetupsListScreenState();
}

class _SetupsListScreenState extends State<SetupsListScreen> {
  @override
  void initState() {
    super.initState();
    // Iniciar la escucha de cambios en los setups
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SetupProvider>().startListening();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Setups'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
      ),
      body: Consumer<SetupProvider>(
        builder: (context, setupProvider, child) {
          // Mostrar snackbar si se eliminó un setup
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (setupProvider.lastDeletedSetupName != null) {
              final setupName = setupProvider.lastDeletedSetupName!;
              setupProvider.clearLastDeletedSetupName();
              
              TopSnackBar.showSuccess(
                context: context,
                message: 'Setup "$setupName" eliminado exitosamente',
                duration: const Duration(seconds: 3),
              );
            }
          });
          if (setupProvider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF21CE99)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Cargando setups...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          if (setupProvider.setups.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_chart,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No tienes setups creados',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Crea tu primer setup para comenzar',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: setupProvider.setups.length,
            itemBuilder: (context, index) {
              final setup = setupProvider.setups[index];
              return _SetupCard(setup: setup);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.setupForm),
        backgroundColor: const Color(0xFF21CE99),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  final Setup setup;

  const _SetupCard({required this.setup});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF2A2A2A),
      child: InkWell(
        onTap: () {
          context.read<SetupProvider>().selectSetup(setup);
          Navigator.pushNamed(context, AppRoutes.setupDetail);
        },
        borderRadius: BorderRadius.circular(12),
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
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          setup.asset,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      if (setup.isExample)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Ejemplo',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
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
                ],
              ),
              const SizedBox(height: 16),
              _buildSetupStats(),
              if (setup.rules.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildRulesSection(),
              ],
              const SizedBox(height: 12),
              _buildSetupFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetupStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            'Posición',
            setup.getPositionSizeDisplay(),
            Icons.account_balance_wallet,
          ),
        ),
        Expanded(
          child: _buildStatItem(
            'Stop Loss',
            setup.getStopLossDisplay(),
            Icons.trending_down,
            color: Colors.red,
          ),
        ),
        Expanded(
          child: _buildStatItem(
            'Take Profit',
            setup.getTakeProfitDisplay(),
            Icons.trending_up,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(
          icon,
          color: color ?? Colors.grey[400],
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildRulesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.rule,
              color: Color(0xFF21CE99),
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Reglas (${setup.rules.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF21CE99),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...setup.rules.take(3).map((rule) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Icon(
                _getRuleIcon(rule.type),
                size: 12,
                color: Colors.grey[400],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rule.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        )),
        if (setup.rules.length > 3)
          Text(
            '+${setup.rules.length - 3} más',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildSetupFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Creado: ${_formatDate(setup.createdAt)}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
      ],
    );
  }

  IconData _getRuleIcon(RuleType type) {
    switch (type) {
      case RuleType.technicalIndicator:
        return Icons.trending_up;
      case RuleType.candlestickPattern:
        return Icons.candlestick_chart;
      case RuleType.timeFrame:
        return Icons.schedule;
      case RuleType.other:
        return Icons.settings;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
} 