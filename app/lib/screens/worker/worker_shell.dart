import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'worker_profile_screen.dart';

class WorkerShell extends StatefulWidget {
  final Map<String, dynamic> user;

  const WorkerShell({super.key, required this.user});

  @override
  State<WorkerShell> createState() => _WorkerShellState();
}

class _WorkerShellState extends State<WorkerShell> {
  late int _index;
  late bool _profileDone;

  static const _titles = ['Anuncios', 'Mi Perfil'];

  @override
  void initState() {
    super.initState();
    _profileDone = widget.user['profile_completed'] == true;
    // Sin perfil completo, se abre directo en "Mi perfil"
    _index = _profileDone ? 0 : 1;
  }

  void _goTo(int i) {
    if (i == 0 && !_profileDone) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Primero completa tu perfil para ver los anuncios'),
        ));
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        titleSpacing: 16,
        title: Row(
          children: [
            // LOGO: reemplaza el Icon por
            // Image.asset('assets/images/logo.png', height: 32)
            const Icon(Icons.handyman, color: AppColors.tertiary, size: 28),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TuOficio',
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'TRABAJADOR',
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  _titles[_index],
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => setState(() => _index = 1),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryContainer.withAlpha(100),
                    width: 2,
                  ),
                ),
                child: const CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  // AVATAR: reemplaza el child por
                  // backgroundImage: AssetImage('assets/images/avatar_default.png')
                  child: Icon(Icons.person,
                      size: 18, color: AppColors.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ],
      ),
      // El orden de estos hijos debe coincidir con el de las pestañas
      body: IndexedStack(
        index: _index,
        children: [
          const _PantallaPendiente(
              icon: Icons.campaign, nombre: 'Anuncios de clientes'),
          WorkerProfileScreen(
            onProfileSaved: () => setState(() => _profileDone = true),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLow,
          boxShadow: [
            BoxShadow(
              color: Color(0x73000000),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.campaign,
                  label: 'Anuncios',
                  selected: _index == 0,
                  onTap: () => _goTo(0),
                ),
                const SizedBox(width: 8),
                _NavItem(
                  icon: Icons.person,
                  label: 'Mi perfil',
                  selected: _index == 1,
                  onTap: () => _goTo(1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? const Color(0xFFDBE1FF) : AppColors.onSurfaceVariant;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.surfaceContainerHighest.withAlpha(153)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PantallaPendiente extends StatelessWidget {
  final IconData icon;
  final String nombre;

  const _PantallaPendiente({required this.icon, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(
            nombre,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pantalla pendiente',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}