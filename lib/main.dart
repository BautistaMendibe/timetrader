import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'src/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const TimeTraderApp());
}

class TimeTraderApp extends StatelessWidget {
  const TimeTraderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const App();
  }
}