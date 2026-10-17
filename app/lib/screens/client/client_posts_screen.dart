import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

const int _otherValue = -1;

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

IconData _tradeIcon(String name) {
  switch (name) {
    case 'Electricidad':
      return Icons.bolt;
    case 'Gasfitería':
      return Icons.plumbing;
    case 'Carpintería':
      return Icons.carpenter;
    case 'Pintura':
      return Icons.format_paint;
    case 'Cerrajería':
      return Icons.vpn_key;
    case 'Albañilería':
      return Icons.construction;
    case 'Soldadura':
      return Icons.hardware;
    case 'Jardinería':
      return Icons.yard;
    default:
      return Icons.handyman;
  }
}

String _two(int n) => n.toString().padLeft(2, '0');
String _apiDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
String _showDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  if (s.length < 10) return null;
  return DateTime.tryParse(s.substring(0, 10));
}

double? _toDouble(dynamic v) => v == null ? null : double.tryParse(v.toString());

String _fmtMoney(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

String _ago(dynamic v) {
  final d = DateTime.tryParse(v?.toString() ?? '');
  if (d == null) return '';
  final diff = DateTime.now().toUtc().difference(d.toUtc());
  if (diff.inMinutes < 1) return 'Publicado hace un momento';
  if (diff.inMinutes < 60) return 'Publicado hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Publicado hace ${diff.inHours} h';
  if (diff.inHours < 48) return 'Publicado ayer';
  return 'Publicado hace ${diff.inDays} días';
}

List<Map<String, dynamic>> _toList(dynamic v) {
  return ((v as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}

InputDecoration _decoration({String? hint, IconData? icon, Widget? suffix}) {
  OutlineInputBorder border([Color color = Colors.transparent]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color),
      );

  return InputDecoration(
    filled: true,
    fillColor: AppColors.surfaceContainerLowest,
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 14, color: AppColors.outline),
    prefixIcon:
        icon != null ? Icon(icon, size: 18, color: AppColors.outline) : null,
    suffixIcon: suffix,
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
    border: border(),
    enabledBorder: border(),
    focusedBorder: border(AppColors.secondary),
    errorBorder: border(AppColors.error),
    focusedErrorBorder: border(AppColors.error),
    errorStyle: const TextStyle(color: AppColors.error, fontSize: 11),
  );
}

// =====================================================================
// Pantalla
// =====================================================================

class ClientPostsScreen extends StatefulWidget {
  const ClientPostsScreen({super.key});

  @override
  State<ClientPostsScreen> createState() => _ClientPostsScreenState();
}

class _ClientPostsScreenState extends State<ClientPostsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _formAnchor = GlobalKey();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _otherTradeCtrl = TextEditingController();

  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _trades = [];

  bool _loading = true;
  bool _loadError = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;

  bool _formOpen = false;
  bool _saving = false;
  int? _editingId;
  String? _editingDistrict;
  String? _clientDistrict;
  int _formSeq = 0;

  int? _tradeSel; // id del oficio, o _otherValue
  String _urgency = 'urgent'; // urgent | scheduled
  DateTime? _date;
  String _status = 'open'; // open | in_progress | closed

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _budgetCtrl.dispose();
    _linkCtrl.dispose();
    _otherTradeCtrl.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  // ---------- Carga de datos ----------
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _loadError = false;
      });
    }

    final res = await Future.wait([
      ApiService.get('/job-posts', query: {'page': '1'}),
      ApiService.get('/trades'),
      ApiService.get('/profile'),
    ]);
    final postsRes = res[0];
    final tradesRes = res[1];
    final profileRes = res[2];

    if (!mounted) return;

    if (!postsRes.ok || !tradesRes.ok) {
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
      _posts = _toList(postsRes.data['data']);
      _trades = _toList(tradesRes.data['trades']);
      _page = 1;
      _hasMore = postsRes.data['next_page_url'] != null;
      _loading = false;
      _loadError = false;

      _clientDistrict = profileRes.ok
          ? (profileRes.data['profile']['district'] ?? '').toString()
          : null;
    });
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final res =
        await ApiService.get('/job-posts', query: {'page': '${_page + 1}'});
    if (!mounted) return;

    if (res.ok) {
      _posts.addAll(_toList(res.data['data']));
      _page++;
      _hasMore = res.data['next_page_url'] != null;
    } else {
      _aviso(res.message);
    }
    setState(() => _loadingMore = false);
  }

  // ---------- Formulario ----------
  void _limpiarForm() {
    _titleCtrl.clear();
    _descCtrl.clear();
    _budgetCtrl.clear();
    _linkCtrl.clear();
    _otherTradeCtrl.clear();
    _tradeSel = null;
    _urgency = 'urgent';
    _date = null;
    _status = 'open';
  }

  void _scrollToForm() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _formAnchor.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _abrirNuevo() {
    _limpiarForm();
    setState(() {
      _editingId = null;
      _formOpen = true;
      _formSeq++;
    });
    _scrollToForm();
  }

  void _abrirEditar(Map<String, dynamic> p) {
    _limpiarForm();
    _titleCtrl.text = (p['title'] ?? '').toString();
    _descCtrl.text = (p['description'] ?? '').toString();
    _linkCtrl.text = (p['location_link'] ?? '').toString();

    final budget = _toDouble(p['budget']);
    _budgetCtrl.text = budget == null ? '' : _fmtMoney(budget);

    if (p['trade_id'] != null) {
      _tradeSel = (p['trade_id'] as num).toInt();
    } else if (p['other_trade'] != null) {
      _tradeSel = _otherValue;
      _otherTradeCtrl.text = p['other_trade'].toString();
    }

    _urgency = (p['urgency'] ?? 'urgent').toString();
    _date = _parseDate(p['desired_date']);
    _status = (p['status'] ?? 'open').toString();

    setState(() {
      _editingId = (p['id'] as num).toInt();
      _editingDistrict = (p['district'] ?? '').toString();
      _formOpen = true;
      _formSeq++;
    });
    _scrollToForm();
  }

  void _cerrarForm() {
    _limpiarForm();
    setState(() {
      _formOpen = false;
      _editingId = null;
      _formSeq++;
    });
  }

  Future<void> _elegirFecha() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial =
        (_date != null && !_date!.isBefore(today)) ? _date! : today;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final esOtro = _tradeSel == _otherValue;
    final budgetText = _budgetCtrl.text.trim().replaceAll(',', '.');
    final link = _linkCtrl.text.trim();

    final Map<String, dynamic> body = {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'trade_id': esOtro ? null : _tradeSel,
      'other_trade': esOtro ? _otherTradeCtrl.text.trim() : null,
      'budget': budgetText.isEmpty ? null : double.parse(budgetText),
      'location_link': link.isEmpty ? null : link,
      'urgency': _urgency,
      'desired_date':
          (_urgency == 'scheduled' && _date != null) ? _apiDate(_date!) : null,
      if (_editingId != null) 'status': _status,
    };

    setState(() => _saving = true);

    final res = _editingId == null
        ? await ApiService.post('/job-posts', body: body)
        : await ApiService.put('/job-posts/$_editingId', body: body);

    if (!mounted) return;
    setState(() => _saving = false);

    if (!res.ok) {
      _aviso(res.message);
      return;
    }

    _aviso((res.data['message'] ?? 'Guardado correctamente').toString());
    _cerrarForm();
    await _load(silent: true);
  }

  Future<void> _eliminar(Map<String, dynamic> p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Eliminar anuncio'),
        content: Text(
          '¿Seguro que deseas eliminar «${p['title']}»? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: const Color(0xFF690005),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final res = await ApiService.delete('/job-posts/${p['id']}');
    if (!mounted) return;

    if (!res.ok) {
      _aviso(res.message);
      return;
    }

    if (_editingId == (p['id'] as num).toInt()) _cerrarForm();
    setState(() => _posts.removeWhere((x) => x['id'] == p['id']));
    _aviso('Anuncio eliminado correctamente');
  }

  Future<void> _abrirLink(String link) async {
    var ok = false;
    final uri = Uri.tryParse(link);
    if (uri != null) {
      try {
        ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        ok = false;
      }
    }
    if (!ok && mounted) _aviso('No se pudo abrir el enlace');
  }

  // ---------- UI ----------
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
              Text('No se pudieron cargar tus anuncios',
                  style: _ts(context, size: 16)),
              const SizedBox(height: 4),
              Text(
                'Revisa tu conexión y que el servidor esté encendido.',
                textAlign: TextAlign.center,
                style: _ts(context,
                    size: 12, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final abiertos = _posts.where((p) => p['status'] == 'open').length;

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // ---------- Encabezado ----------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mis Anuncios',
                        style: _ts(context,
                            size: 22, weight: FontWeight.w600, spacing: -0.2)),
                    const SizedBox(height: 4),
                    Text(
                      'Gestiona tus publicaciones o crea un nuevo requerimiento',
                      style: _ts(context,
                          size: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      abiertos == 1 ? '1 Abierto' : '$abiertos Abiertos',
                      style: _ts(context,
                          size: 10,
                          weight: FontWeight.w700,
                          color: AppColors.secondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ---------- Botón principal ----------
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryContainer.withAlpha(110),
                  blurRadius: 20,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _formOpen ? _cerrarForm : _abrirNuevo,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.onPrimaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                    _formOpen ? Icons.close : Icons.add_circle_outline,
                    size: 20),
                label: Text(
                  _formOpen ? 'Cerrar formulario' : 'Publicar nuevo anuncio',
                  style: _ts(context,
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.onPrimaryContainer,
                      spacing: 0.3),
                ),
              ),
            ),
          ),

          // ---------- Formulario ----------
          if (_formOpen) _buildForm(),

          const SizedBox(height: 24),

          // ---------- Lista ----------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PUBLICACIONES RECIENTES',
                style: _ts(context,
                    size: 10,
                    weight: FontWeight.w700,
                    color: AppColors.outline,
                    spacing: 0.8),
              ),
              Text(
                'Las más nuevas primero',
                style: _ts(context,
                    size: 12, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_posts.isEmpty)
            _buildEmpty()
          else
            ..._posts.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _PostCard(
                  post: p,
                  onEdit: () => _abrirEditar(p),
                  onDelete: () => _eliminar(p),
                  onOpenLink: _abrirLink,
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

          const SizedBox(height: 8),
          _buildTip(),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.campaign_outlined,
              size: 48, color: AppColors.outline),
          const SizedBox(height: 12),
          Text('Aún no tienes anuncios',
              style: _ts(context, size: 16, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Toca «Publicar nuevo anuncio» para crear el primero.',
            textAlign: TextAlign.center,
            style:
                _ts(context, size: 12, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildTip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.lightbulb_outline,
                size: 24, color: AppColors.secondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mantén tus anuncios al día',
                    style: _ts(context, size: 16, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Los trabajadores ven tus anuncios mientras estén abiertos. '
                  'Cuando resuelvas el problema, edítalo y márcalo como Cerrado.',
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
    );
  }

  Widget _buildForm() {
    final esOtro = _tradeSel == _otherValue;
    final editando = _editingId != null;

    return Container(
      key: _formAnchor,
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera del formulario
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.post_add,
                      size: 20, color: AppColors.secondary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        editando ? 'Editar anuncio' : 'Crear requerimiento',
                        style: _ts(context, size: 16, weight: FontWeight.w600),
                      ),
                      Text(
                        editando
                            ? 'Modifica los datos y guarda los cambios'
                            : 'Detalla tu problema para que te encuentren',
                        style: _ts(context,
                            size: 12, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _cerrarForm,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceContainerHigh,
                    ),
                    child: const Icon(Icons.close,
                        size: 18, color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _LabeledField(
              label: 'Título del problema',
              required: true,
              controller: _titleCtrl,
              hint: 'Ej: Puerta de entrada atascada',
              maxLength: 120,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Escribe un título'
                  : null,
            ),
            const SizedBox(height: 16),

            // Oficio
            const _FieldLabel('Oficio', required: true),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              key: ValueKey('trade_$_formSeq'),
              value: _tradeSel,
              isExpanded: true,
              dropdownColor: AppColors.surfaceContainerHigh,
              icon: const Icon(Icons.expand_more, color: AppColors.outline),
              style: _ts(context),
              hint: Text('Selecciona especialidad',
                  style: _ts(context, color: AppColors.outline)),
              decoration: _decoration(),
              items: [
                ..._trades.map(
                  (t) => DropdownMenuItem<int>(
                    value: (t['id'] as num).toInt(),
                    child: Text(t['name'].toString()),
                  ),
                ),
                const DropdownMenuItem<int>(
                  value: _otherValue,
                  child: Text('Otro'),
                ),
              ],
              onChanged: (v) => setState(() => _tradeSel = v),
              validator: (v) => v == null ? 'Selecciona un oficio' : null,
            ),
            if (esOtro) ...[
              const SizedBox(height: 16),
              _LabeledField(
                label: '¿Cuál oficio necesitas?',
                required: true,
                controller: _otherTradeCtrl,
                hint: 'Ej: Instalación de cámaras',
                maxLength: 100,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Escribe el oficio'
                    : null,
              ),
            ],
            const SizedBox(height: 16),

            // Prioridad
            const _FieldLabel('Prioridad', required: true),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _ChoicePill(
                    label: 'Urgente',
                    color: AppColors.error,
                    dot: true,
                    selected: _urgency == 'urgent',
                    onTap: () => setState(() => _urgency = 'urgent'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ChoicePill(
                    label: 'Programable',
                    color: AppColors.secondary,
                    dot: true,
                    selected: _urgency == 'scheduled',
                    onTap: () => setState(() => _urgency = 'scheduled'),
                  ),
                ),
              ],
            ),

            if (_urgency == 'scheduled') ...[
              const SizedBox(height: 16),
              const _FieldLabel('Fecha deseada (opcional)'),
              const SizedBox(height: 6),
              InkWell(
                onTap: _elegirFecha,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event,
                          size: 18, color: AppColors.outline),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _date == null
                              ? 'Seleccionar fecha'
                              : _showDate(_date!),
                          style: _ts(context,
                              color: _date == null
                                  ? AppColors.outline
                                  : AppColors.onSurface),
                        ),
                      ),
                      if (_date != null)
                        GestureDetector(
                          onTap: () => setState(() => _date = null),
                          child: const Icon(Icons.close,
                              size: 18, color: AppColors.outline),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            _LabeledField(
              label: 'Descripción detallada',
              required: true,
              controller: _descCtrl,
              hint:
                  'Describe qué ocurre, cuándo comenzó y tu disponibilidad horaria...',
              maxLines: 4,
              maxLength: 2000,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Describe el problema'
                  : null,
            ),
            const SizedBox(height: 16),

                        Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 18, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (editando ? _editingDistrict : _clientDistrict) == null
                          ? 'Completa tu perfil para poder publicar'
                          : '${editando ? 'Zona del anuncio' : 'Se publicará en'}: '
                              '${editando ? _editingDistrict : _clientDistrict}',
                      style: _ts(context,
                          size: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _LabeledField(
              label: 'Presupuesto referencial en S/ (opcional)',
              controller: _budgetCtrl,
              hint: 'Déjalo vacío para "A cotizar"',
              icon: Icons.payments_outlined,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final n = double.tryParse(t.replaceAll(',', '.'));
                if (n == null || n < 0) return 'Escribe solo números';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _LabeledField(
              label: 'Enlace de Google Maps (opcional)',
              controller: _linkCtrl,
              hint: 'https://maps.app.goo.gl/...',
              icon: Icons.pin_drop_outlined,
              keyboardType: TextInputType.url,
              maxLength: 500,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                if (!t.startsWith('http://') && !t.startsWith('https://')) {
                  return 'Debe empezar con https://';
                }
                return null;
              },
            ),

            if (editando) ...[
              const SizedBox(height: 16),
              const _FieldLabel('Estado del anuncio'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _ChoicePill(
                      label: 'Abierto',
                      color: AppColors.primary,
                      selected: _status == 'open',
                      onTap: () => setState(() => _status = 'open'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ChoicePill(
                      label: 'En proceso',
                      color: AppColors.tertiary,
                      selected: _status == 'in_progress',
                      onTap: () => setState(() => _status = 'in_progress'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ChoicePill(
                      label: 'Cerrado',
                      color: AppColors.onSurfaceVariant,
                      selected: _status == 'closed',
                      onTap: () => setState(() => _status = 'closed'),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : _cerrarForm,
                  child: Text('Cancelar',
                      style: _ts(context,
                          weight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _guardar,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.onPrimaryContainer,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.onPrimaryContainer,
                          ),
                        )
                      : Text(
                          editando ? 'Guardar cambios' : 'Publicar anuncio',
                          style: _ts(context,
                              weight: FontWeight.w600,
                              color: AppColors.onPrimaryContainer),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Widgets de apoyo
// =====================================================================

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;

  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.error),
            ),
        ],
      ),
      style: _ts(context,
          size: 12,
          weight: FontWeight.w600,
          color: AppColors.onSurfaceVariant,
          spacing: 0.3),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final bool required;
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;

  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
    this.required = false,
    this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label, required: required),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType:
              maxLines > 1 ? TextInputType.multiline : keyboardType,
          validator: validator,
          style: _ts(context),
          decoration: _decoration(hint: hint, icon: icon),
        ),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final bool dot;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color:
              selected ? color.withAlpha(38) : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (dot) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: _ts(
                  context,
                  size: 12,
                  weight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? color : AppColors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final bool dot;

  const _Badge({
    required this.text,
    required this.bg,
    required this.fg,
    this.icon,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: fg),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: _ts(context,
                size: 10, weight: FontWeight.w700, color: fg, spacing: 0.4),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(label,
                  style: _ts(context,
                      size: 12, weight: FontWeight.w600, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onOpenLink;

  const _PostCard({
    required this.post,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenLink,
  });

  @override
  Widget build(BuildContext context) {
    final urgent = post['urgency'] == 'urgent';
    final trade = post['trade'];
    final tradeName =
        (trade is Map ? trade['name'] : null) ?? post['other_trade'] ?? 'Sin oficio';
    final budget = _toDouble(post['budget']);
    final date = _parseDate(post['desired_date']);
    final link = (post['location_link'] ?? '').toString();
    final status = (post['status'] ?? 'open').toString();

    late final String statusText;
    late final Color statusColor;
    switch (status) {
      case 'in_progress':
        statusText = 'EN PROCESO';
        statusColor = AppColors.tertiary;
        break;
      case 'closed':
        statusText = 'CERRADO';
        statusColor = AppColors.onSurfaceVariant;
        break;
      default:
        statusText = 'ABIERTO';
        statusColor = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              urgent
                  ? const _Badge(
                      text: 'URGENTE',
                      bg: AppColors.errorContainer,
                      fg: AppColors.onErrorContainer,
                      dot: true,
                    )
                  : _Badge(
                      text: 'PROGRAMABLE',
                      bg: AppColors.secondary.withAlpha(38),
                      fg: AppColors.secondary,
                      dot: true,
                    ),
              _Badge(
                text: tradeName.toString().toUpperCase(),
                bg: AppColors.surfaceContainerHighest,
                fg: AppColors.primary,
                icon: _tradeIcon(tradeName.toString()),
              ),
              _Badge(
                text: statusText,
                bg: statusColor.withAlpha(38),
                fg: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Título y descripción
          Text(
            (post['title'] ?? '').toString(),
            style: _ts(context,
                size: 18, weight: FontWeight.w600, height: 24 / 18),
          ),
          const SizedBox(height: 6),
          Text(
            (post['description'] ?? '').toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _ts(context, color: AppColors.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 16),

          // Datos: zona, presupuesto, fecha, mapa
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 18, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (post['district'] ?? '').toString(),
                        overflow: TextOverflow.ellipsis,
                        style: _ts(context,
                            size: 12, weight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      budget == null ? 'A cotizar' : 'S/ ${_fmtMoney(budget)}',
                      style: _ts(
                        context,
                        size: 12,
                        weight: FontWeight.w700,
                        color: budget == null
                            ? AppColors.tertiary
                            : AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                if (!urgent && date != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.event,
                          size: 18, color: AppColors.outline),
                      const SizedBox(width: 8),
                      Text(
                        'Para el ${_showDate(date)}',
                        style: _ts(context,
                            size: 12, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
                if (link.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => onOpenLink(link),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map_outlined,
                              size: 16, color: AppColors.secondary),
                          const SizedBox(width: 6),
                          Text(
                            'Ver ubicación en mapa',
                            style: _ts(context,
                                size: 12,
                                weight: FontWeight.w600,
                                color: AppColors.secondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tiempo y acciones
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.schedule,
                        size: 14, color: AppColors.outline),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _ago(post['created_at']),
                        overflow: TextOverflow.ellipsis,
                        style: _ts(context,
                            size: 10,
                            weight: FontWeight.w700,
                            color: AppColors.outline),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.edit_outlined,
                label: 'Editar',
                bg: AppColors.surfaceContainerHigh,
                fg: AppColors.onSurface,
                onTap: onEdit,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.delete_outline,
                label: 'Eliminar',
                bg: AppColors.errorContainer.withAlpha(51),
                fg: AppColors.error,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}