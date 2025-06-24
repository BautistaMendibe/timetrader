import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'routes.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

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
      home: const AuthWrapper(),
      routes: AppRoutes.routes,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF21CE99),
              ),
            ),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          // User is signed in
          return const DashboardScreen();
        }
        
        // User is not signed in
        return const LoginScreen();
      },
    );
  }
} 