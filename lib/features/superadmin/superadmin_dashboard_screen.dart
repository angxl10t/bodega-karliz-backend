import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/theme_provider.dart';
import '../../core/api_constants.dart';
import '../../core/secure_storage_service.dart';
import '../auth/auth_service.dart';
import '../home/bodega_service.dart';
import '../home/usuarios_service.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BodegaService _bodegaService = BodegaService();
  final UsuariosService _usuariosService = UsuariosService();
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  String _errorMessage = '';

  // Datos del Sistema
  Map<String, dynamic> _metricasSistema = {};
  Map<String, dynamic> _healthInfo = {};
  Map<String, dynamic> _anuncioGlobal = {};
  List<BodegaInfo> _bodegas = [];
  List<UsuarioItem> _usuarios = [];
  List<PagoSuscripcionItem> _pagos = [];

  // Filtros de búsqueda
  final TextEditingController _searchBodegaCtrl = TextEditingController();
  String _filtroPlanBodega = 'TODOS';
  String _filtroEstadoBodega = 'TODOS';

  final TextEditingController _searchUsuarioCtrl = TextEditingController();
  String _filtroRolUsuario = 'TODOS';

  final TextEditingController _searchPagoCtrl = TextEditingController();
  String _filtroBilleteraPago = 'TODOS';

  int _latencyMs = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarTodo();
    // Refresco periódico ligero cada 60s
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) => _cargarMetricasYHealth());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    _searchBodegaCtrl.dispose();
    _searchUsuarioCtrl.dispose();
    _searchPagoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final stopwatch = Stopwatch()..start();

    try {
      final metricasFuture = _bodegaService.obtenerMetricasSistema();
      final healthFuture = _bodegaService.obtenerHealthServidor();
      final bodegasFuture = _bodegaService.listarTodas();
      final usuariosFuture = _usuariosService.listarUsuarios();
      final pagosFuture = _bodegaService.listarTodosLosPagos();
      final anuncioFuture = _bodegaService.obtenerAnuncioGlobal();

      final results = await Future.wait([
        metricasFuture,
        healthFuture,
        bodegasFuture,
        usuariosFuture,
        pagosFuture,
        anuncioFuture,
      ]);

      stopwatch.stop();

      if (mounted) {
        setState(() {
          _metricasSistema = results[0] as Map<String, dynamic>;
          _healthInfo = results[1] as Map<String, dynamic>;
          _bodegas = results[2] as List<BodegaInfo>;
          _usuarios = results[3] as List<UsuarioItem>;
          _pagos = results[4] as List<PagoSuscripcionItem>;
          _anuncioGlobal = results[5] as Map<String, dynamic>;
          _latencyMs = stopwatch.elapsedMilliseconds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _cargarMetricasYHealth() async {
    try {
      final stopwatch = Stopwatch()..start();
      final m = await _bodegaService.obtenerMetricasSistema();
      final h = await _bodegaService.obtenerHealthServidor();
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _metricasSistema = m;
          _healthInfo = h;
          _latencyMs = stopwatch.elapsedMilliseconds;
        });
      }
    } catch (_) {}
  }

  // ===========================================================================
  // ACCIONES DE GESTIÓN DE BODEGAS & PLATAFORMA
  // ===========================================================================

  Future<void> _abrirModalProvisionarBodega(BuildContext context, bool isDark) async {
    final nombreCtrl = TextEditingController();
    final rucCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final dirCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: '123456');
    final messenger = ScaffoldMessenger.of(context);

    String plan = 'PRO';
    int dias = 30;
    String regimen = 'NUEVO_RUS';
    bool isSaving = false;
    String error = '';

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (_, setModalState) {
          return AlertDialog(
            backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.store, color: Color(0xFF7C3AED), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Provisionar Nueva Bodega',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                      Text(
                        'Alta inmediata de tienda y usuario administrador',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.min(MediaQuery.of(context).size.width - 40, 520),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (error.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.alertRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.alertCircle, color: AppTheme.alertRed, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(error, style: const TextStyle(color: AppTheme.alertRed, fontSize: 12))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text('INFORMACIÓN DE LA TIENDA', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nombreCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nombre Comercial *',
                        hintText: 'Ej. Minimarket San Jorge',
                        prefixIcon: const Icon(LucideIcons.store, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onChanged: (val) {
                        if (userCtrl.text.isEmpty || userCtrl.text.startsWith('admin_')) {
                          final clean = val.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                          final truncated = clean.length > 12 ? clean.substring(0, 12) : clean;
                          userCtrl.text = 'admin_$truncated';
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: rucCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'RUC o DNI',
                              hintText: '10458920112',
                              prefixIcon: const Icon(LucideIcons.fileText, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: telCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Teléfono / WhatsApp',
                              hintText: '987654321',
                              prefixIcon: const Icon(LucideIcons.phone, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dirCtrl,
                      decoration: InputDecoration(
                        labelText: 'Dirección Comercial',
                        hintText: 'Av. Los Próceres 123, Lima',
                        prefixIcon: const Icon(LucideIcons.mapPin, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('SUSCRIPCIÓN & VIGENCIA', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Plan Básico')),
                            selected: plan == 'BASICO',
                            onSelected: (val) {
                              if (val) setModalState(() => plan = 'BASICO');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Plan PRO ⭐')),
                            selected: plan == 'PRO',
                            onSelected: (val) {
                              if (val) setModalState(() => plan = 'PRO');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [14, 30, 60, 90, 180, 365].map((d) {
                        return FilterChip(
                          label: Text('$d días ${d == 14 ? '(Prueba)' : ''}'),
                          selected: dias == d,
                          onSelected: (_) => setModalState(() => dias = d),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Text('CREDENCIALES DE ACCESO DEL DUEÑO', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: userCtrl,
                            decoration: InputDecoration(
                              labelText: 'Usuario Admin *',
                              hintText: 'admin_tienda',
                              prefixIcon: const Icon(LucideIcons.user, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: passCtrl,
                            decoration: InputDecoration(
                              labelText: 'Contraseña *',
                              hintText: '123456',
                              prefixIcon: const Icon(LucideIcons.lock, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dlgCtx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final n = nombreCtrl.text.trim();
                        final u = userCtrl.text.trim();
                        final p = passCtrl.text.trim();
                        if (n.isEmpty) {
                          setModalState(() => error = 'Ingresa el nombre comercial.');
                          return;
                        }
                        if (u.isEmpty || p.isEmpty) {
                          setModalState(() => error = 'Usuario y clave son obligatorios.');
                          return;
                        }
                        setModalState(() => isSaving = true);
                        try {
                          final nueva = await _bodegaService.provisionarBodega({
                            'nombreComercial': n,
                            'rucDni': rucCtrl.text.trim(),
                            'direccion': dirCtrl.text.trim(),
                            'telefono': telCtrl.text.trim(),
                            'plan': plan,
                            'diasVigencia': dias,
                            'adminUsername': u,
                            'adminPassword': p,
                            'regimenTributario': regimen,
                          });
                          if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                          if (mounted) {
                            setState(() {
                              _bodegas.insert(0, nueva);
                            });
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('¡Bodega "${nueva.nombreComercial}" provisionada exitosamente!'),
                                backgroundColor: AppTheme.accentGreen,
                              ),
                            );
                            _cargarTodo();
                          }
                        } catch (e) {
                          setModalState(() {
                            isSaving = false;
                            error = e.toString().replaceAll('Exception: ', '');
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Crear Bodega & Admin'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _enviarRecordatorioWhatsApp(BodegaInfo b, int? diasRestantes, bool vencido) async {
    final tel = b.telefono?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (tel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta bodega no tiene teléfono registrado')),
      );
      return;
    }
    final num = tel.length == 9 ? '51$tel' : tel;
    final estadoMsg = vencido
        ? 'tu suscripción CajaYa POS se encuentra vencida'
        : 'tu suscripción CajaYa POS (Plan ${b.plan}) vence en ${diasRestantes ?? 0} días';
    final texto = Uri.encodeComponent(
      'Hola estimado/a ${b.nombreComercial}, te saludamos del equipo de soporte de CajaYa POS. '
      'Te informamos que $estadoMsg. '
      'Puedes renovar fácilmente vía Yape o Plin al número 987654321 para continuar disfrutando de tu sistema sin interrupciones. ¡Muchas gracias por tu preferencia!',
    );
    final uri = Uri.parse('https://wa.me/$num?text=$texto');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _cambiarEstadoPago(PagoSuscripcionItem p, String nuevoEstado) async {
    try {
      final actualizado = await _bodegaService.cambiarEstadoPago(p.idPago, nuevoEstado);
      setState(() {
        final idx = _pagos.indexWhere((x) => x.idPago == p.idPago);
        if (idx != -1) _pagos[idx] = actualizado;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pago #${p.codigoOperacion} marcado como $nuevoEstado'),
            backgroundColor: nuevoEstado == 'CONFIRMADO' ? AppTheme.accentGreen : AppTheme.alertRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.alertRed),
        );
      }
    }
  }

  Future<void> _abrirModalPublicarAnuncio() async {
    final msgCtrl = TextEditingController(text: _anuncioGlobal['mensaje']?.toString() ?? '');
    String tipo = _anuncioGlobal['tipo']?.toString() ?? 'INFO';
    final messenger = ScaffoldMessenger.of(context);
    bool isSaving = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (_, setModalState) {
          return AlertDialog(
            backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(LucideIcons.megaphone, color: Color(0xFF7C3AED), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Comunicado Global',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Este aviso aparecerá en la parte superior de las pantallas de todas las bodegas y cajas activas.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                ),
                const SizedBox(height: 12),
                Text('TIPO DE AVISO:', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('ℹ️ Informativo'),
                      selected: tipo == 'INFO',
                      onSelected: (val) {
                        if (val) setModalState(() => tipo = 'INFO');
                      },
                    ),
                    ChoiceChip(
                      label: const Text('⚠️ Advertencia'),
                      selected: tipo == 'WARNING',
                      onSelected: (val) {
                        if (val) setModalState(() => tipo = 'WARNING');
                      },
                    ),
                    ChoiceChip(
                      label: const Text('🚨 Urgente'),
                      selected: tipo == 'URGENTE',
                      onSelected: (val) {
                        if (val) setModalState(() => tipo = 'URGENTE');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: msgCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Mensaje del comunicado *',
                    hintText: 'Ej: Recordatorio: el domingo a las 2:00 AM se realizará una actualización del sistema.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final msg = msgCtrl.text.trim();
                        if (msg.isEmpty) return;
                        setModalState(() => isSaving = true);
                        try {
                          final res = await _bodegaService.publicarAnuncioGlobal(msg, tipo: tipo);
                          if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                          if (mounted) {
                            setState(() => _anuncioGlobal = res);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Comunicado global publicado a todos los terminales'),
                                backgroundColor: AppTheme.accentGreen,
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() => isSaving = false);
                        }
                      },
                child: const Text('Publicar Aviso'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _eliminarAnuncio() async {
    try {
      await _bodegaService.eliminarAnuncioGlobal();
      setState(() => _anuncioGlobal = {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comunicado global retirado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.alertRed),
        );
      }
    }
  }

  Future<void> _toggleEstadoBodega(BodegaInfo b) async {
    final nuevoEstado = !b.estado;
    final accion = nuevoEstado ? 'Activar' : 'Suspender';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              nuevoEstado ? LucideIcons.checkCircle : LucideIcons.alertTriangle,
              color: nuevoEstado ? AppTheme.accentGreen : AppTheme.alertRed,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$accion Tienda',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          nuevoEstado
              ? '¿Deseas activar la bodega "${b.nombreComercial}"? Sus administradores y cajeros podrán volver a acceder al sistema.'
              : '¿Deseas suspender la bodega "${b.nombreComercial}"? Se revocarán inmediatamente las sesiones de sus cajeros y administradores.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: nuevoEstado ? AppTheme.accentGreen : AppTheme.alertRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(accion),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final actualizada = await _bodegaService.cambiarEstadoBodega(b.idBodega, nuevoEstado);
        if (mounted) {
          setState(() {
            final idx = _bodegas.indexWhere((x) => x.idBodega == b.idBodega);
            if (idx != -1) _bodegas[idx] = actualizada;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tienda "${b.nombreComercial}" ${nuevoEstado ? "activada" : "suspendida"} exitosamente.'),
              backgroundColor: nuevoEstado ? AppTheme.accentGreen : AppTheme.alertRed,
            ),
          );
          _cargarMetricasYHealth();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
              backgroundColor: AppTheme.alertRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _abrirModalCambiarPlan(BodegaInfo b) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messenger = ScaffoldMessenger.of(context);
    String planElegido = b.plan.toUpperCase() == 'PRO' ? 'PRO' : 'BASICO';
    int dias = 30;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (_, setModalState) {
          return AlertDialog(
            backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.sparkles, color: Color(0xFF7C3AED), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gestionar Suscripción',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                      Text(
                        b.nombreComercial,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SELECCIONA EL PLAN:', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Plan Básico')),
                        selected: planElegido == 'BASICO',
                        onSelected: (val) {
                          if (val) setModalState(() => planElegido = 'BASICO');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Plan PRO ⭐')),
                        selected: planElegido == 'PRO',
                        onSelected: (val) {
                          if (val) setModalState(() => planElegido = 'PRO');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('DÍAS DE VIGENCIA ADICIONAL:', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [30, 60, 90, 180, 365].map((d) {
                    final sel = dias == d;
                    return FilterChip(
                      label: Text('$d días'),
                      selected: sel,
                      onSelected: (_) => setModalState(() => dias = d),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dlgCtx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        setModalState(() => isSaving = true);
                        try {
                          final actualizada = await _bodegaService.cambiarPlanBodega(
                            b.idBodega,
                            planElegido,
                            dias: dias,
                          );
                          if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                          if (mounted) {
                            setState(() {
                              final idx = _bodegas.indexWhere((x) => x.idBodega == b.idBodega);
                              if (idx != -1) _bodegas[idx] = actualizada;
                            });
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Plan de "${b.nombreComercial}" actualizado a $planElegido ($dias días).'),
                                backgroundColor: AppTheme.accentGreen,
                              ),
                            );
                            _cargarMetricasYHealth();
                          }
                        } catch (e) {
                          setModalState(() => isSaving = false);
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.alertRed),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Inspeccionar Bodega (Audit / Support Mode)
  Future<void> _inspeccionarBodega(BodegaInfo b) async {
    // Guarda el ID y nombre temporal en almacenamiento para inspección
    await SecureStorageService.write('id_bodega', b.idBodega.toString());
    await SecureStorageService.write('nombre_bodega', b.nombreComercial);
    await SecureStorageService.write('plan_bodega', b.plan);
    await SecureStorageService.write('color_primario', b.colorPrimario);
    if (mounted) {
      context.read<ThemeProvider>().setAccentColorFromHex(b.colorPrimario);
      context.go('/home');
    }
  }

  // ===========================================================================
  // ACCIONES DE GESTIÓN DE USUARIOS
  // ===========================================================================

  Future<void> _abrirResetPasswordUsuario(UsuarioItem u) async {
    final passCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messenger = ScaffoldMessenger.of(context);
    bool isSaving = false;
    String error = '';

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (_, setDlgState) {
          return AlertDialog(
            backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(LucideIcons.keyRound, color: Color(0xFF7C3AED), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Restablecer Clave', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 17)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Usuario: ${u.username}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13)),
                Text('Rol: ${u.rol} • Tienda: ${u.nombreBodega ?? "Sin bodega"}', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 14),
                TextField(
                  controller: passCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña o PIN (mín. 4 caracteres)',
                    hintText: 'Ej. 123456',
                    prefixIcon: const Icon(LucideIcons.lock, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(error, style: const TextStyle(color: AppTheme.alertRed, fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final p = passCtrl.text.trim();
                        if (p.length < 4) {
                          setDlgState(() => error = 'Mínimo 4 caracteres.');
                          return;
                        }
                        setDlgState(() => isSaving = true);
                        try {
                          await _usuariosService.resetPassword(u.idUsuario, p);
                          if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Clave de "${u.username}" restablecida exitosamente.'),
                                backgroundColor: AppTheme.accentGreen,
                              ),
                            );
                          }
                        } catch (e) {
                          setDlgState(() {
                            isSaving = false;
                            error = e.toString().replaceAll('Exception: ', '');
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Actualizar Clave'),
              ),
            ],
          );
        },
      ),
    ).then((_) => passCtrl.dispose());
  }

  Future<void> _toggleEstadoUsuario(UsuarioItem u) async {
    final nuevo = !u.estado;
    try {
      await _usuariosService.cambiarEstado(u.idUsuario, nuevo);
      if (mounted) {
        setState(() {
          final idx = _usuarios.indexWhere((x) => x.idUsuario == u.idUsuario);
          if (idx != -1) {
            _usuarios[idx] = UsuarioItem(
              idUsuario: u.idUsuario,
              username: u.username,
              nombreCompleto: u.nombreCompleto,
              rol: u.rol,
              estado: nuevo,
              idBodega: u.idBodega,
              nombreBodega: u.nombreBodega,
              planBodega: u.planBodega,
            );
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuario "${u.username}" ${nuevo ? "activado" : "deshabilitado"}.'),
            backgroundColor: nuevo ? AppTheme.accentGreen : AppTheme.alertRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.alertRed),
        );
      }
    }
  }

  // ===========================================================================
  // LOGOUT DEL SISTEMA
  // ===========================================================================

  Future<void> _cerrarSesionSuperAdmin() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(LucideIcons.logOut, color: AppTheme.alertRed, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Cerrar Sesión Superadmin', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 17)),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas salir de la Consola Global de Superadmin?',
          style: GoogleFonts.plusJakartaSans(fontSize: 13.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.alertRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _authService.logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  // ===========================================================================
  // CONSTRUCCIÓN VISUAL PRINCIPAL
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (ModalRoute.of(context)?.canPop ?? false) ...[
                  IconButton(
                    icon: const Icon(LucideIcons.arrowLeft, size: 20),
                    tooltip: 'Regresar',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 4),
                ],
                // Logo & Badge de Plataforma
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.shieldCheck, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'CajaYa',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'SUPERADMIN ROOT',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF8B5CF6),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Consola Global de Gestión • Multi-Tenant',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Latencia en vivo (Oculta en pantallas menores a 390px para proteger el encabezado)
                if (MediaQuery.of(context).size.width >= 390) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardDarkHighlight : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.activity, size: 12, color: _latencyMs < 300 ? AppTheme.accentGreen : Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${_latencyMs}ms',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                ],

                // Botón Refrescar
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Actualizar Telemetría',
                  icon: const Icon(LucideIcons.refreshCw, size: 17),
                  onPressed: _cargarTodo,
                ),

                // Conmutador de Tema
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Cambiar Modo Oscuro/Claro',
                  icon: Icon(themeProvider.isDarkMode ? LucideIcons.sun : LucideIcons.moon, size: 17),
                  onPressed: () => themeProvider.toggleTheme(),
                ),

                // Cerrar Sesión
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Cerrar Sesión Superadmin',
                  icon: const Icon(LucideIcons.logOut, color: AppTheme.alertRed, size: 17),
                  onPressed: _cerrarSesionSuperAdmin,
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF7C3AED)),
                  SizedBox(height: 16),
                  Text('Conectando con la Consola Global del Sistema...', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : _errorMessage.isNotEmpty && _bodegas.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.alertTriangle, size: 48, color: AppTheme.alertRed),
                        const SizedBox(height: 16),
                        Text(
                          'Error cargando datos del sistema',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155), fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _cargarTodo,
                          icon: const Icon(LucideIcons.refreshCw, size: 16),
                          label: const Text('Reintentar Conexión'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarTodo,
                  color: const Color(0xFF7C3AED),
                  child: Column(
                    children: [
                      if (_errorMessage.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: AppTheme.alertRed.withValues(alpha: 0.15),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.alertCircle, size: 16, color: AppTheme.alertRed),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Aviso de telemetría: $_errorMessage',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.alertRed, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // KPI Overview Bar
                      _buildExecutiveKpiBar(isDark),

                  // Barra de Navegación por Módulos
                  Container(
                    color: isDark ? AppTheme.cardDark : Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: const Color(0xFF7C3AED),
                      indicatorWeight: 3,
                      labelColor: const Color(0xFF7C3AED),
                      unselectedLabelColor: isDark ? AppTheme.textDarkSecondary : const Color(0xFF475569),
                      labelStyle: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w800),
                      tabs: [
                        Tab(
                          icon: const Icon(LucideIcons.store, size: 18),
                          text: 'Bodegas & Tiendas (${_bodegas.length})',
                        ),
                        Tab(
                          icon: const Icon(LucideIcons.users, size: 18),
                          text: 'Usuarios Globales (${_usuarios.length})',
                        ),
                        Tab(
                          icon: const Icon(LucideIcons.creditCard, size: 18),
                          text: 'Suscripciones & Pagos (${_pagos.length})',
                        ),
                        const Tab(
                          icon: Icon(LucideIcons.server, size: 18),
                          text: 'Infraestructura & Servidor',
                        ),
                      ],
                    ),
                  ),

                  // Contenido de las pestañas
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTabBodegas(isDark),
                        _buildTabUsuarios(isDark),
                        _buildTabPagos(isDark),
                        _buildTabInfraestructura(isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ===========================================================================
  // RESUMEN EJECUTIVO (KPIs)
  // ===========================================================================

  Widget _buildExecutiveKpiBar(bool isDark) {
    final totalBodegas = _metricasSistema['totalBodegas'] ?? _bodegas.length;
    final bodegasActivas = _metricasSistema['bodegasActivas'] ?? _bodegas.where((b) => b.estado).length;
    final bodegasInactivas = _metricasSistema['bodegasInactivas'] ?? (totalBodegas - bodegasActivas);
    final bodegasPro = _metricasSistema['bodegasPro'] ?? _bodegas.where((b) => b.plan.toUpperCase() == 'PRO').length;
    final totalUsuarios = _metricasSistema['totalUsuarios'] ?? _usuarios.length;
    final totalVentas = _metricasSistema['totalVentas'] ?? 0;
    final totalRecaudado = _metricasSistema['totalRecaudado'] != null
        ? double.tryParse(_metricasSistema['totalRecaudado'].toString()) ?? 0.0
        : _pagos.fold<double>(0.0, (acc, p) => acc + p.monto);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
        border: Border(
          bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildKpiCard(
              title: 'TOTAL BODEGAS',
              value: '$totalBodegas',
              subtitle: '$bodegasActivas Activas • $bodegasInactivas Suspendidas',
              icon: LucideIcons.store,
              color: const Color(0xFF7C3AED),
              isDark: isDark,
            ),
            const SizedBox(width: 12),
            _buildKpiCard(
              title: 'PENETRACIÓN PLAN PRO',
              value: '$bodegasPro PRO',
              subtitle: totalBodegas > 0 ? '${((bodegasPro / totalBodegas) * 100).toStringAsFixed(0)}% del total' : '0%',
              icon: LucideIcons.sparkles,
              color: const Color(0xFF2563EB),
              isDark: isDark,
            ),
            const SizedBox(width: 12),
            _buildKpiCard(
              title: 'FACTURACIÓN SUSCRIPCIONES',
              value: 'S/ ${totalRecaudado.toStringAsFixed(2)}',
              subtitle: '${_pagos.length} Pagos Yape / Plin',
              icon: LucideIcons.wallet,
              color: const Color(0xFF10B981),
              isDark: isDark,
            ),
            const SizedBox(width: 12),
            _buildKpiCard(
              title: 'USUARIOS ACTIVOS',
              value: '$totalUsuarios',
              subtitle: '${_usuarios.where((u) => u.rol == "ADMIN").length} Admins • ${_usuarios.where((u) => u.rol == "CAJERO").length} Cajeros',
              icon: LucideIcons.users,
              color: const Color(0xFFF59E0B),
              isDark: isDark,
            ),
            const SizedBox(width: 12),
            _buildKpiCard(
              title: 'TRANSACCIONES PROCESADAS',
              value: '$totalVentas',
              subtitle: 'Kardex & POS Global',
              icon: LucideIcons.shoppingBag,
              color: const Color(0xFF06B6D4),
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PESTAÑA 1: GESTIÓN DE BODEGAS (MULTI-TENANT HUB)
  // ===========================================================================

  Widget _buildTabBodegas(bool isDark) {
    final query = _searchBodegaCtrl.text.trim().toLowerCase();

    final filtradas = _bodegas.where((b) {
      if (query.isNotEmpty) {
        final nom = b.nombreComercial.toLowerCase();
        final ruc = (b.rucDni ?? '').toLowerCase();
        final tel = (b.telefono ?? '').toLowerCase();
        final dir = (b.direccion ?? '').toLowerCase();
        if (!nom.contains(query) && !ruc.contains(query) && !tel.contains(query) && !dir.contains(query)) {
          return false;
        }
      }

      if (_filtroPlanBodega != 'TODOS') {
        if (_filtroPlanBodega == 'PRO' && b.plan.toUpperCase() != 'PRO') return false;
        if (_filtroPlanBodega == 'BASICO' && b.plan.toUpperCase() == 'PRO') return false;
      }

      if (_filtroEstadoBodega != 'TODOS') {
        if (_filtroEstadoBodega == 'ACTIVAS' && !b.estado) return false;
        if (_filtroEstadoBodega == 'INACTIVAS' && b.estado) return false;
        if (_filtroEstadoBodega == 'POR VENCER') {
          if (b.fechaVencimientoPlan == null) return false;
          try {
            final exp = DateTime.parse(b.fechaVencimientoPlan!);
            final diff = exp.difference(DateTime.now()).inDays;
            if (diff < 0 || diff > 7) return false;
          } catch (_) {
            return false;
          }
        }
        if (_filtroEstadoBodega == 'VENCIDAS') {
          if (b.fechaVencimientoPlan == null) return false;
          try {
            final exp = DateTime.parse(b.fechaVencimientoPlan!);
            if (exp.isAfter(DateTime.now())) return false;
          } catch (_) {
            return false;
          }
        }
      }

      return true;
    }).toList();

    return Column(
      children: [
        // Barra de búsqueda y filtros
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    controller: _searchBodegaCtrl,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Buscar bodega por nombre, RUC, dirección...',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                icon: const Icon(LucideIcons.store, size: 16),
                label: Text(
                  '+ Nueva Bodega',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                onPressed: () => _abrirModalProvisionarBodega(context, isDark),
              ),
            ],
          ),
        ),

        // Chips de Filtro
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Planes:', 'TODOS', _filtroPlanBodega, (v) => setState(() => _filtroPlanBodega = v)),
                const SizedBox(width: 4),
                _buildFilterChip('', 'PRO', _filtroPlanBodega, (v) => setState(() => _filtroPlanBodega = v)),
                const SizedBox(width: 4),
                _buildFilterChip('', 'BASICO', _filtroPlanBodega, (v) => setState(() => _filtroPlanBodega = v)),
                const SizedBox(width: 16),
                _buildFilterChip('Estado:', 'TODOS', _filtroEstadoBodega, (v) => setState(() => _filtroEstadoBodega = v)),
                const SizedBox(width: 4),
                _buildFilterChip('', 'ACTIVAS', _filtroEstadoBodega, (v) => setState(() => _filtroEstadoBodega = v)),
                const SizedBox(width: 4),
                _buildFilterChip('', 'INACTIVAS', _filtroEstadoBodega, (v) => setState(() => _filtroEstadoBodega = v)),
                const SizedBox(width: 4),
                _buildFilterChip('', 'POR VENCER', _filtroEstadoBodega, (v) => setState(() => _filtroEstadoBodega = v)),
                const SizedBox(width: 4),
                _buildFilterChip('', 'VENCIDAS', _filtroEstadoBodega, (v) => setState(() => _filtroEstadoBodega = v)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Listado de Bodegas
        Expanded(
          child: filtradas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.store, size: 48, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      Text('No se encontraron bodegas', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtradas.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final b = filtradas[idx];
                    return _buildBodegaCard(b, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBodegaCard(BodegaInfo b, bool isDark) {
    final esPro = b.plan.toUpperCase() == 'PRO';
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;
    final borderColor = isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0);

    int? diasRestantes;
    bool vencido = false;
    bool porVencer = false;
    if (b.fechaVencimientoPlan != null) {
      try {
        final exp = DateTime.parse(b.fechaVencimientoPlan!);
        final diff = exp.difference(DateTime.now()).inDays;
        diasRestantes = diff;
        if (diff < 0) {
          vencido = true;
        } else if (diff <= 7) {
          porVencer = true;
        }
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: b.estado ? borderColor : AppTheme.alertRed.withValues(alpha: 0.4),
          width: b.estado ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: Icono, Nombre de Bodega, Dirección y Switch Activo/Inactivo
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: esPro
                      ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                      : const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  LucideIcons.store,
                  color: esPro ? const Color(0xFF7C3AED) : const Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.nombreComercial,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.direccion ?? 'Dirección no registrada',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Switch de Estado con etiqueta clara
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Switch(
                    value: b.estado,
                    activeThumbColor: AppTheme.accentGreen,
                    inactiveThumbColor: AppTheme.alertRed,
                    onChanged: (_) => _toggleEstadoBodega(b),
                  ),
                  Text(
                    b.estado ? 'ACTIVA' : 'SUSPENDIDA',
                    style: GoogleFonts.outfit(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: b.estado ? AppTheme.accentGreen : AppTheme.alertRed,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Fila 2: Badges (ID, Plan, Vencimiento) organizados con Wrap para que nunca colisionen
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Badge ID
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  'ID #${b.idBodega}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                  ),
                ),
              ),

              // Badge Plan
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: esPro ? const Color(0xFF7C3AED) : const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  esPro ? 'PLAN PRO' : 'PLAN BÁSICO',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),

              // Badge de Vencimiento
              if (b.fechaVencimientoPlan != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: vencido
                        ? AppTheme.alertRed.withValues(alpha: 0.15)
                        : (porVencer ? Colors.amber.withValues(alpha: 0.15) : AppTheme.accentGreen.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: vencido
                          ? AppTheme.alertRed.withValues(alpha: 0.4)
                          : (porVencer ? Colors.amber.withValues(alpha: 0.5) : AppTheme.accentGreen.withValues(alpha: 0.4)),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        vencido
                            ? LucideIcons.alertTriangle
                            : (porVencer ? LucideIcons.clock : LucideIcons.checkCircle2),
                        size: 11,
                        color: vencido
                            ? AppTheme.alertRed
                            : (porVencer ? Colors.amber.shade800 : AppTheme.accentGreen),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        vencido
                            ? 'Vencido (${diasRestantes?.abs()}d)'
                            : (porVencer ? 'Vence en ${diasRestantes}d' : 'Vigente (${diasRestantes}d)'),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: vencido
                              ? AppTheme.alertRed
                              : (porVencer ? Colors.amber.shade800 : AppTheme.accentGreen),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Fila 3: Datos de Contacto y RUC
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 5,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.fileText, size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      'RUC/DNI: ${b.rucDni ?? "Sin registrar"}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.phone, size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      'Tel: ${b.telefono ?? "Sin teléfono"}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (b.fechaVencimientoPlan != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.calendar, size: 13, color: AppTheme.textMuted),
                      const SizedBox(width: 5),
                      Text(
                        'Vence: ${_formatearFechaIso(b.fechaVencimientoPlan!)}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Fila 4: Acciones con Wrap (Cero desbordamiento)
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (b.telefono != null && b.telefono!.trim().isNotEmpty)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(LucideIcons.messageCircle, size: 14),
                    label: const Text('WhatsApp'),
                    onPressed: () => _enviarRecordatorioWhatsApp(b, diasRestantes, vencido),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(LucideIcons.sparkles, size: 14),
                  label: const Text('Gestionar Plan'),
                  onPressed: () => _abrirModalCambiarPlan(b),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(LucideIcons.eye, size: 14),
                  label: const Text('Inspeccionar'),
                  onPressed: () => _inspeccionarBodega(b),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PESTAÑA 2: USUARIOS GLOBALES (USER ACCESS CONTROL)
  // ===========================================================================

  Widget _buildTabUsuarios(bool isDark) {
    final query = _searchUsuarioCtrl.text.trim().toLowerCase();

    final filtrados = _usuarios.where((u) {
      if (query.isNotEmpty) {
        final user = u.username.toLowerCase();
        final bodega = (u.nombreBodega ?? '').toLowerCase();
        if (!user.contains(query) && !bodega.contains(query)) return false;
      }

      if (_filtroRolUsuario != 'TODOS') {
        if (u.rol.toUpperCase() != _filtroRolUsuario) return false;
      }

      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    controller: _searchUsuarioCtrl,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Buscar usuario por username o nombre de bodega...',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Filtro por Rol
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Rol:', 'TODOS', _filtroRolUsuario, (v) => setState(() => _filtroRolUsuario = v)),
                const SizedBox(width: 4),
                _buildFilterChip('', 'SUPERADMIN', _filtroRolUsuario, (v) => setState(() => _filtroRolUsuario = v)),
                const SizedBox(width: 4),
                _buildFilterChip('', 'ADMIN', _filtroRolUsuario, (v) => setState(() => _filtroRolUsuario = v)),
                const SizedBox(width: 4),
                _buildFilterChip('', 'CAJERO', _filtroRolUsuario, (v) => setState(() => _filtroRolUsuario = v)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: filtrados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.users, size: 48, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      Text('No se encontraron usuarios', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtrados.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final u = filtrados[idx];
                    return _buildUsuarioTile(u, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUsuarioTile(UsuarioItem u, bool isDark) {
    final esSuper = u.rol.toUpperCase() == 'SUPERADMIN';
    final esAdmin = u.rol.toUpperCase() == 'ADMIN';

    final Color badgeColor = esSuper
        ? const Color(0xFF7C3AED)
        : (esAdmin ? const Color(0xFF2563EB) : const Color(0xFF10B981));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              esSuper ? LucideIcons.shieldCheck : (esAdmin ? LucideIcons.userCheck : LucideIcons.user),
              color: badgeColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        u.username,
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        u.rol,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  esSuper
                      ? 'Superadministrador Global'
                      : 'Tienda: ${u.nombreBodega ?? "Sin bodega vinculada"}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Botón Restablecer Clave
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Restablecer Clave',
            icon: const Icon(LucideIcons.keyRound, size: 17),
            onPressed: () => _abrirResetPasswordUsuario(u),
          ),

          // Switch Estado Usuario (no permitir apagar al superadmin actual)
          if (!esSuper)
            Switch(
              value: u.estado,
              activeThumbColor: AppTheme.accentGreen,
              inactiveThumbColor: AppTheme.alertRed,
              onChanged: (_) => _toggleEstadoUsuario(u),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PESTAÑA 3: SUSCRIPCIONES & PAGOS (FINTECH LEDGER)
  // ===========================================================================

  Widget _buildTabPagos(bool isDark) {
    final query = _searchPagoCtrl.text.trim().toLowerCase();

    final filtrados = _pagos.where((p) {
      if (query.isNotEmpty) {
        final cod = p.codigoOperacion.toLowerCase();
        final bodega = (p.nombreBodega ?? '').toLowerCase();
        if (!cod.contains(query) && !bodega.contains(query)) return false;
      }

      if (_filtroBilleteraPago != 'TODOS') {
        if (p.billetera.toUpperCase() != _filtroBilleteraPago) return false;
      }

      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    controller: _searchPagoCtrl,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Buscar por código de operación o nombre de bodega...',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Filtro por Billetera
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildFilterChip('Billetera:', 'TODOS', _filtroBilleteraPago, (v) => setState(() => _filtroBilleteraPago = v)),
              const SizedBox(width: 4),
              _buildFilterChip('', 'YAPE', _filtroBilleteraPago, (v) => setState(() => _filtroBilleteraPago = v)),
              const SizedBox(width: 4),
              _buildFilterChip('', 'PLIN', _filtroBilleteraPago, (v) => setState(() => _filtroBilleteraPago = v)),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: filtrados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.receiptText, size: 48, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      Text('No se registraron transacciones', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtrados.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final p = filtrados[idx];
                    final isYape = p.billetera.toUpperCase().contains('YAPE');
                    final walletColor = isYape ? const Color(0xFF732283) : const Color(0xFF0084FF);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: walletColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              p.billetera.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
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
                                    Flexible(
                                      child: Text(
                                        'Op: ${p.codigoOperacion}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: p.codigoOperacion));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Código ${p.codigoOperacion} copiado')),
                                        );
                                      },
                                      child: const Icon(LucideIcons.copy, size: 13, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Tienda: ${p.nombreBodega ?? "Bodega #${p.idBodega ?? ''}"} • Plan ${p.plan}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (p.fechaPago != null) ...[
                                  const SizedBox(height: 1),
                                  Text(
                                    _formatearFechaIso(p.fechaPago!),
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'S/ ${p.monto.toStringAsFixed(2)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.accentGreen,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: p.estado == 'CONFIRMADO'
                                      ? AppTheme.accentGreen.withValues(alpha: 0.15)
                                      : (p.estado == 'RECHAZADO'
                                          ? AppTheme.alertRed.withValues(alpha: 0.15)
                                          : Colors.amber.withValues(alpha: 0.15)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p.estado,
                                  style: GoogleFonts.outfit(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: p.estado == 'CONFIRMADO'
                                        ? AppTheme.accentGreen
                                        : (p.estado == 'RECHAZADO' ? AppTheme.alertRed : Colors.amber.shade800),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 6),
                          PopupMenuButton<String>(
                            tooltip: 'Gestionar Estado del Pago',
                            icon: const Icon(LucideIcons.ellipsisVertical, size: 16, color: AppTheme.textMuted),
                            onSelected: (val) => _cambiarEstadoPago(p, val),
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'CONFIRMADO',
                                child: Row(
                                  children: [
                                    Icon(LucideIcons.checkCheck, size: 16, color: AppTheme.accentGreen),
                                    SizedBox(width: 8),
                                    Text('Aprobar / Confirmar'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'RECHAZADO',
                                child: Row(
                                  children: [
                                    Icon(LucideIcons.circleX, size: 16, color: AppTheme.alertRed),
                                    SizedBox(width: 8),
                                    Text('Rechazar Pago'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'PENDIENTE',
                                child: Row(
                                  children: [
                                    Icon(LucideIcons.clock, size: 16, color: Colors.amber),
                                    SizedBox(width: 8),
                                    Text('Marcar Pendiente'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ===========================================================================
  // PESTAÑA 4: INFRAESTRUCTURA & SERVIDOR (DEVOPS & HEALTH)
  // ===========================================================================

  Widget _buildTabInfraestructura(bool isDark) {
    final jvm = _healthInfo['jvm'] as Map<String, dynamic>? ?? {};
    final usedMem = jvm['used_memory_mb'] ?? 0;
    final totalMem = jvm['total_memory_mb'] ?? 0;
    final maxMem = jvm['max_memory_mb'] ?? 0;
    final uptimeSecs = jvm['uptime_seconds'] ?? 0;
    final activeThreads = jvm['active_threads'] ?? 0;
    final dbStatus = _healthInfo['database'] ?? 'UNKNOWN';
    final apiStatus = _healthInfo['status'] ?? 'UP';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ESTADO DEL SERVIDOR & CLOUD RUNTIME',
            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155), letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),

          // Grid de Indicadores de Salud
          Row(
            children: [
              Expanded(
                child: _buildHealthIndicatorCard(
                  title: 'API Backend Gateway',
                  statusText: apiStatus.toString().toUpperCase(),
                  isHealthy: apiStatus.toString().toUpperCase() == 'UP',
                  icon: LucideIcons.cloudLightning,
                  detail: 'Endpoint: /health',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHealthIndicatorCard(
                  title: 'PostgreSQL Multi-Tenant',
                  statusText: dbStatus.toString(),
                  isHealthy: dbStatus.toString() == 'CONNECTED',
                  icon: LucideIcons.database,
                  detail: 'HikariCP Pool Shielded',
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Memoria JVM y Uptime
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.cpu, size: 20, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 10),
                    Text(
                      'Telemetría JVM & Recursos',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Memoria Usada / Total:', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155))),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$usedMem MB / $totalMem MB (Límite: $maxMem MB)',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: totalMem > 0 ? (usedMem / totalMem).clamp(0.0, 1.0) : 0.0,
                  backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                  color: const Color(0xFF7C3AED),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tiempo de Actividad (Uptime):', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155))),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _formatearUptime(uptimeSecs is int ? uptimeSecs : int.tryParse(uptimeSecs.toString()) ?? 0),
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Hilos de Ejecución Activos:', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155))),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$activeThreads threads',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Aislamiento Multi-Tenant:', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155))),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'multitenant_v4 (RLS Active)',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.accentGreen),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Comunicado Global Broadcast
          _buildCardComunicadoGlobal(isDark),
          const SizedBox(height: 16),

          // Volumen Global de Datos
          _buildCardVolumenDatos(isDark),
          const SizedBox(height: 16),

          // URL del Servidor API
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.globe, size: 20, color: Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    Text(
                      'Ruta del Servidor Backend',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  ApiConstants.baseUrl,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: const Text('Probar Ping y Latencia HTTP'),
                  onPressed: () async {
                    await _cargarMetricasYHealth();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ping completado: Latencia ${_latencyMs}ms con el backend.'),
                          backgroundColor: AppTheme.accentGreen,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardVolumenDatos(bool isDark) {
    final Map<String, dynamic> items = {
      'Bodegas': _metricasSistema['totalBodegas'] ?? _bodegas.length,
      'Usuarios': _metricasSistema['totalUsuarios'] ?? _usuarios.length,
      'Productos': _metricasSistema['totalProductos'] ?? 0,
      'Ventas': _metricasSistema['totalVentas'] ?? 0,
      'Compras': _metricasSistema['totalCompras'] ?? 0,
      'Kardex': _metricasSistema['totalMovimientos'] ?? 0,
      'Categorías': _metricasSistema['totalCategorias'] ?? 0,
      'Pagos': _metricasSistema['totalPagos'] ?? _pagos.length,
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                    const Icon(LucideIcons.database, size: 20, color: Color(0xFF0284C7)),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Volumen Global de Datos & Tablas',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(LucideIcons.copy, size: 14),
                label: const Text('Copiar JSON'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(_metricasSistema)));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Métricas del sistema copiadas en formato JSON')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items.entries.map((e) {
              return Container(
                width: 135,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.key.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      e.value.toString(),
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCardComunicadoGlobal(bool isDark) {
    final tieneAnuncio = _anuncioGlobal.isNotEmpty && _anuncioGlobal['activo'] == true;
    final tipo = _anuncioGlobal['tipo']?.toString() ?? 'INFO';
    final mensaje = _anuncioGlobal['mensaje']?.toString() ?? '';

    final Color badgeColor = tipo == 'URGENTE'
        ? AppTheme.alertRed
        : (tipo == 'WARNING' ? Colors.amber.shade800 : const Color(0xFF2563EB));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                    const Icon(LucideIcons.megaphone, size: 18, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Comunicado Global (Broadcast)',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(LucideIcons.plus, size: 13),
                label: Text(tieneAnuncio ? 'Editar' : 'Emitir'),
                onPressed: _abrirModalPublicarAnuncio,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tieneAnuncio) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tipo,
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      mensaje,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Retirar comunicado',
                    icon: const Icon(LucideIcons.trash2, color: AppTheme.alertRed, size: 18),
                    onPressed: _eliminarAnuncio,
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'No hay avisos globales activos actualmente. Las tiendas y cajas están operando con normalidad sin alertas perimetrales.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthIndicatorCard({
    required String title,
    required String statusText,
    required bool isHealthy,
    required IconData icon,
    required String detail,
    required bool isDark,
  }) {
    final color = isHealthy ? AppTheme.accentGreen : AppTheme.alertRed;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  statusText,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            detail,
            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HELPERS VISUALES
  // ===========================================================================

  Widget _buildFilterChip(String prefix, String label, String currentVal, Function(String) onSelect) {
    final isSelected = currentVal == label;
    return ChoiceChip(
      label: Text(prefix.isNotEmpty ? '$prefix $label' : label),
      selected: isSelected,
      onSelected: (val) {
        if (val) onSelect(label);
      },
    );
  }

  String _formatearFechaIso(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  String _formatearUptime(int seconds) {
    if (seconds < 60) return '$seconds seg.';
    if (seconds < 3600) return '${seconds ~/ 60} min.';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    return '$hours h $mins m';
  }
}
