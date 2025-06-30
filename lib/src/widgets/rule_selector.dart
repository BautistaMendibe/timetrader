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
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBarView(
              controller: _tabController,
              children: [
                ...RuleType.values.map((type) => _buildRulesList(type)),
                _buildCustomRulesTab(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: ShapeDecoration(
          color: const Color(0xFF21CE99),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[400],
        isScrollable: true,
        labelPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        tabs: [
          _buildTab(Icons.trending_up, 'Indicadores'),
          _buildTab(Icons.candlestick_chart, 'Patrones'),
          _buildTab(Icons.schedule, 'Horarios'),
          _buildTab(Icons.settings, 'Otros'),
          _buildTab(Icons.rule, 'Mis Reglas'),
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
              fontWeight: FontWeight.w500,
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
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.rule_outlined,
                size: 48,
                color: Colors.grey,
              ),
              SizedBox(height: 12),
              Text(
                'No hay reglas disponibles',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Para este tipo de regla',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
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
          final isSelected = widget.selectedRules
              .any((selectedRule) => selectedRule.id == rule.id);

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
          // Header con botón de agregar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF21CE99).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF21CE99).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF21CE99).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.rule,
                    color: Color(0xFF21CE99),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mis Reglas Personalizadas',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${customRules.length} regla${customRules.length != 1 ? 's' : ''} creada${customRules.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCustomRuleForm(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nueva'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF21CE99),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Lista de reglas personalizadas
          Expanded(
            child: customRules.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.rule_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No tienes reglas personalizadas',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Crea tu primera regla personalizada\ntocando el botón "Nueva"',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
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
                      final isSelected = widget.selectedRules
                          .any((selectedRule) => selectedRule.id == rule.id);

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
                          onDelete: () => _showDeleteCustomRuleDialog(context, rule),
                        ),
                      );
                    },
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
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Eliminar Regla',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar la regla "${rule.name}"?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey),
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
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
} 