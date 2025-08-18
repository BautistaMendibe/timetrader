import 'package:flutter/material.dart';
import '../models/rule.dart';

class RuleCard extends StatelessWidget {
  final Rule rule;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showDeleteButton;
  final bool isSelected;

  const RuleCard({
    super.key,
    required this.rule,
    this.onTap,
    this.onDelete,
    this.showDeleteButton = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF22C55E).withValues(alpha: 0.1)
            : const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF22C55E).withValues(alpha: 0.3)
              : const Color(0xFF374151),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildRuleIcon(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            rule.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Color(0xFFF8FAFC),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                        if (!rule.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF6B7280,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Inactiva',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rule.description,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildRuleTypeChip(),
                  ],
                ),
              ),
              if (showDeleteButton && onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                  tooltip: 'Eliminar regla',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleIcon() {
    IconData iconData;
    Color iconColor;

    switch (rule.type) {
      case RuleType.technicalIndicator:
        iconData = Icons.trending_up;
        iconColor = const Color(0xFF3B82F6);
        break;
      case RuleType.candlestickPattern:
        iconData = Icons.candlestick_chart;
        iconColor = const Color(0xFFF59E0B);
        break;
      case RuleType.timeFrame:
        iconData = Icons.schedule;
        iconColor = const Color(0xFF22C55E);
        break;
      case RuleType.other:
        iconData = Icons.settings;
        iconColor = const Color(0xFF6B7280);
        break;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Icon(iconData, color: iconColor, size: 22),
    );
  }

  Widget _buildRuleTypeChip() {
    String typeText;
    Color chipColor;

    switch (rule.type) {
      case RuleType.technicalIndicator:
        typeText = 'Indicador';
        chipColor = const Color(0xFF3B82F6);
        break;
      case RuleType.candlestickPattern:
        typeText = 'Patrón';
        chipColor = const Color(0xFFF59E0B);
        break;
      case RuleType.timeFrame:
        typeText = 'Horario';
        chipColor = const Color(0xFF22C55E);
        break;
      case RuleType.other:
        typeText = 'Otro';
        chipColor = const Color(0xFF6B7280);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: chipColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        typeText,
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}
