import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'client_posts_screen.dart';
import 'client_profile_screen.dart';

class ClientShell extends StatefulWidget {
  final Map<String, dynamic> user;

  const ClientShell({super.key, required this.user});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  late int _index;

  static const _titles = ['Trabajadores', 'Mis anuncios', 'Mi Perfil'];

  @override
  void initState() {
    super.initState();
    // Si el perfil está incompleto, se abre directo en "Mi perfil"
    _index = widget.user['profile_completed'] == true ? 0 : 2;
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
            //Image.asset('assets/images/logo.png', height: 32)
            const Icon(Icons.handyman, color: AppColors.tertiary, size: 28),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TUOFICIO',
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AppColors.secondary,
                  ),
                ),
                Text(
                  _titles[_index],
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
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
              onTap: () => setState(() => _index = 2),
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
      body: IndexedStack(
        index: _index,
        children: [
          const _PantallaPendiente(
              icon: Icons.engineering, nombre: 'Lista de trabajadores'),
          const ClientPostsScreen(),
          ClientProfileScreen(user: widget.user),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLow,
          boxShadow: [
            BoxShadow(
              color: Color(0xB3010F1F),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.engineering,
                  label: 'Trabajadores',
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _NavItem(
                  icon: Icons.campaign,
                  label: 'Mis anuncios',
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                _NavItem(
                  icon: Icons.person,
                  label: 'Mi perfil',
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2),
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
    final color = selected ? AppColors.primary : AppColors.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 72, minHeight: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    letterSpacing: 0.5,
                    color: color,
                  ),
            ),
          ],
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