import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/setup_provider.dart';
import '../models/setup.dart';
import '../models/rule.dart';
import '../widgets/rule_selector.dart';
import '../widgets/rule_card.dart';
import '../widgets/top_snack_bar.dart';
import '../widgets/position_chart.dart';

class SetupFormScreen extends StatefulWidget {
  final Setup? setupToEdit;

  const SetupFormScreen({super.key, this.setupToEdit});

  @override
  State<SetupFormScreen> createState() => _SetupFormScreenState();
}

class _SetupFormScreenState extends State<SetupFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _riskPercentController = TextEditingController();
  final _stopLossDistanceController = TextEditingController();
  final _customTakeProfitController = TextEditingController();

  StopLossType _stopLossType = StopLossType.pips;
  TakeProfitRatio _takeProfitRatio = TakeProfitRatio.oneToTwo;

  bool _useAdvancedRules = false;
  final List<Rule> _selectedRules = [];
  bool _showRulesSelector = false;
  bool _showCustomTakeProfit = false;

  @override
  void initState() {
    super.initState();
    if (widget.setupToEdit != null) {
      // Modo edición
      _nameController.text = widget.setupToEdit!.name;
      _riskPercentController.text = widget.setupToEdit!.riskPercent.toString();
      _stopLossDistanceController.text = widget.setupToEdit!.stopLossDistance
          .toString();
      _stopLossType = widget.setupToEdit!.stopLossType;
      _takeProfitRatio = widget.setupToEdit!.takeProfitRatio;
      _useAdvancedRules = widget.setupToEdit!.useAdvancedRules;
      _selectedRules.addAll(widget.setupToEdit!.rules);

      if (widget.setupToEdit!.takeProfitRatio == TakeProfitRatio.custom) {
        _showCustomTakeProfit = true;
        _customTakeProfitController.text =
            widget.setupToEdit!.customTakeProfitRatio?.toString() ?? '2.0';
      }
    } else {
      // Modo creación
      _riskPercentController.text = '1.0';
      _stopLossDistanceController.text = '50.0';
    }

    // Add listeners to update chart when values change
    _riskPercentController.addListener(_updateChart);
    _stopLossDistanceController.addListener(_updateChart);
    _customTakeProfitController.addListener(_updateChart);
  }

  void _updateChart() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _riskPercentController.dispose();
    _stopLossDistanceController.dispose();
    _customTakeProfitController.dispose();
    super.dispose();
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
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildBasicInfoSection(),
                      const SizedBox(height: 24),
                      _buildRiskManagementSection(),
                      const SizedBox(height: 24),
                      _buildRulesSection(),
                      const SizedBox(height: 24),
                      if (_showRulesSelector) _buildRulesSelector(),
                      const SizedBox(height: 24),
                    ],
                  ),
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
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.setupToEdit != null ? 'Editar Setup' : 'Nuevo Setup',
              style: const TextStyle(
                color: Color(0xFFF8FAFC),
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFamily: 'Inter',
              ),
            ),
          ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: _saveSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
                shadowColor: const Color(0xFF22C55E).withValues(alpha: 0.18),
              ),
              child: const Text(
                'Guardar',
                style: TextStyle(
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

  Widget _buildBasicInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF374151), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF22C55E)),
                const SizedBox(width: 8),
                const Text(
                  'Información Básica',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF8FAFC),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nombre del Setup *',
                labelStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF374151)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF22C55E)),
                ),
                filled: true,
                fillColor: const Color(0xFF111827),
              ),
              style: const TextStyle(
                color: Color(0xFFF8FAFC),
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingresa un nombre';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskManagementSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF374151), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security, color: Color(0xFF22C55E)),
                const SizedBox(width: 8),
                const Text(
                  'Gestión de Riesgo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF8FAFC),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Risk per trade
            TextFormField(
              controller: _riskPercentController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Riesgo por Operación (%)',
                labelStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF374151)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF22C55E)),
                ),
                suffixText: '%',
                filled: true,
                fillColor: const Color(0xFF111827),
              ),
              style: const TextStyle(
                color: Color(0xFFF8FAFC),
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
              ),
              onChanged: (value) {
                setState(() {});
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Requerido';
                }
                final number = double.tryParse(value);
                if (number == null) {
                  return 'Número válido';
                }
                if (number <= 0 || number > 100) {
                  return 'Entre 0.1 y 100';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Stop Loss
            const Text(
              'Stop Loss',
              style: TextStyle(
                color: Color(0xFFF8FAFC),
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stopLossDistanceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _stopLossType == StopLossType.pips
                          ? 'Distancia (pips)'
                          : 'Precio (\$)',
                      labelStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF374151)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF22C55E)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF111827),
                    ),
                    style: const TextStyle(
                      color: Color(0xFFF8FAFC),
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Requerido';
                      }
                      final number = double.tryParse(value);
                      if (number == null) {
                        return 'Número válido';
                      }
                      if (number <= 0) {
                        return 'Debe ser mayor a 0';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF374151)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: DropdownButton<StopLossType>(
                    value: _stopLossType,
                    underline: const SizedBox(),
                    dropdownColor: const Color(0xFF1F2937),
                    style: const TextStyle(
                      color: Color(0xFFF8FAFC),
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: StopLossType.pips,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('Pips'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: StopLossType.price,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('Precio'),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _stopLossType = value;
                        });
                        _updateChart();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF374151).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF374151), width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFF94A3B8),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _stopLossType == StopLossType.price
                          ? 'Nivel exacto al que cierras la operación. La app ajusta tu posición para que al tocar ese precio pierdas justo tu % de riesgo.'
                          : 'Distancia en pips desde la entrada. La app calcula cuántas unidades necesitas para que esa cantidad de pips equivalga a tu % de riesgo.',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Take Profit Ratio
            const Text(
              'Take Profit',
              style: TextStyle(
                color: Color(0xFFF8FAFC),
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<TakeProfitRatio>(
              value: _takeProfitRatio,
              decoration: InputDecoration(
                labelText: 'Ratio Riesgo/Recompensa',
                labelStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF374151)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF22C55E)),
                ),
                filled: true,
                fillColor: const Color(0xFF111827),
              ),
              dropdownColor: const Color(0xFF1F2937),
              style: const TextStyle(
                color: Color(0xFFF8FAFC),
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
              ),
              items: TakeProfitRatio.values.map((ratio) {
                return DropdownMenuItem(
                  value: ratio,
                  child: Text(ratio.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _takeProfitRatio = value;
                    _showCustomTakeProfit = value == TakeProfitRatio.custom;
                  });
                  _updateChart();
                }
              },
            ),
            if (_showCustomTakeProfit) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _customTakeProfitController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Ratio Personalizado (ej: 2.5)',
                  labelStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF374151)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF22C55E)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF111827),
                ),
                style: const TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
                onChanged: (value) {
                  setState(() {});
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Requerido';
                  }
                  final number = double.tryParse(value);
                  if (number == null) {
                    return 'Número válido';
                  }
                  if (number <= 0) {
                    return 'Debe ser mayor a 0';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 16),

            // Position Chart
            PositionChart(
              riskPercent: double.tryParse(_riskPercentController.text) ?? 1.0,
              stopLossDistance:
                  double.tryParse(_stopLossDistanceController.text) ?? 0.0,
              stopLossType: _stopLossType,
              takeProfitRatio: _takeProfitRatio,
              customTakeProfitRatio: _showCustomTakeProfit
                  ? double.tryParse(_customTakeProfitController.text)
                  : null,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF374151), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rule, color: Color(0xFF22C55E)),
                const SizedBox(width: 8),
                const Text(
                  'Reglas de Trading',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF8FAFC),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text(
                'Usar reglas avanzadas',
                style: TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
              subtitle: const Text(
                'Agregar condiciones específicas para las entradas',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
              value: _useAdvancedRules,
              onChanged: (value) {
                setState(() {
                  _useAdvancedRules = value;
                  if (!value) {
                    _selectedRules.clear();
                    _showRulesSelector = false;
                  }
                });
              },
              activeColor: const Color(0xFF22C55E),
            ),
            if (_useAdvancedRules) ...[
              const SizedBox(height: 16),
              if (_selectedRules.isNotEmpty) ...[
                Text(
                  'Reglas seleccionadas (${_selectedRules.length})',
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 8),
                ..._selectedRules.map(
                  (rule) => RuleCard(
                    rule: rule,
                    showDeleteButton: true,
                    onDelete: () {
                      setState(() {
                        _selectedRules.remove(rule);
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showRulesSelector = !_showRulesSelector;
                  });
                },
                icon: Icon(_showRulesSelector ? Icons.close : Icons.add),
                label: Text(_showRulesSelector ? 'Cerrar' : 'Agregar Reglas'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                  shadowColor: const Color(0xFF22C55E).withValues(alpha: 0.18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRulesSelector() {
    final setupProvider = context.read<SetupProvider>();
    final availableRules = setupProvider.getAllAvailableRules();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF374151), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.list_alt, color: Color(0xFF22C55E)),
                const SizedBox(width: 8),
                const Text(
                  'Seleccionar Reglas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF8FAFC),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: RuleSelector(
                selectedRules: _selectedRules,
                availableRules: availableRules,
                onRuleSelected: (rule) {
                  setState(() {
                    if (!_selectedRules.any((r) => r.id == rule.id)) {
                      _selectedRules.add(rule);
                    }
                  });
                },
                onRuleDeselected: (rule) {
                  setState(() {
                    _selectedRules.removeWhere((r) => r.id == rule.id);
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSaving = false;

  Future<void> _saveSetup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      debugPrint('DEBUG: Iniciando guardado de setup...');

      double? customTakeProfitRatio;
      if (_takeProfitRatio == TakeProfitRatio.custom) {
        customTakeProfitRatio = double.tryParse(
          _customTakeProfitController.text,
        );
      }

      final setup = Setup(
        id:
            widget.setupToEdit?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        riskPercent: double.parse(_riskPercentController.text),
        stopLossDistance: double.parse(_stopLossDistanceController.text),
        stopLossType: _stopLossType,
        takeProfitRatio: _takeProfitRatio,
        customTakeProfitRatio: customTakeProfitRatio,
        useAdvancedRules: _useAdvancedRules,
        rules: _selectedRules,
        createdAt: widget.setupToEdit?.createdAt ?? DateTime.now(),
      );

      final setupProvider = context.read<SetupProvider>();

      debugPrint('DEBUG: Setup creado, guardando en Firebase...');

      if (widget.setupToEdit != null) {
        await setupProvider.updateSetup(setup);
        if (mounted) {
          // Limpiar el estado de loading antes de mostrar el snackbar
          setState(() {
            _isSaving = false;
          });

          TopSnackBar.showSuccess(
            context: context,
            message: 'Setup actualizado exitosamente',
          );
          Navigator.pop(context);
        }
      } else {
        debugPrint('DEBUG: Guardando nuevo setup...');
        await setupProvider.addSetup(setup);
        debugPrint('DEBUG: Setup guardado exitosamente (local o Firebase)');
        if (mounted) {
          // Limpiar el estado de loading
          setState(() {
            _isSaving = false;
          });

          // Navegar directamente al listado
          Navigator.of(context).pop();

          // Mostrar snackbar de confirmación en la pantalla del listado
          TopSnackBar.showSuccess(
            context: context,
            message: 'Setup "${setup.name}" creado exitosamente',
            duration: const Duration(seconds: 3),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        TopSnackBar.showError(
          context: context,
          message: 'Error: ${e.toString()}',
        );
      }
    } finally {
      // Solo limpiar el estado si no se ha limpiado ya
      if (mounted && _isSaving) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
