import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/configuracion_ticket_service.dart';
import '../../core/permisos_cajero_service.dart';
import '../../core/responsive_layout.dart';
import '../../core/theme.dart';
import '../../core/theme_provider.dart';
import '../../core/thermal_ticket_service.dart';
import '../auth/auth_service.dart';
import '../home/bodega_service.dart';
import '../home/usuarios_service.dart';
import 'modal_generar_codigo_terminal.dart';

enum ConfiguracionTab { tienda, usuarios, hardware, online, plan }

class ConfiguracionScreen extends StatefulWidget {
  final ConfiguracionTab tabInicial;
  final VoidCallback? onConfigSaved;

  const ConfiguracionScreen({
    super.key,
    this.tabInicial = ConfiguracionTab.tienda,
    this.onConfigSaved,
  });

  static Future<void> abrir(
    BuildContext context, {
    ConfiguracionTab tabInicial = ConfiguracionTab.tienda,
    VoidCallback? onConfigSaved,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfiguracionScreen(
          tabInicial: tabInicial,
          onConfigSaved: onConfigSaved,
        ),
      ),
    );
  }

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final _bodegaService = BodegaService();
  final _usuariosService = UsuariosService();
  final _authService = AuthService();

  late ConfiguracionTab _currentTab;
  bool _isLoading = true;
  bool _isSaving = false;

  BodegaInfo? _bodegaInfo;
  List<UsuarioItem> _usuarios = [];
  List<Map<String, dynamic>> _terminalesPOS = [];
  bool _cargandoTerminales = false;

  // Pestaña 1: Mi Tienda & Identidad
  final _nombreCtrl = TextEditingController();
  final _rucCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _lemaCtrl = TextEditingController();
  String _selectedHex = '#2563EB';

  // Pestaña 2: Permisos de Cajero
  bool _verCostos = false;
  bool _aplicarDescuentos = true;
  bool _anularSinPin = false;
  bool _modificarPrecios = false;
  bool _verFinanzas = false;
  String _activePreset = 'estandar';

  // Pestaña 3: Hardware & Tickets
  int _anchoPapel = ThermalTicketService.width58mm;
  String _modoConexion = 'rawbt';
  bool _abrirGaveta = true;
  bool _impresionAutomatica = false;
  bool _mostrarQr = false;
  String _tipoQr = 'YAPE';
  final _numeroQrCtrl = TextEditingController();
  final _titularQrCtrl = TextEditingController();

  // Pestaña 4: Canales & Mi Tienda Web
  bool _catalogoAbierto = true;
  bool _deliveryActivo = true;
  final _slugCtrl = TextEditingController();
  final _whatsappDeliveryCtrl = TextEditingController();
  final _pedidoMinimoCtrl = TextEditingController();
  final _horarioAtencionCtrl = TextEditingController();

  // Pestaña 5: Plan
  String _planActual = 'PRO';

  String get _giroNegocio =>
      (_bodegaInfo?.giroNegocio ?? 'BODEGA').toUpperCase();

  bool get _esGastronomico =>
      _giroNegocio == 'POLLERIA' ||
      _giroNegocio == 'CHIFA' ||
      _giroNegocio == 'FASTFOOD' ||
      _giroNegocio == 'RESTAURANTE';

  String get _tituloTabOnline {
    switch (_giroNegocio) {
      case 'POLLERIA':
        return 'Carta Digital Pollería & Pedidos';
      case 'CHIFA':
        return 'Carta Digital Chifa & Pedidos';
      case 'FASTFOOD':
        return 'Menú Digital Fast Food & Pedidos';
      case 'RESTAURANTE':
        return 'Carta Digital Restaurante & Pedidos';
      case 'BODEGA':
      default:
        return 'Catálogo Web & Pedidos por WhatsApp';
    }
  }

  String get _subtituloTabOnline {
    if (_esGastronomico) {
      return 'Tu carta gastronómica digital disponible 24/7 para tus clientes';
    }
    return 'Tu vitrina digital disponible 24/7 para tus vecinos';
  }

  String get _tituloQrCartel {
    if (_esGastronomico) {
      return 'Código QR para Salón y Mostrador';
    }
    return 'Código QR para tu Vitrina';
  }

  String get _subtituloQrCartel {
    if (_esGastronomico) {
      return 'Imprime este cartel con tu código QR para ver la carta digital en mesa o para llevar';
    }
    return 'Imprime este cartel con tu color de marca para pedidos desde casa';
  }

  @override
  void initState() {
    super.initState();
    _currentTab = widget.tabInicial;
    _cargarDatosGlobales();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _rucCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _lemaCtrl.dispose();
    _numeroQrCtrl.dispose();
    _titularQrCtrl.dispose();
    _slugCtrl.dispose();
    _whatsappDeliveryCtrl.dispose();
    _pedidoMinimoCtrl.dispose();
    _horarioAtencionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosGlobales() async {
    setState(() => _isLoading = true);
    try {
      final info = await _bodegaService.obtenerMiBodega();
      final users = await _usuariosService.listarUsuarios().catchError(
        (_) => <UsuarioItem>[],
      );
      final ticketCfg = await ConfiguracionTicketService.cargar();
      final permisos = await PermisosCajeroService.obtenerPermisos();

      if (mounted) {
        setState(() {
          _bodegaInfo = info;
          _usuarios = users;

          if (info != null) {
            _nombreCtrl.text = info.nombreComercial;
            _rucCtrl.text = info.rucDni ?? '';
            _telefonoCtrl.text = info.telefono ?? '';
            _direccionCtrl.text = info.direccion ?? '';
            _lemaCtrl.text =
                info.lemaComercial ?? '¡Gracias por su compra, vuelva pronto!';
            _selectedHex = info.colorPrimario;
            _catalogoAbierto = info.catalogoAbierto;
            _deliveryActivo = info.deliveryActivo;
            _planActual = info.plan;
            _slugCtrl.text = info.nombreComercial.toLowerCase().replaceAll(
              RegExp(r'[^a-z0-9]'),
              '-',
            );
            _whatsappDeliveryCtrl.text = info.telefono ?? '';
            _pedidoMinimoCtrl.text = '15.00';
            _horarioAtencionCtrl.text = 'Lunes a Sábado: 8:00 am - 10:00 pm';
          }

          // Ticket
          _anchoPapel = ticketCfg.anchoPapel;
          _modoConexion = ticketCfg.modoConexion;
          _abrirGaveta = ticketCfg.abrirGaveta;
          _impresionAutomatica = ticketCfg.impresionAutomatica;
          _mostrarQr = ticketCfg.mostrarQr;
          _tipoQr = (ticketCfg.tipoQr == 'SUNAT') ? 'YAPE' : ticketCfg.tipoQr;
          _numeroQrCtrl.text = ticketCfg.numeroQr.isNotEmpty
              ? ticketCfg.numeroQr
              : (_telefonoCtrl.text);
          _titularQrCtrl.text = ticketCfg.titularQr.isNotEmpty
              ? ticketCfg.titularQr
              : (_nombreCtrl.text);

          // Permisos
          _verCostos = permisos.verCostosYMargen;
          _aplicarDescuentos = permisos.aplicarDescuentosManuales;
          _anularSinPin = permisos.anularVentasSinPin;
          _modificarPrecios = permisos.modificarPreciosVenta;
          _verFinanzas = permisos.verReportesFinanzas;
          _detectarPresetActivo();

          _isLoading = false;
        });
        _cargarTerminalesPOS();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarTerminalesPOS() async {
    setState(() => _cargandoTerminales = true);
    try {
      final list = await _authService.listarTerminales();
      if (mounted) {
        setState(() {
          _terminalesPOS = list;
          _cargandoTerminales = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoTerminales = false);
    }
  }

  Future<void> _abrirModalNuevoCodigoTerminal() async {
    await ModalGenerarCodigoTerminal.show(
      context,
      authService: _authService,
      onCerrar: () {
        _cargarTerminalesPOS();
      },
    );
  }

  Future<void> _confirmarRevocarTerminal(int idTerminal, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '¿Revocar terminal "$nombre"?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Este dispositivo perderá su autorización y no podrá iniciar sesión con PIN ni consultar cajeros.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Revocar Acceso',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      final ok = await _authService.revocarTerminal(idTerminal);
      if (ok && mounted) {
        _cargarTerminalesPOS();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Terminal "$nombre" revocada exitosamente.',
              style: GoogleFonts.plusJakartaSans(),
            ),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    }
  }

  void _detectarPresetActivo() {
    if (!_verCostos &&
        !_aplicarDescuentos &&
        !_anularSinPin &&
        !_modificarPrecios &&
        !_verFinanzas) {
      _activePreset = 'estricto';
    } else if (!_verCostos &&
        _aplicarDescuentos &&
        !_anularSinPin &&
        !_modificarPrecios &&
        !_verFinanzas) {
      _activePreset = 'estandar';
    } else if (_verCostos &&
        _aplicarDescuentos &&
        _anularSinPin &&
        !_modificarPrecios &&
        _verFinanzas) {
      _activePreset = 'confianza';
    } else {
      _activePreset = 'custom';
    }
  }

  void _aplicarPresetSeguridad(String presetKey) {
    HapticFeedback.selectionClick();
    setState(() {
      _activePreset = presetKey;
      if (presetKey == 'estricto') {
        _verCostos = false;
        _aplicarDescuentos = false;
        _anularSinPin = false;
        _modificarPrecios = false;
        _verFinanzas = false;
      } else if (presetKey == 'estandar') {
        _verCostos = false;
        _aplicarDescuentos = true;
        _anularSinPin = false;
        _modificarPrecios = false;
        _verFinanzas = false;
      } else if (presetKey == 'confianza') {
        _verCostos = true;
        _aplicarDescuentos = true;
        _anularSinPin = true;
        _modificarPrecios = false;
        _verFinanzas = true;
      }
    });
  }

  Future<void> _guardarTodo() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      // 1. Guardar datos de bodega y color
      if (_bodegaInfo != null) {
        await _bodegaService.actualizarConfiguracion(
          nombreComercial: _nombreCtrl.text.trim().isNotEmpty
              ? _nombreCtrl.text.trim()
              : _bodegaInfo!.nombreComercial,
          rucDni: _rucCtrl.text.trim(),
          direccion: _direccionCtrl.text.trim(),
          telefono: _telefonoCtrl.text.trim(),
          lemaComercial: _lemaCtrl.text.trim(),
          colorPrimario: _selectedHex,
          catalogoAbierto: _catalogoAbierto,
          deliveryActivo: _deliveryActivo,
        );
      }

      // 2. Aplicar color dinámico en ThemeProvider
      if (mounted) {
        Provider.of<ThemeProvider>(
          context,
          listen: false,
        ).setAccentColorFromHex(_selectedHex);
      }

      // 3. Guardar permisos de cajero
      final nuevosPermisos = PermisosCajero(
        verCostosYMargen: _verCostos,
        aplicarDescuentosManuales: _aplicarDescuentos,
        anularVentasSinPin: _anularSinPin,
        modificarPreciosVenta: _modificarPrecios,
        verReportesFinanzas: _verFinanzas,
      );
      await PermisosCajeroService.guardarPermisos(nuevosPermisos);

      // 4. Guardar configuración de ticket
      final ticketCfg = ConfiguracionTicket(
        anchoPapel: _anchoPapel,
        abrirGaveta: _abrirGaveta,
        impresionAutomatica: _impresionAutomatica,
        modoConexion: _modoConexion,
        mensajeAgradecimiento: _lemaCtrl.text.trim(),
        mostrarQr: _mostrarQr,
        tipoQr: _tipoQr,
        numeroQr: _numeroQrCtrl.text.trim(),
        titularQr: _titularQrCtrl.text.trim(),
      );
      await ConfiguracionTicketService.guardar(ticketCfg);

      widget.onConfigSaved?.call();

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Row(
              children: [
                const Icon(
                  LucideIcons.checkCircle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¡Configuración y privilegios guardados correctamente!',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.alertRed,
            content: Text('Error al guardar: $e'),
          ),
        );
      }
    }
  }

  Color _hexToColor(String hex) {
    String cleanHex = hex.replaceAll('#', '');
    if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
    return Color(int.parse('0x$cleanHex'));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF090A0F)
          : const Color(0xFFF8FAFC),
      appBar: _buildAppBar(isDark, primaryColor),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16,
                  vertical: 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScreenHeader(isDark, primaryColor, isDesktop),
                    const SizedBox(height: 18),
                    _buildCapsuleTabBar(isDark, primaryColor),
                    const SizedBox(height: 20),
                    _buildActiveTabContent(isDark, primaryColor, isDesktop),
                  ],
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, Color primaryColor) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(
          LucideIcons.arrowLeft,
          color: isDark ? Colors.white : AppTheme.textDark,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Centro de Control & Configuración',
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : AppTheme.textDark,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
          height: 1,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: ElevatedButton.icon(
            key: const Key('btnGuardarMaster'),
            onPressed: _isSaving ? null : _guardarTodo,
            icon: _isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(LucideIcons.check, size: 16),
            label: Text(
              _isSaving ? 'Guardando...' : 'Guardar Cambios',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenHeader(bool isDark, Color primaryColor, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                LucideIcons.slidersHorizontal,
                color: primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configuración de Tienda & Usuarios',
                    style: GoogleFonts.outfit(
                      fontSize: isDesktop ? 22 : 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                  Text(
                    'Personaliza tu perfil comercial, roles de caja, ticket térmico y vitrina web.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCapsuleTabBar(bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141724) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF262E44) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTabCapsule(
              tab: ConfiguracionTab.tienda,
              label: '1. Mi Tienda & Identidad',
              icon: LucideIcons.store,
              isDark: isDark,
              primaryColor: primaryColor,
            ),
            _buildTabCapsule(
              tab: ConfiguracionTab.usuarios,
              label: '2. Equipo & Seguridad',
              icon: LucideIcons.users,
              badge: '${_usuarios.length}',
              isDark: isDark,
              primaryColor: primaryColor,
            ),
            _buildTabCapsule(
              tab: ConfiguracionTab.hardware,
              label: '3. Hardware & Tickets',
              icon: LucideIcons.printer,
              isDark: isDark,
              primaryColor: primaryColor,
            ),
            _buildTabCapsule(
              tab: ConfiguracionTab.online,
              label: '4. Canales & Tienda Web',
              icon: LucideIcons.globe,
              badge: _catalogoAbierto ? 'Abierta' : 'Cerrada',
              badgeColor: _catalogoAbierto
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              isDark: isDark,
              primaryColor: primaryColor,
            ),
            _buildTabCapsule(
              tab: ConfiguracionTab.plan,
              label: '5. Plan & Facturación',
              icon: LucideIcons.crown,
              badge: _planActual.toUpperCase(),
              badgeColor: const Color(0xFFD97706),
              isDark: isDark,
              primaryColor: primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabCapsule({
    required ConfiguracionTab tab,
    required String label,
    required IconData icon,
    String? badge,
    Color? badgeColor,
    required bool isDark,
    required Color primaryColor,
  }) {
    final isSelected = _currentTab == tab;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentTab = tab);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? primaryColor
                  : (isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? primaryColor
                    : (isDark ? Colors.white : AppTheme.textDark),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor != null
                      ? badgeColor.withValues(alpha: 0.15)
                      : (isSelected
                            ? primaryColor
                            : (isDark
                                  ? const Color(0xFF262E44)
                                  : const Color(0xFFE2E8F0))),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color:
                        badgeColor ??
                        (isSelected
                            ? Colors.white
                            : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B))),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(
    bool isDark,
    Color primaryColor,
    bool isDesktop,
  ) {
    switch (_currentTab) {
      case ConfiguracionTab.tienda:
        return _buildTabTienda(isDark, primaryColor, isDesktop);
      case ConfiguracionTab.usuarios:
        return _buildTabUsuarios(isDark, primaryColor, isDesktop);
      case ConfiguracionTab.hardware:
        return _buildTabHardware(isDark, primaryColor, isDesktop);
      case ConfiguracionTab.online:
        return _buildTabOnline(isDark, primaryColor, isDesktop);
      case ConfiguracionTab.plan:
        return _buildTabPlan(isDark, primaryColor, isDesktop);
    }
  }

  // --- TAB 1: MI TIENDA & IDENTIDAD ---
  Widget _buildTabTienda(bool isDark, Color primaryColor, bool isDesktop) {
    final card1 = _buildCard(
      isDark: isDark,
      icon: LucideIcons.building,
      title: 'Perfil Comercial & SUNAT',
      subtitle:
          'Datos impresos en tickets físicos y visibles en tu catálogo digital',
      child: Column(
        children: [
          _buildTextField(
            label: 'Nombre Comercial de la Tienda',
            controller: _nombreCtrl,
            icon: LucideIcons.store,
            isDark: isDark,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'RUC / DNI Titular',
                  controller: _rucCtrl,
                  icon: LucideIcons.fileText,
                  isDark: isDark,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTextField(
                  label: 'Teléfono de Caja',
                  controller: _telefonoCtrl,
                  icon: LucideIcons.phone,
                  isDark: isDark,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Dirección Comercial',
            controller: _direccionCtrl,
            icon: LucideIcons.mapPin,
            isDark: isDark,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Lema Comercial o Frase de Ticket',
            controller: _lemaCtrl,
            icon: LucideIcons.quote,
            isDark: isDark,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );

    final card2 = _buildCard(
      isDark: isDark,
      icon: LucideIcons.palette,
      title: 'Color Primario de Tienda',
      subtitle: 'Personaliza los acentos en mostrador POS, app móvil y web',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecciona el color corporativo que mejor represente a tu negocio:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kColorPresets.map((preset) {
              final isSelected =
                  _selectedHex.toUpperCase() == preset.hex.toUpperCase();
              return InkWell(
                key: Key('swatch_${preset.hex}'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedHex = preset.hex);
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: preset.color,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: preset.color.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(
                          LucideIcons.check,
                          color: Colors.white,
                          size: 20,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text(
            'VISTA PREVIA EN INTERFAZ POS',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1420) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF262E44)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _hexToColor(_selectedHex),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _nombreCtrl.text.isNotEmpty
                        ? _nombreCtrl.text[0].toUpperCase()
                        : 'C',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nombreCtrl.text.isNotEmpty
                            ? _nombreCtrl.text
                            : 'Mi Bodega',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Caja en Línea • Turno Activo',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _hexToColor(_selectedHex),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Cobrar S/ 48.50',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return isDesktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: card1),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: card2),
            ],
          )
        : Column(children: [card1, const SizedBox(height: 16), card2]);
  }

  // --- TAB 2: EQUIPO & SEGURIDAD DE CAJERO ---
  Widget _buildTabUsuarios(bool isDark, Color primaryColor, bool isDesktop) {
    final cardPersonal = _buildCard(
      isDark: isDark,
      icon: LucideIcons.users,
      title: 'Personal & Cajeros Registrados',
      subtitle: 'Cuentas con acceso a tu terminal y mostrador',
      action: ElevatedButton.icon(
        key: const Key('btnNuevoCajero'),
        onPressed: _abrirModalCrearUsuario,
        icon: const Icon(LucideIcons.userPlus, size: 14),
        label: Text(
          'Nuevo Cajero',
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      child: Column(
        children: [
          if (_usuarios.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No hay colaboradores registrados.',
                style: GoogleFonts.plusJakartaSans(
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
            )
          else
            ..._usuarios.map((u) => _buildUsuarioTile(u, isDark, primaryColor)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.shieldCheck, color: primaryColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Plan PRO Activo: Puedes crear cajeros ilimitados con PIN individual de 4 dígitos para arqueos por turno.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final cardPermisos = _buildCard(
      isDark: isDark,
      icon: LucideIcons.shieldAlert,
      title: 'Matriz de Privilegios de Cajero',
      subtitle:
          'Protección contra fugas de margen y cancelaciones no autorizadas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PLANTILLAS RÁPIDAS DE SEGURIDAD',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetButton(
                keyName: 'estricto',
                label: 'Cajero Estricto (Nuevo)',
                icon: LucideIcons.lock,
                isDark: isDark,
                primaryColor: primaryColor,
              ),
              _buildPresetButton(
                keyName: 'estandar',
                label: 'Cajero Regular',
                icon: LucideIcons.sliders,
                isDark: isDark,
                primaryColor: primaryColor,
              ),
              _buildPresetButton(
                keyName: 'confianza',
                label: 'Encargado de Confianza',
                icon: LucideIcons.sparkles,
                isDark: isDark,
                primaryColor: primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _buildPermissionToggle(
            key: const Key('permCostos'),
            title: 'Ver Precios de Costo y Margen',
            desc: 'Permite al cajero ver cuánto te cuesta cada producto y el margen de ganancia.',
            badge: 'SENSIBLE',
            badgeColor: AppTheme.alertRed,
            value: _verCostos,
            onChanged: (val) => setState(() {
              _verCostos = val;
              _detectarPresetActivo();
            }),
            isDark: isDark,
            primaryColor: primaryColor,
          ),
          _buildPermissionToggle(
            key: const Key('permDescuentos'),
            title: 'Aplicar Descuentos Manuales en Mostrador',
            desc: 'Habilita rebajar soles directamente al momento de cobrar sin requerir PIN supervisor.',
            value: _aplicarDescuentos,
            onChanged: (val) => setState(() {
              _aplicarDescuentos = val;
              _detectarPresetActivo();
            }),
            isDark: isDark,
            primaryColor: primaryColor,
          ),
          _buildPermissionToggle(
            key: const Key('permAnular'),
            title: 'Anular Ventas o Quitar Ítems sin PIN Maestro',
            desc: 'Si está desactivado, el sistema pedirá el PIN del Administrador antes de cancelar un ticket.',
            badge: 'ALERTA',
            badgeColor: AppTheme.alertRed,
            value: _anularSinPin,
            onChanged: (val) => setState(() {
              _anularSinPin = val;
              _detectarPresetActivo();
            }),
            isDark: isDark,
            primaryColor: primaryColor,
          ),
          _buildPermissionToggle(
            key: const Key('permPrecios'),
            title: 'Modificar Precios de Venta al Cobrar',
            desc: 'Permite alterar el precio unitario del catálogo directamente desde la lista de cobro.',
            value: _modificarPrecios,
            onChanged: (val) => setState(() {
              _modificarPrecios = val;
              _detectarPresetActivo();
            }),
            isDark: isDark,
            primaryColor: primaryColor,
          ),
          _buildPermissionToggle(
            key: const Key('permFinanzas'),
            title: 'Ver Reportes y Finanzas Globales',
            desc: 'Acceso al historial de facturación de días anteriores y métricas de balance mensual.',
            value: _verFinanzas,
            onChanged: (val) => setState(() {
              _verFinanzas = val;
              _detectarPresetActivo();
            }),
            isDark: isDark,
            primaryColor: primaryColor,
          ),
        ],
      ),
    );

    return isDesktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: cardPersonal),
              const SizedBox(width: 20),
              Expanded(flex: 3, child: cardPermisos),
            ],
          )
        : Column(
            children: [cardPersonal, const SizedBox(height: 16), cardPermisos],
          );
  }

  Widget _buildUsuarioTile(UsuarioItem u, bool isDark, Color primaryColor) {
    final isAdmin =
        u.rol.toUpperCase() == 'ADMIN' || u.rol.toUpperCase() == 'SUPERADMIN';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2436) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF262E44) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isAdmin
                ? primaryColor.withValues(alpha: 0.15)
                : const Color(0xFF10B981).withValues(alpha: 0.15),
            foregroundColor: isAdmin ? primaryColor : const Color(0xFF10B981),
            child: Text(
              u.username.isNotEmpty ? u.username[0].toUpperCase() : 'U',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
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
                        u.nombreCompleto?.isNotEmpty == true
                            ? u.nombreCompleto!
                            : u.username,
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isAdmin
                            ? primaryColor.withValues(alpha: 0.15)
                            : const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        u.rol.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: isAdmin
                              ? primaryColor
                              : const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Usuario: @${u.username} • Estado: ${u.estado ? "Activo" : "Pausado"}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(LucideIcons.keyRound, size: 16),
                tooltip: 'Cambiar PIN',
                onPressed: () => _abrirModalCambiarPin(u),
              ),
              IconButton(
                icon: Icon(
                  u.estado ? LucideIcons.pauseCircle : LucideIcons.playCircle,
                  size: 16,
                  color: u.estado
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF10B981),
                ),
                tooltip: u.estado ? 'Pausar cuenta' : 'Reactivar cuenta',
                onPressed: () => _toggleEstadoUsuario(u),
              ),
              if (!isAdmin)
                IconButton(
                  icon: const Icon(
                    LucideIcons.trash2,
                    size: 16,
                    color: AppTheme.alertRed,
                  ),
                  tooltip: 'Eliminar colaborador',
                  onPressed: () => _confirmarEliminarUsuario(u),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton({
    required String keyName,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color primaryColor,
  }) {
    final isSelected = _activePreset == keyName;

    return InkWell(
      onTap: () => _aplicarPresetSeguridad(keyName),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF1E2436) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? const Color(0xFF262E44) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? primaryColor
                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? primaryColor
                    : (isDark ? Colors.white : AppTheme.textDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionToggle({
    Key? key,
    required String title,
    required String desc,
    String? badge,
    Color? badgeColor,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? primaryColor).withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: badgeColor ?? primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            key: key,
            value: value,
            activeTrackColor: primaryColor,
            activeThumbColor: Colors.white,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              onChanged(val);
            },
          ),
        ],
      ),
    );
  }

  // --- TAB 3: HARDWARE & TICKETS TÉRMICOS ---
  Widget _buildTabHardware(bool isDark, Color primaryColor, bool isDesktop) {
    final cardHardware = _buildCard(
      isDark: isDark,
      icon: LucideIcons.printer,
      title: 'Impresora Térmica & Mostrador',
      subtitle: 'Conexión de periféricos, cajón portamonedas y tickets',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de Estado de Conexión
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.bluetooth,
                    size: 18,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Impresora ESC/POS Lista',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppTheme.brandInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Canal activo (Bluetooth / USB / RawBT)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF10B981),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        content: Row(
                          children: [
                            const Icon(
                              LucideIcons.checkCircle,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Canal de impresora térmica verificado y activo.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.refreshCw, size: 13),
                  label: Text(
                    'Probar',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(
                      color: primaryColor.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ANCHO DE PAPEL TÉRMICO',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildChoiceButton(
                  key: const Key('btnPapel58'),
                  label: '58 mm (Estándar)',
                  subtitle: '32 cols • Móvil',
                  icon: LucideIcons.receipt,
                  selected: _anchoPapel == ThermalTicketService.width58mm,
                  onTap: () => setState(
                    () => _anchoPapel = ThermalTicketService.width58mm,
                  ),
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChoiceButton(
                  key: const Key('btnPapel80'),
                  label: '80 mm (Mostrador Ancho)',
                  subtitle: '48 cols • Epson / Xprinter',
                  icon: LucideIcons.scroll,
                  selected: _anchoPapel == ThermalTicketService.width80mm,
                  onTap: () => setState(
                    () => _anchoPapel = ThermalTicketService.width80mm,
                  ),
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPermissionToggle(
            title: 'Abrir Gaveta de Dinero Automáticamente',
            desc: 'Envía pulso eléctrico ESC/POS (Pin 2/5) al confirmar venta en efectivo.',
            value: _abrirGaveta,
            onChanged: (val) => setState(() => _abrirGaveta = val),
            isDark: isDark,
            primaryColor: primaryColor,
          ),
          _buildPermissionToggle(
            title: 'Impresión Automática al Cobrar',
            desc: 'Imprime el ticket inmediatamente sin requerir tocar el botón "Imprimir".',
            value: _impresionAutomatica,
            onChanged: (val) => setState(() => _impresionAutomatica = val),
            isDark: isDark,
            primaryColor: primaryColor,
          ),
          _buildPermissionToggle(
            key: const Key('checkQrTicket'),
            title: 'Imprimir Código QR de Pago en el Ticket',
            desc: 'Agrega el QR de Yape / Plin al pie para que clientes escaneen y paguen.',
            value: _mostrarQr,
            onChanged: (val) => setState(() => _mostrarQr = val),
            isDark: isDark,
            primaryColor: primaryColor,
          ),
          if (_mostrarQr) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E2436)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _tipoQr,
                      decoration: const InputDecoration(
                        labelText: 'Billetera',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'YAPE',
                          child: Text(
                            'Yape (BCP)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'PLIN',
                          child: Text(
                            'Plin (Interbank/BBVA)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _tipoQr = val ?? 'YAPE'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      label: 'Número de Celular',
                      controller: _numeroQrCtrl,
                      icon: LucideIcons.phone,
                      isDark: isDark,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.info, size: 16, color: primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'El encabezado del ticket (Nombre, RUC, Dirección, Teléfono y Lema) se sincroniza en vivo desde la pestaña "Mi Tienda & Identidad".',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final cardTicketSim = _buildCard(
      isDark: isDark,
      icon: LucideIcons.scanLine,
      title: 'Simulación de Ticket Térmico en Vivo',
      subtitle:
          'Visualiza exactamente cómo saldrá el papel impreso en mostrador',
      child: Column(
        children: [
          _buildThermalTicketSimulator(isDark, primaryColor),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                key: const Key('btnImprimirTicketPrueba'),
                onPressed: _imprimirTicketPrueba,
                icon: const Icon(LucideIcons.printer, size: 15),
                label: Text(
                  'Imprimir Ticket de Prueba',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('btnProbarGaveta'),
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  await ThermalTicketService.abrirGavetaDinero();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppTheme.brandPrimary,
                        behavior: SnackBarBehavior.floating,
                        content: const Text(
                          'Pulso de apertura de gaveta enviado (Pin 2/5 ESC/POS).',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(LucideIcons.banknote, size: 15),
                label: Text(
                  'Probar Gaveta',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark
                      ? Colors.white70
                      : const Color(0xFF334155),
                  side: BorderSide(
                    color: isDark
                        ? AppTheme.borderDark
                        : const Color(0xFFCBD5E1),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final cardTerminales = _buildCard(
      isDark: isDark,
      icon: LucideIcons.monitorSmartphone,
      title: 'Terminales POS y Cajas Vinculadas',
      subtitle: 'Dispositivos autorizados de forma segura para inicio rápido con PIN de cajero',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Cada terminal autorizada recibe una credencial criptográfica única de acceso.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _abrirModalNuevoCodigoTerminal,
                icon: const Icon(LucideIcons.plus, size: 14),
                label: Text(
                  'Vincular Terminal',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_cargandoTerminales)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_terminalesPOS.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.cardDarkSunken
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.info, size: 18, color: primaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No tienes terminales vinculadas aún. Haz clic en "Vincular Terminal" para generar un código OTP seguro de 6 dígitos.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _terminalesPOS.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final term = _terminalesPOS[idx];
                final bool activa = term['estado'] == true;
                final dynamic idTermRaw = term['idTerminal'];
                final int? idTerm = idTermRaw is int
                    ? idTermRaw
                    : (idTermRaw is num ? idTermRaw.toInt() : null);
                final String nombre =
                    term['nombre']?.toString() ?? 'Terminal POS';
                final String modelo =
                    term['deviceModel']?.toString() ?? 'Dispositivo Móvil';
                final String fecha = term['fechaVinculacion'] != null
                    ? term['fechaVinculacion'].toString().split('T').first
                    : '';

                return Container(
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
                          ? AppTheme.borderDark
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: activa
                              ? (isDark
                                    ? AppTheme.brandPrimary.withValues(
                                        alpha: 0.2,
                                      )
                                    : const Color(0xFFEFF6FF))
                              : (isDark
                                    ? Colors.red.withValues(alpha: 0.15)
                                    : const Color(0xFFFEF2F2)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          LucideIcons.monitorCheck,
                          size: 16,
                          color: activa ? primaryColor : AppTheme.alertRed,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    nombre,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.brandInk,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: activa
                                        ? AppTheme.accentGreen.withValues(
                                            alpha: 0.15,
                                          )
                                        : AppTheme.alertRed.withValues(
                                            alpha: 0.15,
                                          ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    activa ? 'Activa' : 'Revocada',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: activa
                                          ? AppTheme.accentGreen
                                          : AppTheme.alertRed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$modelo • Vinculada $fecha',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (activa && idTerm != null)
                        IconButton(
                          tooltip: 'Revocar terminal',
                          icon: const Icon(
                            LucideIcons.trash2,
                            size: 16,
                            color: AppTheme.alertRed,
                          ),
                          onPressed: () =>
                              _confirmarRevocarTerminal(idTerm, nombre),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );

    final bool useWideLayout =
        isDesktop || MediaQuery.of(context).size.width >= 800;

    return useWideLayout
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    cardHardware,
                    const SizedBox(height: 16),
                    cardTerminales,
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(flex: 5, child: cardTicketSim),
            ],
          )
        : Column(
            children: [
              cardHardware,
              const SizedBox(height: 16),
              cardTicketSim,
              const SizedBox(height: 16),
              cardTerminales,
            ],
          );
  }

  // --- SIMULADOR DE TICKET TÉRMICO & HARDWARE EN VIVO ---
  Widget _buildThermalTicketSimulator(bool isDark, Color primaryColor) {
    final bool is80mm = _anchoPapel == ThermalTicketService.width80mm;
    final double paperWidth = is80mm ? 320.0 : 255.0;
    final double headWidth = paperWidth + 36.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F121C) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF262E44) : const Color(0xFFCBD5E1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Cabezal de Impresión Hardware (Printer Head Chassis)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: headWidth,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
                bottom: Radius.circular(4),
              ),
              border: Border.all(color: const Color(0xFF374151), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.printer,
                      size: 15,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CAJAYA THERMAL POS',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: const Color(0xFFD1D5DB),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.8),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6)
                                .withValues(alpha: 0.8),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Ranura de Expulsión del Papel (Printer Feeding Slot)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: paperWidth + 16.0,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF030712),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 3. Hoja Física de Papel Térmico (Realistic Thermal Receipt Paper)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: paperWidth,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            child: DefaultTextStyle(
              style: GoogleFonts.firaCode(
                color: const Color(0xFF111827),
                fontSize: is80mm ? 10.5 : 9.5,
                height: 1.35,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Nombre del Comercio
                  Text(
                    _nombreCtrl.text.trim().isNotEmpty
                        ? _nombreCtrl.text.trim().toUpperCase()
                        : 'BODEGA SAN MARTÍN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: is80mm ? 13 : 11.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (_lemaCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '"${_lemaCtrl.text.trim()}"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 8.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    'RUC: ${_rucCtrl.text.trim().isNotEmpty ? _rucCtrl.text.trim() : "20601234567"}',
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    _direccionCtrl.text.trim().isNotEmpty
                        ? _direccionCtrl.text.trim()
                        : "Av. San Martín 450",
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Tel: ${_telefonoCtrl.text.trim().isNotEmpty ? _telefonoCtrl.text.trim() : "987 654 321"}',
                    textAlign: TextAlign.center,
                  ),

                  _buildReceiptDashedLine(),

                  // Badge de Documento
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF111827),
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'TICKET POS  B001-00293',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: is80mm ? 11 : 9.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '20/11/2026 14:35',
                        style: TextStyle(fontSize: is80mm ? 9.5 : 8.5),
                      ),
                      Text(
                        'Caja 1',
                        style: TextStyle(fontSize: is80mm ? 9.5 : 8.5),
                      ),
                    ],
                  ),

                  _buildReceiptDashedLine(),

                  // Tabla de Ítems
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'CANT  DESCRIPCIÓN',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: is80mm ? 10 : 9,
                          ),
                        ),
                      ),
                      Text(
                        'TOTAL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: is80mm ? 10 : 9,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '1  Arroz Costeño 1kg',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: is80mm ? 10 : 9),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'S/ 4.80',
                        style: TextStyle(fontSize: is80mm ? 10 : 9),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '2  Leche Gloria Azul 400g',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: is80mm ? 10 : 9),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'S/ 9.60',
                        style: TextStyle(fontSize: is80mm ? 10 : 9),
                      ),
                    ],
                  ),

                  _buildReceiptDashedLine(),

                  // Subtotales y Total
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'OP. GRAVADA:',
                          style: TextStyle(fontSize: is80mm ? 9.5 : 8.5),
                        ),
                      ),
                      Text(
                        'S/ 12.20',
                        style: TextStyle(fontSize: is80mm ? 9.5 : 8.5),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'I.G.V. (18%):',
                          style: TextStyle(fontSize: is80mm ? 9.5 : 8.5),
                        ),
                      ),
                      Text(
                        'S/ 2.20',
                        style: TextStyle(fontSize: is80mm ? 9.5 : 8.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'TOTAL A PAGAR:',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: is80mm ? 11.5 : 10.5,
                          ),
                        ),
                      ),
                      Text(
                        'S/ 14.40',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: is80mm ? 11.5 : 10.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'PAGO: EFECTIVO',
                          style: TextStyle(fontSize: is80mm ? 9.5 : 8.5),
                        ),
                      ),
                      Text(
                        'S/ 20.00',
                        style: TextStyle(fontSize: is80mm ? 9.5 : 8.5),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'VUELTO:',
                          style: TextStyle(fontSize: is80mm ? 9.5 : 8.5),
                        ),
                      ),
                      Text(
                        'S/ 5.60',
                        style: TextStyle(fontSize: is80mm ? 9.5 : 8.5),
                      ),
                    ],
                  ),

                  // QR de Pago Dinámico
                  if (_mostrarQr) ...[
                    _buildReceiptDashedLine(),
                    Text(
                      'PAGA CON $_tipoQr AL:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: is80mm ? 9.5 : 8.5,
                      ),
                    ),
                    Text(
                      _numeroQrCtrl.text.trim().isNotEmpty
                          ? _numeroQrCtrl.text.trim()
                          : "987 654 321",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: is80mm ? 10.5 : 9.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 68,
                      height: 68,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFF111827),
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.qrCode,
                          color: Color(0xFF111827),
                          size: 46,
                        ),
                      ),
                    ),
                  ],

                  _buildReceiptDashedLine(),

                  // Código de Barras Decorativo
                  _buildReceiptBarcode(is80mm),

                  const SizedBox(height: 6),
                  Text(
                    _lemaCtrl.text.trim().isNotEmpty
                        ? _lemaCtrl.text.trim()
                        : '¡Gracias por su preferencia!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: is80mm ? 9.5 : 8.5,
                      color: const Color(0xFF334151),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Borde en Zigzag / Dientes de Sierra (Sawtooth Jagged Edge)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: paperWidth,
            height: 6,
            child: const CustomPaint(
              size: Size.infinite,
              painter: _SawtoothPainter(
                color: Color(0xFFFFFDF8),
                toothWidth: 8.0,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 5. Pastilla Informativa de Ancho ESC/POS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2436) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF262E44)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  is80mm ? LucideIcons.scroll : LucideIcons.receipt,
                  size: 14,
                  color: primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  is80mm
                      ? 'Papel 80 mm • 48 columnas ESC/POS'
                      : 'Papel 58 mm • 32 columnas ESC/POS',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptDashedLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashWidth = 3.5;
          const dashSpace = 2.5;
          final double totalWidth = constraints.maxWidth > 0
              ? constraints.maxWidth
              : 200.0;
          final int dashCount = (totalWidth / (dashWidth + dashSpace)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dashCount > 0 ? dashCount : 1, (_) {
              return const SizedBox(
                width: dashWidth,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFF6B7280)),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildReceiptBarcode(bool is80mm) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < (is80mm ? 42 : 32); i++)
              Container(
                width: (i % 4 == 0 || i % 7 == 0) ? 2.4 : 1.2,
                height: 20,
                margin: EdgeInsets.only(right: (i % 5 == 0) ? 2.0 : 1.0),
                color: const Color(0xFF111827),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '* 00293-20261120-1440 *',
          style: GoogleFonts.firaCode(
            fontSize: 7.5,
            color: const Color(0xFF4B5563),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Future<void> _imprimirTicketPrueba() async {
    HapticFeedback.mediumImpact();
    final testItems = [
      TicketItem(
        nombre: 'Arroz Costeño 1kg',
        cantidad: 1,
        precioUnitario: 4.80,
        subtotal: 4.80,
      ),
      TicketItem(
        nombre: 'Leche Gloria Azul 400g',
        cantidad: 2,
        precioUnitario: 4.80,
        subtotal: 9.60,
      ),
    ];

    try {
      final ticketCfg = ConfiguracionTicket(
        anchoPapel: _anchoPapel,
        modoConexion: _modoConexion,
        abrirGaveta: _abrirGaveta,
        impresionAutomatica: _impresionAutomatica,
        mostrarQr: _mostrarQr,
        tipoQr: _tipoQr,
        numeroQr: _numeroQrCtrl.text.trim(),
        mensajeAgradecimiento: _lemaCtrl.text.trim(),
      );

      final escPosBytes = ThermalTicketService.generateEscPosBytes(
        ticketId: 293,
        clienteNombre: 'Cliente Mostrador',
        clienteDocumento: null,
        metodoPago: 'EFECTIVO',
        items: testItems,
        total: 14.40,
        pagadoCon: 20.00,
        vuelto: 5.60,
        cajero: 'Caja 1',
        width: _anchoPapel,
        nombreComercio: _nombreCtrl.text.trim().isNotEmpty
            ? _nombreCtrl.text.trim()
            : 'CajaYa POS',
        rucDni: _rucCtrl.text.trim().isNotEmpty ? _rucCtrl.text.trim() : null,
        direccion: _direccionCtrl.text.trim().isNotEmpty
            ? _direccionCtrl.text.trim()
            : null,
        telefono: _telefonoCtrl.text.trim().isNotEmpty
            ? _telefonoCtrl.text.trim()
            : null,
        lemaComercial: _lemaCtrl.text.trim().isNotEmpty
            ? _lemaCtrl.text.trim()
            : null,
        configTicket: ticketCfg,
      );

      final receiptText = ThermalTicketService.generateReceiptText(
        ticketId: 293,
        clienteNombre: 'Cliente Mostrador',
        clienteDocumento: null,
        metodoPago: 'EFECTIVO',
        items: testItems,
        total: 14.40,
        pagadoCon: 20.00,
        vuelto: 5.60,
        cajero: 'Caja 1',
        width: _anchoPapel,
        nombreComercio: _nombreCtrl.text.trim().isNotEmpty
            ? _nombreCtrl.text.trim()
            : 'CajaYa POS',
        rucDni: _rucCtrl.text.trim().isNotEmpty ? _rucCtrl.text.trim() : null,
        direccion: _direccionCtrl.text.trim().isNotEmpty
            ? _direccionCtrl.text.trim()
            : null,
        telefono: _telefonoCtrl.text.trim().isNotEmpty
            ? _telefonoCtrl.text.trim()
            : null,
        lemaComercial: _lemaCtrl.text.trim().isNotEmpty
            ? _lemaCtrl.text.trim()
            : null,
        configTicket: ticketCfg,
      );

      final res = await ThermalTicketService.imprimirTicketDirecto(
        escPosBytes: escPosBytes,
        receiptText: receiptText,
        config: ticketCfg,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: res.exito
                ? const Color(0xFF10B981)
                : AppTheme.brandPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Row(
              children: [
                Icon(
                  res.exito ? LucideIcons.checkCircle : LucideIcons.printer,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    res.exito
                        ? 'Ticket de prueba enviado a la impresora térmica.'
                        : 'Simulación completada: ${res.mensaje}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.brandPrimary,
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Simulación de ticket completada ($e)',
              style: GoogleFonts.plusJakartaSans(fontSize: 12),
            ),
          ),
        );
      }
    }
  }

  // --- TAB 4: CANALES & TIENDA ONLINE ---
  Widget _buildTabOnline(bool isDark, Color primaryColor, bool isDesktop) {
    final cardOnline = _buildCard(
      isDark: isDark,
      icon: LucideIcons.globe,
      title: _tituloTabOnline,
      subtitle: _subtituloTabOnline,
      child: Column(
        children: [
          _buildPermissionToggle(
            title: 'Estado de la Tienda Digital',
            desc: 'Si está apagado, los clientes verán un cartel de "Cerrado por el momento".',
            value: _catalogoAbierto,
            onChanged: (val) => setState(() => _catalogoAbierto = val),
            isDark: isDark,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Enlace Web Público (Slug)',
            controller: _slugCtrl,
            icon: LucideIcons.link,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'WhatsApp Pedidos',
                  controller: _whatsappDeliveryCtrl,
                  icon: LucideIcons.phone,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTextField(
                  label: 'Pedido Mínimo (S/)',
                  controller: _pedidoMinimoCtrl,
                  icon: LucideIcons.coins,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Horario de Atención para Entregas',
            controller: _horarioAtencionCtrl,
            icon: LucideIcons.clock,
            isDark: isDark,
          ),
        ],
      ),
    );

    final cardQrMarketing = _buildCard(
      isDark: isDark,
      icon: LucideIcons.qrCode,
      title: _tituloQrCartel,
      subtitle: _subtituloQrCartel,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  _nombreCtrl.text.isNotEmpty
                      ? _nombreCtrl.text.toUpperCase()
                      : (_esGastronomico
                            ? 'CARTA DIGITAL'
                            : 'BODEGA SAN MARTÍN'),
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    LucideIcons.qrCode,
                    size: 80,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'cajaya.pe/${_slugCtrl.text}',
                  style: GoogleFonts.outfit(
                    color: _hexToColor(_selectedHex),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _esGastronomico
                        ? 'Generando PDF listo para imprimir para mesas y mostrador...'
                        : 'Generando PDF listo para imprimir en vitrina...',
                  ),
                ),
              );
            },
            icon: const Icon(LucideIcons.download, size: 16),
            label: const Text('Descargar Cartel PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
        ],
      ),
    );

    return isDesktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: cardOnline),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: cardQrMarketing),
            ],
          )
        : Column(
            children: [cardOnline, const SizedBox(height: 16), cardQrMarketing],
          );
  }

  // --- TAB 5: PLAN & FACTURACIÓN ---
  Widget _buildTabPlan(bool isDark, Color primaryColor, bool isDesktop) {
    final isPro =
        _planActual.toUpperCase() == 'PRO' ||
        _planActual.toUpperCase() == 'CORPORATIVO';

    return Column(
      children: [
        // Hero Plan Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPro
                  ? [const Color(0xFF0D9488), const Color(0xFF0F766E)]
                  : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isPro
                            ? 'PLAN MINIMARKET PRO ACTIVO'
                            : 'PLAN BODEGA BÁSICO',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPro ? 'S/ 79.00 / mes' : 'S/ 39.00 / mes',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _bodegaInfo?.fechaVencimientoPlan != null
                          ? 'Vigente hasta el ${_bodegaInfo!.fechaVencimientoPlan}'
                          : 'Suscripción mensual activa con renovación por Yape',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Abriendo canal de soporte y pagos Yape...',
                      ),
                    ),
                  );
                },
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('Renovar Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F766E),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildCard(
          isDark: isDark,
          icon: LucideIcons.award,
          title: 'Beneficios Desbloqueados en tu Cuenta',
          subtitle: 'Herramientas premium disponibles en tu terminal',
          child: Column(
            children: [
              _buildBenefitRow(
                'Cajeros ilimitados con PIN individual para control de turnos',
              ),
              _buildBenefitRow(
                'Personalización de color dinámico en mostrador y web',
              ),
              _buildBenefitRow('Catálogo web con pedidos directos al WhatsApp'),
              _buildBenefitRow(
                'Detección de productos hueso y dinero estancado',
              ),
              _buildBenefitRow(
                'Auditorías ciegas por pasillo y arqueo de caja con 1 toque',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const Icon(LucideIcons.check, color: Color(0xFF10B981), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  // --- COMPONENTES AUXILIARES ---
  Widget _buildCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141724) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF262E44) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isDark,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: isDark
                ? const Color(0xFF0F1420)
                : const Color(0xFFF8FAFC),
            prefixIcon: Icon(
              icon,
              size: 15,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF262E44)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF262E44)
                    : const Color(0xFFCBD5E1),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceButton({
    Key? key,
    required String label,
    String? subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
    required Color primaryColor,
  }) {
    return InkWell(
      key: key,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? primaryColor.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF1E2436) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? primaryColor
                : (isDark ? const Color(0xFF262E44) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? primaryColor
                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? primaryColor
                          : (isDark ? Colors.white : AppTheme.textDark),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DIÁLOGOS DE USUARIOS ---
  void _abrirModalCrearUsuario() {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    String rolSeleccionado = 'CAJERO';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
          final primaryColor = Theme.of(dialogCtx).colorScheme.primary;

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E2436) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              children: [
                Icon(LucideIcons.userPlus, color: primaryColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Nuevo Colaborador',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('inputNombreCajero'),
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('inputUsuarioCajero'),
                  controller: userCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Usuario de Ingreso',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('inputPinCajero'),
                        controller: pinCtrl,
                        maxLength: 4,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.firaCode(
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'PIN (4 dígitos)',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      key: const Key('btnGenerarPinAzar'),
                      onPressed: () {
                        final randomPin = (1000 + Random().nextInt(9000))
                            .toString();
                        setModalState(() => pinCtrl.text = randomPin);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor.withValues(alpha: 0.15),
                        foregroundColor: primaryColor,
                        elevation: 0,
                      ),
                      child: const Text('PIN al Azar'),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                key: const Key('btnConfirmarCrearCajero'),
                onPressed: () async {
                  final user = userCtrl.text.trim();
                  final pin = pinCtrl.text.trim();
                  final name = nameCtrl.text.trim();
                  if (user.isEmpty || pin.length != 4) return;

                  try {
                    await _usuariosService.crearUsuario(
                      username: user,
                      nombreCompleto: name,
                      password: pin,
                      rol: rolSeleccionado,
                    );
                    final updatedUsers = await _usuariosService
                        .listarUsuarios();
                    if (!mounted) return;
                    setState(() => _usuarios = updatedUsers);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '¡Colaborador $user creado exitosamente!',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Crear Cajero'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _abrirModalCambiarPin(UsuarioItem u) {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
          final primaryColor = Theme.of(dialogCtx).colorScheme.primary;

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E2436) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(
              'Cambiar PIN de @${u.username}',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            content: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: pinCtrl,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.firaCode(
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Nuevo PIN (4 dígitos)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final randomPin = (1000 + Random().nextInt(9000))
                        .toString();
                    setModalState(() => pinCtrl.text = randomPin);
                  },
                  child: const Text('Azar'),
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
                  final pin = pinCtrl.text.trim();
                  if (pin.length != 4) return;
                  await _usuariosService.resetPassword(u.idUsuario, pin);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('¡PIN de @${u.username} actualizado!'),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Guardar PIN'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleEstadoUsuario(UsuarioItem u) async {
    final nuevoEstado = !u.estado;
    await _usuariosService.cambiarEstado(u.idUsuario, nuevoEstado);
    final updated = await _usuariosService.listarUsuarios();
    if (mounted) {
      setState(() => _usuarios = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nuevoEstado ? 'Cuenta activada' : 'Cuenta pausada'),
        ),
      );
    }
  }

  Future<void> _confirmarEliminarUsuario(UsuarioItem u) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar a @${u.username}?'),
        content: const Text(
          'Esta acción quitará el acceso a este colaborador definitivamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.alertRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _usuariosService.eliminarUsuario(u.idUsuario);
      final updated = await _usuariosService.listarUsuarios();
      if (mounted) {
        setState(() => _usuarios = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usuario @${u.username} eliminado')),
        );
      }
    }
  }
}

/// Dibuja los dientes de sierra característicos del corte de papel en guillotinas térmicas.
class _SawtoothPainter extends CustomPainter {
  final Color color;
  final double toothWidth;

  const _SawtoothPainter({required this.color, this.toothWidth = 8.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);

    double x = 0;
    while (x < size.width) {
      final midX = x + (toothWidth / 2);
      final nextX = x + toothWidth;
      path.lineTo(midX, size.height);
      path.lineTo(nextX, 0);
      x = nextX;
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SawtoothPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.toothWidth != toothWidth;
}
