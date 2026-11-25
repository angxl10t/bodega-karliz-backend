import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/karliz_sound_service.dart';
import '../../../core/offline/offline_models.dart';
import '../../../core/offline/offline_sync_manager.dart';
import '../../../core/offline/uuid_helper.dart';
import '../../../core/thermal_ticket_service.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/karliz_barcode_scanner_modal.dart';
import '../../../core/widgets/product_image_widget.dart';
import '../../clientes/cliente_model.dart';
import '../../clientes/cliente_service.dart';
import '../../productos/producto_model.dart';
import '../venta_model.dart';
import '../venta_service.dart';

enum MostradorSubvista { calculadora, catalogo }

class MostradorCalculadoraView extends StatefulWidget {
  final List<Producto> productosDisponibles;
  final VoidCallback onVolverAPos;
  final bool isDark;

  const MostradorCalculadoraView({
    super.key,
    required this.productosDisponibles,
    required this.onVolverAPos,
    required this.isDark,
  });

  @override
  State<MostradorCalculadoraView> createState() =>
      _MostradorCalculadoraViewState();
}

class _MostradorCalculadoraViewState extends State<MostradorCalculadoraView> {
  static const String _prefSubvistaKey = 'cajaya_mostrador_subvista_activa';

  MostradorSubvista _subvista = MostradorSubvista.calculadora;

  // Estado Modo Calculadora (Tira Continua)
  final List<double> _montosTicket = [];
  String _bufferCalculadora = '';
  int _billeteSeleccionado = -1; // -1: ninguno, 0: exacto, 10, 20, 50, 100
  bool _mostrarEfectivoInline = false;
  bool _mostrarFiadoInline = false;

  // Estado Modo Catálogo & Buscador
  final TextEditingController _busquedaController = TextEditingController();
  String _categoriaSeleccionada = 'TODOS';
  final List<CartItem> _carritoCat = [];

  // Clientes para fiados
  final ClienteService _clienteService = ClienteService();
  List<Cliente> _clientesVecinos = [];

  // Resumen de caja diaria
  final VentaService _ventaService = VentaService();
  double _cajaEfectivo = 0.0;
  double _cajaYape = 0.0;
  double _cajaTotal = 0.0;
  bool _isProcesandoVenta = false;

  @override
  void initState() {
    super.initState();
    _cargarPreferenciaSubvista();
    _cargarVecinos();
    _cargarCierreCajaHoy();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarPreferenciaSubvista() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(_prefSubvistaKey);
      if (val == 'catalogo' && mounted) {
        setState(() => _subvista = MostradorSubvista.catalogo);
      }
    } catch (_) {}
  }

  Future<void> _guardarPreferenciaSubvista(MostradorSubvista sub) async {
    setState(() => _subvista = sub);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefSubvistaKey,
        sub == MostradorSubvista.catalogo ? 'catalogo' : 'calculadora',
      );
    } catch (_) {}
  }

  Future<void> _cargarVecinos() async {
    try {
      final list = await _clienteService.getClientes();
      if (mounted) {
        setState(() => _clientesVecinos = list);
      }
    } catch (_) {}
  }

  Future<void> _cargarCierreCajaHoy() async {
    try {
      final cierre = await _ventaService.getCierreCajaHoy();
      if (cierre != null && mounted) {
        setState(() {
          _cajaTotal = cierre.totalVentas;
          _cajaEfectivo = cierre.totalEfectivo;
          _cajaYape = cierre.totalYape + cierre.totalPlin;
        });
      }
    } catch (_) {}
  }

  // ==========================================================
  // OPERACIONES DE LA CALCULADORA DE MOSTRADOR
  // ==========================================================
  void _presionarDigito(String c) {
    if (c == '.' && _bufferCalculadora.contains('.')) return;
    if (_bufferCalculadora.length >= 7) return;
    setState(() {
      _bufferCalculadora += c;
    });
    HapticFeedback.selectionClick();
  }

  void _limpiarBuffer() {
    setState(() => _bufferCalculadora = '');
    HapticFeedback.selectionClick();
  }

  void _sumarAlTicket() {
    final val = double.tryParse(_bufferCalculadora);
    if (val == null || val <= 0) return;

    setState(() {
      _montosTicket.add(val);
      _bufferCalculadora = '';
      _mostrarEfectivoInline = false;
      _mostrarFiadoInline = false;
    });

    KarlizSoundService.instance.playBarcodeBeep();
  }

  void _borrarLineaTicket(int index) {
    if (index >= 0 && index < _montosTicket.length) {
      setState(() {
        _montosTicket.removeAt(index);
        if (_montosTicket.isEmpty) {
          _mostrarEfectivoInline = false;
          _mostrarFiadoInline = false;
        }
      });
      HapticFeedback.mediumImpact();
    }
  }

  void _deshacerUltimoMonto() {
    if (_montosTicket.isNotEmpty) {
      setState(() {
        _montosTicket.removeLast();
        if (_montosTicket.isEmpty) {
          _mostrarEfectivoInline = false;
          _mostrarFiadoInline = false;
        }
      });
      HapticFeedback.mediumImpact();
    }
  }

  void _cancelarTicket() {
    if (_montosTicket.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar cuenta?'),
        content: const Text(
          'Se borrarán todos los montos de la cuenta actual.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No, continuar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.alertRed),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _montosTicket.clear();
                _bufferCalculadora = '';
                _mostrarEfectivoInline = false;
                _mostrarFiadoInline = false;
              });
              HapticFeedback.heavyImpact();
            },
            child: const Text('Sí, borrar cuenta'),
          ),
        ],
      ),
    );
  }

  double get _totalCalculadora => _montosTicket.fold(0.0, (a, b) => a + b);

  // ==========================================================
  // OPERACIONES DEL MODO CATÁLOGO & BUSCADOR
  // ==========================================================
  void _agregarProductoCatalogo(Producto p) {
    final idx = _carritoCat.indexWhere(
      (item) => item.producto.idProducto == p.idProducto,
    );
    setState(() {
      if (idx >= 0) {
        _carritoCat[idx].cantidad += 1;
      } else {
        _carritoCat.add(CartItem(producto: p, cantidad: 1));
      }
    });
    KarlizSoundService.instance.playBarcodeBeep();
  }

  double get _totalCatalogo =>
      _carritoCat.fold(0.0, (acc, item) => acc + item.subtotal);

  // ==========================================================
  // EJECUCIÓN REAL DE VENTA
  // ==========================================================
  Future<void> _ejecutarVenta({
    required String metodoPago,
    required double total,
    Cliente? cliente,
    double? montoRecibido,
  }) async {
    if (total <= 0 || _isProcesandoVenta) return;

    setState(() => _isProcesandoVenta = true);
    HapticFeedback.heavyImpact();

    try {
      // 1. Resolver detalles de venta
      List<VentaDetalleEnvio> detallesEnvio = [];
      List<OfflineVentaDetalle> detallesOffline = [];

      if (_subvista == MostradorSubvista.catalogo && _carritoCat.isNotEmpty) {
        detallesEnvio = _carritoCat
            .map(
              (i) => VentaDetalleEnvio(
                idProducto: i.producto.idProducto ?? 1,
                cantidad: i.cantidad,
              ),
            )
            .toList();

        detallesOffline = _carritoCat
            .map(
              (i) => OfflineVentaDetalle(
                idProducto: i.producto.idProducto ?? 1,
                nombreProducto: i.producto.nombre,
                cantidad: i.cantidad,
                precioUnitario: i.producto.precioVenta,
                subtotal: i.subtotal,
              ),
            )
            .toList();
      } else {
        // En modo calculadora, usar el producto disponible o genérico
        final productoBase = widget.productosDisponibles.isNotEmpty
            ? widget.productosDisponibles.first
            : Producto(
                idProducto: 1,
                codigo: 'GEN-01',
                nombre: 'Venta Mostrador Rápido',
                precioVenta: total,
                stockActual: 999,
              );

        detallesEnvio = [
          VentaDetalleEnvio(
            idProducto: productoBase.idProducto ?? 1,
            cantidad: 1.0,
          ),
        ];

        detallesOffline = [
          OfflineVentaDetalle(
            idProducto: productoBase.idProducto ?? 1,
            nombreProducto: 'Venta Mostrador Rápido',
            cantidad: 1.0,
            precioUnitario: total,
            subtotal: total,
          ),
        ];
      }

      final idempotencyKey = UuidHelper.generateV4();
      final ventaEnvio = VentaEnvio(
        idCliente: cliente?.idCliente,
        clienteNombre: cliente?.nombreCompleto ?? 'Cliente Mostrador',
        clienteDocumento: cliente?.documento,
        metodoPago: metodoPago,
        tipoComprobante: 'TICKET',
        detalles: detallesEnvio,
        idempotencyKey: idempotencyKey,
        montoRecibido: montoRecibido,
      );

      bool ventaRegistrada = false;

      // Intentar registro en línea si no está forzado offline
      if (!OfflineSyncManager.instance.isForceOffline) {
        final res = await _ventaService.registrarVentaCompleta(ventaEnvio);
        if (res.success) {
          ventaRegistrada = true;
        }
      }

      // Si falló o estamos offline, encolar en OfflineSyncManager
      if (!ventaRegistrada) {
        final offlineVenta = OfflineVenta(
          uuid: idempotencyKey,
          localTicket:
              'TK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          idBodega: 1,
          idCliente: cliente?.idCliente,
          clienteDocumento: cliente?.documento,
          clienteNombre: cliente?.nombreCompleto ?? 'Cliente Mostrador',
          metodoPago: metodoPago,
          tipoComprobante: 'TICKET',
          montoRecibido: montoRecibido,
          vuelto: montoRecibido != null && montoRecibido > total
              ? montoRecibido - total
              : 0.0,
          total: total,
          usuarioRegistro: 'mostrador',
          fechaCreacion: DateTime.now(),
          detalles: detallesOffline,
        );
        await OfflineSyncManager.instance.enqueueSale(offlineVenta);
      }

      // Abrir gaveta de dinero si fue en efectivo
      if (metodoPago == 'EFECTIVO') {
        try {
          await ThermalTicketService.abrirGavetaDinero();
        } catch (_) {}
      }

      // Actualizar métricas locales de caja
      setState(() {
        _cajaTotal += total;
        if (metodoPago == 'EFECTIVO') {
          _cajaEfectivo += total;
        } else if (metodoPago == 'YAPE') {
          _cajaYape += total;
        }

        // Limpiar cuenta procesada
        _montosTicket.clear();
        _bufferCalculadora = '';
        _carritoCat.clear();
        _mostrarEfectivoInline = false;
        _mostrarFiadoInline = false;
      });

      VentaService.notifyVentasChanged();
      KarlizSoundService.instance.playBarcodeBeep();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  LucideIcons.checkCircle2,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  '¡Cobrado S/ ${total.toStringAsFixed(2)} con $metodoPago!',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF15803D),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar cobro: $e'),
            backgroundColor: AppTheme.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcesandoVenta = false);
      }
    }
  }

  // ==========================================================
  // CONSTRUCCIÓN VISUAL PRINCIPAL
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final surface = isDark ? AppTheme.cardDark : Colors.white;
    final border = isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // Barra Superior de Control: Conmutador de Vistas + Caja Diaria
            _buildTopControlBar(isDark, surface, border),

            // Contenido según Subvista Activa
            Expanded(
              child: _subvista == MostradorSubvista.calculadora
                  ? _buildCalculadoraSplitView(isDark, surface, border)
                  : _buildCatalogoBuscadorView(isDark, surface, border),
            ),
          ],
        ),
      ),
    );
  }

  // Barra Superior con Conmutador Segmentado
  Widget _buildTopControlBar(bool isDark, Color surface, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          // Conmutador Segmentado: Calculadora ↔ Catálogo
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSegmentButton(
                  title: 'Calculadora',
                  icon: LucideIcons.calculator,
                  isActive: _subvista == MostradorSubvista.calculadora,
                  onTap: () => _guardarPreferenciaSubvista(
                    MostradorSubvista.calculadora,
                  ),
                  isDark: isDark,
                ),
                _buildSegmentButton(
                  title: 'Catálogo',
                  icon: LucideIcons.layoutGrid,
                  isActive: _subvista == MostradorSubvista.catalogo,
                  onTap: () =>
                      _guardarPreferenciaSubvista(MostradorSubvista.catalogo),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Resumen de Caja Diaria en Vivo
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildCajaPill(
                    icon: LucideIcons.banknote,
                    label: 'Cajón',
                    value: 'S/ ${_cajaEfectivo.toStringAsFixed(2)}',
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildCajaPill(
                    icon: LucideIcons.smartphone,
                    label: 'Yape',
                    value: 'S/ ${_cajaYape.toStringAsFixed(2)}',
                    color: const Color(0xFFC084FC),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildCajaPill(
                    icon: LucideIcons.star,
                    label: 'Total',
                    value: 'S/ ${_cajaTotal.toStringAsFixed(2)}',
                    color: const Color(0xFF60A5FA),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Botón para volver al POS Completo
          IconButton(
            tooltip: 'Volver al POS tradicional',
            icon: Icon(
              LucideIcons.arrowRightFromLine,
              size: 20,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
            onPressed: widget.onVolverAPos,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? const Color(0xFF2563EB) : const Color(0xFF1E40AF))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF1E40AF).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive
                  ? Colors.white
                  : (isDark ? Colors.white60 : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                color: isActive
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCajaPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // VISTA 1: CALCULADORA DE MOSTRADOR (TIRA CONTINUA FIJA)
  // ==========================================================
  Widget _buildCalculadoraSplitView(bool isDark, Color surface, Color border) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Columna Izquierda: Tira de Papel / Ticket en Vivo
              SizedBox(
                width: 340,
                child: _buildTicketPaperCol(isDark, surface, border),
              ),
              // Columna Derecha: Teclado Gigante y Cobro Inmediato
              Expanded(
                child: _buildNumpadAndCheckoutCol(isDark, surface, border),
              ),
            ],
          );
        }

        // Layout Móvil: Tira compacta arriba + Teclado abajo
        return Column(
          children: [
            SizedBox(
              height: 220,
              child: _buildTicketPaperCol(isDark, surface, border),
            ),
            Expanded(
              child: _buildNumpadAndCheckoutCol(isDark, surface, border),
            ),
          ],
        );
      },
    );
  }

  // Columna Tira de Papel
  Widget _buildTicketPaperCol(bool isDark, Color surface, Color border) {
    final total = _totalCalculadora;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(right: BorderSide(color: border)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'TIRA DE CUENTA',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ),
              if (_montosTicket.isNotEmpty)
                InkWell(
                  onTap: _cancelarTicket,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      'Borrar todo',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.alertRed,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 16),

          // Lista de montos en la tira de papel
          Expanded(
            child: _montosTicket.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.receipt,
                          size: 38,
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Digita montos a la derecha\ny presiona [+ SUMAR]',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _montosTicket.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 6),
                    itemBuilder: (ctx, idx) {
                      final m = _montosTicket[idx];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${idx + 1}.',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Monto sumado',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            Text(
                              'S/ ${m.toStringAsFixed(2)}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? const Color(0xFF60A5FA)
                                    : const Color(0xFF1E40AF),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _borrarLineaTicket(idx),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  LucideIcons.x,
                                  size: 14,
                                  color: AppTheme.alertRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Total en letras gigantes
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL A COBRAR',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'S/',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF60A5FA),
                      ),
                    ),
                    Text(
                      total.toStringAsFixed(2),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Botón Deshacer Último
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.alertRed,
              side: const BorderSide(color: Color(0xFFFECDD3)),
              backgroundColor: const Color(0xFFFFF1F2),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _montosTicket.isNotEmpty ? _deshacerUltimoMonto : null,
            icon: const Icon(LucideIcons.undo2, size: 15),
            label: Text(
              'Deshacer último',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Columna Teclado Numérico y Cobro Directo
  Widget _buildNumpadAndCheckoutCol(bool isDark, Color surface, Color border) {
    final total = _totalCalculadora;
    final tieneItems = _montosTicket.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Display de la Calculadora
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFFBFDBFE),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MONTO A SUMAR:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  _bufferCalculadora.isEmpty
                      ? 'S/ 0.00'
                      : 'S/ $_bufferCalculadora',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? const Color(0xFF60A5FA)
                        : const Color(0xFF1E40AF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Teclado + Botón Gigante [+ SUMAR]
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 12 Botones Numéricos
              Expanded(
                flex: 3,
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.35,
                  children: [
                    for (final digit in [
                      '7',
                      '8',
                      '9',
                      '4',
                      '5',
                      '6',
                      '1',
                      '2',
                      '3',
                    ])
                      _buildNumpadKey(digit, isDark, surface, border),
                    _buildNumpadKey(
                      'C',
                      isDark,
                      surface,
                      border,
                      isClear: true,
                    ),
                    _buildNumpadKey('0', isDark, surface, border),
                    _buildNumpadKey('.', isDark, surface, border),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Botón Gigante [+ SUMAR AL TICKET]
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 220,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF1E40AF),
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: _sumarAlTicket,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.plus, size: 38),
                        const SizedBox(height: 8),
                        Text(
                          'SUMAR AL\nTICKET',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
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

          // 3 Botones de Cobro Inmediato (Efectivo / Yape / Fiar)
          Row(
            children: [
              // Efectivo
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: tieneItems
                        ? () {
                            setState(() {
                              _mostrarEfectivoInline = !_mostrarEfectivoInline;
                              _mostrarFiadoInline = false;
                              _billeteSeleccionado = -1;
                            });
                          }
                        : null,
                    icon: const Icon(LucideIcons.banknote, size: 20),
                    label: Text(
                      'EFECTIVO',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Yape / Plin
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF742284),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: tieneItems
                        ? () => _ejecutarVenta(metodoPago: 'YAPE', total: total)
                        : null,
                    icon: const Icon(LucideIcons.smartphone, size: 20),
                    label: Text(
                      'YAPE / PLIN',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Fiar a Vecino
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBE123C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: tieneItems
                        ? () {
                            setState(() {
                              _mostrarFiadoInline = !_mostrarFiadoInline;
                              _mostrarEfectivoInline = false;
                            });
                          }
                        : null,
                    icon: const Icon(LucideIcons.bookUser, size: 20),
                    label: Text(
                      'FIAR',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Sub-panel Inline Efectivo (Billetes y Vuelto)
          if (_mostrarEfectivoInline && tieneItems) ...[
            const SizedBox(height: 12),
            _buildEfectivoBilletesBox(total, isDark, surface, border),
          ],

          // Sub-panel Inline Fiados (Vecinos)
          if (_mostrarFiadoInline && tieneItems) ...[
            const SizedBox(height: 12),
            _buildFiadosVecinosBox(total, isDark, surface, border),
          ],
        ],
      ),
    );
  }

  Widget _buildNumpadKey(
    String label,
    bool isDark,
    Color surface,
    Color border, {
    bool isClear = false,
  }) {
    return Material(
      key: ValueKey('numpad_$label'),
      color: isClear ? const Color(0xFFFFF1F2) : surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isClear ? const Color(0xFFFECDD3) : border),
      ),
      child: InkWell(
        onTap: isClear ? _limpiarBuffer : () => _presionarDigito(label),
        borderRadius: BorderRadius.circular(10),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isClear ? 18 : 22,
              fontWeight: FontWeight.w800,
              color: isClear
                  ? AppTheme.alertRed
                  : (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEfectivoBilletesBox(
    double total,
    bool isDark,
    Color surface,
    Color border,
  ) {
    double? vuelto;
    if (_billeteSeleccionado > 0 && _billeteSeleccionado >= total) {
      vuelto = _billeteSeleccionado - total;
    } else if (_billeteSeleccionado == 0) {
      vuelto = 0.0;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '¿CON CUÁNTO PAGA EL CLIENTE?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF166534),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              _buildBillChip(0, 'Exacto', isDark),
              const SizedBox(width: 6),
              _buildBillChip(10, 'S/ 10', isDark),
              const SizedBox(width: 6),
              _buildBillChip(20, 'S/ 20', isDark),
              const SizedBox(width: 6),
              _buildBillChip(50, 'S/ 50', isDark),
              const SizedBox(width: 6),
              _buildBillChip(100, 'S/ 100', isDark),
            ],
          ),

          if (vuelto != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'VUELTO A ENTREGAR:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                  Text(
                    'S/ ${vuelto.toStringAsFixed(2)}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF78350F),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),

          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF15803D),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              final montoRec = _billeteSeleccionado > 0
                  ? _billeteSeleccionado.toDouble()
                  : total;
              _ejecutarVenta(
                metodoPago: 'EFECTIVO',
                total: total,
                montoRecibido: montoRec,
              );
            },
            child: Text(
              'Confirmar Cobro en Efectivo',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillChip(int billVal, String label, bool isDark) {
    final isSelected = _billeteSeleccionado == billVal;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _billeteSeleccionado = billVal);
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0F172A)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFCBD5E1),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFiadosVecinosBox(
    double total,
    bool isDark,
    Color surface,
    Color border,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECDD3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'TOCA AL VECINO PARA CARGARLE LA DEUDA:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFBE123C),
            ),
          ),
          const SizedBox(height: 8),

          if (_clientesVecinos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'No hay clientes registrados aún.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _clientesVecinos.take(6).map((c) {
                return ActionChip(
                  avatar: const Icon(LucideIcons.user, size: 14),
                  label: Text(
                    c.nombreCompleto,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => _ejecutarVenta(
                    metodoPago: 'CREDITO',
                    total: total,
                    cliente: c,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // VISTA 2: CATÁLOGO & BUSCADOR INTELIGENTE
  // ==========================================================
  Widget _buildCatalogoBuscadorView(bool isDark, Color surface, Color border) {
    final query = _busquedaController.text.trim().toLowerCase();
    List<Producto> filtrados = widget.productosDisponibles;

    if (_categoriaSeleccionada != 'TODOS') {
      filtrados = filtrados
          .where(
            (p) =>
                (p.nombreCategoria ?? '').toUpperCase() ==
                _categoriaSeleccionada,
          )
          .toList();
    }

    if (query.isNotEmpty) {
      filtrados = filtrados.where((p) {
        final nom = p.nombre.toLowerCase();
        final cod = (p.codigoBarras ?? p.codigo).toLowerCase();
        return nom.contains(query) || cod.contains(query);
      }).toList();
    }

    final totalCat = _totalCatalogo;

    return Column(
      children: [
        // Buscador Inteligente + Escáner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: surface,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _busquedaController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar producto o código...',
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Escanear Código de Barras',
                icon: const Icon(LucideIcons.scanLine, size: 20),
                onPressed: () async {
                  final code = await KarlizBarcodeScannerModal.scan(context);
                  if (code != null && code.isNotEmpty) {
                    _busquedaController.text = code;
                    setState(() {});
                  }
                },
              ),
            ],
          ),
        ),

        // Píldoras de Categorías
        Container(
          height: 44,
          color: surface,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              _buildCatChip('TODOS', '⭐ Todos', isDark),
              _buildCatChip('BEBIDAS', '🥤 Bebidas', isDark),
              _buildCatChip('LACTEOS', '🥛 Lácteos', isDark),
              _buildCatChip('ABARROTES', '🌾 Abarrotes', isDark),
              _buildCatChip('LIMPIEZA', '🧼 Limpieza', isDark),
            ],
          ),
        ),

        // Grilla de Productos
        Expanded(
          child: filtrados.isEmpty
              ? Center(
                  child: Text(
                    'No se encontraron productos',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: filtrados.length,
                  itemBuilder: (ctx, idx) {
                    final p = filtrados[idx];
                    return _buildProductCard(p, isDark, surface, border);
                  },
                ),
        ),

        // Barra Inferior de Cobro Catálogo
        if (_carritoCat.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: surface,
              border: Border(top: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_carritoCat.length} productos en canasta',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        'S/ ${totalCat.toStringAsFixed(2)}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () =>
                      _ejecutarVenta(metodoPago: 'EFECTIVO', total: totalCat),
                  icon: const Icon(LucideIcons.checkCheck, size: 18),
                  label: const Text('COBRAR AHORA'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCatChip(String catKey, String label, bool isDark) {
    final isSelected = _categoriaSeleccionada == catKey;

    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _categoriaSeleccionada = catKey),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildProductCard(
    Producto p,
    bool isDark,
    Color surface,
    Color border,
  ) {
    return InkWell(
      onTap: () => _agregarProductoCatalogo(p),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Center(
                  child: ProductImageWidget(
                    imagenUrl: p.imagenUrl,
                    nombre: p.nombre,
                    categoria: p.nombreCategoria,
                    size: 80,
                    isDark: widget.isDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              p.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'S/ ${p.precioVenta.toStringAsFixed(2)}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF2563EB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
