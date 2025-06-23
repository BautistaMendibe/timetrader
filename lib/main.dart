import 'package:flutter/material.dart';
import 'src/app.dart';

void main() {
  runApp(const TimeTraderApp());
}

class TimeTraderApp extends StatelessWidget {
  const TimeTraderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const App();
  }
}