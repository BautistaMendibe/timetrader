import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/setup_detail_screen.dart';
import 'screens/setup_form_screen.dart';
import 'screens/simulation_screen.dart';
import 'screens/test_chart_screen.dart';
import 'models/setup.dart';

class AppRoutes {
  static const String login = '/login';
  static const String main = '/main';
  static const String setupDetail = '/setup-detail';
  static const String setupForm = '/setup-form';
  static const String simulation = '/simulation';
  static const String testChart = '/test-chart';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      login: (context) => const LoginScreen(),
      main: (context) => const MainNavigation(),
      setupDetail: (context) => const SetupDetailScreen(),
      setupForm: (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        final setupToEdit = args is Setup ? args : null;
        return SetupFormScreen(setupToEdit: setupToEdit);
      },
      simulation: (context) => const SimulationScreen(),
      testChart: (context) => const TestChartScreen(),
    };
  }
}
