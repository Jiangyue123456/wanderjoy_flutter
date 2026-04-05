import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'auth/auth_gate.dart';

class WanderJoyApp extends StatelessWidget {
  const WanderJoyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WanderJoy',
      theme: AppTheme.light(),
      home: const AuthGate(),
    );
  }
}
