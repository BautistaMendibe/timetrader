import 'package:flutter/material.dart';
import '../models/setup.dart';

class PositionChart extends StatelessWidget {
  final double riskPercent;
  final double stopLossDistance;
  final StopLossType stopLossType;
  final TakeProfitRatio takeProfitRatio;
  final double? customTakeProfitRatio;

  const PositionChart({
    super.key,
    required this.riskPercent,
    required this.stopLossDistance,
    required this.stopLossType,
    required this.takeProfitRatio,
    this.customTakeProfitRatio,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTakeProfitRatio =
        takeProfitRatio == TakeProfitRatio.custom &&
            customTakeProfitRatio != null
        ? customTakeProfitRatio!
        : takeProfitRatio.ratio;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade600),
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF1A1A1A),
      ),
      child: Stack(
        children: [
          // Background grid
          CustomPaint(
            size: const Size(double.infinity, double.infinity),
            painter: ChartGridPainter(),
          ),
          // Position visualization
          CustomPaint(
            size: const Size(double.infinity, double.infinity),
            painter: PositionPainter(
              riskPercent: riskPercent,
              stopLossDistance: stopLossDistance,
              stopLossType: stopLossType,
              takeProfitRatio: effectiveTakeProfitRatio,
            ),
          ),
          // Labels
          Positioned(
            top: 8,
            left: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entrada',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // Risk/Reward ratio info
                Text(
                  'R/R: 1:${effectiveTakeProfitRatio.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Stop Loss label
          Positioned(
            bottom: 8,
            left: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stop Loss',
                  style: TextStyle(
                    color: const Color(0xFFE74C3C),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  stopLossType == StopLossType.pips
                      ? '${stopLossDistance.toStringAsFixed(1)} pips'
                      : '\$${stopLossDistance.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                ),
              ],
            ),
          ),
          // Take Profit label
          Positioned(
            bottom: 8,
            right: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Take Profit',
                  style: TextStyle(
                    color: const Color(0xFF21CE99),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '1:${effectiveTakeProfitRatio.toStringAsFixed(1)}',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                ),
              ],
            ),
          ),
          // Risk percentage label (near stop loss)
          Positioned(
            bottom: 60,
            left: 8,
            child: Text(
              'Riesgo: ${riskPercent.toStringAsFixed(1)}%',
              style: const TextStyle(
                color: Color(0xFFE74C3C),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Profit percentage label (near take profit)
          Positioned(
            top: 60,
            right: 8,
            child: Text(
              'Ganancia: ${(riskPercent * effectiveTakeProfitRatio).toStringAsFixed(1)}%',
              style: const TextStyle(
                color: Color(0xFF21CE99),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChartGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade700
      ..strokeWidth = 0.5;

    // Vertical lines
    for (int i = 0; i <= 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PositionPainter extends CustomPainter {
  final double riskPercent;
  final double stopLossDistance;
  final StopLossType stopLossType;
  final double takeProfitRatio;

  PositionPainter({
    required this.riskPercent,
    required this.stopLossDistance,
    required this.stopLossType,
    required this.takeProfitRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate positions for horizontal lines
    final entryY = size.height * 0.5;

    // Normalize distances for visualization
    double normalizedStopLossDistance;
    if (stopLossType == StopLossType.pips) {
      normalizedStopLossDistance = (stopLossDistance * 0.3).clamp(15.0, 60.0);
    } else {
      normalizedStopLossDistance = (stopLossDistance * 0.05).clamp(15.0, 60.0);
    }

    // Calculate positions
    final stopLossY = entryY + normalizedStopLossDistance;
    final takeProfitY = entryY - (normalizedStopLossDistance * takeProfitRatio);

    // Draw entry line (horizontal)
    final entryPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, entryY), Offset(size.width, entryY), entryPaint);

    // Draw entry point indicator
    final entryPointPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.5, entryY), 4, entryPointPaint);

    // Draw stop loss line (horizontal)
    final stopLossPaint = Paint()
      ..color = const Color(0xFFE74C3C)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, stopLossY),
      Offset(size.width, stopLossY),
      stopLossPaint,
    );

    // Draw stop loss point indicator
    final stopLossPointPaint = Paint()
      ..color = const Color(0xFFE74C3C)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.5, stopLossY),
      4,
      stopLossPointPaint,
    );

    // Draw take profit line (horizontal)
    final takeProfitPaint = Paint()
      ..color = const Color(0xFF21CE99)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, takeProfitY),
      Offset(size.width, takeProfitY),
      takeProfitPaint,
    );

    // Draw take profit point indicator
    final takeProfitPointPaint = Paint()
      ..color = const Color(0xFF21CE99)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.5, takeProfitY),
      4,
      takeProfitPointPaint,
    );

    // Draw vertical connecting lines
    final connectingPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Line from entry to stop loss
    canvas.drawLine(
      Offset(size.width * 0.5, entryY),
      Offset(size.width * 0.5, stopLossY),
      connectingPaint,
    );

    // Line from entry to take profit
    canvas.drawLine(
      Offset(size.width * 0.5, entryY),
      Offset(size.width * 0.5, takeProfitY),
      connectingPaint,
    );

    // Draw arrows pointing to levels
    final arrowPaint = Paint()
      ..color = const Color(0xFFE74C3C)
      ..style = PaintingStyle.fill;

    // Stop loss arrow
    final stopLossArrow = Path();
    stopLossArrow.moveTo(size.width * 0.5, stopLossY - 8);
    stopLossArrow.lineTo(size.width * 0.5 - 4, stopLossY - 15);
    stopLossArrow.lineTo(size.width * 0.5 + 4, stopLossY - 15);
    stopLossArrow.close();
    canvas.drawPath(stopLossArrow, arrowPaint);

    // Take profit arrow
    final takeProfitArrowPaint = Paint()
      ..color = const Color(0xFF21CE99)
      ..style = PaintingStyle.fill;

    final takeProfitArrow = Path();
    takeProfitArrow.moveTo(size.width * 0.5, takeProfitY + 8);
    takeProfitArrow.lineTo(size.width * 0.5 - 4, takeProfitY + 15);
    takeProfitArrow.lineTo(size.width * 0.5 + 4, takeProfitY + 15);
    takeProfitArrow.close();
    canvas.drawPath(takeProfitArrow, takeProfitArrowPaint);

    // Draw risk amount indicator (horizontal bar)
    final riskPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final riskWidth = (riskPercent * 0.8).clamp(10.0, 80.0);
    final riskX = (size.width - riskWidth) / 2;

    canvas.drawLine(
      Offset(riskX, entryY + 20),
      Offset(riskX + riskWidth, entryY + 20),
      riskPaint,
    );

    // Risk percentage text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '',
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(riskX + (riskWidth - textPainter.width) / 2, entryY + 15),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
