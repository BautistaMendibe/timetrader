import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/simulation_provider.dart';
import '../widgets/trading_view_chart.dart';
import '../models/simulation_result.dart';
import 'package:tuple/tuple.dart';

class TradingTab extends StatefulWidget {
  final GlobalKey<TradingViewChartState> chartKey;
  final SimulationProvider simulationProvider;

  const TradingTab({
    super.key,
    required this.chartKey,
    required this.simulationProvider,
  });

  @override
  State<TradingTab> createState() => _TradingTabState();
}

class _TradingTabState extends State<TradingTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _showOrderContainerInline = false;
  bool _isBuyOrder = true;
  bool _showManageSLTPContainer = false;
  bool _showSlTpOnOrderInline = false;
  double? _clickPrice;

  Timeframe? _selectedTimeframe;
  double _slRiskPercent = 1.0;
  double _tpRiskPercent = 2.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _selectedTimeframe = widget.simulationProvider.activeTimeframe;
      });
    });
  }

  void _showOrderContainer(
    BuildContext context,
    SimulationProvider simulationProvider,
    bool isBuy,
  ) {
    simulationProvider.pauseSimulation();
    _clickPrice = simulationProvider.lastVisibleTickPrice;

    if (_clickPrice != null) {
      simulationProvider.calculatePositionParameters(
        isBuy ? 'buy' : 'sell',
        _clickPrice!,
      );
    }
    final slSetup = simulationProvider.calculatedStopLossPrice;
    final tpSetup = simulationProvider.calculatedTakeProfitPrice;

    if (_clickPrice != null && slSetup != null && tpSetup != null) {
      _slRiskPercent = 1.0;
      _tpRiskPercent = 2.0;
    }

    setState(() {
      _showOrderContainerInline = true;
      _isBuyOrder = isBuy;
      _showSlTpOnOrderInline = true;
    });

    if (slSetup != null) simulationProvider.updateManualStopLoss(slSetup);
    if (tpSetup != null) simulationProvider.updateManualTakeProfit(tpSetup);
  }

  void _showTimeframeSelector(
    BuildContext context,
    SimulationProvider simulationProvider,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F2937), Color(0xFF111827)],
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seleccionar Timeframe',
              style: TextStyle(
                color: Color(0xFFF8FAFC),
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 16),
            ...Timeframe.values.map((tf) {
              String label;
              switch (tf) {
                case Timeframe.d1:
                  label = '1D - Diario';
                  break;
                case Timeframe.h1:
                  label = '1H - 1 Hora';
                  break;
                case Timeframe.m15:
                  label = '15M - 15 Minutos';
                  break;
                case Timeframe.m5:
                  label = '5M - 5 Minutos';
                  break;
                case Timeframe.m1:
                  label = '1M - 1 Minuto';
                  break;
              }

              final isSelected =
                  (_selectedTimeframe ?? simulationProvider.activeTimeframe) ==
                  tf;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () {
                    setState(() => _selectedTimeframe = tf);
                    simulationProvider.setTimeframe(tf);
                    Navigator.pop(context);
                  },
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF22C55E).withValues(alpha: 0.2)
                          : const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.schedule_rounded,
                      color: isSelected
                          ? const Color(0xFF22C55E)
                          : const Color(0xFF94A3B8),
                      size: 18,
                    ),
                  ),
                  title: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFF8FAFC),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF22C55E),
                          size: 20,
                        )
                      : null,
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSpeedSelector(
    BuildContext context,
    SimulationProvider simulationProvider,
  ) {
    final speedOptions = [0.5, 1.0, 2.0, 4.0, 6.0];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F2937), Color(0xFF111827)],
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Velocidad de Simulación',
                style: TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 16),
              ...speedOptions.map((speed) {
                final isSelected =
                    widget.simulationProvider.ticksPerSecondFactor == speed;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () {
                      bool wasRunning =
                          widget.simulationProvider.isSimulationRunning;
                      if (wasRunning) {
                        widget.simulationProvider.pauseTickSimulation();
                      }

                      widget.simulationProvider.ticksPerSecondFactor = speed;

                      if (wasRunning &&
                          widget.simulationProvider.currentSetup != null) {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          widget.simulationProvider.resumeTickSimulation();
                        });
                      }

                      Navigator.pop(context);
                    },
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                            : const Color(0xFF374151),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.speed_rounded,
                        color: isSelected
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF94A3B8),
                        size: 18,
                      ),
                    ),
                    title: Text(
                      '${speed.toStringAsFixed(1)}x',
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFFF8FAFC),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                    subtitle: Text(
                      speed == 0.5
                          ? 'Lenta'
                          : speed == 1.0
                          ? 'Normal'
                          : speed == 2.0
                          ? 'Rápida'
                          : speed == 4.0
                          ? 'Muy rápida'
                          : 'Ultra rápida',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF3B82F6),
                            size: 20,
                          )
                        : null,
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManageSLTPPanel(SimulationProvider simulationProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF374151), Color(0xFF1F2937)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4B5563), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFF3B82F6),
                  size: 14,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Gestionar SL / TP',
                style: TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stop Loss Management
          Row(
            children: [
              const Text(
                'Stop Loss',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
              const Spacer(),
              Text(
                '\$${simulationProvider.manualStopLossPrice?.toStringAsFixed(5) ?? "N/A"}',
                style: const TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: () =>
                    _updateActiveTradeSL(simulationProvider, false),
                icon: const Icon(
                  Icons.remove,
                  color: Color(0xFFFF6B6B),
                  size: 16,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFFF6B6B),
                    inactiveTrackColor: const Color(
                      0xFFFF6B6B,
                    ).withValues(alpha: 0.2),
                    thumbColor: const Color(0xFFFF6B6B),
                    overlayColor: const Color(
                      0xFFFF6B6B,
                    ).withValues(alpha: 0.2),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _calculateSLDistance(simulationProvider),
                    min: 0.0001,
                    max: 0.01,
                    divisions: 100,
                    onChanged: (value) => _updateActiveTradeSLFromSlider(
                      simulationProvider,
                      value,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _updateActiveTradeSL(simulationProvider, true),
                icon: const Icon(Icons.add, color: Color(0xFFFF6B6B), size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Take Profit Management
          Row(
            children: [
              const Text(
                'Take Profit',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
              const Spacer(),
              Text(
                '\$${simulationProvider.manualTakeProfitPrice?.toStringAsFixed(5) ?? "N/A"}',
                style: const TextStyle(
                  color: Color(0xFF22C55E),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: () =>
                    _updateActiveTradeTP(simulationProvider, false),
                icon: const Icon(
                  Icons.remove,
                  color: Color(0xFF22C55E),
                  size: 16,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF22C55E),
                    inactiveTrackColor: const Color(
                      0xFF22C55E,
                    ).withValues(alpha: 0.2),
                    thumbColor: const Color(0xFF22C55E),
                    overlayColor: const Color(
                      0xFF22C55E,
                    ).withValues(alpha: 0.2),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _calculateTPDistance(simulationProvider),
                    min: 0.0001,
                    max: 0.02,
                    divisions: 200,
                    onChanged: (value) => _updateActiveTradeTPFromSlider(
                      simulationProvider,
                      value,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _updateActiveTradeTP(simulationProvider, true),
                icon: const Icon(Icons.add, color: Color(0xFF22C55E), size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _calculateSLDistance(SimulationProvider simulationProvider) {
    if (simulationProvider.manualStopLossPrice == null ||
        simulationProvider.entryPrice <= 0) {
      return 0.001;
    }
    final distance =
        (simulationProvider.entryPrice -
                simulationProvider.manualStopLossPrice!)
            .abs() /
        simulationProvider.entryPrice;

    // Asegurar que el valor esté dentro del rango del slider
    return distance.clamp(0.0001, 0.01);
  }

  double _calculateTPDistance(SimulationProvider simulationProvider) {
    if (simulationProvider.manualTakeProfitPrice == null ||
        simulationProvider.entryPrice <= 0) {
      return 0.002;
    }
    final distance =
        (simulationProvider.manualTakeProfitPrice! -
                simulationProvider.entryPrice)
            .abs() /
        simulationProvider.entryPrice;

    // Asegurar que el valor esté dentro del rango del slider
    return distance.clamp(0.0001, 0.02);
  }

  void _updateActiveTradeSL(
    SimulationProvider simulationProvider,
    bool increase,
  ) {
    if (simulationProvider.manualStopLossPrice == null) return;

    final currentSL = simulationProvider.manualStopLossPrice!;
    final adjustment = increase ? 0.00001 : -0.00001;
    final newSL = currentSL + adjustment;

    simulationProvider.updateManualStopLoss(newSL);
  }

  void _updateActiveTradeTP(
    SimulationProvider simulationProvider,
    bool increase,
  ) {
    if (simulationProvider.manualTakeProfitPrice == null) return;

    final currentTP = simulationProvider.manualTakeProfitPrice!;
    final adjustment = increase ? 0.00001 : -0.00001;
    final newTP = currentTP + adjustment;

    simulationProvider.updateManualTakeProfit(newTP);
  }

  void _updateActiveTradeSLFromSlider(
    SimulationProvider simulationProvider,
    double distance,
  ) {
    if (simulationProvider.entryPrice <= 0) return;

    final entryPrice = simulationProvider.entryPrice;
    final isLong =
        simulationProvider.currentTrades.isNotEmpty &&
        simulationProvider.currentTrades.first.type == 'buy';

    final newSL = isLong
        ? entryPrice - (entryPrice * distance)
        : entryPrice + (entryPrice * distance);

    simulationProvider.updateManualStopLoss(newSL);
  }

  void _updateActiveTradeTPFromSlider(
    SimulationProvider simulationProvider,
    double distance,
  ) {
    if (simulationProvider.entryPrice <= 0) return;

    final entryPrice = simulationProvider.entryPrice;
    final isLong =
        simulationProvider.currentTrades.isNotEmpty &&
        simulationProvider.currentTrades.first.type == 'buy';

    final newTP = isLong
        ? entryPrice + (entryPrice * distance)
        : entryPrice - (entryPrice * distance);

    simulationProvider.updateManualTakeProfit(newTP);
  }

  Widget _buildCompactRuleItem(rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F2937), Color(0xFF111827)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF374151).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _getRuleColor(rule).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getRuleColor(rule).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              _getRuleIcon(rule),
              color: _getRuleColor(rule),
              size: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.name,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (rule.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    rule.description,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                      fontFamily: 'Inter',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRuleIcon(rule) {
    // Determinar el icono basado en el tipo de regla
    if (rule.name.toLowerCase().contains('sma') ||
        rule.name.toLowerCase().contains('ema') ||
        rule.name.toLowerCase().contains('media')) {
      return Icons.show_chart;
    } else if (rule.name.toLowerCase().contains('rsi')) {
      return Icons.speed;
    } else if (rule.name.toLowerCase().contains('macd')) {
      return Icons.timeline;
    } else if (rule.name.toLowerCase().contains('bollinger') ||
        rule.name.toLowerCase().contains('banda')) {
      return Icons.border_all;
    } else if (rule.name.toLowerCase().contains('volumen') ||
        rule.name.toLowerCase().contains('volume')) {
      return Icons.bar_chart;
    } else if (rule.name.toLowerCase().contains('soporte') ||
        rule.name.toLowerCase().contains('resistencia') ||
        rule.name.toLowerCase().contains('support') ||
        rule.name.toLowerCase().contains('resistance')) {
      return Icons.horizontal_rule;
    } else if (rule.name.toLowerCase().contains('precio') ||
        rule.name.toLowerCase().contains('price')) {
      return Icons.attach_money;
    } else {
      return Icons.rule;
    }
  }

  Color _getRuleColor(rule) {
    // Determinar el color basado en el tipo de regla
    if (rule.name.toLowerCase().contains('sma') ||
        rule.name.toLowerCase().contains('ema') ||
        rule.name.toLowerCase().contains('media')) {
      return const Color(0xFF3B82F6); // Azul para medias móviles
    } else if (rule.name.toLowerCase().contains('rsi')) {
      return const Color(0xFF8B5CF6); // Morado para RSI
    } else if (rule.name.toLowerCase().contains('macd')) {
      return const Color(0xFF10B981); // Verde para MACD
    } else if (rule.name.toLowerCase().contains('bollinger') ||
        rule.name.toLowerCase().contains('banda')) {
      return const Color(0xFFF59E0B); // Amarillo para Bollinger
    } else if (rule.name.toLowerCase().contains('volumen') ||
        rule.name.toLowerCase().contains('volume')) {
      return const Color(0xFF06B6D4); // Cian para volumen
    } else if (rule.name.toLowerCase().contains('soporte') ||
        rule.name.toLowerCase().contains('resistencia')) {
      return const Color(0xFFEF4444); // Rojo para S/R
    } else {
      return const Color(0xFF94A3B8); // Gris por defecto
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Crear una key única basada en el símbolo y timeframe activos
    final storageKey = PageStorageKey(
      'trading_scroll_${widget.simulationProvider.activeSymbol}_${widget.simulationProvider.activeTimeframe.name}',
    );

    // Unir trades abiertos y completados para el gráfico
    final allTrades = [
      ...widget.simulationProvider.completedTrades,
      ...widget.simulationProvider.currentTrades,
    ];

    return SafeArea(
      child: Stack(
        children: [
          // Contenido principal con PageStorageKey para mantener scroll
          CustomScrollView(
            key: storageKey, // Key para mantener posición del scroll
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Chart Section -55% of screen height
              SliverToBoxAdapter(
                child: _ChartArea(
                  height: MediaQuery.of(context).size.height * 0.55,
                  child: Container(
                    margin: const EdgeInsets.only(
                      left: 10,
                      right: 10,
                      top: 15,
                      bottom: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1F2937), Color(0xFF111827)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF374151),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          offset: const Offset(0, 8),
                          blurRadius: 24,
                          spreadRadius: -4,
                        ),
                        BoxShadow(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                          offset: const Offset(0, 0),
                          blurRadius: 1,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Chart Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Color(0xFF374151), Color(0xFF1F2937)],
                            ),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.simulationProvider.activeSymbol ??
                                        'BTCUSD',
                                    style: const TextStyle(
                                      color: Color(0xFFF8FAFC),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  SizedBox(
                                    width: 55,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            widget
                                                .simulationProvider
                                                .isSimulationRunning
                                            ? const Color(
                                                0xFF22C55E,
                                              ).withValues(alpha: 0.1)
                                            : const Color(
                                                0xFFF59E0B,
                                              ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 5,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              color:
                                                  widget
                                                      .simulationProvider
                                                      .isSimulationRunning
                                                  ? const Color(0xFF22C55E)
                                                  : const Color(0xFFF59E0B),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            widget
                                                    .simulationProvider
                                                    .isSimulationRunning
                                                ? 'LIVE'
                                                : 'PAUSED',
                                            style: TextStyle(
                                              color:
                                                  widget
                                                      .simulationProvider
                                                      .isSimulationRunning
                                                  ? const Color(0xFF22C55E)
                                                  : const Color(0xFFF59E0B),
                                              fontSize: 8,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              // Botón de timeframe
                              GestureDetector(
                                onTap: () => _showTimeframeSelector(
                                  context,
                                  widget.simulationProvider,
                                ),
                                child: Container(
                                  height: 32,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF374151),
                                        Color(0xFF1F2937),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF4B5563),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.schedule_rounded,
                                        color: Color(0xFF94A3B8),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _selectedTimeframe?.name
                                                .toUpperCase() ??
                                            widget
                                                .simulationProvider
                                                .activeTimeframe
                                                .name
                                                .toUpperCase(),
                                        style: const TextStyle(
                                          color: Color(0xFFF8FAFC),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Botón de control único (pausa/reanudar/iniciar)
                              SizedBox(
                                width: 48,
                                child:
                                    widget
                                        .simulationProvider
                                        .isSimulationRunning
                                    ? Container(
                                        height: 32,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFFF59E0B),
                                              Color(0xFFD97706),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFFF59E0B,
                                              ).withValues(alpha: 0.3),
                                              offset: const Offset(0, 2),
                                              blurRadius: 8,
                                              spreadRadius: -2,
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: () => widget
                                              .simulationProvider
                                              .pauseTickSimulation(),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            shadowColor: Colors.transparent,
                                            elevation: 0,
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(48, 32),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.pause_rounded,
                                            size: 16,
                                          ),
                                        ),
                                      )
                                    : (widget.simulationProvider.currentSetup !=
                                              null &&
                                          (widget
                                                  .simulationProvider
                                                  .isSimulationPaused ||
                                              !widget
                                                  .simulationProvider
                                                  .isSimulationRunning))
                                    ? Container(
                                        height: 32,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFF22C55E),
                                              Color(0xFF16A34A),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF22C55E,
                                              ).withValues(alpha: 0.3),
                                              offset: const Offset(0, 2),
                                              blurRadius: 8,
                                              spreadRadius: -2,
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed:
                                              widget
                                                  .simulationProvider
                                                  .isSimulationPaused
                                              ? () => widget.simulationProvider
                                                    .resumeTickSimulation()
                                              : () => widget.simulationProvider
                                                    .startTickSimulation(
                                                      widget
                                                          .simulationProvider
                                                          .currentSetup!,
                                                      widget
                                                          .simulationProvider
                                                          .historicalData
                                                          .first
                                                          .timestamp,
                                                      widget
                                                          .simulationProvider
                                                          .simulationSpeed,
                                                      widget
                                                          .simulationProvider
                                                          .currentBalance,
                                                      widget
                                                              .simulationProvider
                                                              .activeSymbol ??
                                                          'BTCUSD',
                                                    ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            shadowColor: Colors.transparent,
                                            elevation: 0,
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(48, 32),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow_rounded,
                                            size: 20,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF374151),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: ElevatedButton(
                                          onPressed: null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            shadowColor: Colors.transparent,
                                            elevation: 0,
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(48, 32),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow_rounded,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 8),
                              // Botón de velocidad
                              GestureDetector(
                                onTap: () => _showSpeedSelector(
                                  context,
                                  widget.simulationProvider,
                                ),
                                child: Container(
                                  height: 32,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF374151),
                                        Color(0xFF1F2937),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF4B5563),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.speed_rounded,
                                        color: Color(0xFF94A3B8),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${widget.simulationProvider.ticksPerSecondFactor.toStringAsFixed(1)}x',
                                        style: const TextStyle(
                                          color: Color(0xFFF8FAFC),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Chart Content
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                            child:
                                Selector<
                                  SimulationProvider,
                                  Tuple5<
                                    List<Trade>,
                                    int,
                                    double?,
                                    double?,
                                    double?
                                  >
                                >(
                                  selector: (context, provider) => Tuple5(
                                    allTrades,
                                    provider.currentCandleIndex,
                                    provider.manualStopLossPrice,
                                    provider.manualTakeProfitPrice,
                                    provider.entryPrice > 0
                                        ? provider.entryPrice
                                        : null,
                                  ),
                                  builder: (context, data, child) {
                                    // Mejorar la lógica para determinar el entryPrice
                                    final entryPrice =
                                        widget.simulationProvider.inPosition
                                        ? widget.simulationProvider.entryPrice
                                        : (_clickPrice ?? data.item5);

                                    return TradingViewChart(
                                      key: widget
                                          .chartKey, // Usar el GlobalKey pasado
                                      candles: widget
                                          .simulationProvider
                                          .historicalData,
                                      trades: data.item1,
                                      currentCandleIndex: data.item2,
                                      stopLoss: data.item3,
                                      takeProfit: data.item4,
                                      entryPrice: entryPrice,
                                      slPercent: -_slRiskPercent,
                                      slValue:
                                          -(widget
                                                  .simulationProvider
                                                  .currentBalance *
                                              (_slRiskPercent / 100)),
                                      tpPercent: _tpRiskPercent,
                                      tpValue:
                                          widget
                                              .simulationProvider
                                              .currentBalance *
                                          (_tpRiskPercent / 100),
                                      entryValue:
                                          widget.simulationProvider.inPosition
                                          ? widget
                                                .simulationProvider
                                                .unrealizedPnL
                                          : 0.0,
                                      isRunning: widget
                                          .simulationProvider
                                          .isSimulationRunning,
                                    );
                                  },
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Order Container (cuando se presiona comprar/vender)
              if (_showOrderContainerInline) ...[
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1F2937),
                          const Color(0xFF111827),
                          _isBuyOrder
                              ? const Color(0xFF22C55E).withValues(alpha: 0.05)
                              : const Color(0xFFFF6B6B).withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _isBuyOrder
                            ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                            : const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: _isBuyOrder
                                            ? [
                                                const Color(0xFF22C55E),
                                                const Color(0xFF16A34A),
                                              ]
                                            : [
                                                const Color(0xFFFF6B6B),
                                                const Color(0xFFDC2626),
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _isBuyOrder
                                          ? Icons.trending_up
                                          : Icons.trending_down,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isBuyOrder
                                            ? 'ORDEN DE COMPRA'
                                            : 'ORDEN DE VENTA',
                                        style: TextStyle(
                                          color: _isBuyOrder
                                              ? const Color(0xFF22C55E)
                                              : const Color(0xFFFF6B6B),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'Inter',
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF374151,
                                  ).withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF4B5563),
                                  ),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFF94A3B8),
                                    size: 22,
                                  ),
                                  onPressed: () {
                                    widget.simulationProvider.cancelOrder();
                                    setState(() {
                                      _showOrderContainerInline = false;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Price Entry Section
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF374151), Color(0xFF1F2937)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF4B5563),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF22C55E,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.price_change_rounded,
                                      color: Color(0xFF22C55E),
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'PRECIO DE ENTRADA',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '\$${_clickPrice?.toStringAsFixed(5) ?? "--"}',
                                        style: const TextStyle(
                                          color: Color(0xFFF8FAFC),
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // SL/TP Display and Controls
                        if (_clickPrice != null &&
                            widget.simulationProvider.calculatedPositionSize !=
                                null &&
                            widget.simulationProvider.calculatedPositionSize! >
                                0) ...[
                          const SizedBox(height: 12),
                          // SL/TP Display
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFFF6B6B),
                                        Color(0xFFDC2626),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFF6B6B,
                                        ).withValues(alpha: 0.3),
                                        offset: const Offset(0, 4),
                                        blurRadius: 12,
                                        spreadRadius: -2,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.stop_circle_rounded,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'STOP LOSS',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '\$${(() {
                                          final riskAmount = widget.simulationProvider.currentBalance * (_slRiskPercent / 100);
                                          final priceDistance = riskAmount / widget.simulationProvider.calculatedPositionSize!;
                                          final slPrice = _isBuyOrder ? _clickPrice! - priceDistance : _clickPrice! + priceDistance;
                                          return slPrice.toStringAsFixed(5);
                                        })()}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '-${_slRiskPercent.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),
                                          fontSize: 10,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF22C55E),
                                        Color(0xFF16A34A),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF22C55E,
                                        ).withValues(alpha: 0.3),
                                        offset: const Offset(0, 4),
                                        blurRadius: 12,
                                        spreadRadius: -2,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.trending_up_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'TAKE PROFIT',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '\$${(() {
                                          final potentialAmount = widget.simulationProvider.currentBalance * (_tpRiskPercent / 100);
                                          final priceDistance = potentialAmount / widget.simulationProvider.calculatedPositionSize!;
                                          final tpPrice = _isBuyOrder ? _clickPrice! + priceDistance : _clickPrice! - priceDistance;
                                          return tpPrice.toStringAsFixed(5);
                                        })()}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '+${_tpRiskPercent.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),
                                          fontSize: 10,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (_showSlTpOnOrderInline) ...[
                          const SizedBox(height: 24),
                          // SL/TP Slider Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF374151), Color(0xFF1F2937)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF4B5563),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF3B82F6,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.tune_rounded,
                                        color: Color(0xFF3B82F6),
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'SL / TP',
                                      style: TextStyle(
                                        color: Color(0xFFF8FAFC),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Stop Loss Row
                                Row(
                                  children: [
                                    // SL Icon & Label
                                    SizedBox(
                                      width: 50,
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFFFF6B6B,
                                              ).withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Icon(
                                              Icons.stop_circle_rounded,
                                              color: Color(0xFFFF6B6B),
                                              size: 10,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'SL',
                                            style: TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // SL Decrease Button
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFF6B6B,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFFF6B6B,
                                          ).withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _slRiskPercent =
                                                (_slRiskPercent - 0.1).clamp(
                                                  0.1,
                                                  10,
                                                );
                                          });
                                          if (widget
                                                      .simulationProvider
                                                      .calculatedPositionSize !=
                                                  null &&
                                              widget
                                                      .simulationProvider
                                                      .calculatedPositionSize! >
                                                  0) {
                                            final riskAmount =
                                                widget
                                                    .simulationProvider
                                                    .currentBalance *
                                                (_slRiskPercent / 100);
                                            final priceDistance =
                                                riskAmount /
                                                widget
                                                    .simulationProvider
                                                    .calculatedPositionSize!;
                                            final slPrice = _isBuyOrder
                                                ? _clickPrice! - priceDistance
                                                : _clickPrice! + priceDistance;
                                            widget.simulationProvider
                                                .updateManualStopLoss(slPrice);
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.remove,
                                          color: Color(0xFFFF6B6B),
                                          size: 12,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 24,
                                          minHeight: 24,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 4),

                                    // SL Slider
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          activeTrackColor: const Color(
                                            0xFFFF6B6B,
                                          ),
                                          inactiveTrackColor: const Color(
                                            0xFFFF6B6B,
                                          ).withValues(alpha: 0.2),
                                          thumbColor: const Color(0xFFFF6B6B),
                                          overlayColor: const Color(
                                            0xFFFF6B6B,
                                          ).withValues(alpha: 0.2),
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                enabledThumbRadius: 5,
                                              ),
                                          trackHeight: 2,
                                        ),
                                        child: Slider(
                                          value: _slRiskPercent.clamp(0.1, 10),
                                          min: 0.1,
                                          max: 10,
                                          divisions: 99,
                                          onChanged: (newPercent) {
                                            setState(
                                              () => _slRiskPercent = newPercent,
                                            );
                                            if (widget
                                                        .simulationProvider
                                                        .calculatedPositionSize !=
                                                    null &&
                                                widget
                                                        .simulationProvider
                                                        .calculatedPositionSize! >
                                                    0) {
                                              final riskAmount =
                                                  widget
                                                      .simulationProvider
                                                      .currentBalance *
                                                  (_slRiskPercent / 100);
                                              final priceDistance =
                                                  riskAmount /
                                                  widget
                                                      .simulationProvider
                                                      .calculatedPositionSize!;
                                              final slPrice = _isBuyOrder
                                                  ? _clickPrice! - priceDistance
                                                  : _clickPrice! +
                                                        priceDistance;
                                              widget.simulationProvider
                                                  .updateManualStopLoss(
                                                    slPrice,
                                                  );
                                            }
                                          },
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 4),

                                    // SL Increase Button
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFF6B6B,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFFF6B6B,
                                          ).withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _slRiskPercent =
                                                (_slRiskPercent + 0.1).clamp(
                                                  0.1,
                                                  10,
                                                );
                                          });
                                          if (widget
                                                      .simulationProvider
                                                      .calculatedPositionSize !=
                                                  null &&
                                              widget
                                                      .simulationProvider
                                                      .calculatedPositionSize! >
                                                  0) {
                                            final riskAmount =
                                                widget
                                                    .simulationProvider
                                                    .currentBalance *
                                                (_slRiskPercent / 100);
                                            final priceDistance =
                                                riskAmount /
                                                widget
                                                    .simulationProvider
                                                    .calculatedPositionSize!;
                                            final slPrice = _isBuyOrder
                                                ? _clickPrice! - priceDistance
                                                : _clickPrice! + priceDistance;
                                            widget.simulationProvider
                                                .updateManualStopLoss(slPrice);
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.add,
                                          color: Color(0xFFFF6B6B),
                                          size: 12,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 24,
                                          minHeight: 24,
                                        ),
                                      ),
                                    ),

                                    // SL Value
                                    SizedBox(
                                      width: 45,
                                      child: Text(
                                        '${_slRiskPercent.toStringAsFixed(1)}%',
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                          color: Color(0xFFFF6B6B),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // Take Profit Row
                                Row(
                                  children: [
                                    // TP Icon & Label
                                    SizedBox(
                                      width: 50,
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF22C55E,
                                              ).withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Icon(
                                              Icons.trending_up_rounded,
                                              color: Color(0xFF22C55E),
                                              size: 10,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'TP',
                                            style: TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // TP Decrease Button
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF22C55E,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF22C55E,
                                          ).withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _tpRiskPercent =
                                                (_tpRiskPercent - 0.1).clamp(
                                                  0.1,
                                                  20,
                                                );
                                          });
                                          if (widget
                                                      .simulationProvider
                                                      .calculatedPositionSize !=
                                                  null &&
                                              widget
                                                      .simulationProvider
                                                      .calculatedPositionSize! >
                                                  0) {
                                            final potentialAmount =
                                                widget
                                                    .simulationProvider
                                                    .currentBalance *
                                                (_tpRiskPercent / 100);
                                            final priceDistance =
                                                potentialAmount /
                                                widget
                                                    .simulationProvider
                                                    .calculatedPositionSize!;
                                            final tpPrice = _isBuyOrder
                                                ? _clickPrice! + priceDistance
                                                : _clickPrice! - priceDistance;
                                            widget.simulationProvider
                                                .updateManualTakeProfit(
                                                  tpPrice,
                                                );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.remove,
                                          color: Color(0xFF22C55E),
                                          size: 12,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 24,
                                          minHeight: 24,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 4),

                                    // TP Slider
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          activeTrackColor: const Color(
                                            0xFF22C55E,
                                          ),
                                          inactiveTrackColor: const Color(
                                            0xFF22C55E,
                                          ).withValues(alpha: 0.2),
                                          thumbColor: const Color(0xFF22C55E),
                                          overlayColor: const Color(
                                            0xFF22C55E,
                                          ).withValues(alpha: 0.2),
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                enabledThumbRadius: 5,
                                              ),
                                          trackHeight: 2,
                                        ),
                                        child: Slider(
                                          value: _tpRiskPercent.clamp(0.1, 20),
                                          min: 0.1,
                                          max: 20,
                                          divisions: 199,
                                          onChanged: (newPercent) {
                                            setState(
                                              () => _tpRiskPercent = newPercent,
                                            );
                                            if (widget
                                                        .simulationProvider
                                                        .calculatedPositionSize !=
                                                    null &&
                                                widget
                                                        .simulationProvider
                                                        .calculatedPositionSize! >
                                                    0) {
                                              final potentialAmount =
                                                  widget
                                                      .simulationProvider
                                                      .currentBalance *
                                                  (_tpRiskPercent / 100);
                                              final priceDistance =
                                                  potentialAmount /
                                                  widget
                                                      .simulationProvider
                                                      .calculatedPositionSize!;
                                              final tpPrice = _isBuyOrder
                                                  ? _clickPrice! + priceDistance
                                                  : _clickPrice! -
                                                        priceDistance;
                                              widget.simulationProvider
                                                  .updateManualTakeProfit(
                                                    tpPrice,
                                                  );
                                            }
                                          },
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 4),

                                    // TP Increase Button
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF22C55E,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF22C55E,
                                          ).withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _tpRiskPercent =
                                                (_tpRiskPercent + 0.1).clamp(
                                                  0.1,
                                                  20,
                                                );
                                          });
                                          if (widget
                                                      .simulationProvider
                                                      .calculatedPositionSize !=
                                                  null &&
                                              widget
                                                      .simulationProvider
                                                      .calculatedPositionSize! >
                                                  0) {
                                            final potentialAmount =
                                                widget
                                                    .simulationProvider
                                                    .currentBalance *
                                                (_tpRiskPercent / 100);
                                            final priceDistance =
                                                potentialAmount /
                                                widget
                                                    .simulationProvider
                                                    .calculatedPositionSize!;
                                            final tpPrice = _isBuyOrder
                                                ? _clickPrice! + priceDistance
                                                : _clickPrice! - priceDistance;
                                            widget.simulationProvider
                                                .updateManualTakeProfit(
                                                  tpPrice,
                                                );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.add,
                                          color: Color(0xFF22C55E),
                                          size: 12,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 24,
                                          minHeight: 24,
                                        ),
                                      ),
                                    ),

                                    // TP Value
                                    SizedBox(
                                      width: 45,
                                      child: Text(
                                        '${_tpRiskPercent.toStringAsFixed(1)}%',
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                          color: Color(0xFF22C55E),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // Risk/Reward Summary
                                if (_clickPrice != null &&
                                    widget
                                            .simulationProvider
                                            .calculatedPositionSize !=
                                        null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1F2937),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Color(0xFF374151),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Column(
                                          children: [
                                            const Text(
                                              'RIESGO',
                                              style: TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 8,
                                                fontWeight: FontWeight.w600,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                            Text(
                                              '\$${(widget.simulationProvider.currentBalance * (_slRiskPercent / 100)).toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Color(0xFFFF6B6B),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          width: 1,
                                          height: 24,
                                          color: const Color(0xFF374151),
                                        ),
                                        Column(
                                          children: [
                                            const Text(
                                              'GANANCIA',
                                              style: TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 8,
                                                fontWeight: FontWeight.w600,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                            Text(
                                              '\$${(widget.simulationProvider.currentBalance * (_tpRiskPercent / 100)).toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Color(0xFF22C55E),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          width: 1,
                                          height: 24,
                                          color: const Color(0xFF374151),
                                        ),
                                        Column(
                                          children: [
                                            const Text(
                                              'R:R',
                                              style: TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 8,
                                                fontWeight: FontWeight.w600,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                            Text(
                                              '1:${(_tpRiskPercent / _slRiskPercent).toStringAsFixed(1)}',
                                              style: const TextStyle(
                                                color: Color(0xFF3B82F6),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Confirm Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                widget.simulationProvider
                                        .canCalculatePosition() &&
                                    _clickPrice != null &&
                                    _slRiskPercent > 0 &&
                                    _tpRiskPercent > 0
                                ? () {
                                    // Ejecutar la orden
                                    final riskAmount =
                                        widget
                                            .simulationProvider
                                            .currentBalance *
                                        (_slRiskPercent / 100);
                                    final tpAmount =
                                        widget
                                            .simulationProvider
                                            .currentBalance *
                                        (_tpRiskPercent / 100);
                                    final slPrice = _isBuyOrder
                                        ? _clickPrice! -
                                              (riskAmount /
                                                  (widget
                                                          .simulationProvider
                                                          .calculatedPositionSize ??
                                                      1))
                                        : _clickPrice! +
                                              (riskAmount /
                                                  (widget
                                                          .simulationProvider
                                                          .calculatedPositionSize ??
                                                      1));
                                    final tpPrice = _isBuyOrder
                                        ? _clickPrice! +
                                              (tpAmount /
                                                  (widget
                                                          .simulationProvider
                                                          .calculatedPositionSize ??
                                                      1))
                                        : _clickPrice! -
                                              (tpAmount /
                                                  (widget
                                                          .simulationProvider
                                                          .calculatedPositionSize ??
                                                      1));

                                    widget.simulationProvider
                                        .updateManualStopLoss(slPrice);
                                    widget.simulationProvider
                                        .updateManualTakeProfit(tpPrice);

                                    widget.simulationProvider
                                        .executeManualTrade(
                                          type: _isBuyOrder ? 'buy' : 'sell',
                                          amount:
                                              widget
                                                  .simulationProvider
                                                  .calculatedPositionSize ??
                                              0.0,
                                          leverage:
                                              widget
                                                  .simulationProvider
                                                  .calculatedLeverage
                                                  ?.toInt() ??
                                              1,
                                          entryPrice: _clickPrice!,
                                        );

                                    Future.delayed(
                                      const Duration(milliseconds: 100),
                                      () {
                                        widget.simulationProvider
                                            .resumeSimulation();
                                      },
                                    );

                                    setState(() {
                                      _showOrderContainerInline = false;
                                      // No limpiar _clickPrice inmediatamente para mantener SL/TP visible
                                      // _clickPrice = null;
                                    });

                                    // Limpiar _clickPrice después de un delay para que el chart tenga tiempo de actualizar
                                    Future.delayed(
                                      const Duration(milliseconds: 500),
                                      () {
                                        if (mounted) {
                                          setState(() {
                                            _clickPrice = null;
                                          });
                                        }
                                      },
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 24,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: _isBuyOrder
                                      ? [
                                          const Color(0xFF22C55E),
                                          const Color(0xFF16A34A),
                                        ]
                                      : [
                                          const Color(0xFFFF6B6B),
                                          const Color(0xFFDC2626),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      _isBuyOrder
                                          ? Icons.trending_up
                                          : Icons.trending_down,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _isBuyOrder
                                        ? 'CONFIRMAR COMPRA'
                                        : 'CONFIRMAR VENTA',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Inter',
                                      letterSpacing: 1.0,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 16)),
              ],

              // Controls Section - Trading buttons
              if (!_showOrderContainerInline) ...[
                SliverToBoxAdapter(child: const SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1F2937), Color(0xFF111827)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF374151),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Trading buttons
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient:
                                      (!widget.simulationProvider.inPosition &&
                                          widget.simulationProvider
                                              .canCalculatePosition())
                                      ? const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF22C55E),
                                            Color(0xFF16A34A),
                                          ],
                                        )
                                      : null,
                                  color:
                                      (!widget.simulationProvider.inPosition &&
                                          widget.simulationProvider
                                              .canCalculatePosition())
                                      ? null
                                      : const Color(0xFF374151),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ElevatedButton.icon(
                                  onPressed:
                                      (!widget.simulationProvider.inPosition &&
                                          widget.simulationProvider
                                              .canCalculatePosition())
                                      ? () => _showOrderContainer(
                                          context,
                                          widget.simulationProvider,
                                          true,
                                        )
                                      : null,
                                  icon: const Icon(Icons.trending_up, size: 22),
                                  label: const Text(
                                    'COMPRAR',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient:
                                      (!widget.simulationProvider.inPosition &&
                                          widget.simulationProvider
                                              .canCalculatePosition())
                                      ? const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFFFF6B6B),
                                            Color(0xFFDC2626),
                                          ],
                                        )
                                      : null,
                                  color:
                                      (!widget.simulationProvider.inPosition &&
                                          widget.simulationProvider
                                              .canCalculatePosition())
                                      ? null
                                      : const Color(0xFF374151),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ElevatedButton.icon(
                                  onPressed:
                                      (!widget.simulationProvider.inPosition &&
                                          widget.simulationProvider
                                              .canCalculatePosition())
                                      ? () => _showOrderContainer(
                                          context,
                                          widget.simulationProvider,
                                          false,
                                        )
                                      : null,
                                  icon: const Icon(
                                    Icons.trending_down,
                                    size: 22,
                                  ),
                                  label: const Text(
                                    'VENDER',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Close Position Button (only show if position is open)
                        if (widget.simulationProvider.inPosition) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF374151,
                              ).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF4B5563),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFF59E0B,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.account_balance_wallet,
                                        color: Color(0xFFF59E0B),
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Posición Activa',
                                      style: TextStyle(
                                        color: Color(0xFFF8FAFC),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFFFF6B6B),
                                              Color(0xFFDC2626),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            widget.simulationProvider
                                                .closeManualPosition(
                                                  widget
                                                      .simulationProvider
                                                      .currentTickPrice,
                                                );
                                          },
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'CERRAR',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            shadowColor: Colors.transparent,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFF3B82F6),
                                              Color(0xFF1D4ED8),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF3B82F6,
                                              ).withValues(alpha: 0.3),
                                              offset: const Offset(0, 4),
                                              blurRadius: 12,
                                              spreadRadius: -2,
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              _showManageSLTPContainer =
                                                  !_showManageSLTPContainer;
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.tune_rounded,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'SL/TP',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            shadowColor: Colors.transparent,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Panel de gestión de SL/TP para trades abiertos
                        if (_showManageSLTPContainer &&
                            widget.simulationProvider.inPosition) ...[
                          const SizedBox(height: 20),
                          _buildManageSLTPPanel(widget.simulationProvider),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              // Setup Details Section (below controls)
              if (widget.simulationProvider.currentSetup != null &&
                  !_showOrderContainerInline) ...[
                SliverToBoxAdapter(child: const SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1F2937), Color(0xFF111827)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF374151),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Setup Header
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF10B981),
                                      Color(0xFF059669),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.settings_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Configuración Activa',
                                    style: TextStyle(
                                      color: Color(0xFFF8FAFC),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget
                                        .simulationProvider
                                        .currentSetup!
                                        .name,
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Setup details in compact format
                        Row(
                          children: [
                            Expanded(
                              child: _buildCompactSetupDetail(
                                'Riesgo',
                                widget.simulationProvider.currentSetup!
                                    .getRiskPercentDisplay(),
                                Icons.security,
                                Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildCompactSetupDetail(
                                'SL',
                                widget.simulationProvider.currentSetup!
                                    .getStopLossDisplay(),
                                Icons.trending_down,
                                Colors.red,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildCompactSetupDetail(
                                'TP',
                                widget.simulationProvider.currentSetup!
                                    .getTakeProfitRatioDisplay(),
                                Icons.trending_up,
                                Colors.green,
                              ),
                            ),
                          ],
                        ),

                        // Enhanced Advanced Rules Section
                        if (widget
                            .simulationProvider
                            .currentSetup!
                            .rules
                            .isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF111827,
                              ).withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(
                                  0xFF374151,
                                ).withValues(alpha: 0.5),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
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
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFFF59E0B),
                                            Color(0xFFD97706),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFFF59E0B,
                                            ).withValues(alpha: 0.3),
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
                                    const Text(
                                      'Reglas Avanzadas',
                                      style: TextStyle(
                                        color: Color(0xFFF8FAFC),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Enhanced Scrollable rules list
                                Container(
                                  constraints: const BoxConstraints(
                                    maxHeight: 200,
                                  ),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: widget
                                          .simulationProvider
                                          .currentSetup!
                                          .rules
                                          .map(
                                            (rule) =>
                                                _buildCompactRuleItem(rule),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSetupDetail(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF374151), const Color(0xFF1F2937)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartArea extends StatelessWidget {
  final double height;
  final Widget child;

  const _ChartArea({required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height, child: child);
  }
}
