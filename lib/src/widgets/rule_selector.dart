import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/rule.dart';
import '../services/setup_provider.dart';
import 'rule_card.dart';
import 'custom_rule_form.dart';

class RuleSelector extends StatefulWidget {
  final List<Rule> selectedRules;
  final Function(Rule) onRuleSelected;
  final Function(Rule) onRuleDeselected;
  final List<Rule> availableRules;

  const RuleSelector({
    super.key,
    required this.selectedRules,
    required this.onRuleSelected,
    required this.onRuleDeselected,
    required this.availableRules,
  });

  @override
  State<RuleSelector> createState() => _RuleSelectorState();
}

class _RuleSelectorState extends State<RuleSelector>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTypeTabs(),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF374151), width: 1),
            ),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCustomRulesTab(),
                ...RuleType.values.map((type) => _buildRulesList(type)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTypeTabs() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF374151), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: ShapeDecoration(
          color: const Color(0xFF22C55E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: const Color(0xFFF8FAFC),
        unselectedLabelColor: const Color(0xFF94A3B8),
        isScrollable: true,
        labelPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        tabs: [
          _buildTab(Icons.rule, 'Mis Reglas'),
          _buildTab(Icons.trending_up, 'Indicadores'),
          _buildTab(Icons.candlestick_chart, 'Patrones'),
          _buildTab(Icons.schedule, 'Horarios'),
          _buildTab(Icons.settings, 'Otros'),
        ],
      ),
    );
  }

  Widget _buildTab(IconData icon, String text) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesList(RuleType type) {
    final setupProvider = context.read<SetupProvider>();
    final rulesOfType = setupProvider.getAvailableRulesByType(type);

    if (rulesOfType.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF374151), width: 1),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.rule_outlined, size: 48, color: Color(0xFF6B7280)),
              SizedBox(height: 12),
              Text(
                'No hay reglas disponibles',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Para este tipo de regla',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView.builder(
        itemCount: rulesOfType.length,
        itemBuilder: (context, index) {
          final rule = rulesOfType[index];
          final isSelected = widget.selectedRules.any(
            (selectedRule) => selectedRule.id == rule.id,
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: RuleCard(
              rule: rule,
              isSelected: isSelected,
              onTap: () {
                if (isSelected) {
                  widget.onRuleDeselected(rule);
                } else {
                  widget.onRuleSelected(rule);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomRulesTab() {
    final setupProvider = context.read<SetupProvider>();
    final customRules = setupProvider.customRules;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Header compacto con botón y cantidad
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.rule, color: Color(0xFF22C55E), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Mis Reglas: ',
                style: TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${customRules.length}',
                  style: const TextStyle(
                    color: Color(0xFF22C55E),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCustomRuleForm(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  shadowColor: const Color(0xFF22C55E).withValues(alpha: 0.18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Lista de reglas personalizadas
          Flexible(
            fit: FlexFit.loose,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 350),
              child: customRules.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF374151),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.rule_outlined,
                              size: 48,
                              color: Color(0xFF6B7280),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No tienes reglas personalizadas',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Crea tu primera regla personalizada\ntocando el botón "Nueva"',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: customRules.length,
                      itemBuilder: (context, index) {
                        final rule = customRules[index];
                        final isSelected = widget.selectedRules.any(
                          (selectedRule) => selectedRule.id == rule.id,
                        );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: RuleCard(
                            rule: rule,
                            isSelected: isSelected,
                            showDeleteButton: true,
                            onTap: () {
                              if (isSelected) {
                                widget.onRuleDeselected(rule);
                              } else {
                                widget.onRuleSelected(rule);
                              }
                            },
                            onDelete: () =>
                                _showDeleteCustomRuleDialog(context, rule),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomRuleForm(BuildContext context, [Rule? ruleToEdit]) {
    showDialog(
      context: context,
      builder: (context) => CustomRuleForm(
        ruleToEdit: ruleToEdit,
        onSave: (rule) {
          final setupProvider = context.read<SetupProvider>();
          if (ruleToEdit != null) {
            setupProvider.updateCustomRule(rule);
          } else {
            setupProvider.addCustomRule(rule);
          }
        },
      ),
    );
  }

  void _showDeleteCustomRuleDialog(BuildContext context, Rule rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Eliminar Regla',
          style: TextStyle(
            color: Color(0xFFF8FAFC),
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar la regla "${rule.name}"?',
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final setupProvider = context.read<SetupProvider>();
              setupProvider.deleteCustomRule(rule.id);
              Navigator.of(context).pop();
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
