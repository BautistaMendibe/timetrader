import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../routes.dart';
import '../services/simulation_provider.dart';
import '../models/simulation_result.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al cerrar sesión'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('TimeTrader'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _signOut(context);
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text('Cerrar Sesión'),
                  ],
                ),
              ),
            ],
            child: CircleAvatar(
              backgroundColor: const Color(0xFF21CE99),
              child: Text(
                user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Text(
              '¡Bienvenido de vuelta!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? 'Usuario',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[400],
              ),
            ),
            if (user?.displayName != null) ...[
              const SizedBox(height: 4),
              Text(
                user!.displayName!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF21CE99),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Last Simulation Card
            Consumer<SimulationProvider>(
              builder: (context, simulationProvider, child) {
                final history = simulationProvider.simulationHistory;
                
                return Card(
                  color: const Color(0xFF2C2C2C),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.history,
                              color: Color(0xFF21CE99),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Últimas Simulaciones',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (history.isEmpty)
                          Text(
                            'No hay simulaciones recientes',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[400],
                            ),
                          )
                        else
                          Column(
                            children: history.reversed.take(3).map((simulation) {
                              return _buildSimulationHistoryItem(context, simulation);
                            }).toList(),
                          ),
                        if (history.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextButton(
                              onPressed: () {
                                // TODO: Navigate to full history screen
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Historial completo próximamente')),
                                );
                              },
                              child: Text(
                                'Ver todas (${history.length})',
                                style: const TextStyle(color: Color(0xFF21CE99)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Weekly Challenges
            Card(
              color: const Color(0xFF2C2C2C),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Color(0xFF21CE99),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Retos Semanales',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildChallengeItem('Completa 5 simulaciones', 2, 5),
                    const SizedBox(height: 8),
                    _buildChallengeItem('Alcanza 60% win rate', 1, 1),
                    const SizedBox(height: 8),
                    _buildChallengeItem('Reduce drawdown a 5%', 0, 1),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quick Actions
            Text(
              'Acciones Rápidas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    'Nuevo Setup',
                    Icons.add_chart,
                    () => Navigator.pushNamed(context, AppRoutes.setupForm),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    'Mis Setups',
                    Icons.list_alt,
                    () => Navigator.pushNamed(context, AppRoutes.setupsList),
                  ),
                ),
              ],
            ),

            // Test Chart Button (Temporary)
            Card(
              color: const Color(0xFF2C2C2C),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bug_report,
                          color: Color(0xFFFF5A5F),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Debug - Test Chart',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.testChart);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5A5F),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Probar Gráfico TradingView'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.simulationSetup),
        backgroundColor: const Color(0xFF21CE99),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Nueva Simulación'),
      ),
    );
  }

  Widget _buildSimulationHistoryItem(BuildContext context, SimulationResult simulation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          // Navigate to simulation summary
          Navigator.pushNamed(context, AppRoutes.simulationSummary);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: simulation.netPnL >= 0 ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                simulation.netPnL >= 0 ? Icons.trending_up : Icons.trending_down,
                color: simulation.netPnL >= 0 ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${simulation.startDate.day}/${simulation.startDate.month}/${simulation.startDate.year}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${simulation.totalTrades} trades • ${(simulation.winRate * 100).toStringAsFixed(1)}% win rate',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${simulation.netPnL.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: simulation.netPnL >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${(simulation.maxDrawdown * 100).toStringAsFixed(1)}% DD',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeItem(String title, int completed, int total) {
    return Row(
      children: [
        Icon(
          completed >= total ? Icons.check_circle : Icons.radio_button_unchecked,
          color: completed >= total ? const Color(0xFF21CE99) : Colors.grey[600],
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: completed >= total ? Colors.white : Colors.grey[400],
              decoration: completed >= total ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        Text(
          '$completed/$total',
          style: TextStyle(
            color: completed >= total ? const Color(0xFF21CE99) : Colors.grey[400],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      color: const Color(0xFF2C2C2C),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(
                icon,
                color: const Color(0xFF21CE99),
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 