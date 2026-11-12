import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../core/configuracion_ticket_service.dart';
import '../../core/native_bluetooth_printer_service.dart';
import '../../core/thermal_ticket_service.dart';
import '../../core/karliz_sound_service.dart';
import '../productos/producto_model.dart';

/// Modal centralizado de Diagnóstico, Calibración y Control de Hardware en Mostrador.
/// Diseñado para la realidad operativa del bodeguero peruano:
/// 1. Ticketera térmica (58mm/80mm, Bluetooth Nativo Android directo, RawBT móvil, Web Print en PC Windows, Servidor de red)
/// 2. Lector de código de barras (Pistola USB / Bluetooth / Escáner de sobremesa)
/// 3. Gaveta de dinero eléctrica (Cajón monedero RJ11)
/// 4. Teclado rápido y atajos comerciales de mostrador (F2, F4, F7, F8, F9, Esc)
class HardwareMostradorModal extends StatefulWidget {
  final List<Producto> productosDisponibles;
  final VoidCallback? onConfiguracionActualizada;

  const HardwareMostradorModal({
    super.key,
    this.productosDisponibles = const [],
    this.onConfiguracionActualizada,
  });

  static Future<void> show(
    BuildContext context, {
    List<Producto> productos = const [],
    VoidCallback? onConfiguracionActualizada,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => HardwareMostradorModal(
        productosDisponibles: productos,
        onConfiguracionActualizada: onConfiguracionActualizada,
      ),
    );
  }

  @override
  State<HardwareMostradorModal> createState() => _HardwareMostradorModalState();
}

class _HardwareMostradorModalState extends State<HardwareMostradorModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Configuración de ticket
  ConfiguracionTicket _cfg = ConfiguracionTicketService.actual;
  bool _isPrintingTest = false;
  bool _isOpeningDrawer = false;
  String? _printerStatusMessage;
  bool _printerStatusSuccess = true;
  bool _isScanningBluetooth = false;
  List<BluetoothPrinterDevice> _bluetoothDevices = const [];
  String? _bluetoothErrorMessage;

  // Estado del Probador de Escáner
  final TextEditingController _scannerInputCtrl = TextEditingController();
  final FocusNode _scannerFocusNode = FocusNode();
  DateTime? _firstCharTime;
  int _lastScanDurationMs = 0;
  String _ultimoCodigoEscaneado = '';
  Producto? _productoDetectado;
  bool _scannerEnterDetectado = false;
  int _totalEscaneosPrueba = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarConfiguracion();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scannerInputCtrl.dispose();
    _scannerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _cargarConfiguracion() async {
    final cfg = await ConfiguracionTicketService.cargar();
    if (!mounted) return;
    setState(() => _cfg = cfg);
    if (cfg.modoConexion == 'bluetooth_nativo' &&
        NativeBluetoothPrinterService.isSupportedPlatform) {
      _cargarImpresorasBluetooth(silent: true);
    }
  }

  Future<void> _cargarImpresorasBluetooth({bool silent = false}) async {
    if (!NativeBluetoothPrinterService.isSupportedPlatform) {
      if (!silent && mounted) {
        setState(() {
          _bluetoothDevices = const [];
          _bluetoothErrorMessage = 'La detección Bluetooth nativa directa solo está disponible en la app Android.';
        });
      }
      return;
    }

    setState(() {
      _isScanningBluetooth = true;
      _bluetoothErrorMessage = null;
    });

    try {
      final devices =
          await NativeBluetoothPrinterService.listarImpresorasVinculadas();
      if (!mounted) return;
      setState(() {
        _isScanningBluetooth = false;
        _bluetoothDevices = devices;
        if (devices.isEmpty) {
          _bluetoothErrorMessage = 'No se encontraron dispositivos Bluetooth vinculados. Empareja tu ticketera en Ajustes > Bluetooth del celular y vuelve a buscar.';
        }
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanningBluetooth = false;
        _bluetoothErrorMessage = e.message?.trim().isNotEmpty == true
            ? e.message!.trim()
            : 'No se pudo consultar dispositivos Bluetooth (${e.code}).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanningBluetooth = false;
        _bluetoothErrorMessage = 'Error al consultar Bluetooth: $e';
      });
    }
  }

  Future<void> _guardarConfiguracion(ConfiguracionTicket nuevaCfg) async {
    setState(() => _cfg = nuevaCfg);
    await ConfiguracionTicketService.guardar(nuevaCfg);
    widget.onConfiguracionActualizada?.call();
  }

  Future<void> _probarTicketera() async {
    setState(() {
      _isPrintingTest = true;
      _printerStatusMessage = null;
    });

    final testItems = [
      TicketItem(
        nombre: 'Gaseosa Inka Cola 500ml',
        cantidad: 2,
        precioUnitario: 3.50,
        subtotal: 7.00,
      ),
      TicketItem(
        nombre: 'Galletas Rellenitas Choc.',
        cantidad: 3,
        precioUnitario: 1.00,
        subtotal: 3.00,
      ),
      TicketItem(
        nombre: 'Pan Frances (Bolsa x6)',
        cantidad: 1,
        precioUnitario: 2.00,
        subtotal: 2.00,
      ),
    ];

    final plainText = ThermalTicketService.generateReceiptText(
      ticketId: 9999,
      clienteNombre: 'Vecino del Barrio',
      clienteDocumento: '10458920192',
      metodoPago: 'Efectivo S/ 20.00',
      items: testItems,
      total: 12.00,
      descuento: 0.0,
      pagadoCon: 20.00,
      vuelto: 8.00,
      cajero: 'Cajero Principal',
      fecha: DateTime.now(),
      width: _cfg.anchoPapel,
      nombreComercio: 'BODEGA TEST HARDWARE',
      rucDni: '10458920192',
      direccion: 'Av. El Sol 123 - Lima',
      telefono: '998 765 432',
      lemaComercial: 'Tu bodega de confianza',
      tipoComprobante: 'TICKET DE PRUEBA',
      serieCorrelativo: 'TEST-000001',
      estadoSunat: 'DIAGNOSTICO HARDWARE OK',
      configTicket: _cfg,
    );

    final escPosBytes = ThermalTicketService.generateEscPosBytes(
      ticketId: 9999,
      clienteNombre: 'Vecino del Barrio',
      clienteDocumento: '10458920192',
      metodoPago: 'Efectivo',
      items: testItems,
      total: 12.00,
      descuento: 0.0,
      pagadoCon: 20.00,
      vuelto: 8.00,
      cajero: 'Cajero Principal',
      fecha: DateTime.now(),
      width: _cfg.anchoPapel,
      nombreComercio: 'BODEGA TEST HARDWARE',
      rucDni: '10458920192',
      direccion: 'Av. El Sol 123 - Lima',
      telefono: '998 765 432',
      lemaComercial: 'Tu bodega de confianza',
      tipoComprobante: 'TICKET DE PRUEBA',
      serieCorrelativo: 'TEST-000001',
      estadoSunat: 'DIAGNOSTICO HARDWARE OK',
      configTicket: _cfg,
    );

    final res = await ThermalTicketService.imprimirTicketDirecto(
      escPosBytes: escPosBytes,
      receiptText: plainText,
      config: _cfg,
    );

    if (mounted) {
      setState(() {
        _isPrintingTest = false;
        _printerStatusMessage = res.mensaje;
        _printerStatusSuccess = res.exito;
      });
      if (res.exito) {
        KarlizSoundService.instance.playBarcodeBeep();
      } else {
        KarlizSoundService.instance.playErrorBeep();
      }
    }
  }

  Future<void> _probarAperturaGaveta() async {
    setState(() => _isOpeningDrawer = true);
    HapticFeedback.heavyImpact();
    KarlizSoundService.instance.playBarcodeBeep();

    final res = await ThermalTicketService.abrirGavetaDinero(config: _cfg);

    if (mounted) {
      setState(() => _isOpeningDrawer = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.vault, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  res.exito
                      ? '¡Pulso ESC/POS enviado a la gaveta con éxito!'
                      : res.mensaje,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: res.exito ? AppTheme.accentGreen : AppTheme.alertRed,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _procesarEscaneoPrueba(String codigo, {bool fuePorEnter = false}) {
    final cleanCode = codigo.trim();
    if (cleanCode.isEmpty) return;

    final now = DateTime.now();
    int duration = 0;
    if (_firstCharTime != null) {
      duration = now.difference(_firstCharTime!).inMilliseconds;
    }

    // Buscar si existe en los productos disponibles
    Producto? match;
    for (final p in widget.productosDisponibles) {
      if ((p.codigoBarras ?? '').trim() == cleanCode ||
          p.codigo.trim() == cleanCode) {
        match = p;
        break;
      }
    }

    setState(() {
      _ultimoCodigoEscaneado = cleanCode;
      _productoDetectado = match;
      _lastScanDurationMs = duration;
      _scannerEnterDetectado = fuePorEnter;
      _totalEscaneosPrueba++;
      _firstCharTime = null;
    });

    _scannerInputCtrl.clear();
    KarlizSoundService.instance.playBarcodeBeep();
    _scannerFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgDialog = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F0);

    return Dialog(
      backgroundColor: bgDialog,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera del Centro de Hardware
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      LucideIcons.cpu,
                      color: AppTheme.brandPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hardware & Mostrador POS',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Calibración de ticketera, escáner, gaveta y atajos rápidos',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x, size: 20),
                  ),
                ],
              ),
            ),

            // TabBar de Periféricos
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppTheme.brandPrimary,
                indicatorWeight: 3,
                labelColor: AppTheme.brandPrimary,
                unselectedLabelColor: AppTheme.getAdaptiveMutedText(isDark),
                labelStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(LucideIcons.printer, size: 18),
                    text: 'Ticketera Térmica',
                  ),
                  Tab(
                    icon: Icon(LucideIcons.scanBarcode, size: 18),
                    text: 'Lector de Barras',
                  ),
                  Tab(
                    icon: Icon(LucideIcons.vault, size: 18),
                    text: 'Gaveta de Dinero',
                  ),
                  Tab(
                    icon: Icon(LucideIcons.keyboard, size: 18),
                    text: 'Atajos & Kiosco',
                  ),
                ],
              ),
            ),

            // Contenido de las pestañas
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTabTicketera(isDark),
                  _buildTabScanner(isDark),
                  _buildTabGaveta(isDark),
                  _buildTabAtajos(isDark),
                ],
              ),
            ),

            // Barra Inferior
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0B1120)
                    : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CajaYa Hardware Engine v2.0',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getAdaptiveHintText(isDark),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.brandPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Listo',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PESTAÑA 1: TICKETERA TÉRMICA ESC/POS
  // ==========================================
  Widget _buildTabTicketera(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBanner(
            icon: LucideIcons.checkCircle2,
            title: 'Protocolo Universal ESC/POS',
            subtitle: 'Compatible con rollos de papel térmico continuo de 58mm y 80mm en marcas Xprinter, Epson, POS-58, Sunmi, Goojprt y Zjiang.',
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Ancho de papel
          Text(
            'ANCHO DE PAPEL DE LA TICKETERA',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSelectCard(
                  title: '58 mm (Estándar Bodega)',
                  subtitle: 'Rollito angosto portátil (32 columnas). El más económico en Perú.',
                  selected: _cfg.anchoPapel == ThermalTicketService.width58mm,
                  onTap: () => _guardarConfiguracion(
                    _cfg.copyWith(anchoPapel: ThermalTicketService.width58mm),
                  ),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSelectCard(
                  title: '80 mm (Gran Formato)',
                  subtitle: 'Impresora pesada de mostrador (48 columnas). Letra más amplia.',
                  selected: _cfg.anchoPapel == ThermalTicketService.width80mm,
                  onTap: () => _guardarConfiguracion(
                    _cfg.copyWith(anchoPapel: ThermalTicketService.width80mm),
                  ),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Modo de Conexión
          Text(
            'MÉTODO DE CONEXIÓN DEL HARDWARE',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          _buildSelectCard(
            title: '🖥️ Impresora del Sistema / Web Print (PC Windows & Mac)',
            subtitle: 'Utiliza el driver USB de Windows directamente desde el navegador con formato térmico sin márgenes. No requiere apps intermedias.',
            selected: _cfg.modoConexion == 'navegador',
            onTap: () =>
                _guardarConfiguracion(_cfg.copyWith(modoConexion: 'navegador')),
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildSelectCard(
            title: '📶 Bluetooth Nativo Android (Directo sin RawBT)',
            subtitle: 'Impresión ESC/POS directa por Bluetooth clásico (SPP) desde CajaYa POS, sin instalar aplicaciones externas.',
            selected: _cfg.modoConexion == 'bluetooth_nativo',
            onTap: () {
              _guardarConfiguracion(
                _cfg.copyWith(modoConexion: 'bluetooth_nativo'),
              );
              if (NativeBluetoothPrinterService.isSupportedPlatform) {
                _cargarImpresorasBluetooth();
              }
            },
            isDark: isDark,
          ),
          if (_cfg.modoConexion == 'bluetooth_nativo') ...[
            const SizedBox(height: 8),
            _buildBluetoothNativePanel(isDark),
          ],
          const SizedBox(height: 8),
          _buildSelectCard(
            title: '📱 App RawBT (Android Bluetooth / USB Móvil)',
            subtitle: 'Ideal para celular o tablet conectado por Bluetooth a mini-impresoras portátiles de S/ 80.',
            selected: _cfg.modoConexion == 'rawbt',
            onTap: () =>
                _guardarConfiguracion(_cfg.copyWith(modoConexion: 'rawbt')),
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildSelectCard(
            title: '🌐 Servidor Local / Red LAN (IP Ethernet)',
            subtitle: 'Para impresoras conectadas al router por cable de red (ej. 192.168.1.100) o puente local 127.0.0.1:40213.',
            selected: _cfg.modoConexion == 'servidor_local',
            onTap: () => _guardarConfiguracion(
              _cfg.copyWith(modoConexion: 'servidor_local'),
            ),
            isDark: isDark,
          ),
          const SizedBox(height: 18),

          // Interruptores
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _cfg.impresionAutomatica,
            onChanged: (val) =>
                _guardarConfiguracion(_cfg.copyWith(impresionAutomatica: val)),
            title: Text(
              'Impresión automática al cobrar',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
            subtitle: Text(
              'Emite el ticket inmediatamente al registrar la venta sin requerir confirmación.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12),
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _cfg.abrirGaveta,
            onChanged: (val) =>
                _guardarConfiguracion(_cfg.copyWith(abrirGaveta: val)),
            title: Text(
              'Disparar apertura de gaveta de dinero en efectivo',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
            subtitle: Text(
              'Envía el pulso eléctrico a la gaveta conectada por cable RJ11 a la ticketera.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Botón de prueba
          FilledButton.icon(
            onPressed: _isPrintingTest ? null : _probarTicketera,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _isPrintingTest
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(LucideIcons.printer, size: 18),
            label: Text(
              _isPrintingTest
                  ? 'Imprimiendo ticket de prueba...'
                  : '🖨️ Imprimir Ticket de Diagnóstico',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          if (_printerStatusMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _printerStatusSuccess
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _printerStatusSuccess
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _printerStatusSuccess
                        ? LucideIcons.check
                        : LucideIcons.alertTriangle,
                    color: _printerStatusSuccess
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _printerStatusMessage!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _printerStatusSuccess
                            ? (isDark
                                  ? const Color(0xFF6EE7B7)
                                  : const Color(0xFF065F46))
                            : (isDark
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFF991B1B)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBluetoothNativePanel(bool isDark) {
    final bool isAndroidSupported =
        NativeBluetoothPrinterService.isSupportedPlatform;
    final bool hasSelectedPrinter = _cfg.bluetoothDeviceAddress
        .trim()
        .isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.brandPrimary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.bluetooth,
                size: 18,
                color: AppTheme.brandPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasSelectedPrinter
                      ? 'Ticketera activa: ${_cfg.bluetoothDeviceName.isNotEmpty ? _cfg.bluetoothDeviceName : 'Impresora BT'} (${_cfg.bluetoothDeviceAddress})'
                      : 'Ninguna ticketera Bluetooth seleccionada',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: hasSelectedPrinter
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : (isDark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFB45309)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1. Vincula tu impresora térmica (58mm/80mm) una sola vez en Ajustes > Bluetooth de Android.\n2. Presiona "Buscar impresoras vinculadas" y elige tu ticketera.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('bluetooth_scan_button'),
            onPressed: _isScanningBluetooth
                ? null
                : () => _cargarImpresorasBluetooth(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.brandPrimary,
              side: BorderSide(
                color: AppTheme.brandPrimary.withValues(alpha: 0.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            ),
            icon: _isScanningBluetooth
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.refreshCw, size: 15),
            label: Text(
              _isScanningBluetooth
                  ? 'Consultando impresoras vinculadas...'
                  : 'Buscar impresoras vinculadas',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (!isAndroidSupported && _bluetoothErrorMessage == null) ...[
            const SizedBox(height: 8),
            Text(
              'Disponible únicamente en la app Android. En Windows/Mac/Web usa "Impresora del Sistema / Web Print".',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.getAdaptiveMutedText(isDark),
              ),
            ),
          ],
          if (_bluetoothErrorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                _bluetoothErrorMessage!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFF991B1B),
                ),
              ),
            ),
          ],
          if (_bluetoothDevices.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._bluetoothDevices.map((device) {
              final bool selected =
                  _cfg.bluetoothDeviceAddress.trim().toUpperCase() ==
                  device.address.trim().toUpperCase();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () => _guardarConfiguracion(
                    _cfg.copyWith(
                      modoConexion: 'bluetooth_nativo',
                      bluetoothDeviceName: device.name,
                      bluetoothDeviceAddress: device.address,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.brandPrimary.withValues(alpha: 0.12)
                          : (isDark ? const Color(0xFF0F172A) : Colors.white),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppTheme.brandPrimary
                            : (isDark
                                  ? Colors.white12
                                  : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected ? LucideIcons.check : LucideIcons.printer,
                          size: 16,
                          color: selected
                              ? AppTheme.brandPrimary
                              : AppTheme.getAdaptiveMutedText(isDark),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                device.address,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selected)
                          Text(
                            'ACTIVA',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.brandPrimary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // PESTAÑA 2: LECTOR DE CÓDIGOS DE BARRAS
  // ==========================================
  Widget _buildTabScanner(bool isDark) {
    final bool esHardware = _lastScanDurationMs > 0 && _lastScanDurationMs < 75;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBanner(
            icon: LucideIcons.scanLine,
            title: 'Lector USB / Bluetooth emulado (HID Wedge)',
            subtitle: 'Cualquier pistola lectora de S/ 45 en Wilson o MercadoLibre funciona como teclado emulado. Al escanear, envía los números y salta de línea (Enter).',
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Campo de prueba de disparo
          Text(
            'ZONA DE DISPARO INTERACTIVA (CALIBRACIÓN EN VIVO)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _scannerFocusNode.hasFocus
                    ? AppTheme.brandPrimary
                    : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.barcode,
                      size: 22,
                      color: AppTheme.brandPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Apunta tu pistola y dispara a cualquier producto',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    if (!_scannerFocusNode.hasFocus)
                      TextButton.icon(
                        onPressed: () => _scannerFocusNode.requestFocus(),
                        icon: const Icon(LucideIcons.focus, size: 16),
                        label: const Text('Activar Foco'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _scannerInputCtrl,
                  focusNode: _scannerFocusNode,
                  keyboardType: TextInputType.text,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Esperando disparo de pistola...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppTheme.getAdaptiveHintText(isDark),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(
                      LucideIcons.zap,
                      size: 18,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  onChanged: (val) {
                    _firstCharTime ??= DateTime.now();
                  },
                  onSubmitted: (val) {
                    _procesarEscaneoPrueba(val, fuePorEnter: true);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Resultados del diagnóstico de escáner
          if (_totalEscaneosPrueba > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RESULTADO DEL ÚLTIMO DISPARO',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white60
                              : const Color(0xFF64748B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: esHardware
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          esHardware
                              ? '⚡ ESCÁNER FÍSICO DETECTADO'
                              : '⌨️ TECLEO MANUAL',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: esHardware
                                ? const Color(0xFF10B981)
                                : const Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Código Leído',
                          value: _ultimoCodigoEscaneado,
                          icon: LucideIcons.binary,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Velocidad de ráfaga',
                          value: '$_lastScanDurationMs ms',
                          icon: LucideIcons.gauge,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Terminador Enter',
                          value: _scannerEnterDetectado
                              ? '✓ Sí (Enter)'
                              : '✗ Sin Enter',
                          icon: LucideIcons.cornerDownLeft,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Si el producto existe en inventario
                  if (_productoDetectado != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF0F766E).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              LucideIcons.packageCheck,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _productoDetectado!.nombre,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                Text(
                                  'Precio mostrador: S/ ${_productoDetectado!.precioVenta.toStringAsFixed(2)} | Stock: ${_productoDetectado!.stockActual.toStringAsFixed(0)} un.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.info,
                            color: Color(0xFFD97706),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'El lector leyó el código perfectamente, pero el código no está registrado en tu catálogo. Puedes registrarlo al escanearlo en el POS.',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // PESTAÑA 3: GAVETA DE DINERO (RJ11)
  // ==========================================
  Widget _buildTabGaveta(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBanner(
            icon: LucideIcons.vault,
            title: 'Conexión de Cajón Monedero por Cable RJ11',
            subtitle: 'La gaveta metálica para billetes y monedas no se conecta a la computadora; se enchufa con su cable de teléfono RJ11 en la parte trasera de tu ticketera térmica. La ticketera le envía un pulso de 24V para abrirla.',
            isDark: isDark,
          ),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        LucideIcons.keyRound,
                        color: Color(0xFF10B981),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Apertura Manual de Mostrador',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Abre la gaveta para dar sencillo o cambiar billetes sin necesidad de realizar una venta ficticia.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _isOpeningDrawer ? null : _probarAperturaGaveta,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _isOpeningDrawer
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(LucideIcons.vault, size: 20),
                  label: Text(
                    _isOpeningDrawer
                        ? 'Disparando solenoide...'
                        : '💰 ABRIR GAVETA AHORA (Tecla F7)',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Text(
            'RECOMENDACIONES PARA EL BODEGUERO',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          _buildBulletItem(
            'Atajo de teclado F7: En cualquier momento desde la pantalla de ventas, presiona la tecla F7 en el teclado físico para botar la gaveta.',
            isDark,
          ),
          _buildBulletItem(
            'Llave en posición vertical: Para que la gaveta abra electrónicamente por pulso, la cerradura manual debe estar en posición central (abierta electrónicamente), no trabada con llave.',
            isDark,
          ),
          _buildBulletItem(
            'Apertura automática: Si cobras con efectivo, el sistema siempre abrirá la gaveta para que guardes el billete y des el vuelto.',
            isDark,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PESTAÑA 4: ATAJOS DE TECLADO & KIOSCO
  // ==========================================
  Widget _buildTabAtajos(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBanner(
            icon: LucideIcons.keyboard,
            title: 'Operatividad Rápida sin Ratón (Fast-Keys)',
            subtitle: 'En hora punta con fila de vecinos, el cajero opera a máxima velocidad usando únicamente el teclado físico de la computadora o tablet.',
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          Text(
            'TABLA DE ATAJOS ACTIVOS EN MOSTRADOR',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),

          _buildShortcutRow(
            'F2',
            'Buscar Producto',
            'Enfoca la barra de búsqueda para escribir nombre o marca',
            isDark,
          ),
          _buildShortcutRow(
            'F4 / F12',
            'Cobrar Venta',
            'Abre la bandeja de cobro rápido para pagar con Efectivo o Yape',
            isDark,
          ),
          _buildShortcutRow(
            'F7',
            'Abrir Gaveta',
            'Expulsa la gaveta metálica de billetes sin emitir papel',
            isDark,
          ),
          _buildShortcutRow(
            'F8',
            'Venta en Espera',
            'Pone en espera la compra actual o abre la lista de tickets pausados',
            isDark,
          ),
          _buildShortcutRow(
            'F9',
            'Régimen / Comprobante',
            'Alterna entre Boleta de Venta y Ticket de Mostrador',
            isDark,
          ),
          _buildShortcutRow(
            'Esc',
            'Limpiar / Cancelar',
            'Borra la búsqueda actual o vacía la canasta si está vacía',
            isDark,
          ),
          _buildShortcutRow(
            'Enter',
            'Escanear Código',
            'Al disparar con la pistola, se agrega el ítem automáticamente',
            isDark,
          ),
        ],
      ),
    );
  }

  // Helpers de UI
  Widget _buildInfoBanner({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.brandPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.brandPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.brandPrimary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectCard({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.brandPrimary.withValues(alpha: 0.1)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppTheme.brandPrimary
                : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            width: selected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? LucideIcons.circleDot : LucideIcons.circle,
              color: selected
                  ? AppTheme.brandPrimary
                  : AppTheme.getAdaptiveHintText(isDark),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppTheme.brandPrimary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getAdaptiveMutedText(isDark),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBulletItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(
              LucideIcons.check,
              size: 14,
              color: AppTheme.accentGreen,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutRow(
    String keyBadge,
    String action,
    String description,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              keyBadge,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.5,
                color: AppTheme.brandPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
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
