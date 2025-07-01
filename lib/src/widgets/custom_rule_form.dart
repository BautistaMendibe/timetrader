import 'package:flutter/material.dart';
import '../models/rule.dart';

class CustomRuleForm extends StatefulWidget {
  final Rule? ruleToEdit;
  final Function(Rule) onSave;

  const CustomRuleForm({
    super.key,
    this.ruleToEdit,
    required this.onSave,
  });

  @override
  State<CustomRuleForm> createState() => _CustomRuleFormState();
}

class _CustomRuleFormState extends State<CustomRuleForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  RuleType _selectedType = RuleType.technicalIndicator;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    if (widget.ruleToEdit != null) {
      _nameController.text = widget.ruleToEdit!.name;
      _descriptionController.text = widget.ruleToEdit!.description;
      _selectedType = widget.ruleToEdit!.type;
      _isActive = widget.ruleToEdit!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      title: Text(
        widget.ruleToEdit != null ? 'Editar Regla' : 'Nueva Regla Personalizada',
        style: const TextStyle(color: Colors.white),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la Regla',
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
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
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
                    return 'Por favor ingresa una descripción';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Tipo de Regla',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<RuleType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF21CE99)),
                  ),
                ),
                dropdownColor: const Color(0xFF2A2A2A),
                style: const TextStyle(color: Colors.white),
                items: RuleType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_getRuleTypeDisplayName(type)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text(
                  'Regla Activa',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'La regla se aplicará en los setups',
                  style: TextStyle(color: Colors.grey),
                ),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
                activeColor: const Color(0xFF21CE99),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: _saveRule,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF21CE99),
            foregroundColor: Colors.white,
          ),
          child: Text(
            widget.ruleToEdit != null ? 'Actualizar' : 'Crear',
          ),
        ),
      ],
    );
  }

  String _getRuleTypeDisplayName(RuleType type) {
    switch (type) {
      case RuleType.technicalIndicator:
        return 'Indicador Técnico';
      case RuleType.candlestickPattern:
        return 'Patrón de Vela';
      case RuleType.timeFrame:
        return 'Horario';
      case RuleType.other:
        return 'Otro';
    }
  }

  void _saveRule() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final rule = Rule(
      id: widget.ruleToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      description: _descriptionController.text,
      type: _selectedType,
      parameters: {}, // Los parámetros se pueden expandir en el futuro
      isActive: _isActive,
    );

    widget.onSave(rule);
    Navigator.of(context).pop();
  }
} 