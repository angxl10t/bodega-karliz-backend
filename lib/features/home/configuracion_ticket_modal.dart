import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/configuracion_ticket_service.dart';
import '../../core/thermal_ticket_service.dart';

class ConfiguracionTicketModal extends StatefulWidget {
  final VoidCallback? onSaved;

  const ConfiguracionTicketModal({super.key, this.onSaved});

  static Future<void> show(BuildContext context, {VoidCallback? onSaved}) {
    return showDialog(
      context: context,
      builder: (ctx) => ConfiguracionTicketModal(onSaved: onSaved),
    );
  }

  @override
  State<ConfiguracionTicketModal> createState() => _ConfiguracionTicketModalState();
}

class _ConfiguracionTicketModalState extends State<ConfiguracionTicketModal> {
  final _formKey = GlobalKey<FormState>();

  int _anchoPapel = ThermalTicketService.width58mm;
  bool _abrirGaveta = true;
  bool _impresionAutomatica = false;
  String _modoConexion = 'rawbt';
  late TextEditingController _servidorLocalCtrl;

  late TextEditingController _agradecimientoCtrl;
  late TextEditingController _secundarioCtrl;
  late TextEditingController _horarioCtrl;
  late TextEditingController _redesCtrl;

  bool _mostrarQr = true;
  String _tipoQr = 'YAPE';
  late TextEditingController _numeroQrCtrl;
  late TextEditingController _titularQrCtrl;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _servidorLocalCtrl = TextEditingController();
    _agradecimientoCtrl = TextEditingController();
    _secundarioCtrl = TextEditingController();
    _horarioCtrl = TextEditingController();
    _redesCtrl = TextEditingController();
    _numeroQrCtrl = TextEditingController();
    _titularQrCtrl = TextEditingController();
    _cargarConfiguracion();
  }

  @override
  void dispose() {
    _servidorLocalCtrl.dispose();
    _agradecimientoCtrl.dispose();
    _secundarioCtrl.dispose();
    _horarioCtrl.dispose();
    _redesCtrl.dispose();
    _numeroQrCtrl.dispose();
    _titularQrCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarConfiguracion() async {
    setState(() => _isLoading = true);
    final cfg = await ConfiguracionTicketService.cargar();
    if (mounted) {
      setState(() {
        _anchoPapel = cfg.anchoPapel;
        _abrirGaveta = cfg.abrirGaveta;
        _impresionAutomatica = cfg.impresionAutomatica;
        _modoConexion = cfg.modoConexion;
        _servidorLocalCtrl.text = cfg.servidorLocalUrl;
        _agradecimientoCtrl.text = cfg.mensajeAgradecimiento;
        _secundarioCtrl.text = cfg.mensajeSecundario;
        _horarioCtrl.text = cfg.horarioAtencion;
        _redesCtrl.text = cfg.redesSociales;
        _mostrarQr = cfg.mostrarQr;
        _tipoQr = cfg.tipoQr;
        _numeroQrCtrl.text = cfg.numeroQr;
        _titularQrCtrl.text = cfg.titularQr;
        _isLoading = false;
      });
    }
  }

  ConfiguracionTicket _obtenerConfiguracionActual() {
    return ConfiguracionTicket(
      anchoPapel: _anchoPapel,
      abrirGaveta: _abrirGaveta,
      impresionAutomatica: _impresionAutomatica,
      modoConexion: _modoConexion,
      servidorLocalUrl: _servidorLocalCtrl.text.trim().isEmpty ? 'http://127.0.0.1:40213/' : _servidorLocalCtrl.text.trim(),
      mensajeAgradecimiento: _agradecimientoCtrl.text.trim(),
      mensajeSecundario: _secundarioCtrl.text.trim(),
      horarioAtencion: _horarioCtrl.text.trim(),
      redesSociales: _redesCtrl.text.trim(),
      mostrarQr: _mostrarQr,
      tipoQr: _tipoQr,
      numeroQr: _numeroQrCtrl.text.trim(),
      titularQr: _titularQrCtrl.text.trim(),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final cfg = _obtenerConfiguracionActual();
    await ConfiguracionTicketService.guardar(cfg);

    if (mounted) {
      setState(() => _isSaving = false);
      widget.onSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Configuración de impresión guardada con éxito!'),
          backgroundColor: AppTheme.accentGreen,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _probarImpresion() async {
    setState(() => _isTesting = true);
    final cfg = _obtenerConfiguracionActual();

    final testItems = [
      TicketItem(nombre: 'Gaseosa Inka Cola 500ml', cantidad: 2, precioUnitario: 3.50, subtotal: 7.00),
      TicketItem(nombre: 'Galletas Rellenitas Chocolate', cantidad: 3, precioUnitario: 1.00, subtotal: 3.00),
    ];

    final testEscPosBytes = ThermalTicketService.generateEscPosBytes(
      ticketId: 9999,
      clienteNombre: 'Cliente de Prueba',
      clienteDocumento: '70809010',
      metodoPago: 'Efectivo',
      items: testItems,
      total: 10.00,
      pagadoCon: 20.00,
      vuelto: 10.00,
      width: cfg.anchoPapel,
      nombreComercio: 'CajaYa POS Demo',
      direccion: 'Av. Las Gaviotas 450 - Lima',
      telefono: '987 654 321',
      configTicket: cfg,
      forzarAperturaGaveta: cfg.abrirGaveta,
    );

    final testText = ThermalTicketService.generateReceiptText(
      ticketId: 9999,
      clienteNombre: 'Cliente de Prueba',
      clienteDocumento: '70809010',
      metodoPago: 'Efectivo',
      items: testItems,
      total: 10.00,
      pagadoCon: 20.00,
      vuelto: 10.00,
      width: cfg.anchoPapel,
      nombreComercio: 'CajaYa POS Demo',
      direccion: 'Av. Las Gaviotas 450 - Lima',
      telefono: '987 654 321',
      configTicket: cfg,
    );

    final res = await ThermalTicketService.imprimirTicketDirecto(
      escPosBytes: testEscPosBytes,
      receiptText: testText,
      config: cfg,
    );

    if (mounted) {
      setState(() => _isTesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.mensaje),
          backgroundColor: res.exito ? AppTheme.accentGreen : const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    return Dialog(
      backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: isDark ? const BorderSide(color: AppTheme.borderDarkElevated, width: 1.2) : BorderSide.none,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: _isLoading
            ? const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator(color: AppTheme.brandPrimary)),
              )
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Encabezado
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(LucideIcons.printer, color: AppTheme.brandPrimary, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Impresora Térmica & Tickets',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : AppTheme.textDark,
                                  ),
                                ),
                                Text(
                                  'Configura comandos ESC/POS, gaveta de dinero y QR',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.x, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Cuerpo Scrolleable
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // SECCIÓN 1: HARDWARE Y COMANDOS
                            _buildSectionHeader('1. Hardware & Impresora', LucideIcons.cpu, isDark),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Selector Ancho de Papel
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Ancho de Papel Térmico',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Colors.white : AppTheme.textDark,
                                              ),
                                            ),
                                            Text(
                                              '58mm (32 cols portátil) ó 80mm (48 cols mesón)',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SegmentedButton<int>(
                                        segments: const [
                                          ButtonSegment(value: ThermalTicketService.width58mm, label: Text('58 mm')),
                                          ButtonSegment(value: ThermalTicketService.width80mm, label: Text('80 mm')),
                                        ],
                                        selected: {_anchoPapel},
                                        onSelectionChanged: (val) {
                                          setState(() => _anchoPapel = val.first);
                                        },
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),

                                  // Switch Gaveta de Dinero
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    activeTrackColor: AppTheme.accentGreen,
                                    title: Text(
                                      'Apertura Automática de Gaveta (RJ11/RJ12)',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : AppTheme.textDark,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Envía pulso ESC/POS a la gaveta al cobrar en efectivo',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                                    ),
                                    value: _abrirGaveta,
                                    onChanged: (val) => setState(() => _abrirGaveta = val),
                                  ),
                                  const Divider(height: 20),

                                  // Switch Impresión Silenciosa
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    activeTrackColor: AppTheme.brandPrimary,
                                    title: Text(
                                      'Impresión Automática al Cobrar',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : AppTheme.textDark,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Imprime el ticket inmediatamente al completar la venta',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                                    ),
                                    value: _impresionAutomatica,
                                    onChanged: (val) => setState(() => _impresionAutomatica = val),
                                  ),
                                  const Divider(height: 20),

                                  // Selector Modo de Conexión
                                  Text(
                                    'Método de Conexión:',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: _modoConexion,
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'rawbt',
                                        child: Text('RawBT Driver (Bluetooth SPP/BLE y USB)'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'servidor_local',
                                        child: Text('Servidor Local HTTP (127.0.0.1:40213)'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'navegador',
                                        child: Text('Navegador Web / Vista Previa'),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _modoConexion = val);
                                    },
                                  ),
                                  if (_modoConexion == 'servidor_local') ...[
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _servidorLocalCtrl,
                                      decoration: InputDecoration(
                                        labelText: 'URL del Servidor de Impresión',
                                        hintText: 'http://127.0.0.1:40213/',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // SECCIÓN 2: PERSONALIZACIÓN DEL PIE DE TICKET
                            _buildSectionHeader('2. Pie de Ticket & Agradecimiento', LucideIcons.fileText, isDark),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _agradecimientoCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Mensaje de Agradecimiento',
                                      hintText: '¡Gracias por su compra! Vuelva pronto.',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _secundarioCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Leyenda / Garantía',
                                      hintText: 'Conserve su comprobante para cambios',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _horarioCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Horario de Atención',
                                      hintText: 'Atención: Lun-Dom 7:00 am - 11:00 pm',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _redesCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Redes Sociales o WhatsApp',
                                      hintText: 'WhatsApp: 987 654 321 | @bodegakarliz',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // SECCIÓN 3: CÓDIGO QR DE PAGO (YAPE / PLIN)
                            _buildSectionHeader('3. Código QR de Cobro (Yape / Plin)', LucideIcons.qrCode, isDark),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    activeTrackColor: const Color(0xFF7C3AED), // Púrpura Yape
                                    title: Text(
                                      'Imprimir Código QR en el Ticket',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : AppTheme.textDark,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Permite a los clientes pagar escaneando el papel térmico',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                                    ),
                                    value: _mostrarQr,
                                    onChanged: (val) => setState(() => _mostrarQr = val),
                                  ),
                                  if (_mostrarQr) ...[
                                    const Divider(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            initialValue: _tipoQr,
                                            decoration: InputDecoration(
                                              labelText: 'Billetera Digital',
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            items: const [
                                              DropdownMenuItem(value: 'YAPE', child: Text('Yape')),
                                              DropdownMenuItem(value: 'PLIN', child: Text('Plin')),
                                              DropdownMenuItem(value: 'SUNAT', child: Text('Verificación SUNAT')),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) setState(() => _tipoQr = val);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _numeroQrCtrl,
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        labelText: 'Número de Celular para Cobro',
                                        hintText: '987 654 321',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _titularQrCtrl,
                                      decoration: InputDecoration(
                                        labelText: 'Nombre del Titular de la Cuenta',
                                        hintText: 'Carlos Ramirez (Bodega Karliz)',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Barra Inferior de Acciones
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border(top: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.brandPrimary,
                              side: const BorderSide(color: AppTheme.brandPrimary, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            icon: _isTesting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.brandPrimary),
                                  )
                                : const Icon(LucideIcons.printer, size: 18),
                            label: const Text('Probar Impresora'),
                            onPressed: (_isTesting || _isSaving) ? null : _probarImpresion,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.brandPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(LucideIcons.check, size: 18),
                            label: const Text('Guardar'),
                            onPressed: (_isTesting || _isSaving) ? null : _guardar,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.brandPrimary),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
        ),
      ],
    );
  }
}
