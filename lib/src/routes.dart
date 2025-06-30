import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/setups_list_screen.dart';
import 'screens/setup_detail_screen.dart';
import 'screens/setup_form_screen.dart';
import 'screens/simulation_setup_screen.dart';
import 'screens/simulation_screen.dart';
import 'screens/simulation_summary_screen.dart';
import 'screens/test_chart_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String setupsList = '/setups-list';
  static const String setupDetail = '/setup-detail';
  static const String setupForm = '/setup-form';
  static const String simulationSetup = '/simulation-setup';
  static const String simulation = '/simulation';
  static const String simulationSummary = '/simulation-summary';
  static const String testChart = '/test-chart';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      login: (context) => const LoginScreen(),
      dashboard: (context) => const DashboardScreen(),
      setupsList: (context) => const SetupsListScreen(),
      setupDetail: (context) => const SetupDetailScreen(),
      setupForm: (context) => const SetupFormScreen(),
      simulationSetup: (context) => const SimulationSetupScreen(),
      simulation: (context) => const SimulationScreen(),
      simulationSummary: (context) => const SimulationSummaryScreen(),
      testChart: (context) => const TestChartScreen(),
    };
  }
} 