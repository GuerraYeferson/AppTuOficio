import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'auth_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _abrir(BuildContext context, String role) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AuthScreen(initialRole: role)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // LOGO: reemplaza el Icon por
                // Image.asset('assets/images/logo.png', fit: BoxFit.contain)
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.handyman, color: AppColors.tertiary),
                ),
                const SizedBox(height: 16),
                Text(
                  '¿Cómo deseas continuar?',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    height: 24 / 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(
                    'Selecciona tu perfil para ingresar a la plataforma',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      height: 18 / 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _RoleCard(
                  icon: Icons.person,
                  iconColor: AppColors.secondary,
                  title: 'Soy Cliente',
                  subtitle: 'Busco contratar un servicio',
                  onTap: () => _abrir(context, 'client'),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  icon: Icons.handyman,
                  iconColor: AppColors.tertiary,
                  title: 'Soy Trabajador',
                  subtitle: 'Ofrezco mis servicios',
                  onTap: () => _abrir(context, 'worker'),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿Ya tienes una cuenta? ',
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    InkWell(
                      onTap: () => _abrir(context, 'client'),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Iniciar sesión',
                              style: textTheme.titleMedium?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondary,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: AppColors.secondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 26, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward,
                size: 20,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}