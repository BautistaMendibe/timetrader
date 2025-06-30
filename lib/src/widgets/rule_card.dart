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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
             color: isSelected ? const Color(0xFF21CE99).withValues(alpha: 0.1) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildRuleIcon(),
              const SizedBox(width: 12),
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
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (!rule.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                                                         decoration: BoxDecoration(
                               color: Colors.grey.withValues(alpha: 0.2),
                               borderRadius: BorderRadius.circular(12),
                             ),
                            child: const Text(
                              'Inactiva',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rule.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRuleTypeChip(),
                  ],
                ),
              ),
              if (showDeleteButton && onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
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
        iconColor = Colors.blue;
        break;
      case RuleType.candlestickPattern:
        iconData = Icons.candlestick_chart;
        iconColor = Colors.orange;
        break;
      case RuleType.timeFrame:
        iconData = Icons.schedule;
        iconColor = Colors.green;
        break;
      case RuleType.other:
        iconData = Icons.settings;
        iconColor = Colors.grey;
        break;
    }

    return Container(
      width: 40,
      height: 40,
             decoration: BoxDecoration(
         color: iconColor.withValues(alpha: 0.1),
         borderRadius: BorderRadius.circular(8),
       ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 20,
      ),
    );
  }

  Widget _buildRuleTypeChip() {
    String typeText;
    Color chipColor;

    switch (rule.type) {
      case RuleType.technicalIndicator:
        typeText = 'Indicador';
        chipColor = Colors.blue;
        break;
      case RuleType.candlestickPattern:
        typeText = 'Patrón';
        chipColor = Colors.orange;
        break;
      case RuleType.timeFrame:
        typeText = 'Horario';
        chipColor = Colors.green;
        break;
      case RuleType.other:
        typeText = 'Otro';
        chipColor = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
             decoration: BoxDecoration(
         color: chipColor.withValues(alpha: 0.1),
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: chipColor.withValues(alpha: 0.3)),
       ),
      child: Text(
        typeText,
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
} 