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
  DateTime? _startDate;
  DateTime? _endDate;
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

    // Set default date range: 3 days ago to yesterday
    final now = DateTime.now();
    _startDate = now.subtract(const Duration(days: 3));
    _endDate = now.subtract(const Duration(days: 1));

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
        _startDate == null ||
        _endDate == null ||
        _selectedSetup == null) {
      String errorMessage = 'Por favor completa todos los campos:';
      if (_selectedAsset == null) errorMessage += '\n• Selecciona un activo';
      if (_startDate == null) {
        errorMessage += '\n• Selecciona una fecha de inicio';
      }
      if (_endDate == null) {
        errorMessage += '\n• Selecciona una fecha de fin';
      }
      if (_selectedSetup == null) errorMessage += '\n• Selecciona un setup';

      TopSnackBar.showError(
        context: context,
        message: errorMessage,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Validar que las fechas no sean futuras
    final now = DateTime.now();
    if (_startDate!.isAfter(now) || _endDate!.isAfter(now)) {
      TopSnackBar.showError(
        context: context,
        message:
            'No se puede simular con fechas futuras. Selecciona fechas anteriores a hoy.',
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Validar que la fecha de inicio sea anterior a la fecha de fin
    if (_startDate!.isAfter(_endDate!)) {
      TopSnackBar.showError(
        context: context,
        message: 'La fecha de inicio debe ser anterior a la fecha de fin.',
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
        _startDate!,
      );

      // Set data and start simulation
      simulationProvider.setHistoricalData(data);
      simulationProvider.startTickSimulation(
        _selectedSetup!,
        _startDate!,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Dropdown no modificable
                            DropdownButtonFormField<String>(
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
                              items: _dataService.getAvailableAssets().map((
                                asset,
                              ) {
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
                              onChanged: null, // No modificable
                            ),
                            const SizedBox(height: 12),
                            // Mensaje informativo
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF1E40AF,
                                ).withValues(alpha: 0.1),
                                border: Border.all(
                                  color: const Color(0xFF3B82F6),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: const Color(0xFF3B82F6),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Estamos trabajando para sumar más pares de divisas y criptomonedas próximamente.',
                                      style: TextStyle(
                                        color: const Color(0xFF3B82F6),
                                        fontSize: 14,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Date Range Selection
                      _buildSection(
                        title: 'Rango de Fechas',
                        child: InkWell(
                          onTap: () async {
                            final DateTimeRange? picked =
                                await showDateRangePicker(
                                  context: context,
                                  initialDateRange:
                                      _startDate != null && _endDate != null
                                      ? DateTimeRange(
                                          start: _startDate!,
                                          end: _endDate!,
                                        )
                                      : DateTimeRange(
                                          start: DateTime.now().subtract(
                                            const Duration(days: 2),
                                          ),
                                          end: DateTime.now().subtract(
                                            const Duration(days: 1),
                                          ),
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
                                _startDate = picked.start;
                                _endDate = picked.end;
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
                                  Icons.date_range,
                                  color: Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _startDate != null && _endDate != null
                                        ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year} - ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                        : 'Seleccionar rango de fechas',
                                    style: TextStyle(
                                      color:
                                          _startDate != null && _endDate != null
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
                            'Selecciona el rango de fechas para la simulación (desde 2020 hasta ayer)',
                      ),
                      const SizedBox(height: 20),

                      // Setup Selection
                      Consumer<SetupProvider>(
                        builder: (context, setupProvider, child) {
                          return _buildSection(
                            title: 'Setup',
                            child: setupProvider.setups.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.all(32),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF111827),
                                          Color(0xFF374151),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFF4B5563),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.15,
                                          ),
                                          offset: const Offset(0, 4),
                                          blurRadius: 12,
                                          spreadRadius: -2,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF6B7280),
                                                Color(0xFF4B5563),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF6B7280,
                                                ).withValues(alpha: 0.2),
                                                offset: const Offset(0, 4),
                                                blurRadius: 12,
                                                spreadRadius: -2,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.add_chart_rounded,
                                            color: Colors.white,
                                            size: 48,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        const Text(
                                          'No hay setups disponibles',
                                          style: TextStyle(
                                            color: Color(0xFFF8FAFC),
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Crea tu primer setup para comenzar',
                                          style: TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pushNamed(
                                              context,
                                              AppRoutes.setupForm,
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF10B981,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 32,
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            elevation: 0,
                                            shadowColor: const Color(
                                              0xFF10B981,
                                            ).withValues(alpha: 0.3),
                                          ),
                                          child: const Text(
                                            'Crear Setup',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
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

                      // Enhanced Start Simulation Button
                      Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient:
                              _isLoading ||
                                  _selectedSetup == null ||
                                  _startDate == null ||
                                  _endDate == null
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF6B7280),
                                    Color(0xFF4B5563),
                                  ],
                                )
                              : const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF10B981),
                                    Color(0xFF059669),
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            if (!(_isLoading ||
                                _selectedSetup == null ||
                                _startDate == null ||
                                _endDate == null))
                              BoxShadow(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.3),
                                offset: const Offset(0, 6),
                                blurRadius: 20,
                                spreadRadius: -2,
                              ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed:
                              _isLoading ||
                                  _selectedSetup == null ||
                                  _startDate == null ||
                                  _endDate == null
                              ? null
                              : _startSimulation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Iniciar Simulación',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Inter',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
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
    IconData? icon,
    List<Color>? iconGradient,
  }) {
    // Determine icon and gradient based on title
    IconData sectionIcon;
    List<Color> sectionGradient;

    switch (title.toLowerCase()) {
      case 'activo':
        sectionIcon = Icons.trending_up_rounded;
        sectionGradient = [const Color(0xFF10B981), const Color(0xFF059669)];
        break;
      case 'rango de fechas':
        sectionIcon = Icons.date_range_rounded;
        sectionGradient = [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)];
        break;
      case 'setup':
        sectionIcon = Icons.tune_rounded;
        sectionGradient = [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)];
        break;
      case 'balance inicial':
        sectionIcon = Icons.account_balance_wallet_rounded;
        sectionGradient = [const Color(0xFFF59E0B), const Color(0xFFD97706)];
        break;
      default:
        sectionIcon = icon ?? Icons.settings_rounded;
        sectionGradient =
            iconGradient ?? [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)];
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF374151), Color(0xFF1F2937)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF4B5563), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: sectionGradient,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: sectionGradient.first.withValues(alpha: 0.3),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Icon(sectionIcon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
