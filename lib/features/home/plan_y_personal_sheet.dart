import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'usuarios_service.dart';

import 'bodega_service.dart';

import 'configuracion_marca_modal.dart';
import 'mi_bodega_online_modal.dart';
import 'permisos_cajero_modal.dart';
import '../promociones/promociones_screen.dart';
import '../../core/widgets/pago_yape_modal.dart';
import '../../core/widgets/plan_comparativa_table.dart';
import '../../core/widgets/plan_upgrade_modal.dart';

import '../auth/auth_service.dart';

import '../../core/theme.dart';

enum PlanSheetSeccion { todas, suscripcion, personal }

class PlanYPersonalSheet extends StatefulWidget {
  final String nombreBodega;

  final String plan;

  final String currentUsername;

  final String? userRol;

  final VoidCallback? onPlanUpdated;
  final PlanSheetSeccion seccionInicial;

  const PlanYPersonalSheet({
    super.key,

    required this.nombreBodega,

    required this.plan,

    required this.currentUsername,

    this.userRol,

    this.onPlanUpdated,
    this.seccionInicial = PlanSheetSeccion.todas,
  });

  static Future<void> show(
    BuildContext context, {

    required String nombreBodega,

    required String plan,

    required String currentUsername,

    String? userRol,

    VoidCallback? onPlanUpdated,
    PlanSheetSeccion seccionInicial = PlanSheetSeccion.todas,
  }) {
    return showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (ctx) => PlanYPersonalSheet(
        nombreBodega: nombreBodega,

        plan: plan,

        currentUsername: currentUsername,

        userRol: userRol,

        onPlanUpdated: onPlanUpdated,
        seccionInicial: seccionInicial,
      ),
    );
  }

  @override
  State<PlanYPersonalSheet> createState() => _PlanYPersonalSheetState();
}

class _PlanYPersonalSheetState extends State<PlanYPersonalSheet> {
  final _usuariosService = UsuariosService();

  final _bodegaService = BodegaService();

  List<UsuarioItem> _usuarios = [];

  List<BodegaInfo> _bodegasRegistradas = [];

  bool _isLoading = true;

  String _error = '';

  BodegaInfo? _bodegaInfo;

  late String _currentPlan;

  late String _userRol;

  @override
  void initState() {
    super.initState();

    _currentPlan = widget.plan;

    _userRol = widget.userRol ?? 'ADMIN';

    if (widget.userRol == null) {
      AuthService().getUserRole().then((r) {
        if (mounted) setState(() => _userRol = r);
      });
    }

    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;

      _error = '';
    });

    try {
      final listFuture = _usuariosService.listarUsuarios().catchError(
        (_) => <UsuarioItem>[],
      );

      final bodegaFuture = _bodegaService.obtenerMiBodega().catchError(
        (_) => null,
      );

      final bodegasFuture = _userRol == 'SUPERADMIN'
          ? _bodegaService.listarTodas().catchError((_) => <BodegaInfo>[])
          : Future.value(<BodegaInfo>[]);

      final results = await Future.wait([
        listFuture,
        bodegaFuture,
        bodegasFuture,
      ]);

      if (mounted) {
        setState(() {
          _usuarios = results[0] as List<UsuarioItem>;

          _bodegaInfo = results[1] as BodegaInfo?;

          _bodegasRegistradas = results[2] as List<BodegaInfo>;

          if (_bodegaInfo != null) {
            _currentPlan = _bodegaInfo!.plan;
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar la información.';

          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cargarUsuarios() async {
    try {
      final list = await _usuariosService.listarUsuarios();

      if (mounted) {
        setState(() {
          _usuarios = list;
        });
      }
    } catch (_) {}
  }

  void _abrirCrearUsuarioModal() {
    final userCtrl = TextEditingController();

    final passCtrl = TextEditingController();

    final confirmPassCtrl = TextEditingController();

    String rolSeleccionado = 'CAJERO';

    bool obscurePass = true;

    bool obscureConfirm = true;

    String modalError = '';

    String sugerenciaDetectada = '';

    bool isSubmitting = false;

    void generarClaveAleatoria(StateSetter setModalState) {
      // PIN 100% numérico de 4 dígitos (0-9) para uso ágil en POS

      final pinGenerado =
          (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();

      passCtrl.text = pinGenerado;

      confirmPassCtrl.text = pinGenerado;

      setModalState(() {
        obscurePass = false;

        obscureConfirm = false;

        modalError = '';
      });

      HapticFeedback.lightImpact();
    }

    showDialog(
      context: context,

      barrierDismissible: !isSubmitting,

      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          final currentInput = userCtrl.text.trim().toLowerCase();

          // Detección local en tiempo real de duplicados en la misma bodega

          final matchingLocalUser = currentInput.isEmpty
              ? null
              : _usuarios
                    .where((x) => x.username.equalsIgnoreCase(currentInput))
                    .firstOrNull;

          return AlertDialog(
            backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),

            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),

                  decoration: BoxDecoration(
                    color: AppTheme.brandPrimary.withValues(alpha: 0.12),

                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: const Icon(
                    LucideIcons.userPlus,
                    color: AppTheme.brandPrimary,
                    size: 20,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        'Nuevo Cajero / Personal',

                        style: GoogleFonts.outfit(
                          fontSize: 17,

                          fontWeight: FontWeight.w800,

                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),

                      Text(
                        'Acceso POS y registro de ventas',

                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,

                          fontWeight: FontWeight.w600,

                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),

                  tooltip: 'Cerrar',

                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                ),
              ],
            ),

            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // Alerta de Error del Servidor

                  if (modalError.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),

                      decoration: BoxDecoration(
                        color: AppTheme.alertRed.withValues(alpha: 0.1),

                        borderRadius: BorderRadius.circular(10),

                        border: Border.all(
                          color: AppTheme.alertRed.withValues(alpha: 0.3),
                        ),
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.alertCircle,
                                size: 14,
                                color: AppTheme.alertRed,
                              ),

                              const SizedBox(width: 6),

                              Expanded(
                                child: Text(
                                  modalError,

                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: AppTheme.alertRed,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Sugerencia interactiva con 1 clic
                          if (sugerenciaDetectada.isNotEmpty) ...[
                            const SizedBox(height: 8),

                            InkWell(
                              onTap: () {
                                userCtrl.text = sugerenciaDetectada;

                                setModalState(() {
                                  modalError = '';

                                  sugerenciaDetectada = '';
                                });
                              },

                              borderRadius: BorderRadius.circular(8),

                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),

                                decoration: BoxDecoration(
                                  color: AppTheme.brandPrimary.withValues(
                                    alpha: 0.15,
                                  ),

                                  borderRadius: BorderRadius.circular(8),

                                  border: Border.all(
                                    color: AppTheme.brandPrimary.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),

                                child: Row(
                                  mainAxisSize: MainAxisSize.min,

                                  children: [
                                    const Icon(
                                      LucideIcons.sparkles,
                                      size: 13,
                                      color: AppTheme.brandPrimary,
                                    ),

                                    const SizedBox(width: 6),

                                    Text(
                                      'Usar sugerencia: "$sugerenciaDetectada"',

                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,

                                        fontWeight: FontWeight.w700,

                                        color: isDark
                                            ? AppTheme.brandLight
                                            : AppTheme.brandPrimary,
                                      ),
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
                  ],

                  // Campo: Nombre de Usuario
                  Text(
                    'Usuario de Acceso *',

                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 4),

                  TextField(
                    controller: userCtrl,

                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9._-]'),
                      ),
                    ],

                    onChanged: (_) => setModalState(() {
                      modalError = '';

                      sugerenciaDetectada = '';
                    }),

                    decoration: const InputDecoration(
                      hintText: 'Ej. cajero_tarde o ana_pos',

                      prefixIcon: Icon(LucideIcons.user, size: 18),

                      helperText: 'Sin espacios ni tildes (a-z, 0-9, _, .)',
                    ),
                  ),

                  // Aviso en tiempo real de duplicado local en la misma bodega
                  if (matchingLocalUser != null) ...[
                    const SizedBox(height: 6),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),

                      decoration: BoxDecoration(
                        color: matchingLocalUser.estado
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                            : const Color(0xFF38BDF8).withValues(alpha: 0.12),

                        borderRadius: BorderRadius.circular(8),

                        border: Border.all(
                          color: matchingLocalUser.estado
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                              : const Color(0xFF38BDF8).withValues(alpha: 0.4),
                        ),
                      ),

                      child: Row(
                        children: [
                          Icon(
                            matchingLocalUser.estado
                                ? LucideIcons.alertTriangle
                                : LucideIcons.info,

                            size: 13,

                            color: matchingLocalUser.estado
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF38BDF8),
                          ),

                          const SizedBox(width: 6),

                          Expanded(
                            child: Text(
                              matchingLocalUser.estado
                                  ? 'Ya tienes a este usuario activo en tu equipo.'
                                  : 'Este usuario existe desactivado. Al guardar se reactivará.',

                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,

                                fontWeight: FontWeight.w600,

                                color: matchingLocalUser.estado
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Campo: Contraseña Inicial + Generador Aleatorio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                    children: [
                      Text(
                        'PIN o Contraseña *',

                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      InkWell(
                        onTap: () => generarClaveAleatoria(setModalState),

                        borderRadius: BorderRadius.circular(6),

                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),

                          child: Row(
                            mainAxisSize: MainAxisSize.min,

                            children: [
                              const Icon(
                                LucideIcons.dices,
                                size: 13,
                                color: AppTheme.brandPrimary,
                              ),

                              const SizedBox(width: 4),

                              Text(
                                'Generar PIN (4 Dígitos)',

                                style: GoogleFonts.outfit(
                                  fontSize: 11,

                                  fontWeight: FontWeight.w700,

                                  color: AppTheme.brandPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  TextField(
                    controller: passCtrl,

                    obscureText: obscurePass,

                    onChanged: (_) => setModalState(() => modalError = ''),

                    decoration: InputDecoration(
                      hintText: 'PIN numérico de 4 dígitos o clave',

                      prefixIcon: const Icon(LucideIcons.lock, size: 18),

                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePass ? LucideIcons.eyeOff : LucideIcons.eye,
                          size: 18,
                        ),

                        onPressed: () =>
                            setModalState(() => obscurePass = !obscurePass),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Campo: Confirmar Contraseña
                  Text(
                    'Confirmar PIN o Contraseña *',

                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 4),

                  TextField(
                    controller: confirmPassCtrl,

                    obscureText: obscureConfirm,

                    onChanged: (_) => setModalState(() => modalError = ''),

                    decoration: InputDecoration(
                      hintText: 'Repite el PIN o contraseña',

                      prefixIcon: const Icon(LucideIcons.checkCheck, size: 18),

                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm ? LucideIcons.eyeOff : LucideIcons.eye,
                          size: 18,
                        ),

                        onPressed: () => setModalState(
                          () => obscureConfirm = !obscureConfirm,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Selector de Rol
                  Text(
                    'Rol y Nivel de Acceso',

                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 4),

                  DropdownButtonFormField<String>(
                    initialValue: rolSeleccionado,

                    decoration: const InputDecoration(
                      prefixIcon: Icon(LucideIcons.shield, size: 18),
                    ),

                    items: const [
                      DropdownMenuItem(
                        value: 'CAJERO',

                        child: Text('CAJERO (POS, Ventas y Caja)'),
                      ),

                      DropdownMenuItem(
                        value: 'ADMIN',

                        child: Text('ADMIN (Acceso Total y Ajustes)'),
                      ),
                    ],

                    onChanged: (val) {
                      if (val != null)
                        setModalState(() => rolSeleccionado = val);
                    },
                  ),
                ],
              ),
            ),

            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),

                child: const Text('Cancelar'),
              ),

              ElevatedButton(
                onPressed:
                    isSubmitting ||
                        (matchingLocalUser != null && matchingLocalUser.estado)
                    ? null
                    : () async {
                        final u = userCtrl.text.trim().toLowerCase();

                        final p = passCtrl.text.trim();

                        final cp = confirmPassCtrl.text.trim();

                        if (u.length < 3) {
                          setModalState(
                            () => modalError =
                                'El usuario debe tener al menos 3 caracteres.',
                          );

                          return;
                        }

                        if (p.length < 4) {
                          setModalState(
                            () => modalError = 'El PIN o contraseña debe tener al menos 4 dígitos o caracteres.',
                          );

                          return;
                        }

                        if (p != cp) {
                          setModalState(
                            () => modalError =
                                'Las contraseñas no coinciden. Verifícalas.',
                          );

                          return;
                        }

                        setModalState(() {
                          isSubmitting = true;

                          modalError = '';
                        });

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
                            SnackBar(
                              content: Text(
                                matchingLocalUser != null
                                    ? 'Cajero $u reactivado exitosamente.'
                                    : 'Cajero $u creado y habilitado exitosamente.',
                              ),

                              backgroundColor: AppTheme.accentGreen,
                            ),
                          );
                        } catch (e) {
                          final rawMsg = e.toString().replaceAll(
                            'Exception: ',
                            '',
                          );

                          // Extraer sugerencia si el backend proporcionó una

                          String encontrada = '';

                          final match = RegExp(r"'([^']+)'").allMatches(rawMsg);

                          if (rawMsg.contains('sugerimos') &&
                              match.isNotEmpty) {
                            encontrada = match.last.group(1) ?? '';
                          }

                          setModalState(() {
                            isSubmitting = false;

                            modalError = rawMsg;

                            sugerenciaDetectada = encontrada;
                          });
                        }
                      },

                child: isSubmitting
                    ? const SizedBox(
                        width: 18,

                        height: 18,

                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        matchingLocalUser != null && !matchingLocalUser.estado
                            ? 'REACTIVAR CAJERO'
                            : 'CREAR CAJERO',
                      ),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      userCtrl.dispose();

      passCtrl.dispose();

      confirmPassCtrl.dispose();
    });
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

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),

            title: Text(
              'Resetear Clave: ${u.username}',

              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),

            content: Column(
              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                if (modalError.isNotEmpty) ...[
                  Text(
                    modalError,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),

                  const SizedBox(height: 8),
                ],

                const Text('Nuevo PIN o Contraseña (mínimo 4 dígitos):'),

                const SizedBox(height: 6),

                TextField(
                  controller: passCtrl,

                  obscureText: obscurePass,

                  decoration: InputDecoration(
                    hintText: 'PIN de 4 dígitos o contraseña',

                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePass ? LucideIcons.eyeOff : LucideIcons.eye,
                        size: 18,
                      ),

                      onPressed: () =>
                          setModalState(() => obscurePass = !obscurePass),
                    ),
                  ),
                ),
              ],
            ),

            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),

              ElevatedButton(
                onPressed: () async {
                  final p = passCtrl.text.trim();

                  if (p.length < 4) {
                    setModalState(() => modalError = 'Mínimo 4 dígitos.');

                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);

                  try {
                    await _usuariosService.resetPassword(u.idUsuario, p);

                    if (ctx.mounted) Navigator.pop(ctx);

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Clave de ${u.username} actualizada.'),
                      ),
                    );
                  } catch (e) {
                    setModalState(
                      () => modalError = e.toString().replaceAll(
                        'Exception: ',
                        '',
                      ),
                    );
                  }
                },

                child: const Text('GUARDAR'),
              ),
            ],
          );
        },
      ),
    ).then((_) => passCtrl.dispose());
  }

  void _abrirEditarUsuarioModal(UsuarioItem u) {
    final nombreCtrl = TextEditingController(text: u.nombreCompleto ?? '');
    final emailCtrl = TextEditingController(text: u.email ?? '');
    String modalError = '';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final isMe = u.username.equalsIgnoreCase(widget.currentUsername);

          return AlertDialog(
            backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.userCheck,
                    color: AppTheme.brandPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMe
                            ? 'Mi Perfil y Correo'
                            : 'Editar Datos: @${u.username}',
                        style: GoogleFonts.outfit(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'Actualiza correo de recuperación y titular',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  tooltip: 'Cerrar',
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
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
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.alertRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.alertRed.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.alertCircle,
                            size: 14,
                            color: AppTheme.alertRed,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              modalError,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppTheme.alertRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Badge info usuario
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.shield,
                          size: 14,
                          color: AppTheme.brandPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Cuenta: @${u.username} • Rol: ${u.rol}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Campo: Correo Electrónico
                  Text(
                    'Correo Electrónico (Para recuperación) *',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => setModalState(() => modalError = ''),
                    decoration: const InputDecoration(
                      hintText: 'Ej. mimarketz@gmail.com',
                      prefixIcon: Icon(LucideIcons.mail, size: 18),
                      helperText: 'A este correo te llegará el código de 6 dígitos si olvidas tu contraseña.',
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Campo: Nombre Completo
                  Text(
                    'Nombre del Titular o Cajero',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: nombreCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Ej. Karliz Quispe o Carlos Pérez',
                      prefixIcon: Icon(LucideIcons.user, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final emailIngresado = emailCtrl.text.trim();
                        if (emailIngresado.isNotEmpty &&
                            !RegExp(
                              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                            ).hasMatch(emailIngresado)) {
                          setModalState(
                            () => modalError = 'Por favor ingresa un correo electrónico válido (ej. usuario@gmail.com).',
                          );
                          return;
                        }

                        setModalState(() {
                          isSubmitting = true;
                          modalError = '';
                        });

                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await _usuariosService.actualizarPerfil(
                            idUsuario: u.idUsuario,
                            nombreCompleto: nombreCtrl.text.trim(),
                            email: emailIngresado,
                          );

                          if (isMe && emailIngresado.isNotEmpty) {
                            await AuthService().setUserEmail(emailIngresado);
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          await _cargarUsuarios();

                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Datos y correo de @${u.username} actualizados con éxito.',
                              ),
                              backgroundColor: AppTheme.accentGreen,
                            ),
                          );
                        } catch (e) {
                          setModalState(() {
                            isSubmitting = false;
                            modalError = e.toString().replaceAll(
                              'Exception: ',
                              '',
                            );
                          });
                        }
                      },
                icon: isSubmitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(LucideIcons.save, size: 16),
                label: Text(
                  isSubmitting ? 'Guardando...' : 'Guardar Cambios',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      nombreCtrl.dispose();
      emailCtrl.dispose();
    });
  }

  void _confirmarEliminarUsuario(UsuarioItem u) {
    bool isDeleting = false;
    String modalError = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.alertRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.trash2,
                    color: AppTheme.alertRed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¿Eliminar cajero @${u.username}?',
                    style: GoogleFonts.outfit(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
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
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.alertRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.alertRed.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.alertCircle,
                            size: 14,
                            color: AppTheme.alertRed,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              modalError,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppTheme.alertRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Text(
                    'Esta acción eliminará la cuenta de este cajero y revocará su acceso al sistema de inmediato.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          LucideIcons.info,
                          size: 16,
                          color: AppTheme.brandPrimary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Historial seguro: Las ventas y movimientos registrados por @${u.username} permanecerán en los reportes contables y auditoría de tu negocio.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              height: 1.35,
                              color: AppTheme.getAdaptiveMutedText(isDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.alertRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isDeleting
                    ? null
                    : () async {
                        setModalState(() {
                          isDeleting = true;
                          modalError = '';
                        });

                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await _usuariosService.eliminarUsuario(u.idUsuario);
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _cargarUsuarios();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Cajero @${u.username} eliminado correctamente.',
                              ),
                              backgroundColor: AppTheme.accentGreen,
                            ),
                          );
                        } catch (e) {
                          setModalState(() {
                            isDeleting = false;
                            modalError = e.toString().replaceAll(
                              'Exception: ',
                              '',
                            );
                          });
                        }
                      },
                icon: isDeleting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(LucideIcons.trash2, size: 16),
                label: Text(
                  isDeleting ? 'Eliminando...' : 'Eliminar Cajero',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatearFecha(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);

      final meses = [
        'Ene',
        'Feb',
        'Mar',
        'Abr',
        'May',
        'Jun',

        'Jul',
        'Ago',
        'Set',
        'Oct',
        'Nov',
        'Dic',
      ];

      return '${dt.day} de ${meses[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  void _abrirModalPagoYape(BuildContext context) {
    PagoYapeModal.show(
      context,
      planInicial: _currentPlan,
      onPlanUpdated: () {
        _cargarDatos();
        widget.onPlanUpdated?.call();
      },
    );
  }

  void _abrirHistorialPagosModal(BuildContext context) {
    showDialog(
      context: context,

      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;

        return Dialog(
          backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),

          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),

          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),

            child: Padding(
              padding: const EdgeInsets.all(20),

              child: Column(
                mainAxisSize: MainAxisSize.min,

                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),

                        decoration: BoxDecoration(
                          color: AppTheme.brandPrimary.withValues(alpha: 0.12),

                          borderRadius: BorderRadius.circular(14),
                        ),

                        child: const Icon(
                          LucideIcons.receiptText,
                          color: AppTheme.brandPrimary,
                          size: 22,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Text(
                              'Historial de Suscripciones & Vouchers',

                              style: GoogleFonts.outfit(
                                fontSize: 16.5,

                                fontWeight: FontWeight.w800,

                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textDark,
                              ),
                            ),

                            Text(
                              'Libro mayor auditado contra fraudes',

                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,

                                fontWeight: FontWeight.w600,

                                color: AppTheme.accentGreen,
                              ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 20),

                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Expanded(
                    child: FutureBuilder<List<PagoSuscripcionItem>>(
                      future: _bodegaService.listarMisPagos(),

                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.brandPrimary,
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error al cargar el historial de pagos.',

                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.alertRed,
                              ),
                            ),
                          );
                        }

                        final pagos = snapshot.data ?? [];

                        if (pagos.isEmpty) {
                          return Center(
                            child: Container(
                              padding: const EdgeInsets.all(20),

                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF8FAFC),

                                borderRadius: BorderRadius.circular(16),

                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.borderDark
                                      : AppTheme.borderLight,
                                ),
                              ),

                              child: Column(
                                mainAxisSize: MainAxisSize.min,

                                children: [
                                  Icon(
                                    LucideIcons.receipt,
                                    size: 36,
                                    color: AppTheme.getAdaptiveMutedText(isDark)
                                        .withValues(alpha: 0.7),
                                  ),

                                  const SizedBox(height: 10),

                                  Text(
                                    'Sin vouchers registrados aún',

                                    style: GoogleFonts.outfit(
                                      fontSize: 14.5,

                                      fontWeight: FontWeight.w700,

                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textDark,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    'Cuando renueves tu plan mediante Yape o Plin, los comprobantes validados aparecerán aquí para auditoría contable.',

                                    textAlign: TextAlign.center,

                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,

                                      color: AppTheme.getAdaptiveMutedText(
                                        isDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: pagos.length,

                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),

                          itemBuilder: (context, index) {
                            final p = pagos[index];

                            final bool isYape =
                                p.billetera.toUpperCase() == 'YAPE';

                            final Color walletColor = isYape
                                ? const Color(0xFF732283)
                                : const Color(0xFF0084FF);

                            return Container(
                              padding: const EdgeInsets.all(12),

                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF8FAFC),

                                borderRadius: BorderRadius.circular(16),

                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.borderDark
                                      : AppTheme.borderLight,
                                ),
                              ),

                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),

                                    decoration: BoxDecoration(
                                      color: walletColor.withValues(
                                        alpha: 0.15,
                                      ),

                                      borderRadius: BorderRadius.circular(12),

                                      border: Border.all(
                                        color: walletColor.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),

                                    child: Text(
                                      p.billetera.toUpperCase(),

                                      style: GoogleFonts.outfit(
                                        fontSize: 12,

                                        fontWeight: FontWeight.w900,

                                        color: walletColor,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,

                                      children: [
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              'Plan ${p.plan}',

                                              style: GoogleFonts.outfit(
                                                fontSize: 13.5,

                                                fontWeight: FontWeight.w800,

                                                color: isDark
                                                    ? Colors.white
                                                    : AppTheme.textDark,
                                              ),
                                            ),

                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 1.5,
                                                  ),

                                              decoration: BoxDecoration(
                                                color: AppTheme.accentGreen
                                                    .withValues(alpha: 0.15),

                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),

                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,

                                                children: [
                                                  const Icon(
                                                    LucideIcons.checkCheck,
                                                    size: 10,
                                                    color: AppTheme.accentGreen,
                                                  ),

                                                  const SizedBox(width: 3),

                                                  Text(
                                                    p.estado,

                                                    style:
                                                        GoogleFonts.plusJakartaSans(
                                                          fontSize: 9.5,

                                                          fontWeight:
                                                              FontWeight.w800,

                                                          color: AppTheme
                                                              .accentGreen,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 2),

                                        Text(
                                          'Op: ${p.codigoOperacion}',

                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5,

                                            fontWeight: FontWeight.w700,

                                            color:
                                                AppTheme.getAdaptiveMutedText(
                                                  isDark,
                                                ),
                                          ),
                                        ),

                                        Text(
                                          p.fechaPago != null
                                              ? '${_formatearFecha(p.fechaPago!)} • Reg: ${p.usuarioRegistro ?? "Admin"}'
                                              : 'Reg: ${p.usuarioRegistro ?? "Admin"}',

                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10.5,

                                            color:
                                                AppTheme.getAdaptiveMutedText(
                                                  isDark,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Text(
                                    'S/ ${p.monto.toStringAsFixed(2)}',

                                    style: GoogleFonts.outfit(
                                      fontSize: 15,

                                      fontWeight: FontWeight.w900,

                                      color: AppTheme.accentGreen,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? AppTheme.cardDarkElevated : const Color(0xFFF8FAFC);

    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    final isPro = _currentPlan.toUpperCase() == 'PRO';

    return Align(
      alignment: Alignment.bottomCenter,

      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),

        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),

          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDarkElevated : Colors.white,

            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),

            border: isDark
                ? const Border(
                    top: BorderSide(
                      color: AppTheme.borderDarkElevated,
                      width: 1.2,
                    ),
                  )
                : null,

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
                    color: isDark
                        ? AppTheme.borderDarkElevated
                        : const Color(0xFFCBD5E1),

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
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),

                              decoration: BoxDecoration(
                                color:
                                    (isPro
                                            ? AppTheme.accentGreen
                                            : AppTheme.brandPrimary)
                                        .withValues(alpha: 0.12),

                                borderRadius: BorderRadius.circular(12),
                              ),

                              child: Icon(
                                widget.seccionInicial ==
                                        PlanSheetSeccion.personal
                                    ? LucideIcons.users
                                    : (isPro
                                          ? LucideIcons.sparkles
                                          : LucideIcons.store),
                                color:
                                    widget.seccionInicial ==
                                        PlanSheetSeccion.personal
                                    ? AppTheme.brandPrimary
                                    : (isPro
                                          ? AppTheme.accentGreen
                                          : AppTheme.brandPrimary),
                                size: 22,
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  Text(
                                    widget.seccionInicial ==
                                            PlanSheetSeccion.personal
                                        ? 'Personal & Cajeros'
                                        : (widget.seccionInicial ==
                                                  PlanSheetSeccion.suscripcion
                                              ? 'Mi Suscripción'
                                              : (_userRol == 'SUPERADMIN'
                                                    ? 'Consola Global & Bodegas'
                                                    : 'Suscripción & Personal')),

                                    style: GoogleFonts.outfit(
                                      fontSize: 18,

                                      fontWeight: FontWeight.w800,

                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textDark,
                                    ),

                                    maxLines: 1,

                                    overflow: TextOverflow.ellipsis,
                                  ),

                                  Text(
                                    widget.seccionInicial ==
                                            PlanSheetSeccion.personal
                                        ? 'Gestión de cuentas y PIN de cajeros • ${_usuarios.length} activos'
                                        : (widget.seccionInicial ==
                                                  PlanSheetSeccion.suscripcion
                                              ? 'Plan actual: $_currentPlan • Facturación mensual'
                                              : (_userRol == 'SUPERADMIN'
                                                    ? 'CajaYa Platform • ${_bodegasRegistradas.length} Bodegas Registradas'
                                                    : widget.nombreBodega)),

                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,

                                      fontWeight: FontWeight.w600,

                                      color: AppTheme.getAdaptiveMutedText(
                                        isDark,
                                      ),
                                    ),

                                    maxLines: 1,

                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      IconButton(
                        icon: Icon(
                          LucideIcons.x,
                          size: 20,
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF64748B),
                        ),

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
                        if (widget.seccionInicial !=
                            PlanSheetSeccion.personal) ...[
                          // Directorio de Bodegas para Superadmin

                          if (_userRol == 'SUPERADMIN' ||
                              _bodegasRegistradas.isNotEmpty) ...[
                            _buildDirectorioBodegasGlobal(
                              isDark,
                              cardBg,
                              borderColor,
                            ),

                            const SizedBox(height: 16),
                          ],

                          // Tarjeta de Estado del Plan
                          Container(
                            padding: const EdgeInsets.all(16),

                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isPro
                                    ? [
                                        const Color(0xFF0D9488),
                                        const Color(0xFF0F766E),
                                      ]
                                    : [
                                        const Color(0xFF1E293B),
                                        const Color(0xFF0F172A),
                                      ],

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
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      isPro
                                          ? 'PLAN MINIMARKET PRO'
                                          : 'PLAN BODEGA BÁSICO',

                                      style: GoogleFonts.outfit(
                                        fontSize: 15,

                                        fontWeight: FontWeight.w900,

                                        color: Colors.white,

                                        letterSpacing: 0.5,
                                      ),
                                    ),

                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),

                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),

                                        borderRadius: BorderRadius.circular(8),
                                      ),

                                      child: Text(
                                        isPro ? 'S/ 100 /mes' : 'S/ 50 /mes',

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
                                      ? '• Detector de Productos Hueso: alerta de dinero inmovilizado.\n• Mi Bodega Online: enlace web para pedidos por WhatsApp.\n• Auditoría Rápida por Pasillo: conteos de 5 min contra robo hormiga.\n• Termómetro de Meta Diaria: seguimiento en tiempo real con barra de progreso.\n• Mapa de Horas Punta: analítica de afluencia para saber cuándo vender más.\n• Reporte de Cierre al WhatsApp del Dueño: arqueo ejecutivo con 1 toque.'
                                      : '• Punto de Venta táctil y rápido con tickets digitales.\n• Control de Stock e Inventario en tiempo real (hasta 150 productos).\n• Caja Diaria y Arqueo (apertura, egresos y cierre).\n• Cajeros y administradores con PIN ilimitados.\n• Libreta de fiados y control de vencimientos básico.',

                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,

                                    color: Colors.white.withValues(alpha: 0.9),

                                    height: 1.4,
                                  ),
                                ),

                                if (_bodegaInfo?.fechaVencimientoPlan !=
                                    null) ...[
                                  const SizedBox(height: 8),

                                  Row(
                                    children: [
                                      Icon(
                                        LucideIcons.calendarCheck,
                                        size: 13,
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),

                                      const SizedBox(width: 5),

                                      Expanded(
                                        child: Text(
                                          'Vigente hasta el ${_formatearFecha(_bodegaInfo!.fechaVencimientoPlan!)}',

                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,

                                            fontWeight: FontWeight.w600,

                                            color: Colors.white.withValues(
                                              alpha: 0.95,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                const SizedBox(height: 12),

                                SizedBox(
                                  width: double.infinity,

                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,

                                      foregroundColor: isPro
                                          ? const Color(0xFF0F766E)
                                          : const Color(0xFF1E293B),

                                      elevation: 0,

                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),

                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                        horizontal: 14,
                                      ),
                                    ),

                                    onPressed: () =>
                                        _abrirModalPagoYape(context),

                                    icon: const Icon(
                                      LucideIcons.qrCode,
                                      size: 18,
                                    ),

                                    label: Text(
                                      isPro
                                          ? 'Renovar Plan Pro con Yape / Plin (S/ 100)'
                                          : 'Pagar / Mejorar con Yape / Plin (S/ 50 o S/ 100)',
                                      textAlign: TextAlign.center,

                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                SizedBox(
                                  width: double.infinity,

                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,

                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.35,
                                        ),
                                        width: 1.2,
                                      ),

                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),

                                      padding: const EdgeInsets.symmetric(
                                        vertical: 9,
                                        horizontal: 14,
                                      ),
                                    ),

                                    onPressed: () =>
                                        _abrirHistorialPagosModal(context),

                                    icon: const Icon(
                                      LucideIcons.receipt,
                                      size: 16,
                                    ),

                                    label: Text(
                                      'Ver Historial de Vouchers y Renovaciones',
                                      textAlign: TextAlign.center,

                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Acceso a Configuración de Identidad & Marca (Niveles 1 y 2)
                          InkWell(
                            onTap: () => ConfiguracionMarcaModal.show(
                              context,
                              isPro: isPro,
                              onSaved: () {
                                _cargarDatos();
                                widget.onPlanUpdated?.call();
                              },
                            ),

                            borderRadius: BorderRadius.circular(16),

                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),

                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.cardDarkElevated
                                    : const Color(0xFFF1F5F9),

                                borderRadius: BorderRadius.circular(16),

                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.borderDark
                                      : AppTheme.borderLight,
                                ),
                              ),

                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),

                                    decoration: BoxDecoration(
                                      color: AppTheme.brandPrimary.withValues(
                                        alpha: 0.12,
                                      ),

                                      borderRadius: BorderRadius.circular(10),
                                    ),

                                    child: const Icon(
                                      LucideIcons.palette,
                                      color: AppTheme.brandPrimary,
                                      size: 20,
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,

                                      children: [
                                        Text(
                                          'Identidad & Marca Comercial',

                                          style: GoogleFonts.outfit(
                                            fontSize: 13.5,

                                            fontWeight: FontWeight.w800,

                                            color: isDark
                                                ? Colors.white
                                                : AppTheme.textDark,
                                          ),
                                        ),

                                        Text(
                                          'Nombre, RUC, lema en tickets y paleta de color',

                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5,

                                            fontWeight: FontWeight.w600,

                                            color: isDark
                                                ? AppTheme.textDarkSecondary
                                                : const Color(0xFF334155),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Icon(
                                    LucideIcons.chevronRight,
                                    size: 18,
                                    color: isDark
                                        ? AppTheme.textDarkSecondary
                                        : const Color(0xFF64748B),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // MÓDULO MI BODEGA ONLINE (CATÁLOGO DIGITAL PRO)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.cardDarkElevated
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isPro
                                    ? AppTheme.accentGreen.withValues(
                                        alpha: 0.5,
                                      )
                                    : borderColor,
                                width: isPro ? 1.5 : 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color:
                                            (isPro
                                                    ? AppTheme.accentGreen
                                                    : const Color(0xFF64748B))
                                                .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        LucideIcons.globe,
                                        color: isPro
                                            ? AppTheme.accentGreen
                                            : AppTheme.getAdaptiveMutedText(
                                                isDark,
                                              ),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                'Mi Bodega Online',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: isDark
                                                      ? Colors.white
                                                      : AppTheme.textDark,
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      (isPro
                                                              ? AppTheme
                                                                    .accentGreen
                                                              : const Color(
                                                                  0xFFD97706,
                                                                ))
                                                          .withValues(
                                                            alpha: 0.12,
                                                          ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (!isPro) ...[
                                                      const Icon(
                                                        LucideIcons.lock,
                                                        size: 9,
                                                        color: Color(
                                                          0xFFD97706,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 3),
                                                    ],
                                                    Text(
                                                      isPro
                                                          ? 'PRO ONLINE'
                                                          : 'PLAN PRO',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: isPro
                                                            ? AppTheme
                                                                  .accentGreen
                                                            : const Color(
                                                                0xFFD97706,
                                                              ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            isPro
                                                ? 'Catálogo público activo para pedidos de vecinos'
                                                : 'Catálogo web con pedidos directos por WhatsApp',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: isPro
                                                  ? AppTheme.accentGreen
                                                  : AppTheme.getAdaptiveMutedText(
                                                      isDark,
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isPro
                                            ? 'Comparte tu link propio o QR en tu mostrador'
                                            : 'Desbloquea tu catálogo propio mejorando a PRO',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: AppTheme.getAdaptiveMutedText(
                                            isDark,
                                          ),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isPro
                                            ? AppTheme.brandPrimary
                                            : const Color(0xFFD97706),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        if (isPro) {
                                          MiBodegaOnlineModal.show(
                                            context,
                                            nombreBodega: widget.nombreBodega,
                                            telefonoBodega:
                                                _bodegaInfo?.telefono ?? '',
                                          );
                                        } else {
                                          PlanUpgradeModal.show(
                                            context,
                                            featureName: 'Mi Bodega Online',
                                            featureDescription: 'Obtén tu propio enlace web oficial (cajaya-pos.onrender.com/#/catalogo?tienda=tu-bodega) para compartir en redes sociales y recibir pedidos directos en tu WhatsApp sin comisiones.',
                                            icon: LucideIcons.globe,
                                            onPlanUpdated: () {
                                              _cargarDatos();
                                              widget.onPlanUpdated?.call();
                                            },
                                          );
                                        }
                                      },
                                      icon: Icon(
                                        isPro
                                            ? LucideIcons.share2
                                            : LucideIcons.lock,
                                        size: 14,
                                      ),
                                      label: Text(
                                        isPro ? 'Mi Enlace' : 'Activar PRO',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // MÓDULO DE PROMOCIONES Y COMBOS ESTRATÉGICOS (PLAN PRO)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isPro
                                    ? AppTheme.brandPrimary.withValues(
                                        alpha: 0.3,
                                      )
                                    : (isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.brandPrimary.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        LucideIcons.tag,
                                        color: AppTheme.brandPrimary,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                'Promociones y Descuentos',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  color: isDark
                                                      ? Colors.white
                                                      : AppTheme.textDark,
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1.5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.brandPrimary,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'PRO',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            isPro
                                                ? 'Campañas activas en tu catálogo público'
                                                : 'Ofertas por marcas, categorías y combos',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: isPro
                                                  ? AppTheme.brandPrimary
                                                  : AppTheme.getAdaptiveMutedText(
                                                      isDark,
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isPro
                                            ? 'Combos hueso antiestancamiento y ofertas'
                                            : 'Desbloquea panel de promociones mejorando a PRO',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: AppTheme.getAdaptiveMutedText(
                                            isDark,
                                          ),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isPro
                                            ? AppTheme.brandPrimary
                                            : const Color(0xFFD97706),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PromocionesScreen(
                                              isPro: isPro,
                                              nombreBodega: widget.nombreBodega,
                                              onPlanUpdated: () {
                                                _cargarDatos();
                                                widget.onPlanUpdated?.call();
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                      icon: Icon(
                                        isPro
                                            ? LucideIcons.settings
                                            : LucideIcons.lock,
                                        size: 14,
                                      ),
                                      label: Text(
                                        isPro ? 'Gestionar' : 'Activar PRO',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Si está en plan básico, mostrar tarjeta de UPSELL

                          if (!isPro) ...[
                            Container(
                              padding: const EdgeInsets.all(16),

                              decoration: BoxDecoration(
                                color: AppTheme.brandPrimary.withValues(
                                  alpha: 0.08,
                                ),

                                borderRadius: BorderRadius.circular(18),

                                border: Border.all(
                                  color: AppTheme.brandPrimary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),

                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.sparkles,
                                        color: AppTheme.brandPrimary,
                                        size: 20,
                                      ),

                                      const SizedBox(width: 8),

                                      Expanded(
                                        child: Text(
                                          '¿Quieres crecer con más control?',

                                          style: GoogleFonts.outfit(
                                            fontSize: 14.5,

                                            fontWeight: FontWeight.w800,

                                            color: isDark
                                                ? Colors.white
                                                : AppTheme.textDark,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 6),

                                  Text(
                                    'El Plan PRO (S/ 100 /mes) desbloquea: Detector de Productos Hueso (capital inmovilizado), Catálogo Mi Bodega Online con link para WhatsApp, Auditoría Rápida de Pasillo anti-robo, Termómetro de Meta Diaria, Mapa de Horas Punta y Reporte Ejecutivo de Arqueo al WhatsApp del Dueño. Diseñado para bodegas y minimarkets que buscan máxima rentabilidad y control total.',

                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,

                                      color: AppTheme.getAdaptiveMutedText(
                                        isDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),
                          ],

                          PlanComparativaTable(
                            highlightedPlan: isPro ? 'PRO' : 'BASICO',
                            title: 'COMPARATIVA DETALLADA: BÁSICO VS PRO',
                          ),

                          const SizedBox(height: 16),
                        ], // Fin seccion suscripcion

                        if (widget.seccionInicial !=
                            PlanSheetSeccion.suscripcion) ...[
                          // Sección de Empleados

                          // Tarjeta de Permisos Granulares de Cajeros
                          if (_userRol == 'ADMIN' ||
                              _userRol == 'SUPERADMIN') ...[
                            InkWell(
                              onTap: () => PermisosCajeroModal.show(context),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary
                                      .withValues(alpha: isDark ? 0.15 : 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.3),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        LucideIcons.shieldAlert,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  'Permisos Granulares por Cajero',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: isDark
                                                        ? Colors.white
                                                        : AppTheme.textDark,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1.5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.accentGreen
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                ),
                                                child: Text(
                                                  'NUEVO',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppTheme.accentGreen,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Controla costos visibles, anulaciones con PIN y descuentos',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: isDark
                                                  ? AppTheme.textDarkSecondary
                                                  : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      LucideIcons.chevronRight,
                                      size: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [
                              Expanded(
                                child: Text(
                                  'Personal Registrado (${_usuarios.length})',

                                  style: GoogleFonts.outfit(
                                    fontSize: 15,

                                    fontWeight: FontWeight.w800,

                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textDark,
                                  ),

                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              const SizedBox(width: 8),

                              TextButton.icon(
                                onPressed: _abrirCrearUsuarioModal,

                                icon: const Icon(
                                  LucideIcons.userPlus,
                                  size: 16,
                                ),

                                label: const Text('Agregar Cajero'),
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
                              child: Text(
                                _error,
                                style: const TextStyle(color: Colors.red),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,

                              physics: const NeverScrollableScrollPhysics(),

                              itemCount: _usuarios.length,

                              separatorBuilder: (ctx, i) =>
                                  const SizedBox(height: 8),

                              itemBuilder: (ctx, i) {
                                final u = _usuarios[i];

                                final isMe = u.username.equalsIgnoreCase(
                                  widget.currentUsername,
                                );

                                final infoColumn = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          u.username,
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.white
                                                : AppTheme.textDark,
                                          ),
                                        ),
                                        if (isMe)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accentGreen
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
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
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      u.rol == 'SUPERADMIN'
                                          ? 'Superadministrador'
                                          : (u.rol == 'ADMIN'
                                                ? 'Administrador (Dueño)'
                                                : 'Cajero / Operador'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: AppTheme.getAdaptiveMutedText(
                                          isDark,
                                        ),
                                      ),
                                    ),
                                    // Correo de recuperación: Exclusivo para Administrador / Dueño
                                    if (u.rol == 'ADMIN' ||
                                        u.rol == 'SUPERADMIN') ...[
                                      const SizedBox(height: 3),
                                      if (u.email != null &&
                                          u.email!.trim().isNotEmpty)
                                        Row(
                                          children: [
                                            const Icon(
                                              LucideIcons.mail,
                                              size: 11,
                                              color: AppTheme.brandPrimary,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                u.email!,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF93C5FD,
                                                            )
                                                          : const Color(
                                                              0xFF1D4ED8,
                                                            ),
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 2,
                                              ),
                                              child: Icon(
                                                LucideIcons.mailWarning,
                                                size: 11,
                                                color: Colors.amber.shade700,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'Sin correo de recuperación (Configurar)',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors.amber.shade800,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ],
                                );

                                final actionWidgets = <Widget>[
                                  // Botón editar correo de recuperación: Solo para Administradores
                                  if (u.rol == 'ADMIN' || u.rol == 'SUPERADMIN')
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      icon: const Icon(
                                        LucideIcons.pencil,
                                        size: 17,
                                        color: AppTheme.brandPrimary,
                                      ),
                                      tooltip:
                                          'Configurar correo de recuperación',
                                      onPressed: () =>
                                          _abrirEditarUsuarioModal(u),
                                    ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    icon: const Icon(
                                      LucideIcons.keyRound,
                                      size: 18,
                                    ),
                                    tooltip: 'Resetear contraseña',
                                    onPressed: () =>
                                        _abrirResetPasswordModal(u),
                                  ),
                                  // Botón eliminar: Disponible para cajeros
                                  if (!isMe &&
                                      (u.rol == 'CAJERO' ||
                                          widget.userRol == 'SUPERADMIN'))
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      icon: const Icon(
                                        LucideIcons.trash2,
                                        size: 17,
                                        color: AppTheme.alertRed,
                                      ),
                                      tooltip: 'Eliminar cajero',
                                      onPressed: () =>
                                          _confirmarEliminarUsuario(u),
                                    ),
                                  if (!isMe)
                                    Switch(
                                      value: u.estado,
                                      activeThumbColor: AppTheme.accentGreen,
                                      onChanged: (val) async {
                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );
                                        try {
                                          await _usuariosService.cambiarEstado(
                                            u.idUsuario,
                                            val,
                                          );
                                          _cargarUsuarios();
                                        } catch (e) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                e.toString().replaceAll(
                                                  'Exception: ',
                                                  '',
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                ];

                                return Container(
                                  padding: const EdgeInsets.all(12),

                                  decoration: BoxDecoration(
                                    color: cardBg,

                                    borderRadius: BorderRadius.circular(16),

                                    border: Border.all(color: borderColor),
                                  ),

                                  child: LayoutBuilder(
                                    builder: (context, cardConstraints) {
                                      final isNarrowCard =
                                          cardConstraints.maxWidth < 430;
                                      final avatar = Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color:
                                              (u.rol == 'ADMIN'
                                                      ? AppTheme.brandPrimary
                                                      : const Color(0xFF6366F1))
                                                  .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          u.rol == 'ADMIN'
                                              ? LucideIcons.shield
                                              : LucideIcons.user,
                                          color: u.rol == 'ADMIN'
                                              ? AppTheme.brandPrimary
                                              : const Color(0xFF6366F1),
                                          size: 20,
                                        ),
                                      );

                                      if (isNarrowCard) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                avatar,
                                                const SizedBox(width: 12),
                                                Expanded(child: infoColumn),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: Wrap(
                                                spacing: 2,
                                                runSpacing: 2,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: actionWidgets,
                                              ),
                                            ),
                                          ],
                                        );
                                      }

                                      return Row(
                                        children: [
                                          avatar,
                                          const SizedBox(width: 12),
                                          Expanded(child: infoColumn),
                                          ...actionWidgets,
                                        ],
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                        ], // Fin seccion personal
                      ],
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

  Widget _buildDirectorioBodegasGlobal(
    bool isDark,
    Color cardBg,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: cardBg,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),

                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),

                        borderRadius: BorderRadius.circular(10),
                      ),

                      child: const Icon(
                        LucideIcons.building2,
                        size: 18,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            'Directorio de Bodegas',

                            style: GoogleFonts.outfit(
                              fontSize: 15,

                              fontWeight: FontWeight.w800,

                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),

                          Text(
                            'Consola Global Multi-Inquilino',

                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,

                              fontWeight: FontWeight.w600,

                              color: isDark
                                  ? AppTheme.textDarkSecondary
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),

                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),

                  borderRadius: BorderRadius.circular(8),
                ),

                child: Text(
                  '${_bodegasRegistradas.length} registradas',

                  style: GoogleFonts.outfit(
                    fontSize: 11,

                    fontWeight: FontWeight.w800,

                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (_bodegasRegistradas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),

              child: Text(
                'No hay bodegas adicionales registradas en el sistema.',

                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF334155),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,

              physics: const NeverScrollableScrollPhysics(),

              itemCount: _bodegasRegistradas.length,

              separatorBuilder: (context, index) => const SizedBox(height: 10),

              itemBuilder: (context, index) {
                final b = _bodegasRegistradas[index];

                final isPro = b.plan.toUpperCase() == 'PRO';

                return Container(
                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark : Colors.white,

                    borderRadius: BorderRadius.circular(14),

                    border: Border.all(color: borderColor),
                  ),

                  child: Row(
                    children: [
                      Container(
                        width: 40,

                        height: 40,

                        decoration: BoxDecoration(
                          color:
                              (isPro
                                      ? AppTheme.accentGreen
                                      : AppTheme.brandPrimary)
                                  .withValues(alpha: 0.12),

                          borderRadius: BorderRadius.circular(10),
                        ),

                        child: Center(
                          child: Icon(
                            isPro ? LucideIcons.sparkles : LucideIcons.store,

                            size: 20,

                            color: isPro
                                ? AppTheme.accentGreen
                                : AppTheme.brandPrimary,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  b.nombreComercial,

                                  style: GoogleFonts.outfit(
                                    fontSize: 14,

                                    fontWeight: FontWeight.w700,

                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textDark,
                                  ),
                                ),

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),

                                  decoration: BoxDecoration(
                                    color:
                                        (isPro
                                                ? AppTheme.accentGreen
                                                : AppTheme.brandPrimary)
                                            .withValues(alpha: 0.15),

                                    borderRadius: BorderRadius.circular(6),
                                  ),

                                  child: Text(
                                    isPro ? 'PRO (S/ 100)' : 'BÁSICO (S/ 50)',

                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,

                                      fontWeight: FontWeight.w800,

                                      color: isPro
                                          ? AppTheme.accentGreen
                                          : AppTheme.brandPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 2),

                            Text(
                              'Tenant #${b.idBodega} ${b.rucDni != null && b.rucDni!.isNotEmpty ? "• RUC: ${b.rucDni}" : ""} • ${b.direccion ?? "Sin dirección registrada"}',

                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,

                                color: AppTheme.getAdaptiveMutedText(isDark),
                              ),

                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 6),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),

                        decoration: BoxDecoration(
                          color: b.estado
                              ? AppTheme.accentGreen.withValues(alpha: 0.15)
                              : Colors.red.withValues(alpha: 0.15),

                          borderRadius: BorderRadius.circular(6),
                        ),

                        child: Row(
                          mainAxisSize: MainAxisSize.min,

                          children: [
                            Container(
                              width: 6,

                              height: 6,

                              decoration: BoxDecoration(
                                shape: BoxShape.circle,

                                color: b.estado
                                    ? AppTheme.accentGreen
                                    : Colors.red,
                              ),
                            ),

                            const SizedBox(width: 4),

                            Text(
                              b.estado ? 'Activa' : 'Inactiva',

                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,

                                fontWeight: FontWeight.w700,

                                color: b.estado
                                    ? AppTheme.accentGreen
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
