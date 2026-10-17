import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'welcome_screen.dart';

class HomePlaceholderScreen extends StatelessWidget {
  final Map<String, dynamic> user;

  const HomePlaceholderScreen({super.key, required this.user});

  Future<void> _cerrarSesion(BuildContext context) async {
    await ApiService.post('/logout');
    await ApiService.clearToken();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final esTrabajador = user['role'] == 'worker';
    final completo = user['profile_completed'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pantalla temporal'),
        backgroundColor: AppColors.background,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle,
                  size: 64, color: AppColors.secondary),
              const SizedBox(height: 16),
              Text(
                'Hola, ${user['name']}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text('Rol: ${esTrabajador ? 'Trabajador' : 'Cliente'}'),
              Text('Perfil completo: ${completo ? 'Sí' : 'No'}'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _cerrarSesion(context),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}