import 'package:flutter/material.dart';
import '../routes.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TimeTrader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              // TODO: Implement menu
            },
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
              'Continúa mejorando tus habilidades de trading',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),

            // Last Simulation Card
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
                          Icons.history,
                          color: Color(0xFF21CE99),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Última Simulación',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No hay simulaciones recientes',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
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