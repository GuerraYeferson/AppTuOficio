import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

// =====================================================================
// Utilidades
// =====================================================================

TextStyle _ts(
  BuildContext context, {
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.onSurface,
  double? spacing,
  double? height,
}) {
  return Theme.of(context).textTheme.bodyMedium!.copyWith(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
        height: height,
      );
}

List<Map<String, dynamic>> _toList(dynamic v) {
  return ((v as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}

Map<String, dynamic>? _profileOf(Map<String, dynamic> u) {
  final p = u['profile'];
  return p is Map ? Map<String, dynamic>.from(p) : null;
}

bool _isWorker(Map<String, dynamic> u) => u['role'] == 'worker';
bool _isActive(Map<String, dynamic> u) => u['is_active'] == true;

String _fullName(Map<String, dynamic> u) {
  final p = _profileOf(u);
  if (p != null) {
    return '${p['first_name']} ${p['last_name']}'.trim();
  }
  return (u['name'] ?? '').toString();
}

String _phone(Map<String, dynamic> u) {
  final p = _profileOf(u);
  final t = (p?['phone'] ?? '').toString();
  return t.isEmpty ? 'Perfil sin completar' : t;
}

String _zone(Map<String, dynamic> u) {
  final d = _profileOf(u)?['district'];
  if (d is List) return d.map((e) => e.toString()).join(', ');
  final t = (d ?? '').toString();
  return t.isEmpty ? '—' : t;
}

String _trades(Map<String, dynamic> u) {
  final p = _profileOf(u);
  if (p == null) return '—';
  final names = ((p['trades'] as List?) ?? [])
      .map((e) => (e as Map)['name'].toString())
      .toList();
  final others = (p['other_trades'] ?? '')
      .toString()
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);
  final all = [...names, ...others];
  return all.isEmpty ? '—' : all.join(', ');
}

String _experience(Map<String, dynamic> u) {
  final y = (_profileOf(u)?['years_experience'] as num?)?.toInt();
  if (y == null) return '—';
  return y == 1 ? '1 año' : '$y años';
}

bool _available(Map<String, dynamic> u) =>
    _profileOf(u)?['is_available'] == true;

String _date(dynamic v) {
  final d = DateTime.tryParse(v?.toString() ?? '')?.toLocal();
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

// =====================================================================
// Pantalla
// =====================================================================

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  int _requestSeq = 0;

  List<Map<String, dynamic>> _users = [];
  String? _role; // null = todos | client | worker

  bool _loading = true;
  bool _loadError = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Map<String, String> _query(int page) {
    final q = <String, String>{'page': '$page'};
    if (_role != null) q['role'] = _role!;
    final s = _searchCtrl.text.trim();
    if (s.isNotEmpty) q['search'] = s;
    return q;
  }

  Future<void> _load({bool silent = false}) async {
    final seq = ++_requestSeq;

    if (!silent) {
      setState(() {
        _loading = true;
        _loadError = false;
      });
    }

    final res = await ApiService.get('/admin/users', query: _query(1));
    if (!mounted || seq != _requestSeq) return; // llegó una búsqueda más nueva

    if (!res.ok) {
      if (silent) {
        _aviso('No se pudo actualizar la lista');
      } else {
        setState(() {
          _loading = false;
          _loadError = true;
        });
      }
      return;
    }

    setState(() {
      _users = _toList(res.data['data']);
      _page = 1;
      _hasMore = res.data['next_page_url'] != null;
      _loading = false;
      _loadError = false;
    });
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final res = await ApiService.get('/admin/users', query: _query(_page + 1));
    if (!mounted) return;

    if (res.ok) {
      _users.addAll(_toList(res.data['data']));
      _page++;
      _hasMore = res.data['next_page_url'] != null;
    } else {
      _aviso(res.message);
    }
    setState(() => _loadingMore = false);
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _load);
  }

  void _setRole(String? role) {
    if (_role == role) return;
    setState(() => _role = role);
    _load();
  }

  Future<void> _openSheet(Map<String, dynamic> user,
      {bool confirm = false}) async {
    final newActive = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _UserSheet(user: user, startConfirming: confirm),
    );

    if (newActive == null || !mounted) return;

    setState(() {
      final i = _users.indexWhere((u) => u['id'] == user['id']);
      if (i != -1) _users[i]['is_active'] = newActive;
    });
    _aviso(newActive
        ? 'Cuenta reactivada correctamente'
        : 'Cuenta suspendida correctamente');
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _aviso('Teléfono copiado');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ---------- Búsqueda y filtros (fijos arriba) ----------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: _ts(context),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceContainerLowest,
                  hintText: 'Buscar por nombre o correo...',
                  hintStyle:
                      const TextStyle(fontSize: 14, color: AppColors.outline),
                  prefixIcon: const Icon(Icons.search,
                      size: 20, color: AppColors.outline),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.primaryContainer),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Todos',
                      selected: _role == null,
                      onTap: () => _setRole(null),
                    ),
                    const SizedBox(width: 4),
                    _FilterChip(
                      label: 'Clientes',
                      selected: _role == 'client',
                      onTap: () => _setRole('client'),
                    ),
                    const SizedBox(width: 4),
                    _FilterChip(
                      label: 'Trabajadores',
                      selected: _role == 'worker',
                      onTap: () => _setRole('worker'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ---------- Lista ----------
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
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
              Text('No se pudieron cargar los usuarios',
                  style: _ts(context, size: 16)),
              const SizedBox(height: 4),
              Text(
                'Revisa tu conexión y que el servidor esté encendido.',
                textAlign: TextAlign.center,
                style:
                    _ts(context, size: 12, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: _users.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                const Icon(Icons.group_off_outlined,
                    size: 48, color: AppColors.outline),
                const SizedBox(height: 12),
                Center(
                  child: Text('No hay resultados',
                      style: _ts(context, size: 16, weight: FontWeight.w600)),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text('Prueba con otra búsqueda o filtro.',
                      style: _ts(context,
                          size: 12, color: AppColors.onSurfaceVariant)),
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                ..._users.map(
                  (u) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _UserCard(
                      user: u,
                      onOpen: () => _openSheet(u),
                      onToggle: () => _openSheet(u, confirm: true),
                      onCopy: _copy,
                    ),
                  ),
                ),
                if (_hasMore)
                  Center(
                    child: _loadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(),
                          )
                        : TextButton(
                            onPressed: _loadMore,
                            child: Text('Cargar más',
                                style: _ts(context,
                                    weight: FontWeight.w600,
                                    color: AppColors.secondary)),
                          ),
                  ),
              ],
            ),
    );
  }
}

// =====================================================================
// Widgets de apoyo
// =====================================================================

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryContainer
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: _ts(
            context,
            size: 12,
            weight: FontWeight.w600,
            color: selected
                ? AppColors.onPrimaryContainer
                : AppColors.onSurfaceVariant,
            spacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final bool worker;
  final bool dim;

  const _RoleBadge({required this.worker, required this.dim});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: dim
            ? AppColors.surfaceContainerHighest.withAlpha(128)
            : (worker
                ? AppColors.primaryContainer.withAlpha(51)
                : AppColors.surfaceContainerHighest),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        worker ? 'Trabajador' : 'Cliente',
        style: _ts(
          context,
          size: 10,
          weight: FontWeight.w700,
          color: dim
              ? AppColors.outline
              : (worker ? AppColors.secondary : AppColors.onSurface),
          spacing: 0.4,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;

  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.secondary : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF03B5D3).withAlpha(38)
            : AppColors.errorContainer.withAlpha(102),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          active
              ? Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: color),
                )
              : Icon(Icons.warning_amber, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            active ? 'Activo' : 'Suspendido',
            style: _ts(context,
                size: 10, weight: FontWeight.w700, color: color, spacing: 0.4),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool dim;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.dim,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.outline),
          const SizedBox(width: 6),
          Text(
            '$label:',
            style: _ts(context,
                size: 12,
                color: dim ? AppColors.outline : AppColors.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _ts(
                context,
                size: 12,
                weight: FontWeight.w600,
                color: dim ? AppColors.onSurfaceVariant : AppColors.onSurface,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final Widget? leading;

  const _MiniRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text('$label:',
              style: _ts(context, size: 12, color: AppColors.outline)),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 4)],
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(context,
                        size: 12, weight: FontWeight.w600, color: valueColor),
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

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onOpen;
  final VoidCallback onToggle;
  final ValueChanged<String> onCopy;

  const _UserCard({
    required this.user,
    required this.onOpen,
    required this.onToggle,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final active = _isActive(user);
    final worker = _isWorker(user);
    final hasPhone = (_profileOf(user)?['phone'] ?? '').toString().isNotEmpty;
    final dim = !active;

    return Opacity(
      opacity: dim ? 0.85 : 1,
      child: Material(
        color: dim
            ? AppColors.surfaceContainerLowest
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Nombre, id y etiquetas
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fullName(user),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _ts(
                              context,
                              size: 16,
                              weight: FontWeight.w600,
                              color: dim
                                  ? AppColors.onSurfaceVariant
                                  : AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: #${user['id']}',
                            style: _ts(context,
                                size: 10,
                                weight: FontWeight.w700,
                                color: AppColors.outline,
                                spacing: 0.8),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _RoleBadge(worker: worker, dim: dim),
                        const SizedBox(height: 4),
                        _StatusBadge(active: active),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Datos principales
                _InfoRow(
                  icon: Icons.call_outlined,
                  label: 'Teléfono',
                  value: _phone(user),
                  dim: dim,
                  trailing: hasPhone
                      ? GestureDetector(
                          onTap: () => onCopy(_phone(user)),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.content_copy,
                                size: 15, color: AppColors.outline),
                          ),
                        )
                      : null,
                ),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Zona',
                  value: _zone(user),
                  dim: dim,
                ),
                _InfoRow(
                  icon: Icons.mail_outline,
                  label: 'Correo',
                  value: (user['email'] ?? '').toString(),
                  dim: dim,
                ),

                // Datos técnicos del trabajador
                if (worker && _profileOf(user) != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: dim
                          ? AppColors.surfaceContainerLow
                          : AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _MiniRow(
                          label: 'Oficios',
                          value: _trades(user),
                          valueColor:
                              dim ? AppColors.onSurfaceVariant : AppColors.primary,
                        ),
                        _MiniRow(
                          label: 'Experiencia',
                          value: _experience(user),
                          valueColor:
                              dim ? AppColors.outline : AppColors.onSurface,
                        ),
                        _MiniRow(
                          label: 'Disponibilidad',
                          value: _available(user) ? 'Disponible' : 'Pausado',
                          valueColor: (_available(user) && !dim)
                              ? AppColors.secondary
                              : AppColors.outline,
                          leading: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (_available(user) && !dim)
                                  ? AppColors.secondary
                                  : AppColors.outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Acción
                Material(
                  color: active
                      ? AppColors.error.withAlpha(38)
                      : const Color(0xFF03B5D3).withAlpha(51),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            active ? Icons.block : Icons.check_circle_outline,
                            size: 18,
                            color:
                                active ? AppColors.error : AppColors.secondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            active ? 'Suspender cuenta' : 'Reactivar cuenta',
                            style: _ts(
                              context,
                              size: 12,
                              weight: FontWeight.w600,
                              color: active
                                  ? AppColors.error
                                  : AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Ficha de administración (hoja inferior)
// =====================================================================

class _UserSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool startConfirming;

  const _UserSheet({required this.user, required this.startConfirming});

  @override
  State<_UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends State<_UserSheet> {
  late bool _confirming;
  bool _working = false;
  String? _error;
  int? _postsCount;

  @override
  void initState() {
    super.initState();
    _confirming = widget.startConfirming;
    _loadCount();
  }

  Future<void> _loadCount() async {
    if (_isWorker(widget.user)) return;
    final res = await ApiService.get('/admin/users/${widget.user['id']}');
    if (!mounted || !res.ok) return;
    setState(() {
      _postsCount = (res.data['user']['job_posts_count'] as num?)?.toInt();
    });
  }

  Future<void> _execute() async {
    final active = _isActive(widget.user);
    setState(() {
      _working = true;
      _error = null;
    });

    final res = await ApiService.post(
      '/admin/users/${widget.user['id']}/${active ? 'suspend' : 'reactivate'}',
    );
    if (!mounted) return;

    if (!res.ok) {
      setState(() {
        _working = false;
        _error = res.message;
      });
      return;
    }

    Navigator.of(context).pop(!active);
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final worker = _isWorker(u);
    final active = _isActive(u);
    final p = _profileOf(u);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FICHA DE ADMINISTRACIÓN',
                          style: _ts(context,
                              size: 10,
                              weight: FontWeight.w700,
                              color: AppColors.outline,
                              spacing: 0.8),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _fullName(u),
                          style: _ts(context,
                              size: 18, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close,
                        size: 20, color: AppColors.outline),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Datos
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _SheetRow('Rol', worker ? 'Trabajador' : 'Cliente',
                        valueColor: AppColors.primary),
                    _SheetRow('Estado actual', active ? 'Activo' : 'Suspendido',
                        valueColor:
                            active ? AppColors.secondary : AppColors.error),
                    _SheetRow('Correo', (u['email'] ?? '').toString()),
                    _SheetRow('Teléfono', _phone(u)),
                    _SheetRow(worker ? 'Distritos de atención' : 'Distrito',
                        _zone(u)),
                    _SheetRow('Registrado el', _date(u['created_at'])),
                    if (worker && p != null) ...[
                      _SheetRow('Oficios', _trades(u)),
                      _SheetRow('Experiencia', _experience(u)),
                      _SheetRow('Disponibilidad',
                          _available(u) ? 'Disponible' : 'Pausado'),
                      _SheetRow('Descripción',
                          (p['description'] ?? '—').toString()),
                    ],
                    if (!worker)
                      _SheetRow('Anuncios publicados',
                          _postsCount == null ? '…' : '$_postsCount'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_error != null) ...[
                Text(_error!,
                    style: _ts(context, size: 12, color: AppColors.error)),
                const SizedBox(height: 8),
              ],

              // Confirmación o acciones
              if (_confirming)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            active ? Icons.report_outlined : Icons.verified_user_outlined,
                            size: 20,
                            color: active ? AppColors.error : AppColors.secondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Confirmar acción de cuenta',
                                  style: _ts(context,
                                      size: 16,
                                      weight: FontWeight.w600,
                                      color: active
                                          ? AppColors.error
                                          : AppColors.secondary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  active
                                      ? '¿Suspender a ${_fullName(u)}? No podrá iniciar sesión, '
                                          'se cerrarán sus sesiones abiertas y dejará de aparecer en las listas.'
                                      : '¿Reactivar a ${_fullName(u)}? Podrá iniciar sesión y operar con normalidad.',
                                  style: _ts(context,
                                      size: 12,
                                      color: AppColors.onSurfaceVariant,
                                      height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _SheetButton(
                              label: 'Cancelar',
                              bg: AppColors.surfaceContainerHighest,
                              fg: AppColors.onSurface,
                              onTap: _working
                                  ? null
                                  : () => setState(() => _confirming = false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SheetButton(
                              label: active
                                  ? 'Confirmar suspensión'
                                  : 'Confirmar reactivación',
                              bg: active
                                  ? AppColors.error
                                  : const Color(0xFF03B5D3),
                              fg: active
                                  ? const Color(0xFF690005)
                                  : const Color(0xFF00424E),
                              bold: true,
                              loading: _working,
                              onTap: _working ? null : _execute,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else ...[
                _SheetButton(
                  label: active ? 'Suspender cuenta' : 'Reactivar cuenta',
                  icon: active ? Icons.block : Icons.check_circle_outline,
                  bg: active
                      ? AppColors.error.withAlpha(38)
                      : const Color(0xFF03B5D3).withAlpha(51),
                  fg: active ? AppColors.error : AppColors.secondary,
                  onTap: () => setState(() => _confirming = true),
                ),
                const SizedBox(height: 8),
                _SheetButton(
                  label: 'Cerrar',
                  bg: AppColors.surfaceContainer,
                  fg: AppColors.onSurface,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _SheetRow(this.label, this.value,
      {this.valueColor = AppColors.onSurface});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _ts(context, size: 12, color: AppColors.outline)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: _ts(context,
                  size: 12, weight: FontWeight.w600, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color bg;
  final Color fg;
  final bool bold;
  final bool loading;
  final VoidCallback? onTap;

  const _SheetButton({
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
    this.icon,
    this.bold = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 48,
          child: Center(
            child: loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: fg),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: _ts(
                            context,
                            size: 12,
                            weight: bold ? FontWeight.w800 : FontWeight.w600,
                            color: fg,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}