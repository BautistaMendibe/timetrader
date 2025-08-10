import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../services/simulation_provider.dart';
import '../services/setup_provider.dart';
import '../models/setup.dart';
import '../routes.dart';
import '../widgets/top_snack_bar.dart';

class SimulationSetupScreen extends StatefulWidget {
  const SimulationSetupScreen({super.key});

  @override
  State<SimulationSetupScreen> createState() => _SimulationSetupScreenState();
}

class _SimulationSetupScreenState extends State<SimulationSetupScreen> {
  final DataService _dataService = DataService();
  String? _selectedAsset;
  DateTime? _selectedDate;
  Setup? _selectedSetup;
  double _initialBalance = 1000.0; // Default initial balance
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeValues();
  }

  void _initializeValues() {
    // Set default values
    final assets = _dataService.getAvailableAssets();

    if (assets.isNotEmpty) _selectedAsset = assets.first;

    _isInitialized = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure selected date is valid after dependencies are available
    if (!_isInitialized) {
      _initializeValues();
    }
  }

  Future<void> _startSimulation() async {
    if (_selectedAsset == null ||
        _selectedDate == null ||
        _selectedSetup == null) {
      String errorMessage = 'Por favor completa todos los campos:';
      if (_selectedAsset == null) errorMessage += '\n• Selecciona un activo';
      if (_selectedDate == null) {
        errorMessage += '\n• Selecciona una fecha de inicio';
      }
      if (_selectedSetup == null) errorMessage += '\n• Selecciona un setup';

      TopSnackBar.showError(
        context: context,
        message: errorMessage,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Validar que la fecha no sea futura
    final now = DateTime.now();
    if (_selectedDate!.isAfter(now)) {
      TopSnackBar.showError(
        context: context,
        message:
            'No se puede simular con fechas futuras. Selecciona una fecha anterior a hoy.',
        duration: const Duration(seconds: 3),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final simulationProvider = context.read<SimulationProvider>();

      // Load historical data
      final data = await _dataService.loadHistorical(
        _selectedAsset!,
        _selectedDate!,
      );

      // Set data and start simulation
      simulationProvider.setHistoricalData(data);
      simulationProvider.startTickSimulation(
        _selectedSetup!,
        _selectedDate!,
        1.0,
        _initialBalance,
        _selectedAsset!,
      );

      if (mounted) {
        Navigator.pushNamed(context, AppRoutes.simulation);
      }
    } catch (e) {
      if (mounted) {
        TopSnackBar.showError(
          context: context,
          message: 'Error al cargar datos: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure we have valid values before building
    if (!_isInitialized) {
      _initializeValues();
    }

    // Validate that selected asset is in the available options
    final availableAssets = _dataService.getAvailableAssets();

    if (_selectedAsset != null && !availableAssets.contains(_selectedAsset)) {
      _selectedAsset = availableAssets.isNotEmpty
          ? availableAssets.first
          : null;
    }

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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Asset Selection
                      _buildSection(
                        title: 'Activo',
                        child: DropdownButtonFormField<String>(
                          value: _selectedAsset,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF374151),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF374151),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF22C55E),
                              ),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF111827),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          dropdownColor: const Color(0xFF1F2937),
                          style: const TextStyle(
                            color: Color(0xFFF8FAFC),
                            fontSize: 16,
                            fontFamily: 'Inter',
                          ),
                          items: _dataService.getAvailableAssets().map((asset) {
                            return DropdownMenuItem(
                              value: asset,
                              child: Text(
                                asset,
                                style: const TextStyle(
                                  color: Color(0xFFF8FAFC),
                                  fontFamily: 'Inter',
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedAsset = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Date Selection
                      _buildSection(
                        title: 'Fecha de Inicio',
                        child: InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  _selectedDate ??
                                  DateTime.now().subtract(
                                    const Duration(days: 1),
                                  ),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().subtract(
                                const Duration(days: 1),
                              ),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: Color(0xFF22C55E),
                                      onPrimary: Colors.white,
                                      surface: Color(0xFF1F2937),
                                      onSurface: Colors.white,
                                    ),
                                    dialogTheme: const DialogThemeData(
                                      backgroundColor: Color(0xFF111827),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF374151),
                              ),
                              borderRadius: BorderRadius.circular(16),
                              color: const Color(0xFF111827),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  color: Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedDate != null
                                        ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                        : 'Seleccionar fecha',
                                    style: TextStyle(
                                      color: _selectedDate != null
                                          ? const Color(0xFFF8FAFC)
                                          : const Color(0xFF94A3B8),
                                      fontSize: 16,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  color: Color(0xFF94A3B8),
                                ),
                              ],
                            ),
                          ),
                        ),
                        subtitle:
                            'Selecciona cualquier fecha desde 2020 hasta ayer',
                      ),
                      const SizedBox(height: 20),

                      // Setup Selection
                      Consumer<SetupProvider>(
                        builder: (context, setupProvider, child) {
                          return _buildSection(
                            title: 'Setup',
                            child: setupProvider.setups.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xFF374151),
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      color: const Color(0xFF111827),
                                    ),
                                    child: Column(
                                      children: [
                                        const Icon(
                                          Icons.add_chart,
                                          color: Color(0xFF94A3B8),
                                          size: 48,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No hay setups disponibles',
                                          style: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 16,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pushNamed(
                                              context,
                                              AppRoutes.setupForm,
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF22C55E,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Text(
                                            'Crear Setup',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : DropdownButtonFormField<String>(
                                    value: _selectedSetup?.id,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF374151),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF374151),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF22C55E),
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFF111827),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                    ),
                                    dropdownColor: const Color(0xFF1F2937),
                                    style: const TextStyle(
                                      color: Color(0xFFF8FAFC),
                                      fontSize: 16,
                                      fontFamily: 'Inter',
                                    ),
                                    items: setupProvider.setups.map((setup) {
                                      return DropdownMenuItem(
                                        value: setup.id,
                                        child: Text(
                                          setup.name,
                                          style: const TextStyle(
                                            color: Color(0xFFF8FAFC),
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) async {
                                      if (value != null) {
                                        final selectedSetup = setupProvider
                                            .setups
                                            .firstWhere(
                                              (setup) => setup.id == value,
                                              orElse: () =>
                                                  setupProvider.setups.first,
                                            );
                                        setState(() {
                                          _selectedSetup = selectedSetup;
                                        });
                                      }
                                    },
                                    validator: (value) {
                                      if (value == null) {
                                        return 'Por favor selecciona un setup';
                                      }
                                      return null;
                                    },
                                  ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Initial Balance Selection
                      _buildSection(
                        title: 'Balance Inicial',
                        child: TextFormField(
                          initialValue: _initialBalance.toString(),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Cantidad en USD',
                            labelStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontFamily: 'Inter',
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF374151),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF374151),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF22C55E),
                              ),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF111827),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            prefixText: '\$ ',
                            prefixStyle: const TextStyle(
                              color: Color(0xFFF8FAFC),
                              fontFamily: 'Inter',
                            ),
                          ),
                          style: const TextStyle(
                            color: Color(0xFFF8FAFC),
                            fontSize: 16,
                            fontFamily: 'Inter',
                          ),
                          onChanged: (value) {
                            final balance = double.tryParse(value);
                            if (balance != null && balance > 100) {
                              setState(() {
                                _initialBalance = balance;
                              });
                            }
                          },
                          validator: (value) {
                            final balance = double.tryParse(value ?? '');
                            if (balance == null || balance < 100) {
                              return 'El balance mínimo es \$100';
                            }
                            return null;
                          },
                        ),
                        subtitle:
                            'Balance inicial para la simulación (mínimo \$100)',
                      ),
                      const SizedBox(height: 32),

                      // Start Simulation Button
                      ElevatedButton(
                        onPressed: _isLoading || _selectedSetup == null
                            ? null
                            : _startSimulation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: const Color(0xFF6B7280),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Iniciar Simulación',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                ),
                              ),
                      ),
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
              size: 24,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Configurar Simulación',
            style: TextStyle(
              color: Color(0xFFF8FAFC),
              fontWeight: FontWeight.w600,
              fontSize: 20,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF374151)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontWeight: FontWeight.w600,
              fontSize: 18,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),
          child,
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
