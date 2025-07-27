import 'package:flutter/material.dart';
import '../services/simulation_provider.dart';

class OrderContainer extends StatefulWidget {
  final SimulationProvider provider;
  final bool isBuy;
  final double price;
  final VoidCallback onClose;

  const OrderContainer({
    required this.provider,
    required this.isBuy,
    required this.price,
    required this.onClose,
    super.key,
  });

  @override
  State<OrderContainer> createState() => _OrderContainerState();
}

class _OrderContainerState extends State<OrderContainer> {
  double _slRiskPercent = 1.0;
  double _tpRiskPercent = 2.0;

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final posSize = provider.calculatedPositionSize;
    final hasPosition = posSize != null && posSize > 0;

    double slPrice = 0;
    double tpPrice = 0;
    if (hasPosition) {
      final riskAmount = provider.currentBalance * (_slRiskPercent / 100);
      final dist = riskAmount / posSize;
      slPrice = widget.isBuy ? widget.price - dist : widget.price + dist;

      final tpAmount = provider.currentBalance * (_tpRiskPercent / 100);
      final tpDist = tpAmount / posSize;
      tpPrice = widget.isBuy ? widget.price + tpDist : widget.price - tpDist;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.isBuy ? 'Comprar' : 'Vender',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Precio de entrada: ${widget.price.toStringAsFixed(5)}',
            style: const TextStyle(color: Colors.white),
          ),
          if (hasPosition) ...[
            const SizedBox(height: 4),
            Text(
              'Precio de SL: ${slPrice.toStringAsFixed(5)}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            Text(
              'Precio de TP: ${tpPrice.toStringAsFixed(5)}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stop Loss: ${_slRiskPercent.toStringAsFixed(1)}% (\$${(provider.currentBalance * (_slRiskPercent / 100)).toStringAsFixed(2)})',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Slider(
                  value: _slRiskPercent.clamp(0.1, 100),
                  min: 0.1,
                  max: 100,
                  divisions: 999,
                  label: '${_slRiskPercent.toStringAsFixed(1)}%',
                  activeColor: Colors.red,
                  inactiveColor: Colors.red.withValues(alpha: 0.2),
                  onChanged: (v) {
                    setState(() => _slRiskPercent = v);
                    if (hasPosition) {
                      final riskAmount =
                          provider.currentBalance * (_slRiskPercent / 100);
                      final dist = riskAmount / posSize;
                      final price = widget.isBuy
                          ? widget.price - dist
                          : widget.price + dist;
                      provider.updateManualStopLoss(price);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Take Profit: ${_tpRiskPercent.toStringAsFixed(1)}% (\$${(provider.currentBalance * (_tpRiskPercent / 100)).toStringAsFixed(2)})',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Slider(
                  value: _tpRiskPercent.clamp(0.1, 100),
                  min: 0.1,
                  max: 100,
                  divisions: 999,
                  label: '+${_tpRiskPercent.toStringAsFixed(1)}%',
                  activeColor: Colors.green,
                  inactiveColor: Colors.green.withValues(alpha: 0.2),
                  onChanged: (v) {
                    setState(() => _tpRiskPercent = v);
                    if (hasPosition) {
                      final tpAmount =
                          provider.currentBalance * (_tpRiskPercent / 100);
                      final dist = tpAmount / posSize;
                      final price = widget.isBuy
                          ? widget.price + dist
                          : widget.price - dist;
                      provider.updateManualTakeProfit(price);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: hasPosition
                  ? () {
                      provider.updateManualStopLoss(slPrice);
                      provider.updateManualTakeProfit(tpPrice);
                      provider.executeManualTrade(
                        type: widget.isBuy ? 'buy' : 'sell',
                        amount: posSize,
                        leverage: provider.calculatedLeverage?.toInt() ?? 1,
                        entryPrice: widget.price,
                      );
                      Future.delayed(
                        const Duration(milliseconds: 100),
                        provider.resumeSimulation,
                      );
                      widget.onClose();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isBuy
                    ? const Color(0xFF21CE99)
                    : const Color(0xFFFF6B6B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                widget.isBuy ? 'Comprar' : 'Vender',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (provider.inPosition)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[600]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.getPositionSummaryText(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Stop Loss: ${provider.manualStopLossPrice?.toStringAsFixed(5) ?? 'N/A'}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontFamily: 'Inter',
                    ),
                  ),
                  Text(
                    'Take Profit: ${provider.manualTakeProfitPrice?.toStringAsFixed(5) ?? 'N/A'}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
