import 'package:flutter/material.dart';

import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const TuOficioApp());
}

class TuOficioApp extends StatelessWidget {
  const TuOficioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TuOficio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const WelcomeScreen(),
    );
  }
}