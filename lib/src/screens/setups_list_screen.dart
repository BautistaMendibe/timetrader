import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../routes.dart';
import '../services/setup_provider.dart';

import '../models/setup.dart';
import '../models/rule.dart';
import '../widgets/top_snack_bar.dart';
import '../services/app_navigation.dart';

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
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Content
              Expanded(
                child: Consumer<SetupProvider>(
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF22C55E),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Cargando setups...',
                              style: TextStyle(
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

                    if (setupProvider.setups.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_chart,
                              size: 64,
                              color: const Color(
                                0xFF94A3B8,
                              ).withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No tienes setups creados',
                              style: TextStyle(
                                color: Color(0xFFF8FAFC),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Crea tu primer setup para comenzar',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                AppRoutes.setupForm,
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Crear Setup'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF22C55E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: 0,
                                shadowColor: const Color(
                                  0xFF22C55E,
                                ).withValues(alpha: 0.18),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: setupProvider.setups.length,
                      itemBuilder: (context, index) {
                        final setup = setupProvider.setups[index];
                        return _SetupCard(setup: setup);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          const Text(
            'Mis Setups',
            style: TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => AppNavigation.navigateToSetupForm(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nuevo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
              shadowColor: const Color(0xFF22C55E).withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  final Setup setup;

  const _SetupCard({required this.setup});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF374151), Color(0xFF1F2937)],
        ),
        borderRadius: BorderRadius.circular(24),
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
      child: InkWell(
        onTap: () {
          context.read<SetupProvider>().selectSetup(setup);
          AppNavigation.navigateToSetupDetail(context, setup);
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF8FAFC),
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configuración',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Inter',
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
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
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
                              ? const Color(0xFF22C55E).withValues(alpha: 0.2)
                              : const Color(0xFF94A3B8).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          setup.useAdvancedRules ? 'Avanzado' : 'Básico',
                          style: TextStyle(
                            color: setup.useAdvancedRules
                                ? const Color(0xFF22C55E)
                                : const Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
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
            'Riesgo',
            setup.getRiskPercentDisplay(),
            Icons.security,
            color: const Color(0xFFF59E0B),
          ),
        ),
        Expanded(
          child: _buildStatItem(
            'Stop Loss',
            setup.getStopLossDisplay(),
            Icons.trending_down,
            color: const Color(0xFFEF4444),
          ),
        ),
        Expanded(
          child: _buildStatItem(
            'Take Profit',
            setup.getTakeProfitRatioDisplay(),
            Icons.trending_up,
            color: const Color(0xFF22C55E),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    final itemColor = color ?? const Color(0xFF94A3B8);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF111827).withValues(alpha: 0.8),
            const Color(0xFF374151).withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: itemColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: itemColor.withValues(alpha: 0.1),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: itemColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: itemColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(icon, color: itemColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: itemColor,
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRulesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                      spreadRadius: -1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.rule_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Reglas (${setup.rules.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF8FAFC),
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...setup.rules
              .take(3)
              .map(
                (rule) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF4B5563).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF94A3B8,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFF94A3B8,
                            ).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          _getRuleIcon(rule.type),
                          size: 14,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          rule.name,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFF8FAFC),
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          if (setup.rules.length > 3)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6B7280).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF6B7280).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                '+${setup.rules.length - 3} reglas más',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSetupFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Creado: ${_formatDate(setup.createdAt)}',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
        ),
        const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF94A3B8)),
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
