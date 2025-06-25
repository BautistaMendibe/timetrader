import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../services/simulation_provider.dart';
import '../services/setup_provider.dart';
import '../models/setup.dart';
import '../routes.dart';

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
  double _selectedSpeed = 1.0;
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
    final dates = _dataService.getAvailableDates();
    
    if (assets.isNotEmpty) _selectedAsset = assets.first;
    if (dates.isNotEmpty) _selectedDate = dates.first;
    
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
    if (_selectedAsset == null || _selectedDate == null || _selectedSetup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona todos los campos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final simulationProvider = context.read<SimulationProvider>();
      
      // Load historical data
      final data = await _dataService.loadHistorical(_selectedAsset!, _selectedDate!);
      
      // Set data and start simulation
      simulationProvider.setHistoricalData(data);
      simulationProvider.startSimulation(_selectedSetup!, _selectedDate!, _selectedSpeed);
      
      if (mounted) {
        Navigator.pushNamed(context, AppRoutes.simulation);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.red,
          ),
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
    
    // Validate that selected values are in the available options
    final availableAssets = _dataService.getAvailableAssets();
    final availableDates = _dataService.getAvailableDates();
    
    if (_selectedAsset != null && !availableAssets.contains(_selectedAsset)) {
      _selectedAsset = availableAssets.isNotEmpty ? availableAssets.first : null;
    }
    
    if (_selectedDate != null && !availableDates.contains(_selectedDate)) {
      _selectedDate = availableDates.isNotEmpty ? availableDates.first : null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Simulación'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Asset Selection
            Card(
              color: const Color(0xFF2C2C2C),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activo',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedAsset,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                      ),
                      dropdownColor: const Color(0xFF2C2C2C),
                      style: const TextStyle(color: Colors.white),
                      items: _dataService.getAvailableAssets().map((asset) {
                        return DropdownMenuItem(
                          value: asset,
                          child: Text(asset),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedAsset = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Date Selection
            Card(
              color: const Color(0xFF2C2C2C),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fecha de Inicio',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<DateTime>(
                      value: _selectedDate,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                      ),
                      dropdownColor: const Color(0xFF2C2C2C),
                      style: const TextStyle(color: Colors.white),
                      items: _dataService.getAvailableDates().map((date) {
                        return DropdownMenuItem(
                          value: date,
                          child: Text('${date.day}/${date.month}/${date.year}'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedDate = value;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Por favor selecciona una fecha';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Setup Selection
            Consumer<SetupProvider>(
              builder: (context, setupProvider, child) {
                return Card(
                  color: const Color(0xFF2C2C2C),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Setup',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (setupProvider.setups.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[600]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.add_chart,
                                  color: Colors.grey[400],
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No hay setups disponibles',
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, AppRoutes.setupForm);
                                  },
                                  child: const Text('Crear Setup'),
                                ),
                              ],
                            ),
                          )
                        else
                          DropdownButtonFormField<Setup>(
                            value: _selectedSetup,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF1E1E1E),
                            ),
                            dropdownColor: const Color(0xFF2C2C2C),
                            style: const TextStyle(color: Colors.white),
                            items: setupProvider.setups.map((setup) {
                              return DropdownMenuItem(
                                value: setup,
                                child: Text(setup.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedSetup = value;
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
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Speed Selection
            Card(
              color: const Color(0xFF2C2C2C),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Velocidad de Simulación',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _selectedSpeed,
                            min: 0.1,
                            max: 5.0,
                            divisions: 49,
                            activeColor: const Color(0xFF21CE99),
                            onChanged: (value) {
                              setState(() {
                                _selectedSpeed = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${_selectedSpeed.toStringAsFixed(1)}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '0.1x',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        Text(
                          '5.0x',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Start Simulation Button
            ElevatedButton(
              onPressed: _isLoading || _selectedSetup == null ? null : _startSimulation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF21CE99),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Iniciar Simulación',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }
} 