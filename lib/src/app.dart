import 'package:flutter/material.dart';
import 'routes.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TimeTrader',
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF21CE99),
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        cardColor: const Color(0xFF2C2C2C),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2C2C2C),
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF21CE99),
          secondary: Color(0xFF21CE99),
          surface: Color(0xFF2C2C2C),
        ),
      ),
      initialRoute: AppRoutes.login,
      routes: AppRoutes.routes,
    );
  }
} 