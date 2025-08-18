import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../routes.dart';
import '../services/simulation_provider.dart';
import '../services/setup_provider.dart';
import '../services/navigation_provider.dart';
import '../models/simulation_result.dart';
import '../models/setup.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1220), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // AppBar / Header
                _buildHeader(user),

                // Subtítulo de bienvenida
                _buildWelcomeSubtitle(user),

                // Banner continuar (si hay sesión activa)
                if (user != null) _buildContinueBanner(),

                // Card fija de simulación
                if (user != null) _buildSimulationCard(),

                // Mis setups
                if (user != null) _buildMySetups(),

                // Mis simulaciones
                if (user != null) _buildMySimulations(),

                const SizedBox(
                  height: 20,
                ), // Reduced space since bottom nav is handled by MainNavigation
              ],
            ),
          ),
        ),
      ),
      // Bottom navigation is now handled by MainNavigation
    );
  }

  Widget _buildHeader(User? user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Logo and App Name
          Row(
            children: [
              Image.asset('assets/imgs/icono.png', height: 40, width: 45),
              const SizedBox(width: 12),
              const Text(
                'TimeTrader',
                style: TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const Spacer(),
          // Iconos de notificación y ajustes
          IconButton(
            onPressed: () {
              // TODO: Implementar notificaciones
            },
            icon: const Icon(
              Icons.notifications_outlined,
              color: Color(0xFF94A3B8),
              size: 24,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.settings_outlined,
              color: Color(0xFF94A3B8),
              size: 24,
            ),
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(
                      Icons.settings_outlined,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Ajustes',
                      style: TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(
                      Icons.logout,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'settings') {
                // TODO: Implementar ajustes
              } else if (value == 'logout') {
                await _handleLogout();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSubtitle(User? user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hola, ${user?.displayName ?? 'Usuario'} 👋',
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Practica y mejora tus setups.',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueBanner() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withValues(alpha: 0.18),
            offset: const Offset(0, 16),
            blurRadius: 32,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_outline, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Nueva simulación',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F2937), Color(0xFF111827)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF374151), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            offset: const Offset(0, 8),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.timeline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Simulación EUR/USD — H1',
                  style: TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '65% completado',
            style: TextStyle(
              color: Color(0xFF22C55E),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),
          // Barra de progreso
          LinearProgressIndicator(
            value: 0.65,
            backgroundColor: const Color(0xFF374151),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
            borderRadius: BorderRadius.circular(4),
            minHeight: 8,
          ),
          const SizedBox(height: 20),
          // Botones
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implementar continuar simulación
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Continuar',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    // TODO: Descartar simulación
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Descartar',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Métricas rápidas
          SizedBox(
            height: 130,
            child: ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              children: [
                SizedBox(
                  width: 110,
                  child: _buildMetricCard('P/L', '\$2,450', '+12.5%', true),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: _buildMetricCard('Win-rate', '68%', '+5.2%', true),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: _buildMetricCard('Max DD', '8.3%', '-2.1%', false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String change,
    bool isPositive,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF374151), Color(0xFF1F2937)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPositive
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : const Color(0xFFEF4444).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isPositive
                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                : const Color(0xFFEF4444).withValues(alpha: 0.1),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF111827).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF4B5563).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              gradient: isPositive
                  ? const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: isPositive
                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                      : const Color(0xFFEF4444).withValues(alpha: 0.2),
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                  spreadRadius: -1,
                ),
              ],
            ),
            child: Text(
              change,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMySimulations() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mis simulaciones',
                style: TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to simulation tab in main navigation
                  context.read<NavigationProvider>().goToSimulation();
                },
                child: const Text(
                  'Ver todas',
                  style: TextStyle(
                    color: Color(0xFF22C55E),
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Consumer<SimulationProvider>(
            builder: (context, simulationProvider, child) {
              final simulations = simulationProvider.simulationHistory
                  .take(3)
                  .toList();

              if (simulations.isEmpty) {
                return _buildEmptyState(
                  'No hay simulaciones',
                  'Crea tu primera simulación',
                );
              }

              return Column(
                children: simulations
                    .map((simulation) => _buildSimulationListItem(simulation))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationListItem(SimulationResult simulation) {
    return Dismissible(
      key: Key(simulation.id),
      background: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(width: 20),
            Icon(Icons.copy, color: Colors.white),
            SizedBox(width: 8),
            Text('Duplicar', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Eliminar', style: TextStyle(color: Colors.white)),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.white),
            SizedBox(width: 20),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          return await _showDeleteConfirmation();
        }
        // TODO: Implementar duplicar
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          // TODO: Eliminar simulación
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF374151), Color(0xFF1F2937)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF4B5563), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              offset: const Offset(0, 6),
              blurRadius: 16,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EUR/USD • H1',
                    style: const TextStyle(
                      color: Color(0xFFF8FAFC),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${simulation.startDate.day}/${simulation.startDate.month} - ${simulation.endDate.day}/${simulation.endDate.month}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
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
                    color: simulation.netPnL >= 0
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(simulation.winRate * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMySetups() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mis setups',
                style: TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to setups tab in main navigation
                  context.read<NavigationProvider>().goToSetups();
                },
                child: const Text(
                  'Ver todos',
                  style: TextStyle(
                    color: Color(0xFF22C55E),
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Consumer<SetupProvider>(
            builder: (context, setupProvider, child) {
              final setups = setupProvider.setups.take(5).toList();

              if (setups.isEmpty) {
                return _buildEmptyState(
                  'No hay setups',
                  'Crea tu primer setup',
                );
              }

              return SizedBox(
                height: 210,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  itemCount: setups.length,
                  itemBuilder: (context, index) {
                    final setup = setups[index];
                    return _buildSetupPill(setup);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSetupPill(Setup setup) {
    return GestureDetector(
      onLongPress: () => _showSetupOptions(setup),
      onTap: () {
        // TODO: Navigate to setup detail or edit
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(18),
        width: 160,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF374151), Color(0xFF1F2937)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF4B5563), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              offset: const Offset(0, 8),
              blurRadius: 20,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with name and risk indicator
            Row(
              children: [
                // Setup type indicator
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    setup.name,
                    style: const TextStyle(
                      color: Color(0xFFF8FAFC),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    setup.getRiskPercentDisplay(),
                    style: const TextStyle(
                      color: Color(0xFF22C55E),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Enhanced Risk/Reward ratio with icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF111827).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                          spreadRadius: -1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.trending_up_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      setup.getTakeProfitRatioDisplay(),
                      style: const TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Enhanced Stop Loss with icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF111827).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                          spreadRadius: -1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.trending_down_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      setup.getStopLossDisplay(),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Advanced rules indicator
            if (setup.useAdvancedRules) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: const Color(0xFF6366F1),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${setup.rules.length} reglas',
                      style: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: const Color(0xFF94A3B8).withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  // Bottom navigation is now handled by MainNavigation

  Future<bool> _showDeleteConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1F2937),
            title: const Text(
              'Eliminar simulación',
              style: TextStyle(color: Color(0xFFF8FAFC)),
            ),
            content: const Text(
              '¿Estás seguro de que quieres eliminar esta simulación?',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                ),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSetupOptions(Setup setup) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF22C55E)),
              title: const Text(
                'Editar',
                style: TextStyle(color: Color(0xFFF8FAFC)),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  AppRoutes.setupForm,
                  arguments: setup,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Color(0xFF22C55E)),
              title: const Text(
                'Duplicar',
                style: TextStyle(color: Color(0xFFF8FAFC)),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implementar duplicar setup
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al cerrar sesión'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }
}
