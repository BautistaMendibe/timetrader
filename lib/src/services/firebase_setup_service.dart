import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/setup.dart';
import '../models/rule.dart';

class FirebaseSetupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'setups';

  // Example setups that are always available
  static const List<Map<String, dynamic>> _exampleSetups = [
    {
      'id': 'example_1',
      'name': 'Scalping BTC',
      'asset': 'BTC/USD',
      'positionSize': 100.0,
      'positionSizeType': 'ValueType.fixed',
      'stopLossPercent': 2.0,
      'stopLossType': 'ValueType.percentage',
      'takeProfitPercent': 4.0,
      'takeProfitType': 'ValueType.percentage',
      'useAdvancedRules': true,
      'rules': [
        {
          'id': 'ema_cross',
          'name': 'EMA 10 cruza EMA 5',
          'description': 'Cuando la EMA de 10 períodos cruza por encima de la EMA de 5 períodos',
          'type': 'RuleType.technicalIndicator',
          'parameters': {'ema1': 10, 'ema2': 5, 'direction': 'bullish'},
          'isActive': true,
        },
        {
          'id': 'morning_session',
          'name': 'Sesión de Mañana',
          'description': 'Operar solo entre 10:00 AM y 1:00 PM',
          'type': 'RuleType.timeFrame',
          'parameters': {'start_time': '10:00', 'end_time': '13:00', 'timezone': 'local'},
          'isActive': true,
        },
      ],
      'isExample': true,
    },
    {
      'id': 'example_2',
      'name': 'Swing Trading EUR/USD',
      'asset': 'EUR/USD',
      'positionSize': 5.0,
      'positionSizeType': 'ValueType.percentage',
      'stopLossPercent': 1.5,
      'stopLossType': 'ValueType.percentage',
      'takeProfitPercent': 3.0,
      'takeProfitType': 'ValueType.percentage',
      'useAdvancedRules': true,
      'rules': [
        {
          'id': 'rsi_oversold',
          'name': 'RSI en sobreventa',
          'description': 'Cuando el RSI está por debajo de 30',
          'type': 'RuleType.technicalIndicator',
          'parameters': {'rsi_period': 14, 'threshold': 30, 'condition': 'below'},
          'isActive': true,
        },
        {
          'id': 'hammer_pattern',
          'name': 'Patrón Martillo',
          'description': 'Formación de vela Martillo (reversión alcista)',
          'type': 'RuleType.candlestickPattern',
          'parameters': {'pattern': 'hammer', 'body_ratio': 0.3},
          'isActive': true,
        },
      ],
      'isExample': true,
    },
  ];

  // Get all setups (examples + user setups)
  Future<List<Setup>> getAllSetups() async {
    try {
      // Check if Firebase is initialized
      try {
        await _firestore.app;
      } catch (e) {
        print('Firebase not configured, returning example setups only');
        return _exampleSetups
            .map((exampleData) => Setup.fromJson(exampleData))
            .toList();
      }

      // Get user setups from Firestore
      final QuerySnapshot userSetupsSnapshot = await _firestore
          .collection(_collectionName)
          .where('isExample', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      // Convert user setups
      final List<Setup> userSetups = userSetupsSnapshot.docs
          .map((doc) => Setup.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();

      // Convert example setups
      final List<Setup> exampleSetups = _exampleSetups
          .map((exampleData) => Setup.fromJson(exampleData))
          .toList();

      // Combine and return (examples first, then user setups)
      return [...exampleSetups, ...userSetups];
    } catch (e) {
      print('Error getting setups: $e');
      // Return only example setups if there's an error
      return _exampleSetups
          .map((exampleData) => Setup.fromJson(exampleData))
          .toList();
    }
  }

  // Get only user setups (excluding examples)
  Future<List<Setup>> getUserSetups() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collectionName)
          .where('isExample', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Setup.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting user setups: $e');
      return [];
    }
  }

  // Add a new setup
  Future<void> addSetup(Setup setup) async {
    try {
      final setupData = setup.toJson();
      setupData['isExample'] = false; // Mark as user setup
      
      await _firestore.collection(_collectionName).add(setupData);
    } catch (e) {
      print('Error adding setup: $e');
      throw Exception('Failed to add setup: $e');
    }
  }

  // Update an existing setup
  Future<void> updateSetup(Setup setup) async {
    try {
      final setupData = setup.toJson();
      setupData['isExample'] = false; // Mark as user setup
      
      await _firestore.collection(_collectionName).doc(setup.id).update(setupData);
    } catch (e) {
      print('Error updating setup: $e');
      throw Exception('Failed to update setup: $e');
    }
  }

  // Delete a setup
  Future<void> deleteSetup(String setupId) async {
    try {
      // Check if it's an example setup
      final isExample = _exampleSetups.any((setup) => setup['id'] == setupId);
      if (isExample) {
        throw Exception('Cannot delete example setups');
      }
      
      await _firestore.collection(_collectionName).doc(setupId).delete();
    } catch (e) {
      print('Error deleting setup: $e');
      throw Exception('Failed to delete setup: $e');
    }
  }

  // Get a setup by ID
  Future<Setup?> getSetupById(String setupId) async {
    try {
      // Check if it's an example setup first
      final exampleSetup = _exampleSetups.firstWhere(
        (setup) => setup['id'] == setupId,
        orElse: () => <String, dynamic>{},
      );
      
      if (exampleSetup.isNotEmpty) {
        return Setup.fromJson(exampleSetup);
      }

      // If not an example, get from Firestore
      final DocumentSnapshot doc = await _firestore.collection(_collectionName).doc(setupId).get();
      
      if (doc.exists) {
        return Setup.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id});
      }
      
      return null;
    } catch (e) {
      print('Error getting setup by ID: $e');
      return null;
    }
  }

  // Check if a setup is an example
  bool isExampleSetup(String setupId) {
    return _exampleSetups.any((setup) => setup['id'] == setupId);
  }

  // Get example setups
  List<Setup> getExampleSetups() {
    return _exampleSetups
        .map((exampleData) => Setup.fromJson(exampleData))
        .toList();
  }

  // Listen to user setups changes
  Stream<List<Setup>> listenToUserSetups() {
    return _firestore
        .collection(_collectionName)
        .where('isExample', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Setup.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
            .toList());
  }

  // Listen to all setups changes (examples + user setups)
  Stream<List<Setup>> listenToAllSetups() {
    return _firestore
        .collection(_collectionName)
        .where('isExample', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final userSetups = snapshot.docs
              .map((doc) => Setup.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
              .toList();
          
          final exampleSetups = _exampleSetups
              .map((exampleData) => Setup.fromJson(exampleData))
              .toList();
          
          return [...exampleSetups, ...userSetups];
        });
  }
} 