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
import '../../core/widgets/pago_yape_modal.dart';
import '../auth/auth_service.dart';
import '../home/bodega_service.dart';
import '../home/usuarios_service.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
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
  List<StarterPackPresetItem> _starterPackItems = [];

  // Filtros de búsqueda
  final TextEditingController _searchBodegaCtrl = TextEditingController();
  String _filtroPlanBodega = 'TODOS';
  String _filtroEstadoBodega = 'TODOS';

  final TextEditingController _searchUsuarioCtrl = TextEditingController();
  String _filtroRolUsuario = 'TODOS';

  final TextEditingController _searchPagoCtrl = TextEditingController();
  String _filtroBilleteraPago = 'TODOS';

  final TextEditingController _searchStarterPackCtrl = TextEditingController();
  String _filtroCategoriaStarterPack = 'TODOS';
  String _filtroEstadoStarterPack = 'TODOS';
  bool _isLoadingStarterPack = false;

  Map<String, dynamic> _finanzasSaaS = {};
  Map<String, dynamic> _estadisticasSugerencias = {};
  List<SugerenciaPrecioItem> _sugerenciasSuperadmin = [];
  String _filtroEstadoSugerenciaSuperadmin = 'TODOS';
  final TextEditingController _searchSugerenciaCtrl = TextEditingController();

  int _latencyMs = 0;
  bool _isRefreshingMetrics = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _cargarTodo();
    // Refresco periódico ligero cada 60s
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _cargarMetricasYHealth(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    _searchBodegaCtrl.dispose();
    _searchUsuarioCtrl.dispose();
    _searchPagoCtrl.dispose();
    _searchStarterPackCtrl.dispose();
    _searchSugerenciaCtrl.dispose();
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
      final starterPackFuture = _bodegaService.listarStarterPackPresets();
      final finanzasFuture = _bodegaService.obtenerMonitorFinancieroSaaS();
      final statsSugFuture = _bodegaService.obtenerEstadisticasSugerencias();
      final sugerenciasFuture = _bodegaService.listarSugerenciasSuperadmin();

      final results = await Future.wait([
        metricasFuture,
        healthFuture,
        bodegasFuture,
        usuariosFuture,
        pagosFuture,
        anuncioFuture,
        starterPackFuture,
        finanzasFuture,
        statsSugFuture,
        sugerenciasFuture,
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
          _starterPackItems = results[6] as List<StarterPackPresetItem>;
          _finanzasSaaS = results[7] as Map<String, dynamic>;
          _estadisticasSugerencias = results[8] as Map<String, dynamic>;
          _sugerenciasSuperadmin = results[9] as List<SugerenciaPrecioItem>;
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

  Future<void> _cargarStarterPack() async {
    setState(() => _isLoadingStarterPack = true);
    try {
      final items = await _bodegaService.listarStarterPackPresets();
      if (mounted) {
        setState(() {
          _starterPackItems = items;
          _isLoadingStarterPack = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStarterPack = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al recargar Starter Pack: $e'),
            backgroundColor: AppTheme.alertRed,
          ),
        );
      }
    }
  }

  Future<void> _cargarMetricasYHealth() async {
    if (_isRefreshingMetrics) return;
    _isRefreshingMetrics = true;
    try {
      final stopwatch = Stopwatch()..start();
      final results = await Future.wait<Map<String, dynamic>>([
        _bodegaService.obtenerMetricasSistema(),
        _bodegaService.obtenerHealthServidor(),
      ]);
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _metricasSistema = results[0];
          _healthInfo = results[1];
          _latencyMs = stopwatch.elapsedMilliseconds;
        });
      }
    } catch (_) {
    } finally {
      _isRefreshingMetrics = false;
    }
  }

  // ===========================================================================
  // ACCIONES DE GESTIÓN DE BODEGAS & PLATAFORMA
  // ===========================================================================

  Future<void> _abrirModalProvisionarBodega(
    BuildContext context,
    bool isDark,
  ) async {
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.store,
                    color: Color(0xFF7C3AED),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Provisionar Nueva Bodega',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        'Alta inmediata de tienda y usuario administrador',
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
                  onPressed: () => Navigator.pop(dlgCtx),
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
                            const Icon(
                              LucideIcons.alertCircle,
                              color: AppTheme.alertRed,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                error,
                                style: const TextStyle(
                                  color: AppTheme.alertRed,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      'INFORMACIÓN DE LA TIENDA',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nombreCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nombre Comercial *',
                        hintText: 'Ej. Minimarket San Jorge',
                        prefixIcon: const Icon(LucideIcons.store, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onChanged: (val) {
                        if (userCtrl.text.isEmpty ||
                            userCtrl.text.startsWith('admin_')) {
                          final clean = val.toLowerCase().replaceAll(
                            RegExp(r'[^a-z0-9]'),
                            '',
                          );
                          final truncated = clean.length > 12
                              ? clean.substring(0, 12)
                              : clean;
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
                              prefixIcon: const Icon(
                                LucideIcons.fileText,
                                size: 18,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
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
                              prefixIcon: const Icon(
                                LucideIcons.phone,
                                size: 18,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'SUSCRIPCIÓN & VIGENCIA',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF334155),
                      ),
                    ),
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
                            label: const Center(child: Text('Plan PRO')),
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
                    Text(
                      'CREDENCIALES DE ACCESO DEL DUEÑO',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: userCtrl,
                            decoration: InputDecoration(
                              labelText: 'Usuario Admin *',
                              hintText: 'admin_tienda',
                              prefixIcon: const Icon(
                                LucideIcons.user,
                                size: 18,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
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
                              prefixIcon: const Icon(
                                LucideIcons.lock,
                                size: 18,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final n = nombreCtrl.text.trim();
                        final u = userCtrl.text.trim();
                        final p = passCtrl.text.trim();
                        if (n.isEmpty) {
                          setModalState(
                            () => error = 'Ingresa el nombre comercial.',
                          );
                          return;
                        }
                        if (u.isEmpty || p.isEmpty) {
                          setModalState(
                            () => error = 'Usuario y clave son obligatorios.',
                          );
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
                                content: Text(
                                  '¡Bodega "${nueva.nombreComercial}" provisionada exitosamente!',
                                ),
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
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Crear Bodega & Admin'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _enviarRecordatorioWhatsApp(
    BodegaInfo b,
    int? diasRestantes,
    bool vencido,
  ) async {
    final tel = b.telefono?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (tel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta bodega no tiene teléfono registrado'),
        ),
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
      'Puedes renovar fácilmente vía Yape o Plin al número ${PagoYapeModal.officialYapeDisplay} para continuar disfrutando de tu sistema sin interrupciones. ¡Muchas gracias por tu preferencia!',
    );
    final uri = Uri.parse('https://wa.me/$num?text=$texto');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _cambiarEstadoPago(
    PagoSuscripcionItem p,
    String nuevoEstado,
  ) async {
    try {
      final actualizado = await _bodegaService.cambiarEstadoPago(
        p.idPago,
        nuevoEstado,
      );
      setState(() {
        final idx = _pagos.indexWhere((x) => x.idPago == p.idPago);
        if (idx != -1) _pagos[idx] = actualizado;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pago #${p.codigoOperacion} marcado como $nuevoEstado',
            ),
            backgroundColor: nuevoEstado == 'CONFIRMADO'
                ? AppTheme.accentGreen
                : AppTheme.alertRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.alertRed,
          ),
        );
      }
    }
  }

  Future<void> _abrirModalPublicarAnuncio() async {
    final msgCtrl = TextEditingController(
      text: _anuncioGlobal['mensaje']?.toString() ?? '',
    );
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                const Icon(
                  LucideIcons.megaphone,
                  color: Color(0xFF7C3AED),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Comunicado Global',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(dlgCtx),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Este aviso aparecerá en la parte superior de las pantallas de todas las bodegas y cajas activas.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'TIPO DE AVISO:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF334155),
                  ),
                ),
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
                      avatar: const Icon(
                        LucideIcons.triangleAlert,
                        size: 14,
                        color: AppTheme.warningAmber,
                      ),
                      label: const Text('Advertencia'),
                      selected: tipo == 'WARNING',
                      onSelected: (val) {
                        if (val) setModalState(() => tipo = 'WARNING');
                      },
                    ),
                    ChoiceChip(
                      avatar: const Icon(
                        LucideIcons.alertOctagon,
                        size: 14,
                        color: AppTheme.alertRed,
                      ),
                      label: const Text('Urgente'),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final msg = msgCtrl.text.trim();
                        if (msg.isEmpty) return;
                        setModalState(() => isSaving = true);
                        try {
                          final res = await _bodegaService
                              .publicarAnuncioGlobal(msg, tipo: tipo);
                          if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                          if (mounted) {
                            setState(() => _anuncioGlobal = res);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Comunicado global publicado a todos los terminales',
                                ),
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
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.alertRed,
          ),
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
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
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
              backgroundColor: nuevoEstado
                  ? AppTheme.accentGreen
                  : AppTheme.alertRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(accion),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final actualizada = await _bodegaService.cambiarEstadoBodega(
          b.idBodega,
          nuevoEstado,
        );
        if (mounted) {
          setState(() {
            final idx = _bodegas.indexWhere((x) => x.idBodega == b.idBodega);
            if (idx != -1) _bodegas[idx] = actualizada;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Tienda "${b.nombreComercial}" ${nuevoEstado ? "activada" : "suspendida"} exitosamente.',
              ),
              backgroundColor: nuevoEstado
                  ? AppTheme.accentGreen
                  : AppTheme.alertRed,
            ),
          );
          _cargarMetricasYHealth();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: ${e.toString().replaceAll("Exception: ", "")}',
              ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.sparkles,
                    color: Color(0xFF7C3AED),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gestionar Suscripción',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        b.nombreComercial,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
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
                  onPressed: () => Navigator.pop(dlgCtx),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SELECCIONA EL PLAN:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF334155),
                  ),
                ),
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
                        label: const Center(child: Text('Plan PRO')),
                        selected: planElegido == 'PRO',
                        onSelected: (val) {
                          if (val) setModalState(() => planElegido = 'PRO');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'DÍAS DE VIGENCIA ADICIONAL:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF334155),
                  ),
                ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        setModalState(() => isSaving = true);
                        try {
                          final actualizada = await _bodegaService
                              .cambiarPlanBodega(
                                b.idBodega,
                                planElegido,
                                dias: dias,
                              );
                          if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                          if (mounted) {
                            setState(() {
                              final idx = _bodegas.indexWhere(
                                (x) => x.idBodega == b.idBodega,
                              );
                              if (idx != -1) _bodegas[idx] = actualizada;
                            });
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Plan de "${b.nombreComercial}" actualizado a $planElegido ($dias días).',
                                ),
                                backgroundColor: AppTheme.accentGreen,
                              ),
                            );
                            _cargarMetricasYHealth();
                          }
                        } catch (e) {
                          setModalState(() => isSaving = false);
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: AppTheme.alertRed,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
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
    AuthService.clearTenantCaches();
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                const Icon(
                  LucideIcons.keyRound,
                  color: Color(0xFF7C3AED),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Restablecer Clave',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Usuario: ${u.username}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Rol: ${u.rol} • Tienda: ${u.nombreBodega ?? "Sin bodega"}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppTheme.getAdaptiveMutedText(isDark),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña o PIN (mín. 4 caracteres)',
                    hintText: 'Ej. 123456',
                    prefixIcon: const Icon(LucideIcons.lock, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    error,
                    style: const TextStyle(
                      color: AppTheme.alertRed,
                      fontSize: 12,
                    ),
                  ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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
                                content: Text(
                                  'Clave de "${u.username}" restablecida exitosamente.',
                                ),
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
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
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
            content: Text(
              'Usuario "${u.username}" ${nuevo ? "activado" : "deshabilitado"}.',
            ),
            backgroundColor: nuevo ? AppTheme.accentGreen : AppTheme.alertRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.alertRed,
          ),
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
              child: Text(
                'Cerrar Sesión Superadmin',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas salir de la Consola Global de Superadmin?',
          style: GoogleFonts.plusJakartaSans(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.alertRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
                  child: const Icon(
                    LucideIcons.shieldCheck,
                    color: Colors.white,
                    size: 18,
                  ),
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
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.4),
                                ),
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
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF334155),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.cardDarkHighlight
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.activity,
                          size: 12,
                          color: _latencyMs < 300
                              ? AppTheme.accentGreen
                              : Colors.amber,
                        ),
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
                  icon: Icon(
                    themeProvider.isDarkMode
                        ? LucideIcons.sun
                        : LucideIcons.moon,
                    size: 17,
                  ),
                  onPressed: () => themeProvider.toggleTheme(),
                ),

                // Cerrar Sesión
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Cerrar Sesión Superadmin',
                  icon: const Icon(
                    LucideIcons.logOut,
                    color: AppTheme.alertRed,
                    size: 17,
                  ),
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
                  Text(
                    'Conectando con la Consola Global del Sistema...',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
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
                    const Icon(
                      LucideIcons.alertTriangle,
                      size: 48,
                      color: AppTheme.alertRed,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error cargando datos del sistema',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF334155),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _cargarTodo,
                      icon: const Icon(LucideIcons.refreshCw, size: 16),
                      label: const Text('Reintentar Conexión'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: AppTheme.alertRed.withValues(alpha: 0.15),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.alertCircle,
                            size: 16,
                            color: AppTheme.alertRed,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Aviso de telemetría: $_errorMessage',
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
                      unselectedLabelColor: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF475569),
                      labelStyle: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
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
                          icon: Icon(LucideIcons.circleDollarSign, size: 18),
                          text: 'Finanzas SaaS & Cobranzas',
                        ),
                        Tab(
                          icon: const Icon(LucideIcons.sparkles, size: 18),
                          text: 'Sugerencias Globales (${_sugerenciasSuperadmin.length})',
                        ),
                        Tab(
                          icon: const Icon(LucideIcons.packagePlus, size: 18),
                          text: 'Preset Starter Pack (${_starterPackItems.length})',
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
                        _buildTabFinanzasSaaS(isDark),
                        _buildTabSugerenciasGlobales(isDark),
                        _buildTabStarterPack(isDark),
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
    final bodegasActivas =
        _metricasSistema['bodegasActivas'] ??
        _bodegas.where((b) => b.estado).length;
    final bodegasInactivas =
        _metricasSistema['bodegasInactivas'] ?? (totalBodegas - bodegasActivas);
    final bodegasPro =
        _metricasSistema['bodegasPro'] ??
        _bodegas.where((b) => b.plan.toUpperCase() == 'PRO').length;
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
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildKpiCard(
              title: 'TOTAL BODEGAS',
              value: '$totalBodegas',
              subtitle:
                  '$bodegasActivas Activas • $bodegasInactivas Suspendidas',
              icon: LucideIcons.store,
              color: const Color(0xFF7C3AED),
              isDark: isDark,
            ),
            const SizedBox(width: 12),
            _buildKpiCard(
              title: 'PENETRACIÓN PLAN PRO',
              value: '$bodegasPro PRO',
              subtitle: totalBodegas > 0
                  ? '${((bodegasPro / totalBodegas) * 100).toStringAsFixed(0)}% del total'
                  : '0%',
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
              subtitle:
                  '${_usuarios.where((u) => u.rol == "ADMIN").length} Admins • ${_usuarios.where((u) => u.rol == "CAJERO").length} Cajeros',
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
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
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
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF334155),
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
        if (!nom.contains(query) &&
            !ruc.contains(query) &&
            !tel.contains(query) &&
            !dir.contains(query)) {
          return false;
        }
      }

      if (_filtroPlanBodega != 'TODOS') {
        if (_filtroPlanBodega == 'PRO' && b.plan.toUpperCase() != 'PRO')
          return false;
        if (_filtroPlanBodega == 'BASICO' && b.plan.toUpperCase() == 'PRO')
          return false;
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
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: TextField(
                    controller: _searchBodegaCtrl,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar bodega por nombre, RUC, dirección...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppTheme.getAdaptiveHintText(isDark),
                      ),
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(LucideIcons.store, size: 16),
                label: Text(
                  '+ Nueva Bodega',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
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
                _buildFilterChip(
                  'Planes:',
                  'TODOS',
                  _filtroPlanBodega,
                  (v) => setState(() => _filtroPlanBodega = v),
                ),
                const SizedBox(width: 4),
                _buildFilterChip(
                  '',
                  'PRO',
                  _filtroPlanBodega,
                  (v) => setState(() => _filtroPlanBodega = v),
                ),
                const SizedBox(width: 4),
                _buildFilterChip(
                  '',
                  'BASICO',
                  _filtroPlanBodega,
                  (v) => setState(() => _filtroPlanBodega = v),
                ),
                const SizedBox(width: 16),
                _buildFilterChip(
                  'Estado:',
                  'TODOS',
                  _filtroEstadoBodega,
                  (v) => setState(() => _filtroEstadoBodega = v),
                ),
                const SizedBox(width: 4),
                _buildFilterChip(
                  '',
                  'ACTIVAS',
                  _filtroEstadoBodega,
                  (v) => setState(() => _filtroEstadoBodega = v),
                ),
                const SizedBox(width: 4),
                _buildFilterChip(
                  '',
                  'INACTIVAS',
                  _filtroEstadoBodega,
                  (v) => setState(() => _filtroEstadoBodega = v),
                ),
                const SizedBox(width: 4),
                _buildFilterChip(
                  '',
                  'POR VENCER',
                  _filtroEstadoBodega,
                  (v) => setState(() => _filtroEstadoBodega = v),
                ),
                const SizedBox(width: 4),
                _buildFilterChip(
                  '',
                  'VENCIDAS',
                  _filtroEstadoBodega,
                  (v) => setState(() => _filtroEstadoBodega = v),
                ),
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
                      Icon(
                        LucideIcons.store,
                        size: 48,
                        color: AppTheme.getAdaptiveMutedText(isDark),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No se encontraron bodegas',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
          color: b.estado
              ? borderColor
              : AppTheme.alertRed.withValues(alpha: 0.4),
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
                  color: esPro
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFF2563EB),
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
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF334155),
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
                      color: b.estado
                          ? AppTheme.accentGreen
                          : AppTheme.alertRed,
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
                  color: isDark
                      ? AppTheme.cardDarkSunken
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  'ID #${b.idBodega}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF334155),
                  ),
                ),
              ),

              // Badge Plan
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: esPro
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFF2563EB),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: vencido
                        ? AppTheme.alertRed.withValues(alpha: 0.15)
                        : (porVencer
                              ? Colors.amber.withValues(alpha: 0.15)
                              : AppTheme.accentGreen.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: vencido
                          ? AppTheme.alertRed.withValues(alpha: 0.4)
                          : (porVencer
                                ? Colors.amber.withValues(alpha: 0.5)
                                : AppTheme.accentGreen.withValues(alpha: 0.4)),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        vencido
                            ? LucideIcons.alertTriangle
                            : (porVencer
                                  ? LucideIcons.clock
                                  : LucideIcons.checkCircle2),
                        size: 11,
                        color: vencido
                            ? AppTheme.alertRed
                            : (porVencer
                                  ? Colors.amber.shade800
                                  : AppTheme.accentGreen),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        vencido
                            ? 'Vencido (${diasRestantes?.abs()}d)'
                            : (porVencer
                                  ? 'Vence en ${diasRestantes}d'
                                  : 'Vigente (${diasRestantes}d)'),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: vencido
                              ? AppTheme.alertRed
                              : (porVencer
                                    ? Colors.amber.shade800
                                    : AppTheme.accentGreen),
                        ),
                      ),
                    ],
                  ),
                ),
              // Badge de Color de Marca
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _parseHexToColor(b.colorPrimario).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _parseHexToColor(b.colorPrimario).withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: _parseHexToColor(b.colorPrimario),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      b.colorPrimario,
                      style: GoogleFonts.firaCode(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: _parseHexToColor(b.colorPrimario),
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
                    Icon(
                      LucideIcons.fileText,
                      size: 13,
                      color: AppTheme.getAdaptiveMutedText(isDark),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'RUC/DNI: ${b.rucDni ?? "Sin registrar"}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.phone,
                      size: 13,
                      color: AppTheme.getAdaptiveMutedText(isDark),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Tel: ${b.telefono ?? "Sin teléfono"}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (b.fechaVencimientoPlan != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.calendar,
                        size: 13,
                        color: AppTheme.getAdaptiveMutedText(isDark),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Vence: ${_formatearFechaIso(b.fechaVencimientoPlan!)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(LucideIcons.messageCircle, size: 14),
                    label: const Text('WhatsApp'),
                    onPressed: () =>
                        _enviarRecordatorioWhatsApp(b, diasRestantes, vencido),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(LucideIcons.sparkles, size: 14),
                  label: const Text('Gestionar Plan'),
                  onPressed: () => _abrirModalCambiarPlan(b),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _parseHexToColor(b.colorPrimario),
                    side: BorderSide(color: _parseHexToColor(b.colorPrimario)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(LucideIcons.palette, size: 14),
                  label: const Text('Color'),
                  onPressed: () => _abrirModalCambiarColorBodega(b),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    side: const BorderSide(color: Color(0xFF0284C7)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(LucideIcons.globe, size: 14),
                  label: const Text('Web Online'),
                  onPressed: () => context.push('/catalogo?tienda=${b.idBodega}'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: TextField(
                    controller: _searchUsuarioCtrl,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Buscar usuario por username o nombre de bodega...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppTheme.getAdaptiveHintText(isDark),
                      ),
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
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
                _buildFilterChip(
                  'Rol:',
                  'TODOS',
                  _filtroRolUsuario,
                  (v) => setState(() => _filtroRolUsuario = v),
                ),
                const SizedBox(width: 4),
                _buildFilterChip(
                  '',
                  'SUPERADMIN',
                  _filtroRolUsuario,
                  (v) => setState(() => _filtroRolUsuario = v),
                ),
                const SizedBox(width: 4),
                _buildFilterChip(
                  '',
                  'ADMIN',
                  _filtroRolUsuario,
                  (v) => setState(() => _filtroRolUsuario = v),
                ),
                const SizedBox(width: 4),
                _buildFilterChip(
                  '',
                  'CAJERO',
                  _filtroRolUsuario,
                  (v) => setState(() => _filtroRolUsuario = v),
                ),
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
                      Icon(
                        LucideIcons.users,
                        size: 48,
                        color: AppTheme.getAdaptiveMutedText(isDark),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No se encontraron usuarios',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
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
              esSuper
                  ? LucideIcons.shieldCheck
                  : (esAdmin ? LucideIcons.userCheck : LucideIcons.user),
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
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF334155),
                  ),
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
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: TextField(
                    controller: _searchPagoCtrl,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar por código de operación o nombre de bodega...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppTheme.getAdaptiveHintText(isDark),
                      ),
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
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
              _buildFilterChip(
                'Billetera:',
                'TODOS',
                _filtroBilleteraPago,
                (v) => setState(() => _filtroBilleteraPago = v),
              ),
              const SizedBox(width: 4),
              _buildFilterChip(
                '',
                'YAPE',
                _filtroBilleteraPago,
                (v) => setState(() => _filtroBilleteraPago = v),
              ),
              const SizedBox(width: 4),
              _buildFilterChip(
                '',
                'PLIN',
                _filtroBilleteraPago,
                (v) => setState(() => _filtroBilleteraPago = v),
              ),
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
                      Icon(
                        LucideIcons.receiptText,
                        size: 48,
                        color: AppTheme.getAdaptiveMutedText(isDark),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No se registraron transacciones',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
                    final walletColor = isYape
                        ? const Color(0xFF732283)
                        : const Color(0xFF0084FF);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
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
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: p.codigoOperacion,
                                          ),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Código ${p.codigoOperacion} copiado',
                                            ),
                                          ),
                                        );
                                      },
                                      child: Icon(
                                        LucideIcons.copy,
                                        size: 13,
                                        color: AppTheme.getAdaptiveMutedText(
                                          isDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Tienda: ${p.nombreBodega ?? "Bodega #${p.idBodega ?? ''}"} • Plan ${p.plan}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppTheme.textDarkSecondary
                                        : const Color(0xFF334155),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (p.fechaPago != null) ...[
                                  const SizedBox(height: 1),
                                  Text(
                                    _formatearFechaIso(p.fechaPago!),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppTheme.textDarkSecondary
                                          : const Color(0xFF334155),
                                    ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: p.estado == 'CONFIRMADO'
                                      ? AppTheme.accentGreen.withValues(
                                          alpha: 0.15,
                                        )
                                      : (p.estado == 'RECHAZADO'
                                            ? AppTheme.alertRed.withValues(
                                                alpha: 0.15,
                                              )
                                            : Colors.amber.withValues(
                                                alpha: 0.15,
                                              )),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p.estado,
                                  style: GoogleFonts.outfit(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: p.estado == 'CONFIRMADO'
                                        ? AppTheme.accentGreen
                                        : (p.estado == 'RECHAZADO'
                                              ? AppTheme.alertRed
                                              : Colors.amber.shade800),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 6),
                          PopupMenuButton<String>(
                            tooltip: 'Gestionar Estado del Pago',
                            icon: Icon(
                              LucideIcons.ellipsisVertical,
                              size: 16,
                              color: AppTheme.getAdaptiveMutedText(isDark),
                            ),
                            onSelected: (val) => _cambiarEstadoPago(p, val),
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'CONFIRMADO',
                                child: Row(
                                  children: [
                                    Icon(
                                      LucideIcons.checkCheck,
                                      size: 16,
                                      color: AppTheme.accentGreen,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Aprobar / Confirmar'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'RECHAZADO',
                                child: Row(
                                  children: [
                                    Icon(
                                      LucideIcons.circleX,
                                      size: 16,
                                      color: AppTheme.alertRed,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Rechazar Pago'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'PENDIENTE',
                                child: Row(
                                  children: [
                                    Icon(
                                      LucideIcons.clock,
                                      size: 16,
                                      color: Colors.amber,
                                    ),
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : const Color(0xFF334155),
              letterSpacing: 0.5,
            ),
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
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.cpu,
                      size: 20,
                      color: Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Telemetría JVM & Recursos',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Memoria Usada / Total:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$usedMem MB / $totalMem MB (Límite: $maxMem MB)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: totalMem > 0
                      ? (usedMem / totalMem).clamp(0.0, 1.0)
                      : 0.0,
                  backgroundColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFE2E8F0),
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
                    Text(
                      'Tiempo de Actividad (Uptime):',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _formatearUptime(
                          uptimeSecs is int
                              ? uptimeSecs
                              : int.tryParse(uptimeSecs.toString()) ?? 0,
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
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
                    Text(
                      'Hilos de Ejecución Activos:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$activeThreads threads',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
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
                    Text(
                      'Aislamiento Multi-Tenant:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'multitenant_v4 (RLS Active)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentGreen,
                        ),
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
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.globe,
                      size: 20,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Ruta del Servidor Backend',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: const Text('Probar Ping y Latencia HTTP'),
                  onPressed: () async {
                    await _cargarMetricasYHealth();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Ping completado: Latencia ${_latencyMs}ms con el backend.',
                          ),
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
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                    const Icon(
                      LucideIcons.database,
                      size: 20,
                      color: Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Volumen Global de Datos & Tablas',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(LucideIcons.copy, size: 14),
                label: const Text('Copiar JSON'),
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: const JsonEncoder.withIndent('  ')
                          .convert(_metricasSistema),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Métricas del sistema copiadas en formato JSON',
                      ),
                    ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.cardDarkSunken
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.key.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF334155),
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
    final tieneAnuncio =
        _anuncioGlobal.isNotEmpty && _anuncioGlobal['activo'] == true;
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
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                    const Icon(
                      LucideIcons.megaphone,
                      size: 18,
                      color: Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Comunicado Global (Broadcast)',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tipo,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      mensaje,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Retirar comunicado',
                    icon: const Icon(
                      LucideIcons.trash2,
                      color: AppTheme.alertRed,
                      size: 18,
                    ),
                    onPressed: _eliminarAnuncio,
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'No hay avisos globales activos actualmente. Las tiendas y cajas están operando con normalidad sin alertas perimetrales.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF334155),
              ),
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
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            detail,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : const Color(0xFF334155),
            ),
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

  Widget _buildFilterChip(
    String prefix,
    String label,
    String currentVal,
    Function(String) onSelect,
  ) {
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

  // ===========================================================================
  // PESTAÑA: PRESET STARTER PACK GLOBAL
  // ===========================================================================

  Widget _buildTabStarterPack(bool isDark) {
    if (_isLoadingStarterPack) {
      return const Center(child: CircularProgressIndicator());
    }

    final query = _searchStarterPackCtrl.text.trim().toLowerCase();

    // Obtener lista única de categorías para los filtros
    final categoriasUnicas = <String>{};
    for (final p in _starterPackItems) {
      if (p.categoria.isNotEmpty) {
        categoriasUnicas.add(p.categoria.toUpperCase());
      }
    }
    final listaCategorias = categoriasUnicas.toList()..sort();

    final filtrados = _starterPackItems.where((p) {
      if (query.isNotEmpty) {
        final nom = p.nombre.toLowerCase();
        final cod = p.codigoBarras.toLowerCase();
        final mar = (p.marca ?? '').toLowerCase();
        final cat = p.categoria.toLowerCase();
        if (!nom.contains(query) &&
            !cod.contains(query) &&
            !mar.contains(query) &&
            !cat.contains(query)) {
          return false;
        }
      }

      if (_filtroCategoriaStarterPack != 'TODOS') {
        if (p.categoria.toUpperCase() != _filtroCategoriaStarterPack) {
          return false;
        }
      }

      if (_filtroEstadoStarterPack != 'TODOS') {
        if (_filtroEstadoStarterPack == 'ACTIVOS' && !p.activo) return false;
        if (_filtroEstadoStarterPack == 'INACTIVOS' && p.activo) return false;
      }

      return true;
    }).toList();

    final totalActivos = _starterPackItems.where((i) => i.activo).length;

    return Column(
      children: [
        // Barra Superior: Búsqueda y Botones de Acción
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: TextField(
                    controller: _searchStarterPackCtrl,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar por producto, código de barras o marca...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppTheme.getAdaptiveHintText(isDark),
                      ),
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      suffixIcon: _searchStarterPackCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(LucideIcons.x, size: 16),
                              onPressed: () {
                                _searchStarterPackCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Botón Restablecer de Fábrica
              IconButton.filledTonal(
                tooltip: 'Restablecer Preset a Fábrica (172 productos)',
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFFE11D48),
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(LucideIcons.rotateCcw, size: 18),
                onPressed: () => _confirmarRestablecerPreset(context, isDark),
              ),
              const SizedBox(width: 8),
              // Botón Añadir Producto Preset
              ElevatedButton.icon(
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text(
                  'Añadir',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: () => _mostrarModalCrearEditarPreset(context, isDark),
              ),
            ],
          ),
        ),

        // Barra Informativa / KPIs del Starter Pack
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E1B4B).withValues(alpha: 0.4)
                : const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF4338CA).withValues(alpha: 0.5)
                  : const Color(0xFFC7D2FE),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.sparkles,
                color: Color(0xFF6366F1),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Este catálogo global se clona automáticamente cada vez que se crea o registra una nueva bodega.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFA5B4FC)
                        : const Color(0xFF3730A3),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF312E81) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Activos: $totalActivos / ${_starterPackItems.length}',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Chips de Filtro (Estado y Categorías)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'Estado:',
                  'TODOS',
                  _filtroEstadoStarterPack,
                  (v) => setState(() => _filtroEstadoStarterPack = v),
                ),
                const SizedBox(width: 4),
                _buildFilterChip(
                  '',
                  'ACTIVOS',
                  _filtroEstadoStarterPack,
                  (v) => setState(() => _filtroEstadoStarterPack = v),
                ),
                const SizedBox(width: 4),
                _buildFilterChip(
                  '',
                  'INACTIVOS',
                  _filtroEstadoStarterPack,
                  (v) => setState(() => _filtroEstadoStarterPack = v),
                ),
                const SizedBox(width: 14),
                _buildFilterChip(
                  'Categoría:',
                  'TODOS',
                  _filtroCategoriaStarterPack,
                  (v) => setState(() => _filtroCategoriaStarterPack = v),
                ),
                ...listaCategorias.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _buildFilterChip(
                      '',
                      cat,
                      _filtroCategoriaStarterPack,
                      (v) => setState(() => _filtroCategoriaStarterPack = v),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Lista de Productos del Preset
        Expanded(
          child: filtrados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.packageOpen,
                        size: 48,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No se encontraron productos en el preset',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Prueba ajustando los filtros o restablece los 172 productos de fábrica.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        icon: const Icon(LucideIcons.rotateCcw, size: 16),
                        label: const Text('Restablecer de Fábrica'),
                        onPressed: () =>
                            _confirmarRestablecerPreset(context, isDark),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtrados.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = filtrados[index];
                    return _buildStarterPackItemCard(item, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStarterPackItemCard(
    StarterPackPresetItem item,
    bool isDark,
  ) {
    final margenPorcentaje = item.precioVenta > 0
        ? (((item.precioVenta - item.precioCosto) / item.precioVenta) * 100)
            .toStringAsFixed(0)
        : '0';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? (item.activo ? const Color(0xFF334155) : const Color(0xFF1E293B))
              : (item.activo ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Imagen o Icono de Producto
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: item.imagenUrl != null && item.imagenUrl!.isNotEmpty
                  ? Image.network(
                      item.imagenUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => const Icon(
                        LucideIcons.package,
                        size: 24,
                        color: Color(0xFF94A3B8),
                      ),
                    )
                  : const Icon(
                      LucideIcons.package,
                      size: 24,
                      color: Color(0xFF94A3B8),
                    ),
            ),
            const SizedBox(width: 12),

            // Información Principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título y Marca
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.nombre,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: item.activo
                                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            decoration: item.activo
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!item.activo)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'DESACTIVADO',
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Categoría y Código de Barras
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.categoria,
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                      if (item.marca != null && item.marca!.isNotEmpty)
                        Text(
                          '• ${item.marca}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.scanBarcode,
                            size: 12,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.codigoBarras,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Precios: Venta, Costo, Margen
                  Row(
                    children: [
                      Text(
                        'Venta: ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        'S/ ${item.precioVenta.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Costo: ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        'S/ ${item.precioCosto.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$margenPorcentaje% mg.',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Acciones: Switch Activo, Editar, Eliminar
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch.adaptive(
                  value: item.activo,
                  activeTrackColor: const Color(0xFF7C3AED),
                  onChanged: (val) async {
                    try {
                      await _bodegaService.actualizarStarterPackPreset(
                        item.idPreset,
                        {'activo': val},
                      );
                      if (!mounted) return;
                      setState(() {
                        final idx = _starterPackItems.indexWhere(
                          (i) => i.idPreset == item.idPreset,
                        );
                        if (idx != -1) {
                          _starterPackItems[idx] = StarterPackPresetItem(
                            idPreset: item.idPreset,
                            codigoBarras: item.codigoBarras,
                            nombre: item.nombre,
                            marca: item.marca,
                            categoria: item.categoria,
                            precioVenta: item.precioVenta,
                            precioCosto: item.precioCosto,
                            imagenUrl: item.imagenUrl,
                            activo: val,
                          );
                        }
                      });
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al cambiar estado: $e'),
                          backgroundColor: AppTheme.alertRed,
                        ),
                      );
                    }
                  },
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.send, size: 16, color: Color(0xFF7C3AED)),
                      tooltip: 'Sugerir precio o datos a bodegas',
                      onPressed: () => _mostrarModalSugerirABodegas(
                        context,
                        isDark,
                        item,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.pencil, size: 16),
                      tooltip: 'Editar producto',
                      onPressed: () => _mostrarModalCrearEditarPreset(
                        context,
                        isDark,
                        item: item,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        LucideIcons.trash2,
                        size: 16,
                        color: Color(0xFFEF4444),
                      ),
                      tooltip: 'Eliminar del preset',
                      onPressed: () => _confirmarEliminarPresetItem(
                        context,
                        isDark,
                        item,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MODALES CRUD PRESET STARTER PACK
  // ===========================================================================

  Future<void> _mostrarModalCrearEditarPreset(
    BuildContext context,
    bool isDark, {
    StarterPackPresetItem? item,
  }) async {
    final esEdicion = item != null;
    final codigoCtrl = TextEditingController(text: item?.codigoBarras ?? '');
    final nombreCtrl = TextEditingController(text: item?.nombre ?? '');
    final marcaCtrl = TextEditingController(text: item?.marca ?? '');
    final categoriaCtrl = TextEditingController(
      text: item?.categoria ?? 'ABARROTES',
    );
    final precioVentaCtrl = TextEditingController(
      text: item != null ? item.precioVenta.toStringAsFixed(2) : '1.00',
    );
    final precioCostoCtrl = TextEditingController(
      text: item != null ? item.precioCosto.toStringAsFixed(2) : '0.80',
    );
    final imagenUrlCtrl = TextEditingController(text: item?.imagenUrl ?? '');
    bool activoVal = item?.activo ?? true;
    bool difundirSugerenciaVal = false;

    final formKey = GlobalKey<FormState>();
    bool guardando = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Icon(
                  esEdicion ? LucideIcons.filePenLine : LucideIcons.packagePlus,
                  color: const Color(0xFF7C3AED),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    esEdicion
                        ? 'Editar Producto Preset'
                        : 'Nuevo Producto Preset',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.pop(dlgCtx),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Los cambios se aplicarán globalmente a todas las nuevas bodegas que se registren a partir de ahora.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Código de Barras
                      TextFormField(
                        controller: codigoCtrl,
                        decoration: InputDecoration(
                          labelText: 'Código de Barras (EAN-13 / SKU) *',
                          prefixIcon: const Icon(LucideIcons.scanBarcode, size: 18),
                          suffixIcon: IconButton(
                            tooltip: 'Generar EAN aleatorio',
                            icon: const Icon(LucideIcons.shuffle, size: 16),
                            onPressed: () {
                              final rnd = math.Random();
                              final ean = '775${List.generate(10, (_) => rnd.nextInt(10)).join()}';
                              codigoCtrl.text = ean;
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'El código de barras es obligatorio'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Nombre
                      TextFormField(
                        controller: nombreCtrl,
                        decoration: InputDecoration(
                          labelText: 'Nombre del Producto *',
                          prefixIcon: const Icon(LucideIcons.package, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'El nombre es obligatorio'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Marca y Categoría en Fila
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: marcaCtrl,
                              decoration: InputDecoration(
                                labelText: 'Marca (Opcional)',
                                prefixIcon: const Icon(LucideIcons.tag, size: 18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: categoriaCtrl,
                              decoration: InputDecoration(
                                labelText: 'Categoría *',
                                prefixIcon:
                                    const Icon(LucideIcons.layers, size: 18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'La categoría es obligatoria'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Precios Venta y Costo
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: precioVentaCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Precio Venta (S/) *',
                                prefixText: 'S/ ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (v) {
                                final n = double.tryParse(v ?? '');
                                if (n == null || n < 0) return 'Precio inválido';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: precioCostoCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Precio Costo (S/) *',
                                prefixText: 'S/ ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (v) {
                                final n = double.tryParse(v ?? '');
                                if (n == null || n < 0) return 'Costo inválido';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Imagen URL
                      TextFormField(
                        controller: imagenUrlCtrl,
                        decoration: InputDecoration(
                          labelText: 'URL de Imagen (Opcional)',
                          prefixIcon: const Icon(LucideIcons.image, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Switch Activo
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Activo en Preset Starter Pack',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          'Si está inactivo, no se clonará a las nuevas bodegas creadas.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        value: activoVal,
                        activeTrackColor: const Color(0xFF7C3AED),
                        onChanged: (v) => setDlgState(() => activoVal = v),
                      ),
                      const SizedBox(height: 6),

                      // Switch para difundir sugerencia a bodegas existentes
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Sugerir actualización a bodegas existentes',
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                        subtitle: Text(
                          'Envía una notificación a las bodegas que tienen este código de barras para que adopten estos precios o datos.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        value: difundirSugerenciaVal,
                        activeTrackColor: const Color(0xFF7C3AED),
                        onChanged: (v) => setDlgState(() => difundirSugerenciaVal = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: guardando ? null : () => Navigator.pop(dlgCtx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                icon: guardando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(LucideIcons.save, size: 16),
                label: Text(guardando ? 'Guardando...' : 'Guardar'),
                onPressed: guardando
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDlgState(() => guardando = true);

                        final payload = {
                          'codigoBarras': codigoCtrl.text.trim(),
                          'nombre': nombreCtrl.text.trim(),
                          'marca': marcaCtrl.text.trim().isNotEmpty
                              ? marcaCtrl.text.trim()
                              : null,
                          'categoria': categoriaCtrl.text.trim().toUpperCase(),
                          'precioVenta': double.parse(precioVentaCtrl.text.trim()),
                          'precioCosto': double.parse(precioCostoCtrl.text.trim()),
                          'imagenUrl': imagenUrlCtrl.text.trim().isNotEmpty
                              ? imagenUrlCtrl.text.trim()
                              : null,
                          'activo': activoVal,
                        };

                        try {
                          if (esEdicion) {
                            await _bodegaService.actualizarStarterPackPreset(
                              item.idPreset,
                              payload,
                            );
                          } else {
                            await _bodegaService.crearStarterPackPreset(payload);
                          }

                          int difundidas = 0;
                          if (difundirSugerenciaVal) {
                            try {
                              difundidas = await _bodegaService.difundirSugerenciaPrecio({
                                'codigoBarras': codigoCtrl.text.trim(),
                                'precioVentaSugerido': double.parse(precioVentaCtrl.text.trim()),
                                'precioCostoSugerido': double.tryParse(precioCostoCtrl.text.trim()),
                                'nombreSugerido': nombreCtrl.text.trim(),
                                'marcaSugerida': marcaCtrl.text.trim().isNotEmpty ? marcaCtrl.text.trim() : null,
                                'motivo': 'Actualización sugerida por el SuperAdmin desde el Preset Starter Pack',
                              });
                            } catch (_) {}
                          }

                          if (context.mounted) {
                            Navigator.pop(dlgCtx);
                            final msgDifusion = difundidas > 0 ? ' y sugerido a $difundidas bodegas' : '';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  esEdicion
                                      ? 'Producto actualizado$msgDifusion correctamente'
                                      : 'Nuevo producto agregado al preset$msgDifusion',
                                ),
                                backgroundColor: AppTheme.accentGreen,
                              ),
                            );
                            await _cargarStarterPack();
                          }
                        } catch (e) {
                          setDlgState(() => guardando = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: AppTheme.alertRed,
                              ),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _mostrarModalSugerirABodegas(
    BuildContext context,
    bool isDark,
    StarterPackPresetItem item,
  ) async {
    final precioVentaCtrl = TextEditingController(
      text: item.precioVenta.toStringAsFixed(2),
    );
    final precioCostoCtrl = TextEditingController(
      text: item.precioCosto.toStringAsFixed(2),
    );
    final nombreCtrl = TextEditingController(text: item.nombre);
    final marcaCtrl = TextEditingController(text: item.marca ?? '');
    final motivoCtrl = TextEditingController(
      text: 'Ajuste de precio y catálogo sugerido por CajaYa SuperAdmin',
    );

    int bodegasCount = 0;
    bool cargandoConteo = true;
    bool enviando = false;

    // Consultar conteo en segundo plano
    _bodegaService.contarBodegasConProducto(item.codigoBarras).then((count) {
      bodegasCount = count;
      cargandoConteo = false;
    }).catchError((_) {
      bodegasCount = 0;
      cargandoConteo = false;
    });

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          if (cargandoConteo) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (ctx.mounted && !cargandoConteo) {
                setDlgState(() {});
              }
            });
          }

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
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.send,
                    color: Color(0xFF7C3AED),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sugerir a Bodegas',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.pop(dlgCtx),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Resumen del producto y conteo
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.scanBarcode, size: 18, color: Color(0xFF7C3AED)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.nombre,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'EAN: ${item.codigoBarras}',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              cargandoConteo
                                  ? 'Buscando...'
                                  : '$bodegasCount tiendas',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Esta propuesta llegará a las bodegas como una sugerencia. Cada bodega podrá aceptarla o rechazarla de forma autónoma.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Precios Venta y Costo sugeridos
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: precioVentaCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Precio Venta Sugerido *',
                              prefixText: 'S/ ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: precioCostoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Precio Costo Sugerido',
                              prefixText: 'S/ ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Nombre y Marca sugeridos
                    TextFormField(
                      controller: nombreCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nombre Sugerido',
                        prefixIcon: const Icon(LucideIcons.package, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: marcaCtrl,
                      decoration: InputDecoration(
                        labelText: 'Marca Sugerida',
                        prefixIcon: const Icon(LucideIcons.tag, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Motivo
                    TextFormField(
                      controller: motivoCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Motivo / Mensaje para las Bodegas',
                        prefixIcon: const Icon(LucideIcons.messageSquare, size: 18),
                        hintText: 'Ej. Incremento sugerido por proveedor / Corrección de catálogo',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: enviando ? null : () => Navigator.pop(dlgCtx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                icon: enviando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(LucideIcons.send, size: 16),
                label: Text(enviando ? 'Enviando...' : 'Enviar Sugerencia'),
                onPressed: enviando
                    ? null
                    : () async {
                        final v = double.tryParse(precioVentaCtrl.text.trim());
                        if (v == null || v <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ingresa un precio de venta válido mayor a 0.'),
                              backgroundColor: AppTheme.alertRed,
                            ),
                          );
                          return;
                        }

                        setDlgState(() => enviando = true);

                        try {
                          final notificadas = await _bodegaService.difundirSugerenciaPrecio({
                            'codigoBarras': item.codigoBarras,
                            'precioVentaSugerido': v,
                            'precioCostoSugerido': double.tryParse(precioCostoCtrl.text.trim()),
                            'nombreSugerido': nombreCtrl.text.trim().isNotEmpty ? nombreCtrl.text.trim() : null,
                            'marcaSugerida': marcaCtrl.text.trim().isNotEmpty ? marcaCtrl.text.trim() : null,
                            'motivo': motivoCtrl.text.trim(),
                          });

                          if (context.mounted) {
                            Navigator.pop(dlgCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Sugerencia difundida a $notificadas bodega(s). Podrán aceptarla o rechazarla.',
                                ),
                                backgroundColor: AppTheme.accentGreen,
                              ),
                            );
                          }
                        } catch (e) {
                          setDlgState(() => enviando = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al difundir sugerencia: $e'),
                                backgroundColor: AppTheme.alertRed,
                              ),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmarEliminarPresetItem(
    BuildContext context,
    bool isDark,
    StarterPackPresetItem item,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(
              LucideIcons.alertTriangle,
              color: Color(0xFFEF4444),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Eliminar Producto del Preset',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Deseas eliminar permanentemente "${item.nombre}" (${item.codigoBarras}) del catálogo preset global?\n\n'
          'Las bodegas existentes conservarán su inventario actual, pero las nuevas bodegas ya no recibirán este producto al crearse.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar del Preset'),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      try {
        await _bodegaService.eliminarStarterPackPreset(item.idPreset);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Producto eliminado del preset global'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
          await _cargarStarterPack();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar producto: $e'),
              backgroundColor: AppTheme.alertRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmarRestablecerPreset(
    BuildContext context,
    bool isDark,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(
              LucideIcons.rotateCcw,
              color: Color(0xFFE11D48),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Restablecer Preset de Fábrica',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Esta acción borrará cualquier modificación o adición que hayas realizado en el catálogo Starter Pack global y restablecerá los 172 productos oficiales canónicos de CajaYa.\n\n'
          '¿Estás seguro de continuar?',
          style: GoogleFonts.plusJakartaSans(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, Restablecer Todo'),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      try {
        final nuevos = await _bodegaService.restablecerStarterPackPreset();
        if (context.mounted) {
          setState(() {
            _starterPackItems = nuevos;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Preset global restablecido con éxito (${nuevos.length} productos oficiales).',
              ),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al restablecer preset: $e'),
              backgroundColor: AppTheme.alertRed,
            ),
          );
        }
      }
    }
  }

  // ===========================================================================
  // HELPER DE COLORES & BRANDING DINÁMICO
  // ===========================================================================

  Color _parseHexToColor(String? hexString, [Color defaultColor = const Color(0xFF2563EB)]) {
    if (hexString == null || hexString.isEmpty) return defaultColor;
    try {
      String hex = hexString.replaceAll('#', '').trim();
      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length == 8) return Color(int.parse(hex, radix: 16));
      return defaultColor;
    } catch (_) {
      return defaultColor;
    }
  }

  void _abrirModalCambiarColorBodega(BodegaInfo b) {
    String selectedHex = b.colorPrimario;
    final hexController = TextEditingController(text: selectedHex);
    bool isSaving = false;

    final presets = [
      {'nombre': 'Cobalto Clásico', 'hex': '#2563EB'},
      {'nombre': 'Esmeralda', 'hex': '#059669'},
      {'nombre': 'Púrpura Neón', 'hex': '#7C3AED'},
      {'nombre': 'Ámbar Cálido', 'hex': '#D97706'},
      {'nombre': 'Carmesí', 'hex': '#E11D48'},
      {'nombre': 'Turquesa Mar', 'hex': '#0D9488'},
      {'nombre': 'Índigo Real', 'hex': '#4F46E5'},
      {'nombre': 'Azul Medianoche', 'hex': '#1E293B'},
      {'nombre': 'Naranja Sol', 'hex': '#EA580C'},
      {'nombre': 'Fucsia Moderno', 'hex': '#C026D3'},
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
            final currentColor = _parseHexToColor(selectedHex);

            return AlertDialog(
              backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: currentColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.palette, color: currentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personalizar Color de Tienda',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          b.nombreComercial,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Preview Badge
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: currentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: currentColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: currentColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: currentColor.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Color Seleccionado: $selectedHex',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    'Afectará la app POS móvil y la tienda web online de la bodega.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Paleta de Colores Recomendados:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: presets.map((preset) {
                          final pColor = _parseHexToColor(preset['hex']!);
                          final isSelected = selectedHex.toUpperCase() == preset['hex']!.toUpperCase();
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              setDialogState(() {
                                selectedHex = preset['hex']!;
                                hexController.text = preset['hex']!;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? pColor.withValues(alpha: 0.2)
                                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? pColor : Colors.transparent,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: pColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    preset['nombre']!,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Código HEX Personalizado (#RRGGBB):',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: hexController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.hash, size: 16),
                          hintText: '#2563EB',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (val) {
                          String clean = val.trim();
                          if (!clean.startsWith('#')) clean = '#$clean';
                          if (RegExp(r'^#([0-9a-fA-F]{6})$').hasMatch(clean)) {
                            setDialogState(() {
                              selectedHex = clean.toUpperCase();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(LucideIcons.check, size: 16),
                  label: const Text('Guardar Color'),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          try {
                            await _bodegaService.cambiarColorBodegaSuperadmin(
                              idBodega: b.idBodega,
                              colorPrimario: selectedHex,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _cargarTodo();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Color de "${b.nombreComercial}" actualizado a $selectedHex.',
                                  ),
                                  backgroundColor: AppTheme.accentGreen,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al cambiar color: $e'),
                                  backgroundColor: AppTheme.alertRed,
                                ),
                              );
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // PESTAÑA 4: FINANZAS SAAS & COBRANZAS DE CLIENTES
  // ===========================================================================

  Widget _buildTabFinanzasSaaS(bool isDark) {
    final mrrTotal = (_finanzasSaaS['mrrTotal'] != null)
        ? _finanzasSaaS['mrrTotal'].toString()
        : '0.00';
    final mrrPro = (_finanzasSaaS['mrrPro'] != null)
        ? _finanzasSaaS['mrrPro'].toString()
        : '0.00';
    final mrrCorp = (_finanzasSaaS['mrrCorp'] != null)
        ? _finanzasSaaS['mrrCorp'].toString()
        : '0.00';

    final totalBodegas = _finanzasSaaS['totalBodegas']?.toString() ?? '0';
    final activas = _finanzasSaaS['activas']?.toString() ?? '0';
    final proCount = _finanzasSaaS['proCount']?.toString() ?? '0';
    final corpCount = _finanzasSaaS['corporativoCount']?.toString() ?? '0';
    final basicoCount = _finanzasSaaS['basicoCount']?.toString() ?? '0';

    final porVencer = (_finanzasSaaS['porVencer'] as List<dynamic>?) ?? [];
    final vencidas = (_finanzasSaaS['vencidas'] as List<dynamic>?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Tarjetas de Métricas MRR
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiCard(
              title: 'MRR RECURRENTE TOTAL',
              value: 'S/ $mrrTotal',
              icon: LucideIcons.trendingUp,
              color: AppTheme.brandPrimary,
              subtitle: 'Proyección mensual SaaS',
              isDark: isDark,
            ),
            _buildKpiCard(
              title: 'MRR PLAN PRO',
              value: 'S/ $mrrPro',
              icon: LucideIcons.crown,
              color: const Color(0xFFF59E0B),
              subtitle: '$proCount bodegas × S/ 49.90',
              isDark: isDark,
            ),
            _buildKpiCard(
              title: 'MRR CORPORATIVO',
              value: 'S/ $mrrCorp',
              icon: LucideIcons.building2,
              color: const Color(0xFF7C3AED),
              subtitle: '$corpCount cadenas × S/ 149.00',
              isDark: isDark,
            ),
            _buildKpiCard(
              title: 'DISTRIBUCIÓN CLIENTES',
              value: '$activas / $totalBodegas Activas',
              icon: LucideIcons.store,
              color: AppTheme.accentGreen,
              subtitle: '$basicoCount Básico • $proCount PRO • $corpCount Corp',
              isDark: isDark,
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Sección: Suscripciones Vencidas (Acción Inmediata)
        if (vencidas.isNotEmpty) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.alertRed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.alertOctagon, color: AppTheme.alertRed, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Suscripciones Vencidas (${vencidas.length})',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.alertRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...vencidas.map(
            (item) => _buildCobranzaCard(
              item as Map<String, dynamic>,
              isDark,
              vencido: true,
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Sección: Suscripciones por vencer en los próximos 7 días
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.clock, color: Colors.amber.shade800, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Próximas a Vencer (<= 7 días) (${porVencer.length})',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (porVencer.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkElevated : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.borderDarkElevated : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.checkCircle2, color: AppTheme.accentGreen, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '¡Excelente! No hay bodegas con suscripciones próximas a vencer en los próximos 7 días.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...porVencer.map(
            (item) => _buildCobranzaCard(
              item as Map<String, dynamic>,
              isDark,
              vencido: false,
            ),
          ),
      ],
    );
  }

  Widget _buildCobranzaCard(
    Map<String, dynamic> item,
    bool isDark, {
    required bool vencido,
  }) {
    final nombre = item['nombreComercial']?.toString() ?? 'Bodega';
    final plan = item['plan']?.toString() ?? 'PRO';
    final dias = (item['diasRestantes'] as num?)?.toInt() ?? 0;
    final telefono = item['telefono']?.toString() ?? '';
    final whatsappUrl = item['whatsappUrl']?.toString() ?? '';
    final colorPrimario = item['colorPrimario']?.toString() ?? '#2563EB';
    final bodegaColor = _parseHexToColor(colorPrimario);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkElevated : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: vencido
              ? AppTheme.alertRed.withValues(alpha: 0.5)
              : Colors.amber.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar de Tienda con su color
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bodegaColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: bodegaColor.withValues(alpha: 0.6), width: 1.5),
            ),
            child: Center(
              child: Icon(LucideIcons.store, color: bodegaColor, size: 22),
            ),
          ),
          const SizedBox(width: 14),

          // Info de la Tienda
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nombre,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: vencido
                            ? AppTheme.alertRed.withValues(alpha: 0.15)
                            : Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        vencido ? 'Venció hace ${dias.abs()}d' : 'Vence en ${dias}d',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: vencido ? AppTheme.alertRed : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Plan $plan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    if (telefono.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: isDark ? Colors.white38 : Colors.black26)),
                      const SizedBox(width: 8),
                      Icon(LucideIcons.phone, size: 12, color: isDark ? Colors.white54 : Colors.black45),
                      const SizedBox(width: 4),
                      Text(
                        telefono,
                        style: GoogleFonts.firaCode(
                          fontSize: 11.5,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Botones de Acción
          Wrap(
            spacing: 8,
            children: [
              if (whatsappUrl.isNotEmpty)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(LucideIcons.messageCircle, size: 16),
                  label: const Text('Cobrar por WhatsApp'),
                  onPressed: () async {
                    final uri = Uri.parse(whatsappUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PESTAÑA 5: SUGERENCIAS GLOBALES & MONITOREO DE PRECIOS
  // ===========================================================================

  void _abrirModalSugerirPrecioGlobal() {
    _tabController.animateTo(5); // Lleva al tab Starter Pack Preset
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Selecciona cualquier producto del Preset Starter Pack y pulsa "Sugerir a Bodegas" para proponer precios a la red.',
        ),
        backgroundColor: Color(0xFF7C3AED),
        duration: Duration(seconds: 4),
      ),
    );
  }

  Widget _buildTabSugerenciasGlobales(bool isDark) {
    final total = _estadisticasSugerencias['totalSugerencias']?.toString() ?? '0';
    final pendientes = _estadisticasSugerencias['pendientes']?.toString() ?? '0';
    final aceptadas = _estadisticasSugerencias['aceptadas']?.toString() ?? '0';
    final rechazadas = _estadisticasSugerencias['rechazadas']?.toString() ?? '0';
    final tasa = _estadisticasSugerencias['tasaAceptacionPorcentaje'] != null
        ? '${_estadisticasSugerencias['tasaAceptacionPorcentaje']}%'
        : '0%';

    final filtradas = _sugerenciasSuperadmin.where((s) {
      if (_filtroEstadoSugerenciaSuperadmin != 'TODOS') {
        if (s.estado.toUpperCase() != _filtroEstadoSugerenciaSuperadmin) return false;
      }
      final query = _searchSugerenciaCtrl.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final prod = s.nombreActual.toLowerCase();
        final sug = (s.nombreSugerido ?? '').toLowerCase();
        final bodega = (s.nombreBodega ?? '').toLowerCase();
        final codigo = s.codigoBarras.toLowerCase();
        if (!prod.contains(query) && !sug.contains(query) && !bodega.contains(query) && !codigo.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Métricas de Sugerencias
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiCard(
              title: 'TOTAL SUGERENCIAS',
              value: total,
              icon: LucideIcons.sparkles,
              color: AppTheme.brandPrimary,
              subtitle: 'Propuestas emitidas a la red',
              isDark: isDark,
            ),
            _buildKpiCard(
              title: 'PENDIENTES',
              value: pendientes,
              icon: LucideIcons.clock,
              color: const Color(0xFFF59E0B),
              subtitle: 'Esperando respuesta de bodegas',
              isDark: isDark,
            ),
            _buildKpiCard(
              title: 'ACEPTADAS',
              value: aceptadas,
              icon: LucideIcons.checkCircle2,
              color: AppTheme.accentGreen,
              subtitle: 'Precios adoptados con éxito',
              isDark: isDark,
            ),
            _buildKpiCard(
              title: 'TASA DE ADOPCIÓN',
              value: tasa,
              icon: LucideIcons.percent,
              color: const Color(0xFF7C3AED),
              subtitle: '$rechazadas rechazadas por bodegas',
              isDark: isDark,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Barra de Búsqueda y Filtros
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchSugerenciaCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar por producto, bodega o código de barras...',
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: _searchSugerenciaCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          onPressed: () {
                            setState(() {
                              _searchSugerenciaCtrl.clear();
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(LucideIcons.sparkles, size: 16),
              label: const Text('Nueva Sugerencia'),
              onPressed: () => _abrirModalSugerirPrecioGlobal(),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Filtro por Estado
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFiltroSugerenciaChip('TODOS', 'Todas', isDark),
              const SizedBox(width: 8),
              _buildFiltroSugerenciaChip('PENDIENTE', 'Pendientes', isDark),
              const SizedBox(width: 8),
              _buildFiltroSugerenciaChip('ACEPTADA', 'Aceptadas', isDark),
              const SizedBox(width: 8),
              _buildFiltroSugerenciaChip('RECHAZADA', 'Rechazadas', isDark),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (filtradas.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  LucideIcons.inbox,
                  size: 48,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
                const SizedBox(height: 12),
                Text(
                  'No hay sugerencias que coincidan con los filtros.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          )
        else
          ...filtradas.map((s) => _buildSugerenciaSuperadminCard(s, isDark)),
      ],
    );
  }

  Widget _buildFiltroSugerenciaChip(String estado, String label, bool isDark) {
    final isSelected = _filtroEstadoSugerenciaSuperadmin == estado;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _filtroEstadoSugerenciaSuperadmin = estado;
          });
        }
      },
      selectedColor: AppTheme.brandPrimary,
      labelStyle: GoogleFonts.plusJakartaSans(
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildSugerenciaSuperadminCard(SugerenciaPrecioItem item, bool isDark) {
    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    switch (item.estado.toUpperCase()) {
      case 'ACEPTADA':
        badgeColor = AppTheme.accentGreen;
        badgeIcon = LucideIcons.checkCircle2;
        badgeText = 'Aceptada';
        break;
      case 'RECHAZADA':
        badgeColor = AppTheme.alertRed;
        badgeIcon = LucideIcons.xCircle;
        badgeText = 'Rechazada';
        break;
      default:
        badgeColor = const Color(0xFFF59E0B);
        badgeIcon = LucideIcons.clock;
        badgeText = 'Pendiente';
        break;
    }

    final diff = item.precioVentaSugerido - item.precioVentaActual;
    final diffPorcentaje = item.precioVentaActual > 0
        ? ((diff / item.precioVentaActual) * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkElevated : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.borderDarkElevated : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mini foto de producto o icono
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: item.imagenUrl != null && item.imagenUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          item.imagenUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(LucideIcons.package, size: 24),
                        ),
                      )
                    : const Icon(LucideIcons.package, size: 24),
              ),
              const SizedBox(width: 14),

              // Título y código
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nombreActual,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Código: ${item.codigoBarras}',
                          style: GoogleFonts.firaCode(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        if (item.nombreBodega != null) ...[
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(color: isDark ? Colors.white38 : Colors.black26)),
                          const SizedBox(width: 8),
                          Text(
                            'Bodega: ${item.nombreBodega}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.brandPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Badge Estado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 12, color: badgeColor),
                    const SizedBox(width: 5),
                    Text(
                      badgeText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Comparativa de Precios
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Precio Actual',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'S/ ${item.precioVentaActual.toStringAsFixed(2)}',
                        style: GoogleFonts.firaCode(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(LucideIcons.arrowRight, size: 16, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.brandPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.brandPrimary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Precio Sugerido',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.brandPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'S/ ${item.precioVentaSugerido.toStringAsFixed(2)}',
                            style: GoogleFonts.firaCode(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.brandPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${diff >= 0 ? '+' : ''}$diffPorcentaje%)',
                            style: GoogleFonts.firaCode(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: diff >= 0 ? AppTheme.accentGreen : AppTheme.alertRed,
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

          if (item.motivo != null && item.motivo!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Motivo: ${item.motivo}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
