import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/setup.dart';

class FirebaseSetupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'setups';

  // Get current user ID
  String? get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  // Get user's setups collection reference
  CollectionReference<Map<String, dynamic>> get _userSetupsCollection {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }
    return _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection(_collectionName);
  }

  // No example setups - only user setups
  static const List<Map<String, dynamic>> _exampleSetups = [];

  // Get all setups (user setups only)
  Future<List<Setup>> getAllSetups() async {
    try {
      // Check if Firebase is initialized
      try {
        _firestore.app;
      } catch (e) {
        return [];
      }

      // Get user setups from Firestore (only current user's setups)
      final QuerySnapshot userSetupsSnapshot = await _userSetupsCollection
          .get();

      // Convert user setups
      final List<Setup> userSetups = userSetupsSnapshot.docs
          .where((doc) {
            final data = doc.data();
            return data != null && data is Map<String, dynamic>;
          })
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Setup.fromJson({...data, 'id': doc.id});
          })
          .toList();

      // Ordenar localmente
      userSetups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Return only user setups (no examples)
      return userSetups;
    } catch (e) {
      // Return empty list if there's an error
      return [];
    }
  }

  // Get only user setups
  Future<List<Setup>> getUserSetups() async {
    try {
      final QuerySnapshot snapshot = await _userSetupsCollection.get();

      final setups = snapshot.docs
          .where((doc) {
            final data = doc.data();
            return data != null && data is Map<String, dynamic>;
          })
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Setup.fromJson({...data, 'id': doc.id});
          })
          .toList();

      // Ordenar localmente
      setups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return setups;
    } catch (e) {
      return [];
    }
  }

  // Add a new setup
  Future<void> addSetup(Setup setup) async {
    try {
      debugPrint('DEBUG: FirebaseSetupService.addSetup - Iniciando...');

      // Check if Firebase is initialized
      try {
        _firestore.app;
        debugPrint(
          'DEBUG: FirebaseSetupService.addSetup - Firebase está inicializado',
        );
      } catch (e) {
        debugPrint(
          'DEBUG: FirebaseSetupService.addSetup - Firebase no está inicializado: $e',
        );
        throw Exception('Firebase no está inicializado');
      }

      final Map<String, dynamic> setupData = {
        'name': setup.name,
        'riskPercent': setup.riskPercent,
        'stopLossDistance': setup.stopLossDistance,
        'stopLossType': setup.stopLossType.toString(),
        'takeProfitRatio': setup.takeProfitRatio.toString(),
        'customTakeProfitRatio': setup.customTakeProfitRatio,
        'useAdvancedRules': setup.useAdvancedRules,
        'rules': setup.rules.map((rule) => rule.toJson()).toList(),
        'createdAt': setup.createdAt.toIso8601String(),
        'userId': _currentUserId,
      };

      debugPrint(
        'DEBUG: FirebaseSetupService.addSetup - Datos preparados, guardando en Firestore...',
      );

      // Agregar timeout para evitar que se quede colgado
      await _userSetupsCollection
          .add(setupData)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint(
                'DEBUG: FirebaseSetupService.addSetup - Timeout al guardar en Firestore',
              );
              throw Exception('Timeout al guardar en Firestore');
            },
          );

      debugPrint(
        'DEBUG: FirebaseSetupService.addSetup - Guardado exitosamente en Firestore',
      );
    } catch (e) {
      debugPrint('DEBUG: FirebaseSetupService.addSetup - Error: $e');
      throw Exception('Failed to add setup: $e');
    }
  }

  // Update an existing setup
  Future<void> updateSetup(Setup setup) async {
    try {
      final setupData = setup.toJson();

      await _userSetupsCollection.doc(setup.id).update(setupData);
    } catch (e) {
      throw Exception('Failed to update setup: $e');
    }
  }

  // Delete a setup
  Future<void> deleteSetup(String setupId) async {
    try {
      debugPrint(
        'DEBUG: FirebaseSetupService.deleteSetup - Iniciando eliminación: $setupId',
      );

      debugPrint(
        'DEBUG: FirebaseSetupService.deleteSetup - Eliminando de Firestore...',
      );
      await _userSetupsCollection.doc(setupId).delete();
      debugPrint(
        'DEBUG: FirebaseSetupService.deleteSetup - Eliminación completada en Firestore',
      );
    } catch (e) {
      debugPrint('DEBUG: FirebaseSetupService.deleteSetup - Error: $e');
      throw Exception('Failed to delete setup: $e');
    }
  }

  // Get a setup by ID
  Future<Setup?> getSetupById(String setupId) async {
    try {
      // Get from Firestore
      final DocumentSnapshot doc = await _userSetupsCollection
          .doc(setupId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data is Map<String, dynamic>) {
          final setup = Setup.fromJson({...data, 'id': doc.id});
          return setup;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Listen to user setups changes
  Stream<List<Setup>> listenToUserSetups() {
    return _userSetupsCollection.snapshots().map((snapshot) {
      final setups = snapshot.docs.map((doc) {
        final data = doc.data();
        return Setup.fromJson({...data, 'id': doc.id});
      }).toList();

      // Ordenar localmente
      setups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return setups;
    });
  }

  // Listen to all setups changes (user setups only)
  Stream<List<Setup>> listenToAllSetups() {
    return _userSetupsCollection.snapshots().map((snapshot) {
      final userSetups = snapshot.docs.map((doc) {
        final data = doc.data();
        return Setup.fromJson({...data, 'id': doc.id});
      }).toList();

      // Ordenar localmente en lugar de en la consulta
      userSetups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return userSetups;
    });
  }
}
