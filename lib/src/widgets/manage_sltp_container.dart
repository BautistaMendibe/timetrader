import 'package:flutter/material.dart';
import '../services/simulation_provider.dart';

class ManageSLTPContainer extends StatefulWidget {
  final SimulationProvider simulationProvider;
  final VoidCallback onClose;
  const ManageSLTPContainer({
    required this.simulationProvider,
    required this.onClose,
    super.key,
  });

  @override
  State<ManageSLTPContainer> createState() => _ManageSLTPContainerState();
}

class _ManageSLTPContainerState extends State<ManageSLTPContainer> {
  static const List<double> _slPercents = [
    0.1,
    0.2,
    0.3,
    0.4,
    0.5,
    0.6,
    0.7,
    0.8,
    0.9,
    1,
    1.2,
    1.5,
    2,
    2.5,
    3,
    4,
    5,
    7,
    10,
  ];
  static const List<double> _tpPercents = [
    0.1,
    0.2,
    0.3,
    0.4,
    0.5,
    0.6,
    0.7,
    0.8,
    0.9,
    1,
    1.2,
    1.5,
    2,
    2.5,
    3,
    4,
    5,
    7,
    10,
    15,
    20,
  ];

  int? _takeProfitIndex;
  int? _stopLossIndex;
  double? _partialClosePercent;
  bool _slEnabled = false;
  bool _tpEnabled = false;

  @override
  void initState() {
    super.initState();
    final provider = widget.simulationProvider;
    double? tpPercent =
        provider.manualTakeProfitPercent ?? provider.defaultTakeProfitPercent;
    double? slPercent =
        provider.manualStopLossPercent ?? provider.defaultStopLossPercent;
    _takeProfitIndex = tpPercent != null
        ? _tpPercents.indexWhere((v) => (v - tpPercent).abs() < 0.0001)
        : null;
    _stopLossIndex = slPercent != null
        ? _slPercents.indexWhere((v) => (v - slPercent).abs() < 0.0001)
        : null;
    if (_takeProfitIndex == -1 && tpPercent != null) {
      _takeProfitIndex = _findClosestIndex(_tpPercents, tpPercent);
    }
    if (_stopLossIndex == -1 && slPercent != null) {
      _stopLossIndex = _findClosestIndex(_slPercents, slPercent);
    }
    _tpEnabled = tpPercent != null;
    _slEnabled = slPercent != null;
    _partialClosePercent = 0.0;
  }

  int _findClosestIndex(List<double> values, double target) {
    int closestIndex = 0;
    double closestDistance = (values[0] - target).abs();
    for (int i = 1; i < values.length; i++) {
      double distance = (values[i] - target).abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  @override
  Widget build(BuildContext context) {
    final entryPrice = widget.simulationProvider.entryPrice;
    final positionSize = widget.simulationProvider.positionSize;

    final tpValue = _takeProfitIndex != null
        ? positionSize *
            entryPrice *
            (_tpPercents[_takeProfitIndex!] / 100) *
            (widget.simulationProvider.currentTrades.last.leverage ?? 1)
        : 0;
    final slValue = _stopLossIndex != null
        ? positionSize *
            entryPrice *
            (_slPercents[_stopLossIndex!] / 100) *
            (widget.simulationProvider.currentTrades.last.leverage ?? 1)
        : 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gestión Avanzada',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _tpEnabled,
                  onChanged: (value) {
                    setState(() {
                      _tpEnabled = value ?? false;
                      if (!_tpEnabled) {
                        _takeProfitIndex = null;
                        widget.simulationProvider.setManualTakeProfit(null);
                      } else if (_takeProfitIndex == null) {
                        _takeProfitIndex = 9;
                        widget.simulationProvider.setManualTakeProfit(
                          _tpPercents[9],
                        );
                      }
                    });
                  },
                  activeColor: Colors.green,
                ),
                Expanded(
                  child: Text(
                    _tpEnabled && _takeProfitIndex != null
                        ? 'TP: +\$${tpValue.toStringAsFixed(0)} (+${_tpPercents[_takeProfitIndex!].toStringAsFixed(1)}%)'
                        : 'TP: Desactivado',
                    style: TextStyle(
                      color: _tpEnabled ? Colors.green : Colors.grey[400],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (_tpEnabled) ...[
              Slider(
                value: _takeProfitIndex?.toDouble() ?? 0.0,
                min: 0,
                max: (_tpPercents.length - 1).toDouble(),
                divisions: _tpPercents.length - 1,
                label: '+${_tpPercents[_takeProfitIndex ?? 0].toStringAsFixed(1)}%',
                activeColor: Colors.green,
                inactiveColor: Colors.green.withOpacity(0.2),
                onChanged: (v) {
                  setState(() {
                    _takeProfitIndex = v.round();
                  });
                  widget.simulationProvider.setManualTakeProfit(
                    _tpPercents[_takeProfitIndex!],
                  );
                },
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Checkbox(
                  value: _slEnabled,
                  onChanged: (value) {
                    setState(() {
                      _slEnabled = value ?? false;
                      if (!_slEnabled) {
                        _stopLossIndex = null;
                        widget.simulationProvider.setManualStopLoss(null);
                      } else if (_stopLossIndex == null) {
                        _stopLossIndex = 9;
                        widget.simulationProvider.setManualStopLoss(
                          _slPercents[9],
                        );
                      }
                    });
                  },
                  activeColor: Colors.red,
                ),
                Expanded(
                  child: Text(
                    _slEnabled && _stopLossIndex != null
                        ? 'SL: -\$${slValue.toStringAsFixed(0)} (-${_slPercents[_stopLossIndex!].toStringAsFixed(1)}%)'
                        : 'SL: Desactivado',
                    style: TextStyle(
                      color: _slEnabled ? Colors.red : Colors.grey[400],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (_slEnabled) ...[
              Slider(
                value: _stopLossIndex?.toDouble() ?? 0.0,
                min: 0,
                max: (_slPercents.length - 1).toDouble(),
                divisions: _slPercents.length - 1,
                label: '-${_slPercents[_stopLossIndex ?? 0].toStringAsFixed(1)}%',
                activeColor: Colors.red,
                inactiveColor: Colors.red.withOpacity(0.2),
                onChanged: (v) {
                  setState(() {
                    _stopLossIndex = v.round();
                  });
                  widget.simulationProvider.setManualStopLoss(
                    _slPercents[_stopLossIndex!],
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if ((_partialClosePercent ?? 0) > 0) {
                        widget.simulationProvider.closePartialPosition(
                          _partialClosePercent ?? 0,
                        );
                      }
                      widget.simulationProvider.setManualStopLoss(
                        _slEnabled && _stopLossIndex != null
                            ? _slPercents[_stopLossIndex!]
                            : null,
                      );
                      widget.simulationProvider.setManualTakeProfit(
                        _tpEnabled && _takeProfitIndex != null
                            ? _tpPercents[_takeProfitIndex!]
                            : null,
                      );
                      widget.onClose();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'HECHO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
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
}
