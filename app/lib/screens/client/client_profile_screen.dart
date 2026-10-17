import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../welcome_screen.dart';

class ClientProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ClientProfileScreen({super.key, required this.user});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _loading = true;
  bool _loadError = false;
  bool _editing = false;
  bool _saving = false;
  bool _notifWhatsapp = true; // solo visual
  bool _notifPush = true; // solo visual

  Map<String, dynamic> _user = {};
  Map<String, dynamic>? _profile;
  int _jobCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _districtCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ---------- Datos ----------
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });

    final res = await Future.wait([
      ApiService.get('/me'),
      ApiService.get('/profile'),
      ApiService.get('/job-posts'),
    ]);
    final meRes = res[0];
    final profileRes = res[1];
    final postsRes = res[2];

    if (!mounted) return;

    if (!meRes.ok || (!profileRes.ok && profileRes.statusCode != 404)) {
      setState(() {
        _loading = false;
        _loadError = true;
      });
      return;
    }

    _user = Map<String, dynamic>.from(meRes.data['user'] as Map);
    _profile = profileRes.ok
        ? Map<String, dynamic>.from(profileRes.data['profile'] as Map)
        : null;
    _jobCount =
        postsRes.ok ? ((postsRes.data['total'] as num?)?.toInt() ?? 0) : 0;
    _fillControllers();

    setState(() {
      _loading = false;
      _editing = _profile == null; // sin perfil: abre directo en edición
    });
  }

  void _fillControllers() {
    _firstCtrl.text = (_profile?['first_name'] ?? '').toString();
    _lastCtrl.text = (_profile?['last_name'] ?? '').toString();
    _phoneCtrl.text = (_profile?['phone'] ?? '').toString();
    _districtCtrl.text = (_profile?['district'] ?? '').toString();
    _emailCtrl.text = (_user['email'] ?? '').toString();
  }

  String get _displayName {
    if (_profile != null) {
      return '${_profile!['first_name']} ${_profile!['last_name']}'.trim();
    }
    return (_user['name'] ?? '').toString();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  // ---------- Acciones ----------
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final body = {
      'first_name': _firstCtrl.text.trim(),
      'last_name': _lastCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'district': _districtCtrl.text.trim(),
    };

    final res = _profile == null
        ? await ApiService.post('/profile', body: body)
        : await ApiService.put('/profile', body: body);

    if (!mounted) return;

    if (!res.ok) {
      setState(() => _saving = false);
      _aviso(res.message);
      return;
    }

    setState(() {
      _profile = Map<String, dynamic>.from(res.data['profile'] as Map);
      _user['profile_completed'] = true;
      _editing = false;
      _saving = false;
    });
    _aviso('Tus datos se guardaron correctamente');
  }

  void _cancelarEdicion() {
    _fillControllers();
    _formKey.currentState?.reset();
    setState(() => _editing = false);
  }

  void _irABienvenida() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Future<void> _cerrarSesion() async {
    await ApiService.post('/logout');
    await ApiService.clearToken();
    if (!mounted) return;
    _irABienvenida();
  }

  Future<void> _eliminarCuenta() async {
    final pass = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (pass == null || pass.isEmpty) return;

    setState(() => _saving = true);
    final res = await ApiService.delete('/me', body: {'password': pass});
    if (!mounted) return;

    if (!res.ok) {
      setState(() => _saving = false);
      _aviso(res.message);
      return;
    }

    await ApiService.clearToken();
    if (!mounted) return;
    _irABienvenida();
  }

  // ---------- UI ----------
  TextStyle _t({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.onSurface,
    double? spacing,
  }) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: size,
          fontWeight: weight,
          color: color,
          letterSpacing: spacing,
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: AppColors.outline),
              const SizedBox(height: 12),
              Text('No se pudo cargar tu perfil', style: _t(size: 16)),
              const SizedBox(height: 4),
              Text(
                'Revisa tu conexión y que el servidor esté encendido.',
                textAlign: TextAlign.center,
                style: _t(size: 12, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHero(),
          const SizedBox(height: 24),
          _buildMetrics(),
          const SizedBox(height: 24),
          _buildDatos(),
          const SizedBox(height: 24),
          _buildPreferencias(),
          const SizedBox(height: 24),
          _buildAcciones(),
          const SizedBox(height: 16),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHigh,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryContainer.withAlpha(90),
                      blurRadius: 24,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/avatar_default.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.person,
                        size: 52,
                        color: AppColors.onSurfaceVariant,
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () =>
                      _aviso('Subir foto de perfil estará disponible pronto'),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryContainer,
                    ),
                    child: const Icon(Icons.photo_camera,
                        size: 16, color: AppColors.onPrimary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _displayName.isEmpty ? 'Tu nombre' : _displayName,
            textAlign: TextAlign.center,
            style: _t(size: 22, weight: FontWeight.w600, spacing: -0.2),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withAlpha(38),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'CLIENTE',
                  style: _t(
                      size: 10,
                      weight: FontWeight.w700,
                      color: AppColors.primary,
                      spacing: 0.8),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 4,
            children: [
              _contactPill(Icons.mail, (_user['email'] ?? '').toString()),
              if (_profile != null)
                _contactPill(Icons.call, (_profile!['phone'] ?? '').toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contactPill(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.secondary),
        const SizedBox(width: 4),
        Text(text,
            style: _t(size: 12, color: AppColors.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildMetrics() {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.campaign,
            iconColor: AppColors.primary,
            iconBg: AppColors.surfaceContainerHighest,
            value: '$_jobCount',
            valueColor: AppColors.onSurface,
            label: 'Anuncios publicados',
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: _MetricCard(
            icon: Icons.handshake,
            iconColor: AppColors.secondary,
            iconBg: AppColors.surfaceContainerHighest,
            value: '–',
            valueColor: AppColors.onSurfaceVariant,
            label: 'Trabajos contratados',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            icon: Icons.star,
            iconColor: AppColors.tertiary,
            iconBg: AppColors.tertiaryContainer.withAlpha(77),
            value: '–',
            valueColor: AppColors.onSurfaceVariant,
            label: 'Como empleador',
          ),
        ),
      ],
    );
  }

  Widget _buildDatos() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_outlined,
                    size: 22, color: AppColors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Mis Datos',
                      style: _t(size: 16, weight: FontWeight.w600)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _editing
                        ? AppColors.primaryContainer
                        : AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _editing ? 'Modo edición' : 'Solo lectura',
                    style: _t(
                      size: 10,
                      weight: FontWeight.w700,
                      color: _editing
                          ? AppColors.onPrimaryContainer
                          : AppColors.onSurfaceVariant,
                      spacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DataField(
              label: 'Nombre',
              controller: _firstCtrl,
              icon: Icons.person_outline,
              enabled: _editing,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe tu nombre' : null,
            ),
            const SizedBox(height: 8),
            _DataField(
              label: 'Apellido',
              controller: _lastCtrl,
              icon: Icons.person_outline,
              enabled: _editing,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Escribe tu apellido'
                  : null,
            ),
            const SizedBox(height: 8),
            _DataField(
              label: 'Teléfono',
              controller: _phoneCtrl,
              icon: Icons.phone_outlined,
              enabled: _editing,
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().length < 6)
                  ? 'Escribe un teléfono válido'
                  : null,
            ),
            const SizedBox(height: 8),
            _DataField(
              label: 'Correo electrónico (no editable)',
              controller: _emailCtrl,
              icon: Icons.mail_outline,
              enabled: false,
            ),
            const SizedBox(height: 8),
            _DataField(
              label: 'Distrito / zona',
              controller: _districtCtrl,
              icon: Icons.location_on_outlined,
              enabled: _editing,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Escribe tu distrito o zona'
                  : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _saving
                    ? null
                    : (_editing ? _guardar : () => setState(() => _editing = true)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.onPrimaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.onPrimaryContainer,
                        ),
                      )
                    : Icon(_editing ? Icons.save : Icons.edit, size: 20),
                label: Text(
                  _editing
                      ? (_profile == null ? 'Guardar perfil' : 'Guardar cambios')
                      : 'Editar datos personales',
                  style: _t(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.onPrimaryContainer,
                      spacing: 0.3),
                ),
              ),
            ),
            if (_editing && _profile != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : _cancelarEdicion,
                child: Text('Cancelar',
                    style: _t(
                        size: 14,
                        weight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencias() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  size: 22, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text('Preferencias y seguridad',
                  style: _t(size: 16, weight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          _SettingTile(
            icon: Icons.lock_reset,
            iconColor: AppColors.primary,
            title: 'Cambiar contraseña',
            subtitle: 'Disponible pronto',
            trailing: const Icon(Icons.chevron_right,
                color: AppColors.outline),
            onTap: () => _aviso('Cambiar contraseña estará disponible pronto'),
          ),
          const SizedBox(height: 16),
          Text(
            'NOTIFICACIONES DE PRESUPUESTOS',
            style: _t(
                size: 10,
                weight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
                spacing: 0.8),
          ),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.chat_outlined,
            iconColor: AppColors.secondary,
            title: 'Avisos por WhatsApp',
            subtitle: 'Nuevas ofertas directas a tu chat',
            trailing: _switch(_notifWhatsapp,
                (v) => setState(() => _notifWhatsapp = v)),
          ),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.notifications_active_outlined,
            iconColor: AppColors.secondary,
            title: 'Notificaciones Push',
            subtitle: 'Alertas instantáneas en la app',
            trailing:
                _switch(_notifPush, (v) => setState(() => _notifPush = v)),
          ),
        ],
      ),
    );
  }

  Widget _switch(bool value, ValueChanged<bool> onChanged) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: Colors.white,
      activeTrackColor: AppColors.primaryContainer,
      inactiveThumbColor: AppColors.outline,
      inactiveTrackColor: AppColors.surfaceContainerHighest,
    );
  }

  Widget _buildAcciones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.errorContainer.withAlpha(51),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _saving ? null : _cerrarSesion,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout, size: 20, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text('Cerrar sesión',
                      style: _t(
                          size: 14,
                          weight: FontWeight.w700,
                          color: AppColors.error,
                          spacing: 0.3)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _saving ? null : _eliminarCuenta,
          child: Text('Eliminar cuenta',
              style: _t(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant)),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user_outlined,
                size: 14, color: AppColors.onSurfaceVariant.withAlpha(180)),
            const SizedBox(width: 6),
            Text('TuOficio MVP · Cliente',
                style: _t(
                    size: 10,
                    weight: FontWeight.w700,
                    color: AppColors.onSurfaceVariant.withAlpha(180),
                    spacing: 0.8)),
          ],
        ),
        const SizedBox(height: 4),
        Text('Plataforma de oficios · Hecho en Perú',
            style: _t(
                size: 10,
                weight: FontWeight.w700,
                color: AppColors.outline,
                spacing: 0.5)),
      ],
    );
  }
}

// =====================================================================
// Widgets de apoyo
// =====================================================================

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final Color valueColor;
  final String label;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.valueColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: textTheme.labelSmall?.copyWith(
              fontSize: 10,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DataField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _DataField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.enabled,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    OutlineInputBorder border([Color color = Colors.transparent]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          validator: validator,
          style: textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: AppColors.onSurface,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled
                ? AppColors.surfaceContainer
                : AppColors.surfaceContainerLowest,
            suffixIcon: Icon(icon, size: 18, color: AppColors.outline),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            border: border(),
            enabledBorder: border(),
            disabledBorder: border(),
            focusedBorder: border(AppColors.primaryContainer),
            errorBorder: border(AppColors.error),
            focusedErrorBorder: border(AppColors.error),
            errorStyle: const TextStyle(color: AppColors.error, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.labelLarge?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
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
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerHigh,
      title: const Text('Eliminar cuenta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Esta acción es permanente: se borrarán tu perfil y tus anuncios. '
            'Escribe tu contraseña para confirmar.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              hintText: 'Tu contraseña',
              suffixIcon: IconButton(
                icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                    size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: const Color(0xFF690005),
          ),
          child: const Text('Eliminar'),
        ),
      ],
    );
  }
}