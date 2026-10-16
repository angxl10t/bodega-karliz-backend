import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'usuarios_service.dart';
import 'configuracion_marca_modal.dart';
import '../../core/theme.dart';

class PlanYPersonalSheet extends StatefulWidget {
  final String nombreBodega;
  final String plan;
  final String currentUsername;

  const PlanYPersonalSheet({
    super.key,
    required this.nombreBodega,
    required this.plan,
    required this.currentUsername,
  });

  static Future<void> show(
    BuildContext context, {
    required String nombreBodega,
    required String plan,
    required String currentUsername,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PlanYPersonalSheet(
        nombreBodega: nombreBodega,
        plan: plan,
        currentUsername: currentUsername,
      ),
    );
  }

  @override
  State<PlanYPersonalSheet> createState() => _PlanYPersonalSheetState();
}

class _PlanYPersonalSheetState extends State<PlanYPersonalSheet> {
  final _usuariosService = UsuariosService();
  List<UsuarioItem> _usuarios = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final list = await _usuariosService.listarUsuarios();
      if (mounted) {
        setState(() {
          _usuarios = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar la lista de personal.';
          _isLoading = false;
        });
      }
    }
  }

  void _abrirCrearUsuarioModal() {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String rolSeleccionado = 'CAJERO';
    bool obscurePass = true;
    String modalError = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(LucideIcons.userPlus, color: AppTheme.brandPrimary, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Nuevo Empleado / Cajero',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (modalError.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.alertRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        modalError,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.alertRed),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    'Nombre de Usuario *',
                    style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: userCtrl,
                    decoration: const InputDecoration(hintText: 'Ej. cajero_tarde'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Contraseña Inicial (mínimo 8 caracteres) *',
                    style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: passCtrl,
                    obscureText: obscurePass,
                    decoration: InputDecoration(
                      hintText: 'Contraseña temporal',
                      suffixIcon: IconButton(
                        icon: Icon(obscurePass ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
                        onPressed: () => setModalState(() => obscurePass = !obscurePass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Rol asignado',
                    style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: rolSeleccionado,
                    items: const [
                      DropdownMenuItem(value: 'CAJERO', child: Text('CAJERO (Cobros, Caja y Stock)')),
                      DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN (Acceso Total)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => rolSeleccionado = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final u = userCtrl.text.trim();
                  final p = passCtrl.text.trim();
                  if (u.length < 3) {
                    setModalState(() => modalError = 'Usuario debe tener al menos 3 caracteres.');
                    return;
                  }
                  if (p.length < 8) {
                    setModalState(() => modalError = 'Contraseña debe tener al menos 8 caracteres.');
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await _usuariosService.crearUsuario(
                      username: u,
                      password: p,
                      rol: rolSeleccionado,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _cargarUsuarios();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Personal registrado exitosamente.'),
                        backgroundColor: AppTheme.accentGreen,
                      ),
                    );
                  } catch (e) {
                    setModalState(() {
                      modalError = e.toString().replaceAll('Exception: ', '');
                    });
                  }
                },
                child: const Text('CREAR USUARIO'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _abrirResetPasswordModal(UsuarioItem u) {
    final passCtrl = TextEditingController();
    bool obscurePass = true;
    String modalError = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Resetear Clave: ${u.username}',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (modalError.isNotEmpty) ...[
                  Text(modalError, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                const Text('Nueva Contraseña (mínimo 8 caracteres):'),
                const SizedBox(height: 6),
                TextField(
                  controller: passCtrl,
                  obscureText: obscurePass,
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(obscurePass ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
                      onPressed: () => setModalState(() => obscurePass = !obscurePass),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  final p = passCtrl.text.trim();
                  if (p.length < 8) {
                    setModalState(() => modalError = 'Mínimo 8 caracteres.');
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await _usuariosService.resetPassword(u.idUsuario, p);
                    if (ctx.mounted) Navigator.pop(ctx);
                    messenger.showSnackBar(
                      SnackBar(content: Text('Clave de ${u.username} actualizada.')),
                    );
                  } catch (e) {
                    setModalState(() => modalError = e.toString().replaceAll('Exception: ', ''));
                  }
                },
                child: const Text('GUARDAR'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDarkElevated : const Color(0xFFF8FAFC);
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;
    final isPro = widget.plan.toUpperCase() == 'PRO';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Manija superior
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isPro ? AppTheme.accentGreen : AppTheme.brandPrimary).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isPro ? LucideIcons.sparkles : LucideIcons.store,
                          color: isPro ? AppTheme.accentGreen : AppTheme.brandPrimary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Suscripción & Personal',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          Text(
                            widget.nombreBodega,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 20, color: isDark ? Colors.white60 : AppTheme.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tarjeta de Estado del Plan
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPro
                              ? [const Color(0xFF0D9488), const Color(0xFF0F766E)]
                              : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isPro ? 'PLAN MINIMARKET PRO' : 'PLAN BODEGA BÁSICO',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isPro ? 'S/ 59 /mes' : 'S/ 29 /mes',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isPro
                                ? '✓ Cajeros y administradores ilimitados con PIN.\n✓ Control de turnos y sincronización en tiempo real.\n✓ Almacén y Kardex protegidos contra fraudes.'
                                : '✓ 1 Usuario Administrador incluido.\n✓ Catálogo, POS rápido y Caja en la nube.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Acceso a Configuración de Identidad & Marca (Niveles 1 y 2)
                    InkWell(
                      onTap: () => ConfiguracionMarcaModal.show(context, isPro: isPro),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(LucideIcons.palette, color: AppTheme.brandPrimary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Identidad & Marca Comercial',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : AppTheme.textDark,
                                    ),
                                  ),
                                  Text(
                                    'Nombre, RUC, lema en tickets y paleta de color',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(LucideIcons.chevronRight, size: 18, color: AppTheme.textMuted),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Si está en plan básico, mostrar tarjeta de UPSELL
                    if (!isPro) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.brandPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppTheme.brandPrimary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.sparkles, color: AppTheme.brandPrimary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '¿Necesitas cajeros o empleados?',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : AppTheme.textDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'El Plan Bodega incluye 1 usuario único. Con Plan Pro puedes habilitar cajeros para atender turnos con su propio PIN de seguridad.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Sección de Empleados
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Personal Registrado (${_usuarios.length})',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        if (isPro)
                          TextButton.icon(
                            onPressed: _abrirCrearUsuarioModal,
                            icon: const Icon(LucideIcons.plus, size: 16),
                            label: const Text('Agregar'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_error.isNotEmpty)
                      Center(
                        child: Text(_error, style: const TextStyle(color: Colors.red)),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _usuarios.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final u = _usuarios[i];
                          final isMe = u.username.equalsIgnoreCase(widget.currentUsername);

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: (u.rol == 'ADMIN'
                                            ? AppTheme.brandPrimary
                                            : const Color(0xFF6366F1))
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    u.rol == 'ADMIN' ? LucideIcons.shield : LucideIcons.user,
                                    color: u.rol == 'ADMIN' ? AppTheme.brandPrimary : const Color(0xFF6366F1),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            u.username,
                                            style: GoogleFonts.outfit(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : AppTheme.textDark,
                                            ),
                                          ),
                                          if (isMe) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: AppTheme.accentGreen.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'TÚ',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                  color: AppTheme.accentGreen,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        u.rol == 'ADMIN' ? 'Administrador' : 'Cajero / Operador',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(LucideIcons.keyRound, size: 18),
                                  tooltip: 'Resetear contraseña',
                                  onPressed: () => _abrirResetPasswordModal(u),
                                ),
                                if (!isMe)
                                  Switch(
                                    value: u.estado,
                                    activeThumbColor: AppTheme.accentGreen,
                                    onChanged: (val) async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      try {
                                        await _usuariosService.cambiarEstado(u.idUsuario, val);
                                        _cargarUsuarios();
                                      } catch (e) {
                                        messenger.showSnackBar(
                                          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                                        );
                                      }
                                    },
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
