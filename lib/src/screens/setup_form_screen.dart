import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/setup_provider.dart';
import '../models/setup.dart';
import '../models/rule.dart';
import '../widgets/rule_selector.dart';
import '../widgets/rule_card.dart';

class SetupFormScreen extends StatefulWidget {
  final Setup? setupToEdit;
  
  const SetupFormScreen({
    super.key,
    this.setupToEdit,
  });

  @override
  State<SetupFormScreen> createState() => _SetupFormScreenState();
}

class _SetupFormScreenState extends State<SetupFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _assetController = TextEditingController();
  final _positionSizeController = TextEditingController();
  final _stopLossController = TextEditingController();
  final _takeProfitController = TextEditingController();
  
  ValueType _positionSizeType = ValueType.fixed;
  ValueType _stopLossType = ValueType.percentage;
  ValueType _takeProfitType = ValueType.percentage;
  
  bool _useAdvancedRules = false;
  final List<Rule> _selectedRules = [];
  bool _showRulesSelector = false;

  @override
  void initState() {
    super.initState();
    if (widget.setupToEdit != null) {
      // Modo edición
      _nameController.text = widget.setupToEdit!.name;
      _assetController.text = widget.setupToEdit!.asset;
      _positionSizeController.text = widget.setupToEdit!.positionSize.toString();
      _positionSizeType = widget.setupToEdit!.positionSizeType;
      _stopLossController.text = widget.setupToEdit!.stopLossPercent.toString();
      _stopLossType = widget.setupToEdit!.stopLossType;
      _takeProfitController.text = widget.setupToEdit!.takeProfitPercent.toString();
      _takeProfitType = widget.setupToEdit!.takeProfitType;
      _useAdvancedRules = widget.setupToEdit!.useAdvancedRules;
      _selectedRules.addAll(widget.setupToEdit!.rules);
    } else {
      // Modo creación
      _assetController.text = 'BTC/USD';
      _positionSizeController.text = '100';
      _stopLossController.text = '2.0';
      _takeProfitController.text = '4.0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _assetController.dispose();
    _positionSizeController.dispose();
    _stopLossController.dispose();
    _takeProfitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.setupToEdit != null ? 'Editar Setup' : 'Nuevo Setup'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF21CE99)),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveSetup,
              child: const Text(
                'Guardar',
                style: TextStyle(
                  color: Color(0xFF21CE99),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildBasicInfoSection(),
            const SizedBox(height: 24),
            _buildRiskManagementSection(),
            const SizedBox(height: 24),
            _buildRulesSection(),
            const SizedBox(height: 24),
            if (_showRulesSelector) _buildRulesSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      color: const Color(0xFF2A2A2A),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF21CE99),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Información Básica',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del Setup',
                labelStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF21CE99)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingresa un nombre';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _assetController,
              decoration: const InputDecoration(
                labelText: 'Activo',
                labelStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF21CE99)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingresa un activo';
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
    return Card(
      color: const Color(0xFF2A2A2A),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.security,
                  color: Color(0xFF21CE99),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Gestión de Riesgo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Position Size
            _buildValueInput(
              controller: _positionSizeController,
              label: 'Tamaño de Posición',
              type: _positionSizeType,
              onTypeChanged: (type) {
                setState(() {
                  _positionSizeType = type;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Requerido';
                }
                if (double.tryParse(value) == null) {
                  return 'Número válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Stop Loss y Take Profit en la misma fila
            Row(
              children: [
                Expanded(
                  child: _buildValueInput(
                    controller: _stopLossController,
                    label: 'Stop Loss',
                    type: _stopLossType,
                    onTypeChanged: (type) {
                      setState(() {
                        _stopLossType = type;
                      });
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
                const SizedBox(width: 16),
                Expanded(
                  child: _buildValueInput(
                    controller: _takeProfitController,
                    label: 'Take Profit',
                    type: _takeProfitType,
                    onTypeChanged: (type) {
                      setState(() {
                        _takeProfitType = type;
                      });
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueInput({
    required TextEditingController controller,
    required String label,
    required ValueType type,
    required Function(ValueType) onTypeChanged,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: type == ValueType.percentage ? 'Porcentaje' : 'Cantidad',
                  labelStyle: const TextStyle(color: Colors.grey),
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF21CE99)),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                validator: validator,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButton<ValueType>(
                value: type,
                underline: const SizedBox(),
                dropdownColor: const Color(0xFF2A2A2A),
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(
                    value: ValueType.percentage,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('%'),
                    ),
                  ),
                  DropdownMenuItem(
                    value: ValueType.fixed,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('\$'),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onTypeChanged(value);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRulesSection() {
    return Card(
      color: const Color(0xFF2A2A2A),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.rule,
                  color: Color(0xFF21CE99),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Reglas de Trading',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text(
                'Usar reglas avanzadas',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Agregar condiciones específicas para las entradas',
                style: TextStyle(color: Colors.grey),
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
              activeColor: const Color(0xFF21CE99),
            ),
            if (_useAdvancedRules) ...[
              const SizedBox(height: 16),
              if (_selectedRules.isNotEmpty) ...[
                Text(
                  'Reglas seleccionadas (${_selectedRules.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ..._selectedRules.map((rule) => RuleCard(
                  rule: rule,
                  showDeleteButton: true,
                  onDelete: () {
                    setState(() {
                      _selectedRules.remove(rule);
                    });
                  },
                )),
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
                  backgroundColor: const Color(0xFF21CE99),
                  foregroundColor: Colors.white,
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

    return Card(
      color: const Color(0xFF2A2A2A),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.list_alt,
                  color: Color(0xFF21CE99),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Seleccionar Reglas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
      print('DEBUG: Iniciando guardado de setup...');
      final setup = Setup(
        id: widget.setupToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        asset: _assetController.text,
        positionSize: double.parse(_positionSizeController.text),
        positionSizeType: _positionSizeType,
        stopLossPercent: double.parse(_stopLossController.text),
        stopLossType: _stopLossType,
        takeProfitPercent: double.parse(_takeProfitController.text),
        takeProfitType: _takeProfitType,
        useAdvancedRules: _useAdvancedRules,
        rules: _selectedRules,
        createdAt: widget.setupToEdit?.createdAt ?? DateTime.now(),
      );

      final setupProvider = context.read<SetupProvider>();
      
      print('DEBUG: Setup creado, guardando en Firebase...');
      
      if (widget.setupToEdit != null) {
        await setupProvider.updateSetup(setup);
        if (mounted) {
          // Limpiar el estado de loading antes de mostrar el snackbar
          setState(() {
            _isSaving = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Setup actualizado exitosamente'),
              backgroundColor: Color(0xFF21CE99),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        print('DEBUG: Guardando nuevo setup...');
        await setupProvider.addSetup(setup);
        print('DEBUG: Setup guardado exitosamente (local o Firebase)');
        if (mounted) {
          // Limpiar el estado de loading antes de mostrar el diálogo
          setState(() {
            _isSaving = false;
          });
          
          print('DEBUG: Mostrando diálogo de confirmación...');
          // Mostrar diálogo de confirmación para nuevos setups
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: const Color(0xFF2A2A2A),
                title: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF21CE99),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '¡Setup Creado!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                content: Text(
                  'El setup "${setup.name}" ha sido creado exitosamente.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Cerrar diálogo
                      Navigator.of(context).pop(); // Volver al listado
                      // Mostrar snackbar adicional en la pantalla del listado
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Setup "${setup.name}" agregado al listado'),
                          backgroundColor: const Color(0xFF21CE99),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Text(
                      'Ver Listado',
                      style: TextStyle(
                        color: Color(0xFF21CE99),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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