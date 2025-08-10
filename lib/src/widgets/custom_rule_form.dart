import 'package:flutter/material.dart';
import '../models/rule.dart';

class CustomRuleForm extends StatefulWidget {
  final Rule? ruleToEdit;
  final Function(Rule) onSave;

  const CustomRuleForm({super.key, this.ruleToEdit, required this.onSave});

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
      backgroundColor: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.ruleToEdit != null
            ? 'Editar Regla'
            : 'Nueva Regla Personalizada',
        style: const TextStyle(
          color: Color(0xFFF8FAFC),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
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
                decoration: InputDecoration(
                  labelText: 'Nombre de la Regla',
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descripción',
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
                    return 'Por favor ingresa una descripción';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Tipo de Regla',
                style: TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<RuleType>(
                value: _selectedType,
                decoration: InputDecoration(
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
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF374151), width: 1),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'Regla Activa',
                    style: TextStyle(
                      color: Color(0xFFF8FAFC),
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                  subtitle: const Text(
                    'La regla se aplicará en los setups',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                  ),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                  activeColor: const Color(0xFF22C55E),
                ),
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
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _saveRule,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22C55E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 0,
            shadowColor: const Color(0xFF22C55E).withValues(alpha: 0.18),
          ),
          child: Text(
            widget.ruleToEdit != null ? 'Actualizar' : 'Crear',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
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
      id:
          widget.ruleToEdit?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
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
