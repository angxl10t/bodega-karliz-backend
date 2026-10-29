import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'usuarios_service.dart';
import 'bodega_service.dart';
import 'configuracion_marca_modal.dart';
import '../auth/auth_service.dart';
import '../../core/theme.dart';

class PlanYPersonalSheet extends StatefulWidget {
  final String nombreBodega;
  final String plan;
  final String currentUsername;
  final String? userRol;
  final VoidCallback? onPlanUpdated;

  const PlanYPersonalSheet({
    super.key,
    required this.nombreBodega,
    required this.plan,
    required this.currentUsername,
    this.userRol,
    this.onPlanUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required String nombreBodega,
    required String plan,
    required String currentUsername,
    String? userRol,
    VoidCallback? onPlanUpdated,
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
      final listFuture = _usuariosService.listarUsuarios().catchError((_) => <UsuarioItem>[]);
      final bodegaFuture = _bodegaService.obtenerMiBodega().catchError((_) => null);
      final bodegasFuture = _userRol == 'SUPERADMIN'
          ? _bodegaService.listarTodas().catchError((_) => <BodegaInfo>[])
          : Future.value(<BodegaInfo>[]);
      final results = await Future.wait([listFuture, bodegaFuture, bodegasFuture]);
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
      final pinGenerado = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
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
              : _usuarios.where((x) => x.username.equalsIgnoreCase(currentInput)).firstOrNull;

          return AlertDialog(
            backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.userPlus, color: AppTheme.brandPrimary, size: 20),
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
                          color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
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
                        border: Border.all(color: AppTheme.alertRed.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.alertCircle, size: 14, color: AppTheme.alertRed),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  modalError,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.alertRed, fontWeight: FontWeight.w600),
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
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.brandPrimary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.brandPrimary.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.sparkles, size: 13, color: AppTheme.brandPrimary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Usar sugerencia: "$sugerenciaDetectada"',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
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
                    style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: userCtrl,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._-]')),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                            matchingLocalUser.estado ? LucideIcons.alertTriangle : LucideIcons.info,
                            size: 13,
                            color: matchingLocalUser.estado ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
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
                                color: matchingLocalUser.estado ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
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
                        style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      InkWell(
                        onTap: () => generarClaveAleatoria(setModalState),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.dices, size: 13, color: AppTheme.brandPrimary),
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
                        icon: Icon(obscurePass ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
                        onPressed: () => setModalState(() => obscurePass = !obscurePass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Campo: Confirmar Contraseña
                  Text(
                    'Confirmar PIN o Contraseña *',
                    style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700),
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
                        icon: Icon(obscureConfirm ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
                        onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Selector de Rol
                  Text(
                    'Rol y Nivel de Acceso',
                    style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700),
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
                      if (val != null) setModalState(() => rolSeleccionado = val);
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
                onPressed: isSubmitting || (matchingLocalUser != null && matchingLocalUser.estado)
                    ? null
                    : () async {
                        final u = userCtrl.text.trim().toLowerCase();
                        final p = passCtrl.text.trim();
                        final cp = confirmPassCtrl.text.trim();

                        if (u.length < 3) {
                          setModalState(() => modalError = 'El usuario debe tener al menos 3 caracteres.');
                          return;
                        }
                        if (p.length < 4) {
                          setModalState(() => modalError = 'El PIN o contraseña debe tener al menos 4 dígitos o caracteres.');
                          return;
                        }
                        if (p != cp) {
                          setModalState(() => modalError = 'Las contraseñas no coinciden. Verifícalas.');
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
                          final rawMsg = e.toString().replaceAll('Exception: ', '');
                          // Extraer sugerencia si el backend proporcionó una
                          String encontrada = '';
                          final match = RegExp(r"'([^']+)'").allMatches(rawMsg);
                          if (rawMsg.contains('sugerimos') && match.isNotEmpty) {
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                const Text('Nuevo PIN o Contraseña (mínimo 4 dígitos):'),
                const SizedBox(height: 6),
                TextField(
                  controller: passCtrl,
                  obscureText: obscurePass,
                  decoration: InputDecoration(
                    hintText: 'PIN de 4 dígitos o contraseña',
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
                  if (p.length < 4) {
                    setModalState(() => modalError = 'Mínimo 4 dígitos.');
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
    ).then((_) => passCtrl.dispose());
  }

  String _formatearFecha(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final meses = [
        'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Set', 'Oct', 'Nov', 'Dic'
      ];
      return '${dt.day} de ${meses[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  Widget _buildFinderPattern(Color color) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 3.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildQrSimulado(Color brandColor) {
    return Container(
      width: 150,
      height: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: brandColor.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: brandColor.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned(top: 0, left: 0, child: _buildFinderPattern(brandColor)),
          Positioned(top: 0, right: 0, child: _buildFinderPattern(brandColor)),
          Positioned(bottom: 0, left: 0, child: _buildFinderPattern(brandColor)),
          Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: brandColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: brandColor.withValues(alpha: 0.35),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(LucideIcons.qrCode, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _abrirModalPagoYape(BuildContext context) {
    final codOperacionCtrl = TextEditingController();
    String planSeleccionado = (_currentPlan.toUpperCase() == 'PRO') ? 'PRO' : 'BASICO';
    String billetera = 'YAPE';
    bool isSubmitting = false;
    String modalError = '';

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
          final double monto = planSeleccionado == 'PRO' ? 100.0 : 50.0;
          final Color walletPrimary = billetera == 'YAPE'
              ? const Color(0xFF732283)
              : const Color(0xFF0084FF);

          return Dialog(
            backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
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
                            color: walletPrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(LucideIcons.qrCode, color: walletPrimary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pago Directo Yape / Plin',
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : AppTheme.textDark,
                                ),
                              ),
                              Text(
                                '0% Comisiones • Renovación Inmediata',
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
                          onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'SELECCIONA EL PLAN A SUSCRIBIR:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => planSeleccionado = 'BASICO'),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                              decoration: BoxDecoration(
                                color: planSeleccionado == 'BASICO'
                                    ? AppTheme.brandPrimary.withValues(alpha: 0.12)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: planSeleccionado == 'BASICO'
                                      ? AppTheme.brandPrimary
                                      : Colors.transparent,
                                  width: 1.8,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Plan Bodega',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'S/ 50.00 /mes',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.brandPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '1 Admin + 2 Cajeros',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => planSeleccionado = 'PRO'),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                              decoration: BoxDecoration(
                                color: planSeleccionado == 'PRO'
                                    ? AppTheme.accentGreen.withValues(alpha: 0.12)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: planSeleccionado == 'PRO'
                                      ? AppTheme.accentGreen
                                      : Colors.transparent,
                                  width: 1.8,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Plan PRO',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : AppTheme.textDark,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(LucideIcons.sparkles, size: 12, color: AppTheme.accentGreen),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'S/ 100.00 /mes',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.accentGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Cajeros Ilimitados',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => billetera = 'YAPE'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: billetera == 'YAPE'
                                      ? const Color(0xFF732283)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'YAPE',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: billetera == 'YAPE'
                                          ? Colors.white
                                          : (isDark ? Colors.white60 : AppTheme.textDark),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => billetera = 'PLIN'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: billetera == 'PLIN'
                                      ? const Color(0xFF0084FF)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'PLIN',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: billetera == 'PLIN'
                                          ? Colors.white
                                          : (isDark ? Colors.white60 : AppTheme.textDark),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: walletPrimary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: walletPrimary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          _buildQrSimulado(walletPrimary),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Número: ',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              Text(
                                '987 654 321',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: walletPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(const ClipboardData(text: '987654321'));
                                  HapticFeedback.lightImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Número 987 654 321 copiado al portapapeles.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(LucideIcons.copy, size: 16, color: walletPrimary),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Titular: CajaYa Cloud POS S.A.C.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: walletPrimary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Monto exacto: S/ ${monto.toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: walletPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (modalError.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.alertRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          modalError,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.alertRed, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],

                    TextFormField(
                      controller: codOperacionCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Código de Operación ($billetera)',
                        hintText: 'Ej: 849201 (6 a 8 dígitos)',
                        prefixIcon: const Icon(LucideIcons.receiptText, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        helperText: 'Consúltalo en la constancia de tu app $billetera',
                      ),
                    ),
                    const SizedBox(height: 18),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: walletPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final cod = codOperacionCtrl.text.trim();
                              if (cod.length < 4) {
                                setModalState(() => modalError = 'Ingresa un código de operación válido (mín. 4 dígitos).');
                                return;
                              }

                              final messenger = ScaffoldMessenger.of(context);
                              setModalState(() {
                                isSubmitting = true;
                                modalError = '';
                              });

                              try {
                                final info = await _bodegaService.registrarPagoYape(
                                  codigoOperacion: cod,
                                  plan: planSeleccionado,
                                  monto: monto,
                                  billetera: billetera,
                                );

                                if (dialogCtx.mounted) Navigator.pop(dialogCtx);

                                if (mounted) {
                                  setState(() {
                                    _bodegaInfo = info;
                                    _currentPlan = info.plan;
                                  });
                                  widget.onPlanUpdated?.call();

                                  messenger.showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppTheme.accentGreen,
                                      content: Text(
                                        '¡Suscripción actualizada exitosamente con $billetera! Tu plan $planSeleccionado está activo por 30 días adicionales.',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() {
                                  isSubmitting = false;
                                  modalError = e.toString().replaceAll('Exception: ', '');
                                });
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              'CONFIRMAR Y ACTIVAR SUSCRIPCIÓN',
                              style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w800),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).then((_) => codOperacionCtrl.dispose());
  }

  void _abrirHistorialPagosModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;

        return Dialog(
          backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                        child: const Icon(LucideIcons.receiptText, color: AppTheme.brandPrimary, size: 22),
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
                                color: isDark ? Colors.white : AppTheme.textDark,
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
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: AppTheme.brandPrimary),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error al cargar el historial de pagos.',
                              style: GoogleFonts.plusJakartaSans(color: AppTheme.alertRed),
                            ),
                          );
                        }
                        final pagos = snapshot.data ?? [];
                        if (pagos.isEmpty) {
                          return Center(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.receipt, size: 36, color: AppTheme.textMuted.withValues(alpha: 0.6)),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Sin vouchers registrados aún',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Cuando renueves tu plan mediante Yape o Plin, los comprobantes validados aparecerán aquí para auditoría contable.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: pagos.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final p = pagos[index];
                            final bool isYape = p.billetera.toUpperCase() == 'YAPE';
                            final Color walletColor = isYape ? const Color(0xFF732283) : const Color(0xFF0084FF);

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: walletColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: walletColor.withValues(alpha: 0.3)),
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Plan ${p.plan}',
                                              style: GoogleFonts.outfit(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                                color: isDark ? Colors.white : AppTheme.textDark,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: AppTheme.accentGreen.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(LucideIcons.checkCheck, size: 10, color: AppTheme.accentGreen),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    p.estado,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppTheme.accentGreen,
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
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                          ),
                                        ),
                                        Text(
                                          p.fechaPago != null
                                              ? '${_formatearFecha(p.fechaPago!)} • Reg: ${p.usuarioRegistro ?? "Admin"}'
                                              : 'Reg: ${p.usuarioRegistro ?? "Admin"}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10.5,
                                            color: AppTheme.textMuted,
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

  void _abrirModalConfiguracionSunat({bool? activarDirecto}) {
    if (_userRol == 'CAJERO') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acceso denegado: Solo el Administrador de la bodega puede configurar los Comprobantes de Venta.'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    bool activa = activarDirecto ?? (_bodegaInfo?.facturacionSunatActiva ?? false);
    String regimen = _bodegaInfo?.regimenTributario ?? 'NUEVO_RUS';
    String proveedor = _bodegaInfo?.sunatProveedor ?? 'API Facturador SUNAT Gratuito';
    final rucCtrl = TextEditingController(text: _bodegaInfo?.sunatRucEmisor ?? _bodegaInfo?.rucDni ?? '');
    final serieBoletaCtrl = TextEditingController(text: _bodegaInfo?.serieBoleta ?? 'B001');
    bool isSaving = false;
    String modalError = '';

    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;

          return Dialog(
            backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
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
                          child: const Icon(LucideIcons.landmark, color: AppTheme.brandPrimary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Comprobantes de Venta',
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : AppTheme.textDark,
                                ),
                              ),
                              Text(
                                'Régimen Nuevo RUS • Boletas B001 y Tickets',
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
                          onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: activa
                            ? AppTheme.accentGreen.withValues(alpha: 0.1)
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: activa ? AppTheme.accentGreen : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activa ? 'Emisión oficial de Boletas ACTIVADA' : 'Emisión en modo interno (Tickets)',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: activa
                                        ? AppTheme.accentGreen
                                        : (isDark ? Colors.white : AppTheme.textDark),
                                  ),
                                ),
                                Text(
                                  activa
                                      ? 'Las ventas generarán Boletas de Venta B001 para consumidores finales bajo el Régimen Nuevo RUS.'
                                      : 'Las ventas generarán únicamente Tickets de mostrador para control interno.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: activa,
                            activeThumbColor: AppTheme.accentGreen,
                            onChanged: (val) => setModalState(() => activa = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'PROVEEDOR DE FACTURACIÓN ELECTRÓNICA:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => setModalState(() => proveedor = 'API Facturador SUNAT Gratuito'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: proveedor == 'API Facturador SUNAT Gratuito'
                              ? AppTheme.brandPrimary.withValues(alpha: 0.1)
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: proveedor == 'API Facturador SUNAT Gratuito'
                                ? AppTheme.brandPrimary
                                : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              proveedor == 'API Facturador SUNAT Gratuito'
                                  ? LucideIcons.checkCircle2
                                  : LucideIcons.circle,
                              size: 16,
                              color: AppTheme.brandPrimary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'API Facturador SUNAT Gratuito',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : AppTheme.textDark,
                                    ),
                                  ),
                                  Text(
                                    '0% comisión por comprobante • Homologación directa',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'GRATIS',
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.accentGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (modalError.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.alertRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          modalError,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.alertRed, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],

                    TextFormField(
                      controller: rucCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      decoration: InputDecoration(
                        labelText: 'RUC del Emisor (11 dígitos)',
                        hintText: 'Ej: 20601234567 o 10456789012',
                        prefixIcon: const Icon(LucideIcons.building2, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tarjeta informativa Régimen Nuevo RUS
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.fileSpreadsheet, size: 20, color: AppTheme.brandPrimary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Régimen Tributario: Nuevo RUS',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Diseñado para bodegas y minimarkets: emisión exclusiva de Boletas de Venta a consumidor final y Tickets de mostrador. (Las Facturas comerciales no aplican en este régimen).',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10.5,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: serieBoletaCtrl,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [LengthLimitingTextInputFormatter(4)],
                      decoration: InputDecoration(
                        labelText: 'Serie Boleta de Venta',
                        hintText: 'B001',
                        helperText: 'Debe iniciar con B y tener 4 caracteres (ej: B001)',
                        prefixIcon: const Icon(LucideIcons.fileText, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.brandPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.brandPrimary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.shieldCheck, size: 18, color: AppTheme.brandPrimary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Solo tú como Administrador puedes activar o desactivar este módulo. Tus cajeros no tendrán acceso para modificar la configuración de comprobantes.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.brandLight : AppTheme.brandDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final ruc = rucCtrl.text.trim();
                              if (activa && (ruc.length != 11)) {
                                setModalState(() => modalError = 'Para activar SUNAT ingresa un RUC válido de 11 dígitos.');
                                return;
                              }

                              final sBoleta = serieBoletaCtrl.text.trim().toUpperCase();
                              if (sBoleta.isNotEmpty && !RegExp(r'^B[A-Z0-9]{3}$').hasMatch(sBoleta)) {
                                setModalState(() => modalError = 'La serie de boleta debe tener 4 caracteres e iniciar con B (ej: B001).');
                                return;
                              }

                              final messenger = ScaffoldMessenger.of(context);
                              setModalState(() {
                                isSaving = true;
                                modalError = '';
                              });

                              try {
                                final info = await _bodegaService.actualizarConfiguracionSunat(
                                  activa: activa,
                                  regimenTributario: regimen,
                                  proveedor: proveedor,
                                  rucEmisor: ruc,
                                  serieBoleta: sBoleta.isEmpty ? 'B001' : sBoleta,
                                  serieFactura: 'F001',
                                );

                                if (dialogCtx.mounted) Navigator.pop(dialogCtx);

                                if (mounted) {
                                  setState(() {
                                    _bodegaInfo = info;
                                  });
                                  widget.onPlanUpdated?.call();

                                  messenger.showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppTheme.accentGreen,
                                      content: Text(
                                        activa
                                            ? 'Emisión de Boletas B001 configurada exitosamente.'
                                            : 'Modo interno activado. Las ventas se emitirán como tickets de mostrador.',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() {
                                  isSaving = false;
                                  modalError = e.toString().replaceAll('Exception: ', '');
                                });
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              'GUARDAR CONFIGURACIÓN',
                              style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w800),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).then((_) {
      rucCtrl.dispose();
      serieBoletaCtrl.dispose();
    });
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
        border: isDark ? const Border(top: BorderSide(color: AppTheme.borderDarkElevated, width: 1.2)) : null,
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
                color: isDark ? AppTheme.borderDarkElevated : const Color(0xFFCBD5E1),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userRol == 'SUPERADMIN' ? 'Consola Global & Bodegas' : 'Suscripción & Personal',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : AppTheme.textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _userRol == 'SUPERADMIN'
                                    ? 'CajaYa Platform • ${_bodegasRegistradas.length} Bodegas Registradas'
                                    : widget.nombreBodega,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textMuted,
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
                    icon: Icon(LucideIcons.x, size: 20, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B)),
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
                    // Directorio de Bodegas para Superadmin
                    if (_userRol == 'SUPERADMIN' || _bodegasRegistradas.isNotEmpty) ...[
                      _buildDirectorioBodegasGlobal(isDark, cardBg, borderColor),
                      const SizedBox(height: 16),
                    ],

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
                                ? '• Cajeros y administradores ilimitados con PIN.\n• Control de turnos y sincronización en tiempo real.\n• Almacén y Kardex protegidos contra fraudes.\n• Personalización de colores y logo en tickets.\n• Emisión oficial de Boletas de Venta B001 disponible.'
                                : '• 1 Administrador + hasta 2 Cajeros activos con PIN.\n• Punto de Venta rápido, Control de Stock y Caja diaria.\n• Emisión de tickets digitales y reportes de ventas.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.4,
                            ),
                          ),
                          if (_bodegaInfo?.fechaVencimientoPlan != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(LucideIcons.calendarCheck, size: 13, color: Colors.white.withValues(alpha: 0.85)),
                                const SizedBox(width: 5),
                                Text(
                                  'Vigente hasta el ${_formatearFecha(_bodegaInfo!.fechaVencimientoPlan!)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.95),
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
                                foregroundColor: isPro ? const Color(0xFF0F766E) : const Color(0xFF1E293B),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                              ),
                              onPressed: () => _abrirModalPagoYape(context),
                              icon: const Icon(LucideIcons.qrCode, size: 18),
                              label: Text(
                                isPro
                                    ? 'Renovar Plan Pro con Yape / Plin (S/ 100)'
                                    : 'Pagar / Mejorar con Yape / Plin (S/ 50 o S/ 100)',
                                style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
                              ),
                              onPressed: () => _abrirHistorialPagosModal(context),
                              icon: const Icon(LucideIcons.receipt, size: 16),
                              label: Text(
                                'Ver Historial de Vouchers y Renovaciones',
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
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
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(LucideIcons.chevronRight, size: 18, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // MÓDULO FACTURACIÓN ELECTRÓNICA SUNAT (Solución 2)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.cardDarkElevated : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: (_bodegaInfo?.facturacionSunatActiva == true)
                              ? AppTheme.accentGreen.withValues(alpha: 0.5)
                              : borderColor,
                          width: (_bodegaInfo?.facturacionSunatActiva == true) ? 1.5 : 1.0,
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
                                  color: (_bodegaInfo?.facturacionSunatActiva == true
                                          ? AppTheme.accentGreen
                                          : const Color(0xFF64748B))
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  LucideIcons.landmark,
                                  color: _bodegaInfo?.facturacionSunatActiva == true
                                      ? AppTheme.accentGreen
                                      : const Color(0xFF64748B),
                                  size: 22,
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
                                          'Facturación SUNAT',
                                          style: GoogleFonts.outfit(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : AppTheme.textDark,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentGreen.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'NUEVO RUS',
                                            style: GoogleFonts.outfit(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.accentGreen,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      _bodegaInfo?.facturacionSunatActiva == true
                                          ? 'Emisión oficial activa • Boletas B001 y Tickets'
                                          : 'Emisión en modo interno (Tickets de mostrador)',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: _bodegaInfo?.facturacionSunatActiva == true
                                            ? AppTheme.accentGreen
                                            : AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_userRol == 'CAJERO') ...[
                                Tooltip(
                                  message: 'Solo el Administrador puede activar o desactivar la emisión de Boletas',
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(LucideIcons.lock, size: 13, color: Color(0xFFD97706)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'BLOQUEADO',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFFD97706),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Switch(
                                  value: _bodegaInfo?.facturacionSunatActiva ?? false,
                                  activeThumbColor: AppTheme.accentGreen,
                                  onChanged: (val) {
                                    _abrirModalConfiguracionSunat(activarDirecto: val);
                                  },
                                ),
                              ],
                            ],
                          ),
                          if (_userRol == 'CAJERO') ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.shieldAlert, size: 16, color: Color(0xFFD97706)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Protegido por el Administrador: Los cajeros no pueden alterar la configuración de comprobantes.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Proveedor: ',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _abrirModalConfiguracionSunat(),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(LucideIcons.slidersHorizontal, size: 12, color: AppTheme.brandPrimary),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Configurar Boletas',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5,
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
                          ],
                        ],
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
                              'El Plan Bodega (S/ 50 /mes) incluye 1 Admin + hasta 2 Cajeros activos. Para turnos y cajeros ilimitados con PIN, Kardex antifraude y colores de marca propia, pasa a Plan Minimarket Pro (S/ 100 /mes).',
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
                        Expanded(
                          child: Text(
                            'Personal Registrado ()',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _abrirCrearUsuarioModal,
                          icon: const Icon(LucideIcons.userPlus, size: 16),
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
    ),
  ),
);
  }

  Widget _buildDirectorioBodegasGlobal(bool isDark, Color cardBg, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.building2, size: 18, color: Color(0xFF8B5CF6)),
                  ),
                  const SizedBox(width: 10),
                  Column(
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
                          color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
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
                          color: (isPro ? AppTheme.accentGreen : AppTheme.brandPrimary).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(
                            isPro ? LucideIcons.sparkles : LucideIcons.store,
                            size: 20,
                            color: isPro ? AppTheme.accentGreen : AppTheme.brandPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    b.nombreComercial,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : AppTheme.textDark,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: (isPro ? AppTheme.accentGreen : AppTheme.brandPrimary).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isPro ? 'PRO (S/ 100)' : 'BÁSICO (S/ 50)',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: isPro ? AppTheme.accentGreen : AppTheme.brandPrimary,
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
                                color: AppTheme.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: b.estado ? AppTheme.accentGreen.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
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
                                color: b.estado ? AppTheme.accentGreen : Colors.red,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              b.estado ? 'Activa' : 'Inactiva',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: b.estado ? AppTheme.accentGreen : Colors.red,
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
