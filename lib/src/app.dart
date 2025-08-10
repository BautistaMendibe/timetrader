import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'routes.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'services/setup_provider.dart';
import 'services/simulation_provider.dart';
import 'services/navigation_provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SetupProvider()),
        ChangeNotifierProvider(create: (_) => SimulationProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: MaterialApp(
        title: 'TimeTrader',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          primaryColor: const Color(0xFF22C55E),
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
            primary: Color(0xFF22C55E),
            secondary: Color(0xFF22C55E),
            surface: Color(0xFF2C2C2C),
          ),
        ),
        home: const AuthWrapper(),
        routes: AppRoutes.getRoutes(),
      ),
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
        debugPrint(
          'AuthWrapper - Connection state: ${snapshot.connectionState}',
        );
        debugPrint('AuthWrapper - Has data: ${snapshot.hasData}');
        debugPrint('AuthWrapper - User: ${snapshot.data?.email}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF22C55E)),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          debugPrint(
            'AuthWrapper - User is signed in, navigating to main navigation',
          );
          return const SetupListenerWrapper(child: MainNavigation());
        }

        debugPrint('AuthWrapper - User is not signed in, showing login screen');
        return const LoginScreen();
      },
    );
  }
}

class SetupListenerWrapper extends StatefulWidget {
  final Widget child;

  const SetupListenerWrapper({super.key, required this.child});

  @override
  State<SetupListenerWrapper> createState() => _SetupListenerWrapperState();
}

class _SetupListenerWrapperState extends State<SetupListenerWrapper> {
  @override
  void initState() {
    super.initState();
    // Start listening to setup changes when user is authenticated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SetupProvider>().startListening();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
