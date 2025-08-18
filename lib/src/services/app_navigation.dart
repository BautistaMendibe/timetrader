import 'package:flutter/material.dart';
import '../screens/setup_detail_screen.dart';
import '../screens/setup_form_screen.dart';
import '../models/setup.dart';

class AppNavigation {
  // Method to navigate to setup detail
  static void navigateToSetupDetail(BuildContext context, Setup setup) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SetupDetailScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  // Method to navigate to setup form
  static void navigateToSetupForm(BuildContext context, {Setup? setupToEdit}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SetupFormScreen(setupToEdit: setupToEdit),
        fullscreenDialog: true,
      ),
    );
  }
}
