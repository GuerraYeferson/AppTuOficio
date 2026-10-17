import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/password_dialog.dart';
import '../welcome_screen.dart';

const _emerald = Color(0xFF34D399);
const _emeraldDark = Color(0xFF10B981);
const _emeraldKnob = Color(0xFF059669);

class WorkerProfileScreen extends StatefulWidget {
  /// Se llama cuando el perfil se guarda, para desbloquear "Anuncios"
  final VoidCallback onProfileSaved;

  const WorkerProfileScreen({super.key, required this.onProfileSaved});

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _loading = true;
  bool _loadError = false;
  bool _editing = false;
  bool _saving = false;
  bool _togglingAvail = false;
  bool _notifWhatsapp = true; // solo visual
  bool _notifPush = true; // solo visual

  Map<String, dynamic> _user = {};
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _trades = [];
  Set<int> _selected = {};

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
    _yearsCtrl.dispose();
    _descCtrl.dispose();
    _otherCtrl.dispose();
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
      ApiService.get('/trades'),
    ]);
    final meRes = res[0];
    final profileRes = res[1];
    final tradesRes = res[2];

    if (!mounted) return;

    if (!meRes.ok ||
        !tradesRes.ok ||
        (!profileRes.ok && profileRes.statusCode != 404)) {
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
    _trades = ((tradesRes.data['trades'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _fillControllers();

    setState(() {
      _loading = false;
      _editing = _profile == null; // sin perfil: abre directo en edición
    });
  }

  Set<int> _idsFromProfile() {
    final list = (_profile?['trades'] as List?) ?? [];
    return list.map((e) => ((e as Map)['id'] as num).toInt()).toSet();
  }

  List<String> _namesFromProfile() {
    final list = (_profile?['trades'] as List?) ?? [];
    return list.map((e) => (e as Map)['name'].toString()).toList();
  }

  List<String> _splitOthers(dynamic v) {
    return (v ?? '')
        .toString()
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  void _fillControllers() {
    _firstCtrl.text = (_profile?['first_name'] ?? '').toString();
    _lastCtrl.text = (_profile?['last_name'] ?? '').toString();
    _phoneCtrl.text = (_profile?['phone'] ?? '').toString();
    _districtCtrl.text = (_profile?['district'] ?? '').toString();
    _yearsCtrl.text = _profile == null
        ? ''
        : (_profile!['years_experience'] ?? 0).toString();
    _descCtrl.text = (_profile?['description'] ?? '').toString();
    _otherCtrl.text = (_profile?['other_trades'] ?? '').toString();
    _emailCtrl.text = (_user['email'] ?? '').toString();
    _selected = _idsFromProfile();
  }

  bool get _available => _profile?['is_available'] == true;

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
  Map<String, dynamic> _bodyFromProfile(bool available) {
    final p = _profile!;
    final other = (p['other_trades'] ?? '').toString();
    return {
      'first_name': p['first_name'],
      'last_name': p['last_name'],
      'phone': p['phone'],
      'district': p['district'],
      'description': p['description'],
      'years_experience': (p['years_experience'] as num).toInt(),
      'is_available': available,
      'other_trades': other.isEmpty ? null : other,
      'trade_ids': _idsFromProfile().toList(),
    };
  }

  Future<void> _toggleAvailable() async {
    if (_profile == null) {
      _aviso('Completa tu perfil para activar tu disponibilidad');
      return;
    }
    if (_togglingAvail) return;

    final nuevo = !_available;
    setState(() => _togglingAvail = true);

    final res =
        await ApiService.put('/profile', body: _bodyFromProfile(nuevo));
    if (!mounted) return;

    setState(() => _togglingAvail = false);

    if (!res.ok) {
      _aviso(res.message);
      return;
    }

    setState(() {
      _profile = Map<String, dynamic>.from(res.data['profile'] as Map);
    });
    _aviso(nuevo
        ? 'Ahora apareces como disponible'
        : 'Te pausaste: ya no apareces en la lista');
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final other = _otherCtrl.text.trim();
    if (_selected.isEmpty && other.isEmpty) {
      _aviso('Elige al menos un oficio o escribe uno en "Otros oficios"');
      return;
    }

    setState(() => _saving = true);

    final body = {
      'first_name': _firstCtrl.text.trim(),
      'last_name': _lastCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'district': _districtCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'years_experience': int.parse(_yearsCtrl.text.trim()),
      'is_available': _profile == null ? true : _available,
      'other_trades': other.isEmpty ? null : other,
      'trade_ids': _selected.toList(),
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
      _fillControllers();
    });
    widget.onProfileSaved();
    _aviso('Tu perfil se guardó correctamente');
  }

  void _cancelarEdicion() {
    _formKey.currentState?.reset();
    setState(() {
      _fillControllers();
      _editing = false;
    });
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
      builder: (_) => const PasswordDialog(),
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

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
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

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatus(),
            const SizedBox(height: 16),
            _buildIdentity(),
            const SizedBox(height: 16),
            _buildTrades(),
            const SizedBox(height: 16),
            _buildDatos(),
            const SizedBox(height: 16),
            _buildPreferencias(),
            const SizedBox(height: 16),
            _buildAcciones(),
            const SizedBox(height: 16),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ---------- Tarjeta de disponibilidad ----------
  Widget _buildStatus() {
    final hasProfile = _profile != null;
    final on = _available;

    final headline = !hasProfile
        ? 'COMPLETA TU PERFIL'
        : (on ? 'DISPONIBLE PARA TRABAJOS' : 'PAUSADO / NO DISPONIBLE');
    final sub = !hasProfile
        ? 'Aún no apareces en la lista de clientes'
        : (on
            ? 'En línea • Los clientes pueden verte'
            : 'Pausado • No apareces en la lista');

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: on ? _emerald : AppColors.outline,
                            boxShadow: on
                                ? [
                                    BoxShadow(
                                      color: _emerald.withAlpha(200),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'MODO OPERATIVO',
                          style: _t(
                              size: 10,
                              weight: FontWeight.w700,
                              color: AppColors.onSurfaceVariant,
                              spacing: 0.8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(headline,
                        style: _t(size: 16, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: _t(
                            size: 12,
                            weight: FontWeight.w500,
                            color: on
                                ? AppColors.secondary
                                : AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _BigToggle(
                value: on,
                busy: _togglingAvail,
                onTap: _toggleAvailable,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.bolt, size: 15, color: AppColors.tertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Solo los trabajadores disponibles aparecen en la lista de clientes',
                  style: _t(
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Tarjeta de identidad ----------
  Widget _buildIdentity() {
    final names = _namesFromProfile();
    final others = _splitOthers(_profile?['other_trades']);
    final roleLine = [...names, ...others].isEmpty
        ? 'Trabajador'
        : [...names, ...others].join(', ');
    final years = (_profile?['years_experience'] ?? 0).toString();
    final district = (_profile?['district'] ?? '').toString();

    return _card(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/avatar_default.png',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.person,
                            size: 44,
                            color: AppColors.onSurfaceVariant,
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: GestureDetector(
                      onTap: () => _aviso(
                          'Subir foto de perfil estará disponible pronto'),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceContainerHighest,
                        ),
                        child: const Icon(Icons.photo_camera,
                            size: 16, color: AppColors.secondary),
                      ),
                    ),
                  ),
                  if (_available)
                    Positioned(
                      left: -4,
                      top: -4,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _emerald,
                          border: Border.all(
                              color: AppColors.surfaceContainer, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName.isEmpty ? 'Tu nombre' : _displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(size: 18, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(Icons.engineering,
                              size: 15, color: AppColors.secondary),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            roleLine,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _t(
                                size: 12,
                                weight: FontWeight.w600,
                                color: AppColors.secondary),
                          ),
                        ),
                      ],
                    ),
                    if (_profile != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MiniChip(
                              icon: Icons.location_on_outlined,
                              text: district),
                          _MiniChip(
                              icon: Icons.work_outline,
                              text: '$years años de exp.'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    icon: Icons.star,
                    iconColor: AppColors.tertiary,
                    iconBg: AppColors.tertiaryContainer.withAlpha(77),
                    value: '–',
                    label: 'Calificación',
                  ),
                ),
                Expanded(
                  child: _MiniMetric(
                    icon: Icons.workspace_premium,
                    iconColor: AppColors.secondary,
                    iconBg: AppColors.secondary.withAlpha(38),
                    value: _profile == null ? '–' : years,
                    label: 'Años de experiencia',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Oficios ----------
  Widget _buildTrades() {
    final names = _namesFromProfile();
    final others = _splitOthers(_profile?['other_trades']);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium,
                  size: 20, color: AppColors.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Oficios',
                    style: _t(size: 16, weight: FontWeight.w600)),
              ),
              if (!_editing)
                GestureDetector(
                  onTap: () => setState(() => _editing = true),
                  child: Row(
                    children: [
                      Text('Gestionar',
                          style: _t(
                              size: 12,
                              weight: FontWeight.w600,
                              color: AppColors.secondary)),
                      const SizedBox(width: 4),
                      const Icon(Icons.tune,
                          size: 14, color: AppColors.secondary),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_editing) ...[
            Text('Elige todos los oficios que dominas',
                style: _t(size: 12, color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _trades.map((t) {
                final id = (t['id'] as num).toInt();
                return _SelectChip(
                  label: t['name'].toString(),
                  selected: _selected.contains(id),
                  onTap: () => setState(() {
                    if (!_selected.remove(id)) _selected.add(id);
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _DataField(
              label: 'Otros oficios (separados por coma)',
              controller: _otherCtrl,
              icon: Icons.add,
              enabled: true,
              maxLength: 255,
            ),
          ] else if (names.isEmpty && others.isEmpty)
            Text('Aún no has elegido oficios',
                style: _t(size: 12, color: AppColors.onSurfaceVariant))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...names.map((n) => _ViewChip(text: n)),
                ...others.map((n) => _ViewChip(text: n)),
              ],
            ),
        ],
      ),
    );
  }

  // ---------- Datos personales ----------
  Widget _buildDatos() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined,
                  size: 20, color: AppColors.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Datos Personales',
                    style: _t(size: 16, weight: FontWeight.w600)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _editing
                      ? AppColors.primaryContainer
                      : AppColors.surfaceContainerHighest,
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
            maxLength: 100,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Escribe tu nombre' : null,
          ),
          const SizedBox(height: 8),
          _DataField(
            label: 'Apellido',
            controller: _lastCtrl,
            icon: Icons.person_outline,
            enabled: _editing,
            maxLength: 100,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Escribe tu apellido'
                : null,
          ),
          const SizedBox(height: 8),
          _DataField(
            label: 'Teléfono de contacto',
            controller: _phoneCtrl,
            icon: Icons.phone_outlined,
            enabled: _editing,
            keyboardType: TextInputType.phone,
            maxLength: 20,
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
            label: 'Distrito / zona de atención',
            controller: _districtCtrl,
            icon: Icons.location_on_outlined,
            enabled: _editing,
            maxLength: 150,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Escribe tu distrito o zona'
                : null,
          ),
          const SizedBox(height: 8),
          _DataField(
            label: 'Años de experiencia',
            controller: _yearsCtrl,
            icon: Icons.work_outline,
            enabled: _editing,
            keyboardType: TextInputType.number,
            maxLength: 2,
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null || n < 0 || n > 60) return 'Escribe un número de 0 a 60';
              return null;
            },
          ),
          const SizedBox(height: 8),
          _DataField(
            label: 'Descripción de tus servicios',
            controller: _descCtrl,
            icon: Icons.notes,
            enabled: _editing,
            maxLines: 4,
            maxLength: 1000,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Cuéntales a los clientes qué haces'
                : null,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _saving
                  ? null
                  : (_editing
                      ? _guardar
                      : () => setState(() => _editing = true)),
              style: FilledButton.styleFrom(
                backgroundColor: _editing
                    ? AppColors.primaryContainer
                    : AppColors.surfaceContainerHighest,
                foregroundColor: _editing
                    ? AppColors.onPrimaryContainer
                    : AppColors.onSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
                  : Icon(_editing ? Icons.save : Icons.edit,
                      size: 18,
                      color: _editing
                          ? AppColors.onPrimaryContainer
                          : AppColors.secondary),
              label: Text(
                _editing
                    ? (_profile == null ? 'Guardar perfil' : 'Guardar cambios')
                    : 'Editar información personal',
                style: _t(
                    size: 14,
                    weight: FontWeight.w600,
                    color: _editing
                        ? AppColors.onPrimaryContainer
                        : AppColors.onSurface,
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
    );
  }

  // ---------- Preferencias ----------
  Widget _buildPreferencias() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined,
                  size: 20, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text('Preferencias y Notificaciones',
                  style: _t(size: 16, weight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          _SettingTile(
            icon: Icons.chat_outlined,
            iconColor: _emerald,
            title: 'Alertas vía WhatsApp',
            subtitle: 'Nuevos avisos en tu zona',
            value: _notifWhatsapp,
            activeTrack: _emeraldDark,
            onChanged: (v) => setState(() => _notifWhatsapp = v),
          ),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.cell_tower,
            iconColor: AppColors.primary,
            title: 'Notificaciones Push',
            subtitle: 'Avisos dentro de la app',
            value: _notifPush,
            activeTrack: AppColors.primaryContainer,
            onChanged: (v) => setState(() => _notifPush = v),
          ),
        ],
      ),
    );
  }

  // ---------- Acciones ----------
  Widget _buildAcciones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () =>
                  _aviso('Cambiar contraseña estará disponible pronto'),
              icon: const Icon(Icons.lock_reset,
                  size: 16, color: AppColors.onSurfaceVariant),
              label: Text('Cambiar contraseña',
                  style: _t(
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant)),
            ),
            TextButton.icon(
              onPressed: () =>
                  _aviso('Términos y privacidad estarán disponibles pronto'),
              icon: const Icon(Icons.description_outlined,
                  size: 16, color: AppColors.onSurfaceVariant),
              label: Text('Términos y Privacidad',
                  style: _t(
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Material(
          color: AppColors.errorContainer.withAlpha(77),
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
                          size: 16,
                          weight: FontWeight.w600,
                          color: AppColors.error)),
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
    return Text(
      'TuOficio MVP · Trabajador',
      textAlign: TextAlign.center,
      style: _t(
        size: 10,
        weight: FontWeight.w700,
        color: AppColors.onSurfaceVariant.withAlpha(150),
        spacing: 0.8,
      ),
    );
  }
}

// =====================================================================
// Widgets de apoyo
// =====================================================================

class _BigToggle extends StatelessWidget {
  final bool value;
  final bool busy;
  final VoidCallback onTap;

  const _BigToggle({
    required this.value,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 56,
        height: 32,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: value
              ? _emeraldDark.withAlpha(230)
              : AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          boxShadow: value
              ? [BoxShadow(color: _emeraldDark.withAlpha(90), blurRadius: 16)]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.onPrimaryContainer,
            ),
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(5),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    value ? Icons.bolt : Icons.pause,
                    size: 16,
                    color: value ? _emeraldKnob : AppColors.onSurfaceVariant,
                  ),
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.secondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;

  const _MiniMetric({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewChip extends StatelessWidget {
  final String text;

  const _ViewChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest.withAlpha(230),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.construction, size: 16, color: AppColors.secondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryContainer.withAlpha(70)
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.add,
              size: 16,
              color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
            ),
          ],
        ),
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
  final int maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;

  const _DataField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.enabled,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
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
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
          validator: validator,
          style: textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: AppColors.onSurface,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled
                ? AppColors.surfaceContainerHigh
                : AppColors.surfaceContainerLow,
            counterText: '',
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
  final bool value;
  final Color activeTrack;
  final ValueChanged<bool> onChanged;

  const _SettingTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.activeTrack,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: activeTrack,
            inactiveThumbColor: AppColors.outline,
            inactiveTrackColor: AppColors.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}