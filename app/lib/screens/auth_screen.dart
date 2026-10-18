import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'admin/admin_shell.dart';
import 'client/client_shell.dart';
import 'worker/worker_shell.dart';

class AuthScreen extends StatefulWidget {
  /// 'client' o 'worker'
  final String initialRole;

  const AuthScreen({super.key, this.initialRole = 'client'});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  late String _role;
  bool _isLogin = true;
  bool _obscure = true;
  bool _acceptTerms = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  void _cambiarModo(bool login) {
    if (_isLogin == login) return;
    setState(() => _isLogin = login);
    _formKey.currentState?.reset();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isLogin && !_acceptTerms) {
      _aviso('Debes aceptar los términos de servicio');
      return;
    }

    setState(() => _loading = true);

    final ApiResponse res;
    if (_isLogin) {
      res = await ApiService.post('/login', body: {
        'email': _emailCtrl.text.trim(),
        'password': _passCtrl.text,
      });
    } else {
      res = await ApiService.post('/register', body: {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passCtrl.text,
        'password_confirmation': _passCtrl.text,
        'role': _role,
      });
    }

    if (!mounted) return;

    if (!res.ok) {
      setState(() => _loading = false);
      _aviso(res.message);
      return;
    }

    final user = res.data['user'] as Map<String, dynamic>;
    await ApiService.saveToken(res.data['token']);

    // Si la cuenta es de otro rol, se cierra la sesión recién abierta
    // y se muestra el mismo mensaje genérico, sin revelar el rol real
    if (_isLogin && user['role'] != 'admin' && user['role'] != _role) {
      await ApiService.post('/logout');
      await ApiService.clearToken();
      if (!mounted) return;
      setState(() => _loading = false);
      _aviso('Correo o contraseña incorrectos');
      return;
    }

    final Widget destino = switch (user['role']) {
      'admin' => AdminShell(user: user),
      'worker' => WorkerShell(user: user),
      _ => ClientShell(user: user),
    };

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destino),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          color: AppColors.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            // Cuando tengas el logo: Image.asset('assets/images/logo.png', height: 32)
            const Icon(Icons.handyman, color: AppColors.tertiary, size: 24),
            const SizedBox(width: 8),
            Text(
              'TuOficio',
              style: textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- Encabezado ----------
              Text(
                'Bienvenido',
                style: textTheme.headlineSmall?.copyWith(
                  fontSize: 26,
                  height: 34 / 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ingresa a tu cuenta para continuar.',
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // ---------- Rol elegido en la bienvenida ----------
              _RoleBadge(role: _role),
              const SizedBox(height: 16),

              // ---------- Tarjeta principal ----------
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AuthTabs(isLogin: _isLogin, onChanged: _cambiarModo),
                      const SizedBox(height: 16),

                      if (!_isLogin) ...[
                        _Field(
                          label: 'Nombre Completo',
                          controller: _nameCtrl,
                          hint: 'Ej. Camila Morales o Juan Díaz',
                          icon: Icons.badge_outlined,
                          keyboardType: TextInputType.name,
                          validator: (v) => (v == null || v.trim().length < 3)
                              ? 'Escribe tu nombre completo'
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],

                      _Field(
                        label: 'Correo electrónico',
                        controller: _emailCtrl,
                        hint: 'nombre@ejemplo.com',
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          final t = v?.trim() ?? '';
                          if (t.isEmpty) return 'Escribe tu correo';
                          if (!t.contains('@') || !t.contains('.')) {
                            return 'Correo no válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _Field(
                        label: _isLogin ? 'Contraseña' : 'Crea una Contraseña',
                        controller: _passCtrl,
                        hint: _isLogin
                            ? 'Tu clave de seguridad'
                            : 'Mínimo 8 caracteres',
                        icon: _isLogin ? Icons.lock_outline : Icons.key_outlined,
                        obscure: _obscure,
                        labelTrailing: _isLogin
                            ? GestureDetector(
                                onTap: () => _aviso(
                                    'Recuperar contraseña estará disponible pronto'),
                                child: Text(
                                  '¿Olvidaste tu contraseña?',
                                  style: textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              )
                            : null,
                        suffix: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                            size: 20,
                            color: AppColors.outline,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        validator: (v) {
                          final t = v ?? '';
                          if (t.isEmpty) return 'Escribe tu contraseña';
                          if (!_isLogin && t.length < 8) {
                            return 'Mínimo 8 caracteres';
                          }
                          return null;
                        },
                      ),

                      if (!_isLogin) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () =>
                              setState(() => _acceptTerms = !_acceptTerms),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _acceptTerms,
                                  activeColor: AppColors.primaryContainer,
                                  onChanged: (v) =>
                                      setState(() => _acceptTerms = v ?? false),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Acepto los términos de servicio, políticas de garantía y estándares de confianza de TuOficio.',
                                  style: textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    height: 1.3,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ---------- Botón principal ----------
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryContainer.withAlpha(100),
                              blurRadius: 24,
                              spreadRadius: -4,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: _loading ? null : _enviar,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryContainer,
                              foregroundColor: AppColors.onPrimaryContainer,
                              disabledBackgroundColor:
                                  AppColors.primaryContainer.withAlpha(150),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.onPrimaryContainer,
                                    ),
                                  )
                                : Text(
                                    _isLogin ? 'Ingresar' : 'Registrarse',
                                    style: textTheme.titleMedium?.copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                      color: AppColors.onPrimaryContainer,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ---------- Divisor ----------
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(
                                color: AppColors.surfaceContainerHighest,
                                height: 1),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'O CONTINÚA CON',
                              style: textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(
                                color: AppColors.surfaceContainerHighest,
                                height: 1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ---------- Botones sociales (aún sin función) ----------
                      Row(
                        children: [
                          Expanded(
                            child: _SocialButton(
                              label: 'Google',
                              leading: const Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4285F4),
                                ),
                              ),
                              onTap: () => _aviso(
                                  'Ingreso con Google estará disponible pronto'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SocialButton(
                              label: 'Apple',
                              leading: const Icon(Icons.apple,
                                  size: 18, color: AppColors.onSurface),
                              onTap: () => _aviso(
                                  'Ingreso con Apple estará disponible pronto'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Widgets de apoyo
// =====================================================================

class _RoleBadge extends StatelessWidget {
  final String role; // 'client' o 'worker'

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final esCliente = role == 'client';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withAlpha(90),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            esCliente ? Icons.person_outline : Icons.handyman_outlined,
            size: 20,
            color: AppColors.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            esCliente ? 'Cliente' : 'Trabajador',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: AppColors.onPrimaryContainer,
                ),
          ),
        ],
      ),
    );
  }
}

class _AuthTabs extends StatelessWidget {
  final bool isLogin;
  final ValueChanged<bool> onChanged;

  const _AuthTabs({required this.isLogin, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'Iniciar Sesión',
              selected: isLogin,
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: 'Registrarse',
              selected: !isLogin,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceContainerHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color:
                    selected ? AppColors.onSurface : AppColors.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final Widget? labelTrailing;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
    this.labelTrailing,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    OutlineInputBorder border([Color color = Colors.transparent]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: AppColors.onSurface,
              ),
            ),
            if (labelTrailing != null) labelTrailing!,
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          style: textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: AppColors.onSurface,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceContainerLowest,
            hintText: hint,
            hintStyle: textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: AppColors.outline,
            ),
            prefixIcon: Icon(icon, size: 20, color: AppColors.outline),
            suffixIcon: suffix,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
            border: border(),
            enabledBorder: border(),
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

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget leading;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              leading,
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}