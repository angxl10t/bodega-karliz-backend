import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/karliz_sound_service.dart';
import '../../../core/offline/offline_models.dart';
import '../../../core/offline/offline_sync_manager.dart';
import '../../../core/offline/uuid_helper.dart';
import '../../../core/secure_storage_service.dart';
import '../../../core/thermal_ticket_service.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/karliz_barcode_scanner_modal.dart';
import '../../../core/widgets/product_image_widget.dart';
import '../../clientes/cliente_model.dart';
import '../../clientes/cliente_service.dart';
import '../../clientes/nuevo_cliente_sheet.dart';
import '../../productos/producto_model.dart';
import '../venta_model.dart';
import '../venta_service.dart';

enum MostradorSubvista { calculadora, catalogo }

class MostradorCalculadoraView extends StatefulWidget {
  final List<Producto> productosDisponibles;
  final VoidCallback onVolverAPos;
  final bool isDark;
  final VentaService? ventaService;
  final ClienteService? clienteService;

  const MostradorCalculadoraView({
    super.key,
    required this.productosDisponibles,
    required this.onVolverAPos,
    required this.isDark,
    this.ventaService,
    this.clienteService,
  });

  @override
  State<MostradorCalculadoraView> createState() =>
      _MostradorCalculadoraViewState();
}

class _MostradorCalculadoraViewState extends State<MostradorCalculadoraView> {
  static const String _prefSubvistaKey = 'cajaya_mostrador_subvista_activa';
  static const int _maxUndoSteps = 30;
  static const List<String> _conceptosRapidos = [
    'Pan',
    'Suelto',
    'Verdura',
    'Otro',
  ];

  /// Producto genérico para montos manuales de la calculadora
  static Producto _productoManual(
    double monto, {
    String nombre = 'Monto manual',
  }) => Producto(
    idProducto: null,
    codigo: 'MANUAL',
    nombre: nombre,
    precioVenta: monto,
    stockActual: 9999,
  );

  MostradorSubvista _subvista = MostradorSubvista.calculadora;

  // ── Ticket Unificado (calculadora + catálogo en la MISMA cuenta) ──
  final List<CartItem> _ticket = [];
  final List<List<CartItem>> _undoHistory = [];
  String _bufferCalculadora = '';
  String _conceptoManualSeleccionado = '';
  int _billeteSeleccionado = -1;
  double? _montoEfectivoCustom;
  bool _mostrarEfectivoInline = false;

  // ── Estado Modo Catálogo & Buscador ──
  final TextEditingController _busquedaController = TextEditingController();
  String _categoriaSeleccionada = 'TODOS';

  // ── Clientes para fiados ──
  late final ClienteService _clienteService;
  List<Cliente> _clientesVecinos = [];
  bool _isCargandoClientes = false;
  String? _errorClientes;

  // ── Resumen de caja diaria ──
  late final VentaService _ventaService;
  double _cajaEfectivo = 0.0;
  double _cajaYape = 0.0;
  double _cajaTotal = 0.0;
  bool _isCargandoCaja = false;
  bool _errorCaja = false;
  bool _isProcesandoVenta = false;
  String? _alertaMensaje;
  bool _alertaEsError = true;

  @override
  void initState() {
    super.initState();
    _ventaService = widget.ventaService ?? VentaService();
    _clienteService = widget.clienteService ?? ClienteService();
    _cargarPreferenciaSubvista();
    _cargarVecinos();
    _cargarCierreCajaHoy();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  // CARGA INICIAL CON MANEJO DE ERRORES Y REINTENTO
  // ══════════════════════════════════════════════════════════════
  Future<void> _cargarPreferenciaSubvista() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(_prefSubvistaKey);
      if (val == 'catalogo' && mounted) {
        setState(() => _subvista = MostradorSubvista.catalogo);
      }
    } catch (e) {
      developer.log(
        'Error cargando preferencia subvista: $e',
        name: 'Mostrador',
      );
    }
  }

  Future<void> _guardarPreferenciaSubvista(MostradorSubvista sub) async {
    setState(() => _subvista = sub);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefSubvistaKey,
        sub == MostradorSubvista.catalogo ? 'catalogo' : 'calculadora',
      );
    } catch (e) {
      developer.log(
        'Error guardando preferencia subvista: $e',
        name: 'Mostrador',
      );
    }
  }

  Future<void> _cargarVecinos({bool mostrarErrorUsuario = false}) async {
    if (_isCargandoClientes) return;
    if (mounted) {
      setState(() {
        _isCargandoClientes = true;
        _errorClientes = null;
      });
    }
    try {
      final list = await _clienteService.getClientes();
      if (mounted) {
        setState(() {
          _clientesVecinos = list;
          _isCargandoClientes = false;
        });
      }
    } catch (e) {
      developer.log('Error cargando clientes vecinos: $e', name: 'Mostrador');
      if (mounted) {
        setState(() {
          _isCargandoClientes = false;
          _errorClientes = 'No se pudieron cargar los vecinos.';
        });
        if (mostrarErrorUsuario) {
          _mostrarErrorBanner('No se pudieron cargar los clientes: $e');
        }
      }
    }
  }

  Future<void> _cargarCierreCajaHoy({bool mostrarErrorUsuario = false}) async {
    if (_isCargandoCaja) return;
    if (mounted) {
      setState(() {
        _isCargandoCaja = true;
        _errorCaja = false;
      });
    }
    try {
      final cierre = await _ventaService.getCierreCajaHoy();
      if (!mounted) return;
      if (cierre != null) {
        setState(() {
          _cajaTotal = cierre.totalVentas;
          _cajaEfectivo = cierre.totalEfectivo;
          _cajaYape = cierre.totalYape + cierre.totalPlin;
          _isCargandoCaja = false;
          _errorCaja = false;
        });
      } else {
        setState(() {
          _isCargandoCaja = false;
          _errorCaja = true;
        });
        if (mostrarErrorUsuario) {
          _mostrarErrorBanner('No se pudo actualizar el resumen de caja.');
        }
      }
    } catch (e) {
      developer.log('Error cargando cierre de caja: $e', name: 'Mostrador');
      if (mounted) {
        setState(() {
          _isCargandoCaja = false;
          _errorCaja = true;
        });
        if (mostrarErrorUsuario) {
          _mostrarErrorBanner('No se pudo cargar el resumen de caja.');
        }
      }
    }
  }

  // ══════════════════════════════════════════════════════════════
  // FEEDBACK DE ERRORES Y UTILIDADES DE FORMATO
  // ══════════════════════════════════════════════════════════════
  void _mostrarErrorBanner(String mensaje) {
    if (!mounted) return;
    setState(() {
      _alertaMensaje = mensaje;
      _alertaEsError = true;
    });
  }

  void _mostrarAvisoBanner(String mensaje) {
    if (!mounted) return;
    setState(() {
      _alertaMensaje = mensaje;
      _alertaEsError = false;
    });
  }

  static String _formatCantidad(double cant) {
    if ((cant - cant.roundToDouble()).abs() < 0.001) {
      return cant.round().toString();
    }
    return cant.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  static String _normalizarTexto(String input) {
    return input
        .trim()
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N');
  }

  // ══════════════════════════════════════════════════════════════
  // HISTORIAL REAL DE DESHACER (UNDO STACK MULTI-PASO)
  // ══════════════════════════════════════════════════════════════
  List<CartItem> _clonarTicket() {
    return _ticket
        .map(
          (item) => CartItem(
            producto: item.producto,
            cantidad: item.cantidad,
            descuentoManual: item.descuentoManual,
            descuentoMotivo: item.descuentoMotivo,
            variante: item.variante,
            notas: item.notas,
          ),
        )
        .toList();
  }

  void _registrarUndo() {
    _undoHistory.add(_clonarTicket());
    if (_undoHistory.length > _maxUndoSteps) {
      _undoHistory.removeAt(0);
    }
  }

  bool get _puedeDeshacer => _undoHistory.isNotEmpty || _ticket.isNotEmpty;

  // ══════════════════════════════════════════════════════════════
  // TOTAL UNIFICADO DEL TICKET
  // ══════════════════════════════════════════════════════════════
  double get _totalTicket =>
      _ticket.fold(0.0, (acc, item) => acc + item.subtotal);

  bool get _tieneItems => _ticket.isNotEmpty;

  // ══════════════════════════════════════════════════════════════
  // OPERACIONES DE LA CALCULADORA (MONTOS MANUALES AL TICKET)
  // ══════════════════════════════════════════════════════════════
  void _presionarDigito(String c) {
    if (_isProcesandoVenta) return;
    if (c == '.') {
      if (_bufferCalculadora.contains('.')) return;
      setState(() {
        _bufferCalculadora = _bufferCalculadora.isEmpty
            ? '0.'
            : '$_bufferCalculadora.';
      });
      HapticFeedback.selectionClick();
      return;
    }
    if (_bufferCalculadora.contains('.')) {
      final partes = _bufferCalculadora.split('.');
      if (partes.length > 1 && partes[1].length >= 2) return;
    }
    if (_bufferCalculadora.length >= 8) return;
    setState(() {
      if (_bufferCalculadora == '0' && c != '.') {
        _bufferCalculadora = c;
      } else {
        _bufferCalculadora += c;
      }
    });
    HapticFeedback.selectionClick();
  }

  void _retrocederDigito() {
    if (_isProcesandoVenta || _bufferCalculadora.isEmpty) return;
    setState(() {
      _bufferCalculadora = _bufferCalculadora.substring(
        0,
        _bufferCalculadora.length - 1,
      );
    });
    HapticFeedback.selectionClick();
  }

  void _limpiarBuffer() {
    if (_isProcesandoVenta) return;
    setState(() => _bufferCalculadora = '');
    HapticFeedback.selectionClick();
  }

  void _agregarMontoManualAlTicket(double val, {String? concepto}) {
    if (val <= 0 || val.isNaN || val.isInfinite) {
      HapticFeedback.vibrate();
      _mostrarAvisoBanner('Digita un monto válido mayor a S/ 0.00');
      return;
    }
    if (val > 99999.99) {
      HapticFeedback.vibrate();
      _mostrarErrorBanner('El monto máximo por ítem es S/ 99,999.99');
      return;
    }

    final nombreConcepto = (concepto != null && concepto.trim().isNotEmpty)
        ? concepto.trim()
        : (_conceptoManualSeleccionado.isNotEmpty
              ? _conceptoManualSeleccionado
              : 'Monto manual');

    setState(() {
      _registrarUndo();
      _ticket.add(
        CartItem(
          producto: _productoManual(val, nombre: nombreConcepto),
          cantidad: 1.0,
        ),
      );
      _bufferCalculadora = '';
      _conceptoManualSeleccionado = '';
      _alertaMensaje = null;
      _mostrarEfectivoInline = false;
    });
    KarlizSoundService.instance.playBarcodeBeep();
  }

  void _sumarAlTicket() {
    if (_isProcesandoVenta) return;
    final val = double.tryParse(_bufferCalculadora.replaceAll(',', '.'));
    if (val == null || val <= 0) {
      HapticFeedback.vibrate();
      _mostrarAvisoBanner('Digita un monto mayor a S/ 0.00 antes de sumar');
      return;
    }
    _agregarMontoManualAlTicket(val);
  }

  // ══════════════════════════════════════════════════════════════
  // OPERACIONES DEL CATÁLOGO (PRODUCTOS AL TICKET UNIFICADO)
  // ══════════════════════════════════════════════════════════════
  void _agregarProductoCatalogo(Producto p) {
    if (_isProcesandoVenta) return;
    if (p.stockActual <= 0) {
      HapticFeedback.vibrate();
      _mostrarErrorBanner('Sin stock disponible para ${p.nombre}');
      return;
    }

    final idx = _ticket.indexWhere(
      (item) =>
          item.producto.idProducto != null &&
          p.idProducto != null &&
          item.producto.idProducto == p.idProducto,
    );
    final cantidadActual = idx >= 0 ? _ticket[idx].cantidad : 0.0;
    if (cantidadActual + 1 > p.stockActual + 0.0001) {
      HapticFeedback.vibrate();
      _mostrarAvisoBanner(
        'Stock insuficiente para ${p.nombre} (Disponible: ${_formatCantidad(p.stockActual)})',
      );
      return;
    }

    setState(() {
      _registrarUndo();
      if (idx >= 0) {
        _ticket[idx].cantidad += 1;
      } else {
        _ticket.add(CartItem(producto: p, cantidad: 1));
      }
      _alertaMensaje = null;
      _mostrarEfectivoInline = false;
    });
    KarlizSoundService.instance.playBarcodeBeep();
  }

  void _quitarUnoCatalogo(Producto p) {
    if (_isProcesandoVenta) return;
    final idx = _ticket.indexWhere(
      (item) =>
          item.producto.idProducto != null &&
          p.idProducto != null &&
          item.producto.idProducto == p.idProducto,
    );
    if (idx < 0) return;
    _decrementarCantidad(idx);
  }

  // ══════════════════════════════════════════════════════════════
  // EDICIÓN DE LÍNEAS DEL TICKET UNIFICADO
  // ══════════════════════════════════════════════════════════════
  void _incrementarCantidad(int index) {
    if (_isProcesandoVenta || index < 0 || index >= _ticket.length) return;
    final item = _ticket[index];
    final isManual = item.producto.codigo == 'MANUAL';
    if (!isManual && item.cantidad + 1 > item.producto.stockActual + 0.0001) {
      HapticFeedback.vibrate();
      _mostrarAvisoBanner(
        'Tope de stock alcanzado para ${item.producto.nombre} (${_formatCantidad(item.producto.stockActual)})',
      );
      return;
    }
    setState(() {
      _registrarUndo();
      _ticket[index].cantidad += 1;
    });
    HapticFeedback.selectionClick();
  }

  void _decrementarCantidad(int index) {
    if (_isProcesandoVenta || index < 0 || index >= _ticket.length) return;
    if (_ticket[index].cantidad <= 1) {
      _borrarLineaTicket(index);
      return;
    }
    setState(() {
      _registrarUndo();
      _ticket[index].cantidad -= 1;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _editarCantidadManual(int index) async {
    if (_isProcesandoVenta || index < 0 || index >= _ticket.length) return;
    final item = _ticket[index];
    final isManual = item.producto.codigo == 'MANUAL';

    final result = await showDialog<_LineaEditResult>(
      context: context,
      builder: (_) => _EditarLineaTicketDialog(
        item: item,
        isManual: isManual,
        formatCantidad: _formatCantidad,
      ),
    );
    if (result == null || !mounted || index >= _ticket.length) return;

    setState(() {
      _registrarUndo();
      if (isManual) {
        _ticket[index] = CartItem(
          producto: _productoManual(
            result.montoUnitario ?? item.producto.precioVenta,
            nombre: (result.concepto ?? '').trim().isNotEmpty
                ? result.concepto!.trim()
                : item.producto.nombre,
          ),
          cantidad: result.cantidad,
        );
      } else {
        _ticket[index].cantidad = result.cantidad;
      }
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _abrirModalMontoRapido({double? montoInicial}) async {
    if (_isProcesandoVenta) return;
    final result = await showDialog<_MontoRapidoResult>(
      context: context,
      builder: (_) => _AgregarMontoRapidoDialog(
        montoInicial: montoInicial,
        conceptosSugeridos: _conceptosRapidos,
      ),
    );
    if (result == null || !mounted) return;
    _agregarMontoManualAlTicket(result.monto, concepto: result.concepto);
  }

  void _borrarLineaTicket(int index) {
    if (_isProcesandoVenta) return;
    if (index >= 0 && index < _ticket.length) {
      setState(() {
        _registrarUndo();
        _ticket.removeAt(index);
        if (_ticket.isEmpty) {
          _mostrarEfectivoInline = false;
        }
      });
      HapticFeedback.mediumImpact();
    }
  }

  void _deshacerUltimo() {
    if (_isProcesandoVenta) return;
    if (_undoHistory.isNotEmpty) {
      setState(() {
        _ticket
          ..clear()
          ..addAll(_undoHistory.removeLast());
        if (_ticket.isEmpty) {
          _mostrarEfectivoInline = false;
        }
      });
      HapticFeedback.mediumImpact();
      return;
    }
    if (_ticket.isNotEmpty) {
      setState(() {
        _ticket.removeLast();
        if (_ticket.isEmpty) {
          _mostrarEfectivoInline = false;
        }
      });
      HapticFeedback.mediumImpact();
    }
  }

  void _cancelarTicket() {
    if (_isProcesandoVenta || _ticket.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar cuenta?'),
        content: const Text(
          'Se borrarán todos los productos y montos de la cuenta actual (puedes recuperarlo con Deshacer último).',
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
                _registrarUndo();
                _ticket.clear();
                _bufferCalculadora = '';
                _mostrarEfectivoInline = false;
              });
              HapticFeedback.heavyImpact();
            },
            child: const Text('Sí, borrar cuenta'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // EJECUCIÓN REAL DE VENTA (UNIFICADA CON MANEJO DE ERRORES)
  // ══════════════════════════════════════════════════════════════
  static bool _esErrorDeRed(String? error) {
    if (error == null) return false;
    final e = error.toLowerCase();
    return e.contains('conexión') ||
        e.contains('conexion') ||
        e.contains('internet') ||
        e.contains('servidor no disponible') ||
        e.contains('timeout') ||
        e.contains('socket') ||
        e.contains('failed host lookup') ||
        e.contains('connection refused') ||
        e.contains('network') ||
        e.contains('clientexception') ||
        e.contains('502') ||
        e.contains('503') ||
        e.contains('504');
  }

  static String _normalizarMetodoPago(String raw) {
    switch (raw.toUpperCase()) {
      case 'EFECTIVO':
        return 'Efectivo';
      case 'YAPE':
        return 'Yape';
      case 'CREDITO':
        return 'Crédito';
      default:
        return raw;
    }
  }

  Future<void> _ejecutarVenta({
    required String metodoPago,
    required double total,
    Cliente? cliente,
    double? montoRecibido,
  }) async {
    if (_isProcesandoVenta) return;
    if (_ticket.isEmpty || total <= 0) {
      _mostrarAvisoBanner(
        'Agrega al menos un monto o producto antes de cobrar.',
      );
      return;
    }
    if (metodoPago == 'EFECTIVO' &&
        montoRecibido != null &&
        montoRecibido + 0.001 < total) {
      _mostrarErrorBanner(
        'El monto recibido (S/ ${montoRecibido.toStringAsFixed(2)}) es menor al total.',
      );
      return;
    }
    if (metodoPago == 'CREDITO') {
      if (cliente == null) {
        _mostrarErrorBanner('Selecciona un vecino para registrar el fiado.');
        return;
      }
      if (cliente.excedeCon(total)) {
        final disponible = (cliente.limiteCredito - cliente.saldoDeudor).clamp(
          0.0,
          double.infinity,
        );
        _mostrarErrorBanner(
          'Límite de crédito excedido para ${cliente.nombreCompleto}. Disponible: S/ ${disponible.toStringAsFixed(2)}',
        );
        return;
      }
    }

    // Validar stock agregado de productos del catálogo antes de enviar
    final catalogItems = _ticket
        .where((i) => i.producto.idProducto != null)
        .toList();
    final manualItems = _ticket
        .where((i) => i.producto.idProducto == null)
        .toList();

    final Map<int, double> cantPorProd = {};
    final Map<int, Producto> prodPorId = {};
    for (final item in catalogItems) {
      final id = item.producto.idProducto!;
      cantPorProd[id] = (cantPorProd[id] ?? 0.0) + item.cantidad;
      prodPorId[id] = item.producto;
    }
    for (final entry in cantPorProd.entries) {
      final prod = prodPorId[entry.key]!;
      if (entry.value > prod.stockActual + 0.0001) {
        _mostrarErrorBanner(
          'Stock insuficiente para ${prod.nombre}. Tienes ${_formatCantidad(prod.stockActual)} y la cuenta pide ${_formatCantidad(entry.value)}.',
        );
        return;
      }
    }

    setState(() => _isProcesandoVenta = true);
    HapticFeedback.heavyImpact();

    try {
      int idBodega = 1;
      String usuarioReg = 'mostrador';
      try {
        final rawBodega = await SecureStorageService.read('id_bodega');
        idBodega = int.tryParse(rawBodega ?? '') ?? 1;
        final rawUser =
            await SecureStorageService.read('nombre_usuario') ??
            await SecureStorageService.read('usuario');
        if (rawUser != null && rawUser.trim().isNotEmpty) {
          usuarioReg = rawUser.trim();
        }
      } catch (e) {
        developer.log(
          'No se pudo leer metadata local de bodega: $e',
          name: 'Mostrador',
        );
      }

      final metodoNorm = _normalizarMetodoPago(metodoPago);
      final double totalCatalogo = catalogItems.fold(
        0.0,
        (acc, i) => acc + i.subtotal,
      );
      final double totalManual = manualItems.fold(
        0.0,
        (acc, i) => acc + i.subtotal,
      );
      bool enqueuedOffline = false;

      if (catalogItems.isNotEmpty) {
        final detallesEnvio = catalogItems
            .map(
              (item) => VentaDetalleEnvio(
                idProducto: item.producto.idProducto!,
                cantidad: item.cantidad,
              ),
            )
            .toList();
        final detallesOffline = catalogItems
            .map(
              (item) => OfflineVentaDetalle(
                idProducto: item.producto.idProducto!,
                nombreProducto: item.producto.nombre,
                cantidad: item.cantidad,
                precioUnitario: item.producto.precioVenta,
                subtotal: item.subtotal,
                codigo: item.producto.codigo,
              ),
            )
            .toList();

        final idempotencyKey = UuidHelper.generateV4();
        final ventaEnvio = VentaEnvio(
          idCliente: cliente?.idCliente,
          clienteNombre: cliente?.nombreCompleto ?? 'Cliente Mostrador',
          clienteDocumento: cliente?.documento,
          metodoPago: metodoNorm,
          tipoComprobante: 'TICKET',
          detalles: detallesEnvio,
          idempotencyKey: idempotencyKey,
          montoRecibido: montoRecibido,
        );

        bool catalogSyncOk = false;
        final forceOffline =
            OfflineSyncManager.instance.isForceOffline ||
            OfflineSyncManager.instance.isOfflineNotifier.value;

        if (!forceOffline) {
          final res = await _ventaService.registrarVentaCompleta(ventaEnvio);
          if (res.success) {
            catalogSyncOk = true;
          } else if (!_esErrorDeRed(res.errorMessage)) {
            if (!mounted) return;
            _mostrarErrorBanner(
              res.errorMessage ?? 'El servidor rechazó la venta.',
            );
            return;
          }
        }

        if (!catalogSyncOk) {
          final offlineVenta = OfflineVenta(
            uuid: idempotencyKey,
            localTicket:
                'TK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
            idBodega: idBodega,
            idCliente: cliente?.idCliente,
            clienteDocumento: cliente?.documento,
            clienteNombre: cliente?.nombreCompleto ?? 'Cliente Mostrador',
            metodoPago: metodoNorm,
            tipoComprobante: 'TICKET',
            montoRecibido: montoRecibido,
            vuelto: montoRecibido != null && montoRecibido > total
                ? montoRecibido - total
                : 0.0,
            total: totalCatalogo,
            usuarioRegistro: usuarioReg,
            fechaCreacion: DateTime.now(),
            detalles: detallesOffline,
          );
          await OfflineSyncManager.instance.enqueueSale(offlineVenta);
          enqueuedOffline = true;
        }
      }

      // Abrir gaveta de dinero si fue en efectivo
      if (metodoPago == 'EFECTIVO') {
        try {
          await ThermalTicketService.abrirGavetaDinero();
        } catch (e) {
          developer.log('No se pudo abrir gaveta: $e', name: 'Mostrador');
        }
      }

      if (!mounted) return;
      setState(() {
        _cajaTotal += total;
        if (metodoPago == 'EFECTIVO') {
          _cajaEfectivo += total;
        } else if (metodoPago == 'YAPE') {
          _cajaYape += total;
        }

        _ticket.clear();
        _undoHistory.clear();
        _bufferCalculadora = '';
        _conceptoManualSeleccionado = '';
        _alertaMensaje = null;
        _billeteSeleccionado = -1;
        _montoEfectivoCustom = null;
        _mostrarEfectivoInline = false;
      });

      VentaService.notifyVentasChanged();
      KarlizSoundService.instance.playBarcodeBeep();

      String mensajeConfirmacion;
      Color bgColor = const Color(0xFF15803D);
      if (enqueuedOffline && manualItems.isEmpty) {
        mensajeConfirmacion =
            '¡Cobrado S/ ${total.toStringAsFixed(2)} (Modo Offline - se sincronizará al volver internet)!';
        bgColor = const Color(0xFF0369A1);
      } else if (manualItems.isNotEmpty && catalogItems.isNotEmpty) {
        mensajeConfirmacion =
            '¡Cobrado S/ ${total.toStringAsFixed(2)}! (Catálogo sincronizado + S/ ${totalManual.toStringAsFixed(2)} manual en mostrador)';
      } else if (manualItems.isNotEmpty) {
        mensajeConfirmacion =
            '¡Cobrado S/ ${total.toStringAsFixed(2)} con $metodoNorm (Mostrador rápido)!';
        if (metodoPago == 'CREDITO') {
          mensajeConfirmacion +=
              ' Nota: montos manuales sin catálogo quedan solo en caja local.';
          bgColor = Colors.orange.shade800;
        }
      } else {
        mensajeConfirmacion =
            '¡Cobrado S/ ${total.toStringAsFixed(2)} con $metodoNorm!';
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    LucideIcons.checkCircle2,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      mensajeConfirmacion,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: bgColor,
              duration: const Duration(seconds: 4),
            ),
          );
      }
    } catch (e) {
      developer.log('Error crítico al registrar venta: $e', name: 'Mostrador');
      _mostrarErrorBanner('Error al registrar cobro: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcesandoVenta = false);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════
  // CONSTRUCCIÓN VISUAL PRINCIPAL
  // ══════════════════════════════════════════════════════════════
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
            _buildTopControlBar(isDark, surface, border),
            if (_alertaMensaje != null) _buildTopAlertBanner(),
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

  Widget _buildTopAlertBanner() {
    final bg = _alertaEsError ? AppTheme.alertRed : Colors.orange.shade800;
    final icon = _alertaEsError
        ? LucideIcons.alertCircle
        : LucideIcons.alertTriangle;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: bg,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _alertaMensaje ?? '',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _alertaMensaje = null),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(LucideIcons.x, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ── Barra Superior con Conmutador Segmentado ──
  Widget _buildTopControlBar(bool isDark, Color surface, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
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
          IconButton(
            tooltip: 'Actualizar resumen de caja',
            visualDensity: VisualDensity.compact,
            onPressed: _isCargandoCaja
                ? null
                : () => _cargarCierreCajaHoy(mostrarErrorUsuario: true),
            icon: _isCargandoCaja
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    LucideIcons.refreshCw,
                    size: 16,
                    color: _errorCaja
                        ? Colors.orange.shade600
                        : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                  ),
          ),
          if (_tieneItems) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_ticket.length}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Volver al POS tradicional',
            icon: Icon(
              LucideIcons.arrowRightFromLine,
              size: 20,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
            onPressed: _isProcesandoVenta ? null : widget.onVolverAPos,
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

  // ══════════════════════════════════════════════════════════════
  // VISTA 1: CALCULADORA DE MOSTRADOR
  // ══════════════════════════════════════════════════════════════
  Widget _buildCalculadoraSplitView(bool isDark, Color surface, Color border) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        if (isWide) {
          final ticketWidth = (constraints.maxWidth * 0.36).clamp(270.0, 350.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: ticketWidth,
                child: _buildTicketPaperCol(isDark, surface, border),
              ),
              Expanded(
                child: _buildNumpadAndCheckoutCol(isDark, surface, border),
              ),
            ],
          );
        }

        if (constraints.maxHeight < 520) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTicketPaperCol(
                  isDark,
                  surface,
                  border,
                  isCompactVertical: true,
                  expandList: false,
                ),
                _buildNumpadAndCheckoutCol(
                  isDark,
                  surface,
                  border,
                  shrinkWrapScroll: true,
                ),
              ],
            ),
          );
        }

        final topTicketHeight = (constraints.maxHeight * 0.36).clamp(
          215.0,
          360.0,
        );

        return Column(
          children: [
            SizedBox(
              height: topTicketHeight,
              child: _buildTicketPaperCol(
                isDark,
                surface,
                border,
                isCompactVertical: true,
              ),
            ),
            Expanded(
              child: _buildNumpadAndCheckoutCol(isDark, surface, border),
            ),
          ],
        );
      },
    );
  }

  ButtonStyle _buildUndoButtonStyle(
    bool isDark, {
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    ),
  }) {
    final enabledFg = isDark
        ? const Color(0xFFFECACA)
        : const Color(0xFF991B1B);
    final enabledBg = isDark
        ? const Color(0xFF45141B)
        : const Color(0xFFFEE2E2);
    final enabledBorder = isDark
        ? const Color(0xFFF87171).withValues(alpha: 0.65)
        : const Color(0xFFFCA5A5);

    final disabledFg = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF475569);
    final disabledBg = isDark
        ? AppTheme.cardDarkElevated
        : const Color(0xFFF1F5F9);
    final disabledBorder = isDark
        ? AppTheme.borderDarkElevated
        : const Color(0xFFCBD5E1);

    return ButtonStyle(
      padding: WidgetStatePropertyAll(padding),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.disabled) ? disabledFg : enabledFg;
      }),
      iconColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.disabled) ? disabledFg : enabledFg;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.disabled) ? disabledBg : enabledBg;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        final color = states.contains(WidgetState.disabled)
            ? disabledBorder
            : enabledBorder;
        return BorderSide(color: color, width: 1.2);
      }),
      textStyle: WidgetStatePropertyAll(
        GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }

  // ── Columna Tira de Papel (TICKET UNIFICADO) ──
  Widget _buildTicketPaperCol(
    bool isDark,
    Color surface,
    Color border, {
    bool isCompactVertical = false,
    bool expandList = true,
  }) {
    final total = _totalTicket;

    final Widget listaItemsWidget = _ticket.isEmpty
        ? LayoutBuilder(
            builder: (context, box) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: box.maxHeight.isFinite ? box.maxHeight : 0,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.receipt,
                          size: isCompactVertical ? 28 : 38,
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                        SizedBox(height: isCompactVertical ? 4 : 8),
                        Text(
                          'Digita montos con la calculadora\no agrega productos del catálogo',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isCompactVertical ? 11.5 : 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          )
        : ListView.separated(
            shrinkWrap: !expandList,
            physics: expandList ? null : const NeverScrollableScrollPhysics(),
            itemCount: _ticket.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (ctx, idx) {
              final item = _ticket[idx];
              final isManual = item.producto.codigo == 'MANUAL';
              return _buildTicketLine(
                idx: idx,
                item: item,
                isManual: isManual,
                isDark: isDark,
                border: border,
              );
            },
          );

    final Widget undoButton = OutlinedButton.icon(
      style: _buildUndoButtonStyle(
        isDark,
        padding: EdgeInsets.symmetric(
          horizontal: isCompactVertical ? 10 : 12,
          vertical: isCompactVertical ? 12 : 10,
        ),
      ),
      onPressed: (_puedeDeshacer && !_isProcesandoVenta)
          ? _deshacerUltimo
          : null,
      icon: const Icon(LucideIcons.undo2, size: 15),
      label: const Text('Deshacer último'),
    );

    return ClipRect(
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          border: isCompactVertical
              ? Border(bottom: BorderSide(color: border))
              : Border(right: BorderSide(color: border)),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: isCompactVertical ? 10 : 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: expandList ? MainAxisSize.max : MainAxisSize.min,
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
                if (_tieneItems)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_ticket.length} items',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
              ],
            ),
            Divider(height: isCompactVertical ? 10 : 16),

            // Lista de items en el ticket unificado
            if (expandList)
              Expanded(child: listaItemsWidget)
            else
              listaItemsWidget,

            SizedBox(height: isCompactVertical ? 8 : 10),

            if (isCompactVertical)
              // Pie compacto en vertical: TOTAL A COBRAR + Deshacer último lado a lado sin colisionar
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              'TOTAL A COBRAR',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: Colors.white60,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'S/',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF60A5FA),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                total.toStringAsFixed(2),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  undoButton,
                ],
              )
            else ...[
              // Total en letras gigantes (vista ancha / horizontal)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFF0F172A),
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
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              total.toStringAsFixed(2),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Botón Deshacer Último
              undoButton,
            ],
          ],
        ),
      ),
    );
  }

  /// Línea individual del ticket con controles [−] qty [+] nombre S/xx [🗑]
  Widget _buildTicketLine({
    required int idx,
    required CartItem item,
    required bool isManual,
    required bool isDark,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Text(
            '${idx + 1}.',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(width: 6),

          // Controles de cantidad [−] qty [+] (solo para productos, o tap para editar monto/qty)
          if (!isManual) ...[
            _buildQtyButton(
              icon: LucideIcons.minus,
              onTap: _isProcesandoVenta
                  ? null
                  : () => _decrementarCantidad(idx),
              isDark: isDark,
            ),
            GestureDetector(
              onTap: _isProcesandoVenta
                  ? null
                  : () => _editarCantidadManual(idx),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatCantidad(item.cantidad),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
            _buildQtyButton(
              icon: LucideIcons.plus,
              onTap: _isProcesandoVenta
                  ? null
                  : () => _incrementarCantidad(idx),
              isDark: isDark,
            ),
            const SizedBox(width: 6),
          ],

          // Nombre del producto / concepto manual (tap para editar cantidad decimal o monto)
          Expanded(
            child: InkWell(
              onTap: _isProcesandoVenta
                  ? null
                  : () => _editarCantidadManual(idx),
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.producto.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  if (isManual)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        LucideIcons.pencil,
                        size: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Subtotal
          Text(
            'S/ ${item.subtotal.toStringAsFixed(2)}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E40AF),
            ),
          ),
          const SizedBox(width: 4),

          // Botón Eliminar
          InkWell(
            onTap: _isProcesandoVenta ? null : () => _borrarLineaTicket(idx),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(LucideIcons.x, size: 14, color: AppTheme.alertRed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 12, color: Colors.white),
      ),
    );
  }

  // ── Columna Teclado Numérico y Cobro Directo (UNIFICADO) ──
  Widget _buildNumpadAndCheckoutCol(
    bool isDark,
    Color surface,
    Color border, {
    bool shrinkWrapScroll = false,
  }) {
    final total = _totalTicket;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: shrinkWrapScroll ? MainAxisSize.min : MainAxisSize.max,
      children: [
        // Display de la Calculadora + Retroceso
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  'MONTO A SUMAR:',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
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
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                key: const ValueKey('numpad_backspace'),
                tooltip: 'Borrar último dígito',
                visualDensity: VisualDensity.compact,
                onPressed:
                    (_bufferCalculadora.isNotEmpty && !_isProcesandoVenta)
                    ? _retrocederDigito
                    : null,
                icon: Icon(
                  Icons.backspace_outlined,
                  size: 19,
                  color: _bufferCalculadora.isNotEmpty
                      ? AppTheme.alertRed
                      : (isDark ? Colors.white24 : Colors.black26),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Etiquetas rápidas opcionales para montos sueltos (Pan, Suelto, etc.)
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _conceptosRapidos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (ctx, i) {
              final c = _conceptosRapidos[i];
              final active = _conceptoManualSeleccionado == c;
              return ChoiceChip(
                label: Text(c),
                selected: active,
                visualDensity: VisualDensity.compact,
                onSelected: _isProcesandoVenta
                    ? null
                    : (_) => setState(() {
                        _conceptoManualSeleccionado = active ? '' : c;
                      }),
                labelStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // Teclado + Botón Gigante [+ SUMAR]
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  _buildNumpadKey('C', isDark, surface, border, isClear: true),
                  _buildNumpadKey('0', isDark, surface, border),
                  _buildNumpadKey('.', isDark, surface, border),
                ],
              ),
            ),
            const SizedBox(width: 10),
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
                  onPressed: _isProcesandoVenta ? null : _sumarAlTicket,
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

        // ── 3 Botones de Cobro (SIEMPRE VISIBLES) ──
        _buildBotonesCobroUnificados(total, isDark, surface, border),
      ],
    );

    if (shrinkWrapScroll) {
      return Padding(padding: const EdgeInsets.all(14), child: content);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: content,
    );
  }

  /// Botones de cobro unificados (Efectivo / Yape / Fiar) reutilizables
  Widget _buildBotonesCobroUnificados(
    double total,
    bool isDark,
    Color surface,
    Color border,
  ) {
    final bool canCheckout = _tieneItems && !_isProcesandoVenta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isProcesandoVenta) ...[
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: canCheckout
                      ? () {
                          setState(() {
                            _mostrarEfectivoInline = !_mostrarEfectivoInline;
                            _billeteSeleccionado = -1;
                            _montoEfectivoCustom = null;
                          });
                        }
                      : null,
                  icon: const Icon(LucideIcons.banknote, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'EFECTIVO',
                      maxLines: 1,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF742284),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: canCheckout
                      ? () => _ejecutarVenta(metodoPago: 'YAPE', total: total)
                      : null,
                  icon: _isProcesandoVenta
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(LucideIcons.smartphone, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'YAPE / PLIN',
                      maxLines: 1,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBE123C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: canCheckout
                      ? () => _abrirModalSeleccionarClienteFiado(total)
                      : null,
                  icon: const Icon(LucideIcons.bookUser, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'FIAR',
                      maxLines: 1,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_mostrarEfectivoInline && _tieneItems) ...[
          const SizedBox(height: 12),
          _buildEfectivoBilletesBox(total, isDark, surface, border),
        ],
      ],
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
        onTap: _isProcesandoVenta
            ? null
            : (isClear ? _limpiarBuffer : () => _presionarDigito(label)),
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

  Future<void> _abrirDialogoEfectivoCustom(double total) async {
    if (_isProcesandoVenta) return;
    final val = await showDialog<double>(
      context: context,
      builder: (_) => _EfectivoCustomDialog(total: total),
    );
    if (val != null && mounted) {
      setState(() {
        _billeteSeleccionado = -1;
        _montoEfectivoCustom = val;
      });
    }
  }

  Widget _buildEfectivoBilletesBox(
    double total,
    bool isDark,
    Color surface,
    Color border,
  ) {
    final double? montoIngresado =
        _montoEfectivoCustom ??
        (_billeteSeleccionado > 0
            ? _billeteSeleccionado.toDouble()
            : (_billeteSeleccionado == 0 ? total : null));

    double? vuelto;
    if (montoIngresado != null && montoIngresado + 0.001 >= total) {
      vuelto = (montoIngresado - total).clamp(0.0, double.infinity);
    }

    final bool billeteInsuficiente =
        montoIngresado != null && montoIngresado + 0.001 < total;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  '¿CON CUÁNTO PAGA EL CLIENTE?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF166534),
                  ),
                ),
              ),
              InkWell(
                onTap: _isProcesandoVenta
                    ? null
                    : () => _abrirDialogoEfectivoCustom(total),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _montoEfectivoCustom != null
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _montoEfectivoCustom != null
                        ? 'Otro: S/ ${_montoEfectivoCustom!.toStringAsFixed(2)}'
                        : 'Otro monto',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _montoEfectivoCustom != null
                          ? Colors.white
                          : const Color(0xFF166534),
                    ),
                  ),
                ),
              ),
            ],
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
          if (billeteInsuficiente) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.alertRed),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.alertTriangle,
                    size: 14,
                    color: AppTheme.alertRed,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'El monto S/ ${montoIngresado.toStringAsFixed(2)} es menor al total S/ ${total.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            onPressed: (billeteInsuficiente || _isProcesandoVenta)
                ? null
                : () {
                    final montoRec = montoIngresado ?? total;
                    _ejecutarVenta(
                      metodoPago: 'EFECTIVO',
                      total: total,
                      montoRecibido: montoRec,
                    );
                  },
            child: Text(
              _isProcesandoVenta
                  ? 'Registrando cobro...'
                  : 'Confirmar Cobro en Efectivo',
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
    final isSelected =
        _montoEfectivoCustom == null && _billeteSeleccionado == billVal;
    return Expanded(
      child: InkWell(
        onTap: _isProcesandoVenta
            ? null
            : () {
                setState(() {
                  _montoEfectivoCustom = null;
                  _billeteSeleccionado = billVal;
                });
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

  Future<void> _abrirModalSeleccionarClienteFiado(double total) async {
    if (_isProcesandoVenta) return;
    setState(() {
      _mostrarEfectivoInline = false;
    });

    final seleccionado = await showDialog<Cliente>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => _SelectorClienteFiadoDialog(
        clientes: _clientesVecinos,
        totalVenta: total,
        clienteService: _clienteService,
        errorInicial: _errorClientes,
        isCargandoInicial: _isCargandoClientes,
        onClientesActualizados: (nuevos) {
          if (mounted) {
            setState(() {
              _clientesVecinos = nuevos;
              _errorClientes = null;
            });
          }
        },
      ),
    );

    if (seleccionado != null && mounted) {
      await _ejecutarVenta(
        metodoPago: 'CREDITO',
        total: total,
        cliente: seleccionado,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════
  // VISTA 2: CATÁLOGO & BUSCADOR (agrega al ticket unificado)
  // ══════════════════════════════════════════════════════════════
  static String _labelCategoriaConEmoji(String rawCategoria) {
    final norm = _normalizarTexto(rawCategoria);
    switch (norm) {
      case 'BEBIDAS':
      case 'GASEOSAS':
        return '🥤 $rawCategoria';
      case 'LACTEOS':
        return '🥛 $rawCategoria';
      case 'ABARROTES':
        return '🌾 $rawCategoria';
      case 'LIMPIEZA':
        return '🧼 $rawCategoria';
      case 'PANADERIA':
      case 'PAN':
        return '🥖 $rawCategoria';
      case 'SNACKS':
      case 'GOLOSINAS':
        return '🍪 $rawCategoria';
      case 'CARNES':
      case 'EMBUTIDOS':
        return '🥩 $rawCategoria';
      case 'FRUTAS':
      case 'VERDURAS':
        return '🥬 $rawCategoria';
      default:
        return '📦 $rawCategoria';
    }
  }

  Future<void> _escanearCodigoCatalogo() async {
    if (_isProcesandoVenta) return;
    try {
      final code = await KarlizBarcodeScannerModal.scan(context);
      if (!mounted || code == null || code.trim().isEmpty) return;
      final clean = code.trim();
      final exacto = widget.productosDisponibles.cast<Producto?>().firstWhere(
        (p) =>
            p != null &&
            ((p.codigoBarras ?? '').trim().toLowerCase() ==
                    clean.toLowerCase() ||
                p.codigo.trim().toLowerCase() == clean.toLowerCase()),
        orElse: () => null,
      );
      if (exacto != null) {
        _agregarProductoCatalogo(exacto);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Agregado: ${exacto.nombre}'),
              backgroundColor: const Color(0xFF15803D),
              duration: const Duration(seconds: 2),
            ),
          );
      } else {
        _busquedaController.text = clean;
        setState(() {});
        final hayCoincidencia = widget.productosDisponibles.any((p) {
          final nom = p.nombre.toLowerCase();
          final cod = (p.codigoBarras ?? p.codigo).toLowerCase();
          return nom.contains(clean.toLowerCase()) ||
              cod.contains(clean.toLowerCase());
        });
        if (!hayCoincidencia) {
          _mostrarAvisoBanner('No se encontró producto con código "$clean"');
        }
      }
    } catch (e) {
      developer.log(
        'Error al escanear código de barras: $e',
        name: 'Mostrador',
      );
      _mostrarErrorBanner('No se pudo abrir el escáner: $e');
    }
  }

  Future<void> _abrirModalTicketUnificado() async {
    final isDark = widget.isDark;
    final surface = isDark ? AppTheme.cardDark : Colors.white;
    final border = isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final total = _totalTicket;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.68,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'CUENTA UNIFICADA (${_ticket.length} ítems)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _isProcesandoVenta
                                ? null
                                : () async {
                                    await _abrirModalMontoRapido();
                                    if (ctx.mounted) setSheetState(() {});
                                  },
                            icon: const Icon(LucideIcons.plus, size: 15),
                            label: const Text('+ Monto / Pan'),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.pop(sheetCtx),
                            icon: const Icon(LucideIcons.x, size: 18),
                          ),
                        ],
                      ),
                      const Divider(height: 12),
                      Expanded(
                        child: _ticket.isEmpty
                            ? Center(
                                child: Text(
                                  'La cuenta está vacía',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _ticket.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (_, idx) {
                                  final item = _ticket[idx];
                                  final isManual =
                                      item.producto.codigo == 'MANUAL';
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
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
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black45,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        if (!isManual) ...[
                                          _buildQtyButton(
                                            icon: LucideIcons.minus,
                                            onTap: _isProcesandoVenta
                                                ? null
                                                : () {
                                                    _decrementarCantidad(idx);
                                                    setSheetState(() {});
                                                  },
                                            isDark: isDark,
                                          ),
                                          GestureDetector(
                                            onTap: _isProcesandoVenta
                                                ? null
                                                : () async {
                                                    await _editarCantidadManual(
                                                      idx,
                                                    );
                                                    if (ctx.mounted) {
                                                      setSheetState(() {});
                                                    }
                                                  },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0xFF334155)
                                                    : const Color(0xFFE2E8F0),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _formatCantidad(item.cantidad),
                                                style:
                                                    GoogleFonts.jetBrainsMono(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: isDark
                                                          ? Colors.white
                                                          : Colors.black87,
                                                    ),
                                              ),
                                            ),
                                          ),
                                          _buildQtyButton(
                                            icon: LucideIcons.plus,
                                            onTap: _isProcesandoVenta
                                                ? null
                                                : () {
                                                    _incrementarCantidad(idx);
                                                    setSheetState(() {});
                                                  },
                                            isDark: isDark,
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        Expanded(
                                          child: InkWell(
                                            onTap: _isProcesandoVenta
                                                ? null
                                                : () async {
                                                    await _editarCantidadManual(
                                                      idx,
                                                    );
                                                    if (ctx.mounted) {
                                                      setSheetState(() {});
                                                    }
                                                  },
                                            child: Text(
                                              item.producto.nombre,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'S/ ${item.subtotal.toStringAsFixed(2)}',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? const Color(0xFF60A5FA)
                                                : const Color(0xFF1E40AF),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Quitar línea',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: _isProcesandoVenta
                                              ? null
                                              : () {
                                                  _borrarLineaTicket(idx);
                                                  setSheetState(() {});
                                                },
                                          icon: Icon(
                                            LucideIcons.x,
                                            size: 16,
                                            color: AppTheme.alertRed,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const Divider(height: 12),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: _buildUndoButtonStyle(
                              isDark,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onPressed: (_puedeDeshacer && !_isProcesandoVenta)
                                ? () {
                                    _deshacerUltimo();
                                    setSheetState(() {});
                                  }
                                : null,
                            icon: const Icon(LucideIcons.undo2, size: 15),
                            label: const Text('Deshacer'),
                          ),
                          const Spacer(),
                          Text(
                            'Total: S/ ${total.toStringAsFixed(2)}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCatalogoBuscadorView(bool isDark, Color surface, Color border) {
    final query = _busquedaController.text.trim().toLowerCase();
    List<Producto> filtrados = widget.productosDisponibles;

    // Construir mapa dinámico de categorías normalizadas (sin romper acentos como Lácteos)
    final Map<String, String> categoriasDinamicas = {};
    for (final p in widget.productosDisponibles) {
      final rawCat = (p.nombreCategoria ?? '').trim();
      if (rawCat.isNotEmpty) {
        final key = _normalizarTexto(rawCat);
        categoriasDinamicas.putIfAbsent(
          key,
          () => _labelCategoriaConEmoji(rawCat),
        );
      }
    }

    if (_categoriaSeleccionada != 'TODOS') {
      filtrados = filtrados
          .where(
            (p) =>
                _normalizarTexto(p.nombreCategoria ?? '') ==
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

    final total = _totalTicket;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // Buscador Inteligente + Escáner + Monto Rápido en la misma cuenta
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
                        suffixIcon: _busquedaController.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'Limpiar búsqueda',
                                icon: const Icon(LucideIcons.x, size: 16),
                                onPressed: () {
                                  _busquedaController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    key: const ValueKey('btn_monto_rapido_catalogo'),
                    onPressed: _isProcesandoVenta
                        ? null
                        : () => _abrirModalMontoRapido(),
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: Text(
                      'Monto',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    tooltip: 'Escanear Código de Barras',
                    icon: const Icon(LucideIcons.scanLine, size: 20),
                    onPressed: _isProcesandoVenta
                        ? null
                        : _escanearCodigoCatalogo,
                  ),
                ],
              ),
            ),

            // Píldoras de Categorías dinámicas + fallback
            Container(
              height: 44,
              color: surface,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  _buildCatChip('TODOS', '⭐ Todos', isDark),
                  if (categoriasDinamicas.isEmpty) ...[
                    _buildCatChip('BEBIDAS', '🥤 Bebidas', isDark),
                    _buildCatChip('LACTEOS', '🥛 Lácteos', isDark),
                    _buildCatChip('ABARROTES', '🌾 Abarrotes', isDark),
                    _buildCatChip('LIMPIEZA', '🧼 Limpieza', isDark),
                  ] else
                    for (final entry in categoriasDinamicas.entries)
                      _buildCatChip(entry.key, entry.value, isDark),
                ],
              ),
            ),

            // Grilla de Productos
            Expanded(
              child: filtrados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'No se encontraron productos',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          if (_busquedaController.text.isNotEmpty ||
                              _categoriaSeleccionada != 'TODOS') ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => setState(() {
                                _busquedaController.clear();
                                _categoriaSeleccionada = 'TODOS';
                              }),
                              child: const Text('Mostrar todos los productos'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.78,
                          ),
                      itemCount: filtrados.length,
                      itemBuilder: (ctx, idx) {
                        final p = filtrados[idx];
                        return _buildProductCard(p, isDark, surface, border);
                      },
                    ),
            ),

            // ── Barra Inferior de Cobro Unificado (o recuperación tras borrado) ──
            if (_tieneItems)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (constraints.maxHeight * 0.56).clamp(150.0, 480.0),
                ),
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: surface,
                      border: Border(top: BorderSide(color: border)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _abrirModalTicketUnificado,
                                borderRadius: BorderRadius.circular(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            '${_ticket.length} items en cuenta',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Ver / editar',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF2563EB),
                                          ),
                                        ),
                                      ],
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'S/ ${total.toStringAsFixed(2)}',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF15803D),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Ver y editar detalle de cuenta',
                              icon: Icon(
                                Icons.receipt_long_outlined,
                                size: 19,
                                color: isDark
                                    ? const Color(0xFF60A5FA)
                                    : const Color(0xFF1E40AF),
                              ),
                              onPressed: _abrirModalTicketUnificado,
                            ),
                            IconButton(
                              tooltip: 'Deshacer último',
                              icon: Icon(
                                LucideIcons.undo2,
                                size: 18,
                                color: (_puedeDeshacer && !_isProcesandoVenta)
                                    ? (isDark
                                          ? const Color(0xFFFCA5A5)
                                          : const Color(0xFF991B1B))
                                    : (isDark
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF94A3B8)),
                              ),
                              onPressed: (_puedeDeshacer && !_isProcesandoVenta)
                                  ? _deshacerUltimo
                                  : null,
                            ),
                            const SizedBox(width: 2),
                            IconButton(
                              tooltip: 'Borrar todo',
                              icon: Icon(
                                LucideIcons.trash2,
                                size: 18,
                                color: isDark
                                    ? const Color(0xFFFCA5A5)
                                    : const Color(0xFF991B1B),
                              ),
                              onPressed: _isProcesandoVenta
                                  ? null
                                  : _cancelarTicket,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildBotonesCobroUnificados(
                          total,
                          isDark,
                          surface,
                          border,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_puedeDeshacer)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border(top: BorderSide(color: border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cuenta vacía — puedes recuperar tu selección anterior',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: _buildUndoButtonStyle(
                        isDark,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: _isProcesandoVenta ? null : _deshacerUltimo,
                      icon: const Icon(LucideIcons.undo2, size: 15),
                      label: const Text('Deshacer último'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
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
    final ticketIdx = _ticket.indexWhere(
      (item) =>
          item.producto.idProducto != null &&
          p.idProducto != null &&
          item.producto.idProducto == p.idProducto,
    );
    final cantidadEnTicket = ticketIdx >= 0 ? _ticket[ticketIdx].cantidad : 0.0;
    final sinStock = p.stockActual <= 0;

    return InkWell(
      onTap: _isProcesandoVenta ? null : () => _agregarProductoCatalogo(p),
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: sinStock ? 0.55 : 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cantidadEnTicket > 0
                      ? const Color(0xFF2563EB)
                      : border,
                  width: cantidadEnTicket > 0 ? 2 : 1,
                ),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'S/ ${p.precioVenta.toStringAsFixed(2)}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      Text(
                        sinStock
                            ? 'Agotado'
                            : 'Stk ${_formatCantidad(p.stockActual)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: sinStock
                              ? AppTheme.alertRed
                              : (isDark
                                    ? Colors.white54
                                    : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (cantidadEnTicket > 0)
            Positioned(
              top: 4,
              left: 4,
              child: Material(
                color: AppTheme.alertRed,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _isProcesandoVenta
                      ? null
                      : () => _quitarUnoCatalogo(p),
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Icon(
                      LucideIcons.minus,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          if (cantidadEnTicket > 0)
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: _isProcesandoVenta
                    ? null
                    : () => _editarCantidadManual(ticketIdx),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '×${_formatCantidad(cantidadEnTicket)}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// DIÁLOGOS AUXILIARES CON GESTIÓN SEGURA DE CONTROLLERS
// ══════════════════════════════════════════════════════════════

class _LineaEditResult {
  final double cantidad;
  final double? montoUnitario;
  final String? concepto;

  const _LineaEditResult({
    required this.cantidad,
    this.montoUnitario,
    this.concepto,
  });
}

class _EditarLineaTicketDialog extends StatefulWidget {
  final CartItem item;
  final bool isManual;
  final String Function(double) formatCantidad;

  const _EditarLineaTicketDialog({
    required this.item,
    required this.isManual,
    required this.formatCantidad,
  });

  @override
  State<_EditarLineaTicketDialog> createState() =>
      _EditarLineaTicketDialogState();
}

class _EditarLineaTicketDialogState extends State<_EditarLineaTicketDialog> {
  late final TextEditingController _cantidadCtrl;
  late final TextEditingController _conceptoCtrl;
  late final TextEditingController _montoCtrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _cantidadCtrl = TextEditingController(
      text: widget.formatCantidad(widget.item.cantidad),
    );
    _conceptoCtrl = TextEditingController(text: widget.item.producto.nombre);
    _montoCtrl = TextEditingController(
      text: widget.item.producto.precioVenta.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _conceptoCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final cant = double.tryParse(
      _cantidadCtrl.text.trim().replaceAll(',', '.'),
    );
    if (cant == null || cant <= 0 || cant.isNaN || cant.isInfinite) {
      setState(() => _errorText = 'Ingresa una cantidad mayor a 0 (ej: 1.5).');
      return;
    }

    if (widget.isManual) {
      final monto = double.tryParse(
        _montoCtrl.text.trim().replaceAll(',', '.'),
      );
      if (monto == null || monto <= 0 || monto.isNaN || monto.isInfinite) {
        setState(() => _errorText = 'Ingresa un monto válido mayor a S/ 0.00.');
        return;
      }
      if (monto > 99999.99) {
        setState(() => _errorText = 'El monto máximo es S/ 99,999.99.');
        return;
      }
      Navigator.pop(
        context,
        _LineaEditResult(
          cantidad: cant,
          montoUnitario: monto,
          concepto: _conceptoCtrl.text.trim(),
        ),
      );
      return;
    }

    if (cant > widget.item.producto.stockActual + 0.0001) {
      setState(
        () => _errorText =
            'Stock insuficiente (disponible: ${widget.formatCantidad(widget.item.producto.stockActual)}).',
      );
      return;
    }

    Navigator.pop(context, _LineaEditResult(cantidad: cant));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isManual
            ? 'Editar monto manual'
            : 'Editar cantidad: ${widget.item.producto.nombre}',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isManual) ...[
              TextField(
                controller: _conceptoCtrl,
                decoration: InputDecoration(
                  labelText: 'Concepto (ej: Pan, Culantro)',
                  prefixIcon: const Icon(LucideIcons.pencil),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Monto S/ (ej: 1.50)',
                  prefixIcon: const Icon(LucideIcons.banknote),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _cantidadCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: !widget.isManual,
              decoration: InputDecoration(
                labelText: 'Cantidad (ej: 1.5)',
                hintText: '1.5',
                helperText: widget.isManual
                    ? null
                    : 'Disponible: ${widget.formatCantidad(widget.item.producto.stockActual)}',
                prefixIcon: const Icon(LucideIcons.hash),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ['0.5', '1', '1.5', '2', '2.5'].map((preset) {
                return ActionChip(
                  label: Text(preset),
                  onPressed: () {
                    _cantidadCtrl.text = preset;
                    setState(() => _errorText = null);
                  },
                );
              }).toList(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.alertRed,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Aceptar')),
      ],
    );
  }
}

class _MontoRapidoResult {
  final double monto;
  final String concepto;

  const _MontoRapidoResult({required this.monto, required this.concepto});
}

class _AgregarMontoRapidoDialog extends StatefulWidget {
  final double? montoInicial;
  final List<String> conceptosSugeridos;

  const _AgregarMontoRapidoDialog({
    this.montoInicial,
    required this.conceptosSugeridos,
  });

  @override
  State<_AgregarMontoRapidoDialog> createState() =>
      _AgregarMontoRapidoDialogState();
}

class _AgregarMontoRapidoDialogState extends State<_AgregarMontoRapidoDialog> {
  late final TextEditingController _montoCtrl;
  late final TextEditingController _conceptoCtrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _montoCtrl = TextEditingController(
      text: widget.montoInicial != null
          ? widget.montoInicial!.toStringAsFixed(2)
          : '',
    );
    _conceptoCtrl = TextEditingController(text: 'Pan');
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _conceptoCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final monto = double.tryParse(_montoCtrl.text.trim().replaceAll(',', '.'));
    if (monto == null || monto <= 0 || monto.isNaN || monto.isInfinite) {
      setState(() => _errorText = 'Ingresa un monto válido (ej: 1.50).');
      return;
    }
    if (monto > 99999.99) {
      setState(() => _errorText = 'El monto máximo por ítem es S/ 99,999.99.');
      return;
    }
    final concepto = _conceptoCtrl.text.trim().isEmpty
        ? 'Monto manual'
        : _conceptoCtrl.text.trim();
    Navigator.pop(
      context,
      _MontoRapidoResult(monto: monto, concepto: concepto),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Sumar monto manual a la cuenta',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Monto en S/ (ej: 1.50)',
                hintText: '1.50',
                prefixIcon: const Icon(LucideIcons.banknote),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _conceptoCtrl,
              decoration: InputDecoration(
                labelText: 'Descripción (ej: Pan)',
                prefixIcon: const Icon(LucideIcons.pencil),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.conceptosSugeridos.map((c) {
                return ActionChip(
                  label: Text(c),
                  onPressed: () {
                    _conceptoCtrl.text = c;
                    setState(() {});
                  },
                );
              }).toList(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.alertRed,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Sumar al ticket')),
      ],
    );
  }
}

class _EfectivoCustomDialog extends StatefulWidget {
  final double total;

  const _EfectivoCustomDialog({required this.total});

  @override
  State<_EfectivoCustomDialog> createState() => _EfectivoCustomDialogState();
}

class _EfectivoCustomDialogState extends State<_EfectivoCustomDialog> {
  late final TextEditingController _ctrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.total.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final val = double.tryParse(_ctrl.text.trim().replaceAll(',', '.'));
    if (val == null || val <= 0 || val.isNaN || val.isInfinite) {
      setState(() => _errorText = 'Ingresa un monto válido.');
      return;
    }
    if (val + 0.001 < widget.total) {
      setState(
        () => _errorText =
            'El monto debe ser al menos S/ ${widget.total.toStringAsFixed(2)}.',
      );
      return;
    }
    Navigator.pop(context, val);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Monto recibido en efectivo',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Efectivo entregado (S/)',
              helperText: 'Total cuenta: S/ ${widget.total.toStringAsFixed(2)}',
              prefixIcon: const Icon(LucideIcons.banknote),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorText!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.alertRed,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Aplicar')),
      ],
    );
  }
}

class _SelectorClienteFiadoDialog extends StatefulWidget {
  final List<Cliente> clientes;
  final double totalVenta;
  final ClienteService? clienteService;
  final String? errorInicial;
  final bool isCargandoInicial;
  final ValueChanged<List<Cliente>>? onClientesActualizados;

  const _SelectorClienteFiadoDialog({
    required this.clientes,
    required this.totalVenta,
    this.clienteService,
    this.errorInicial,
    this.isCargandoInicial = false,
    this.onClientesActualizados,
  });

  @override
  State<_SelectorClienteFiadoDialog> createState() =>
      _SelectorClienteFiadoDialogState();
}

class _SelectorClienteFiadoDialogState
    extends State<_SelectorClienteFiadoDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<Cliente> _clientes;
  late bool _isLoading;
  String? _error;

  @override
  void initState() {
    super.initState();
    _clientes = List<Cliente>.from(widget.clientes);
    _isLoading = widget.isCargandoInicial;
    _error = widget.errorInicial;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _recargarClientes() async {
    if (widget.clienteService == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await widget.clienteService!.getClientes();
      if (mounted) {
        setState(() {
          _clientes = list;
          _isLoading = false;
        });
        widget.onClientesActualizados?.call(list);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'No se pudieron cargar los vecinos.';
        });
      }
    }
  }

  Future<void> _abrirNuevoCliente(BuildContext context) async {
    final query = _searchCtrl.text.trim();
    final clientePrefill = query.isNotEmpty
        ? Cliente(nombreCompleto: query)
        : null;

    final nuevo = await NuevoClienteSheet.show(
      context,
      cliente: clientePrefill,
      clienteService: widget.clienteService,
    );

    if (nuevo != null && mounted) {
      setState(() {
        _clientes.insert(0, nuevo);
      });
      widget.onClientesActualizados?.call(_clientes);
      if (context.mounted) {
        Navigator.of(context).pop(nuevo);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.cardDarkElevated : Colors.white;
    final border = isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppTheme.textDarkPrimary : AppTheme.textDark;
    final textSecondary = isDark
        ? AppTheme.textDarkSecondary
        : AppTheme.textMuted;

    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = (screenHeight * 0.85).clamp(320.0, 560.0);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: border, width: 1.2),
      ),
      backgroundColor: bg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado con ícono, título y monto a fiar
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBE123C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.bookUser,
                      color: Color(0xFFBE123C),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seleccionar vecino para fiado',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Total a fiar: S/ ${widget.totalVenta.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFBE123C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Cerrar',
                    icon: Icon(LucideIcons.x, size: 20, color: textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Barra de búsqueda y botón "+ Nuevo Cliente"
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar vecino o celular...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                          prefixIcon: Icon(
                            LucideIcons.search,
                            size: 17,
                            color: textSecondary,
                          ),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(LucideIcons.x, size: 16),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? AppTheme.cardDarkSunken
                              : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.brandPrimary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      key: const ValueKey('btn_nuevo_cliente_fiado'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _abrirNuevoCliente(context),
                      icon: const Icon(LucideIcons.userPlus, size: 16),
                      label: Text(
                        'Nuevo',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Cuerpo con lista, carga, error o vacío
              Expanded(
                child: _buildBody(
                  context,
                  isDark,
                  textPrimary,
                  textSecondary,
                  border,
                ),
              ),
              const SizedBox(height: 8),

              // Pie de acción (Cancelar)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color border,
  ) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5),
            SizedBox(height: 12),
            Text('Cargando vecinos...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFECDD3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.alertCircle,
                color: Color(0xFF991B1B),
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF991B1B),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                key: const ValueKey('btn_reintentar_clientes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBE123C),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _recargarClientes,
                icon: const Icon(LucideIcons.refreshCw, size: 14),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final q = _searchCtrl.text.trim().toLowerCase();
    final filtrados = q.isEmpty
        ? _clientes
        : _clientes.where((c) {
            final nombre = c.nombreCompleto.toLowerCase();
            final tel = (c.telefono ?? '').toLowerCase();
            final doc = (c.documento ?? '').toLowerCase();
            return nombre.contains(q) || tel.contains(q) || doc.contains(q);
          }).toList();

    if (_clientes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.users,
                size: 38,
                color: textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 10),
              Text(
                'No hay clientes registrados aún.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Registra a tu primer vecino para poder anotarle fiados.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _abrirNuevoCliente(context),
                icon: const Icon(LucideIcons.userPlus, size: 16),
                label: const Text('Registrar nuevo cliente'),
              ),
            ],
          ),
        ),
      );
    }

    if (filtrados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.userX,
                size: 36,
                color: textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 10),
              Text(
                'No se encontró a "${_searchCtrl.text.trim()}"',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.brandPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _abrirNuevoCliente(context),
                icon: const Icon(LucideIcons.userPlus, size: 15),
                label: const Text('Registrar como nuevo cliente'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: filtrados.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        thickness: 0.8,
        color: border.withValues(alpha: 0.7),
      ),
      itemBuilder: (ctx, idx) {
        final c = filtrados[idx];
        final excede = c.excedeCon(widget.totalVenta);
        final disponible = (c.limiteCredito - c.saldoDeudor).clamp(
          0.0,
          double.infinity,
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => Navigator.pop(context, c),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: excede
                        ? const Color(0xFFFEE2E2)
                        : (c.esCaserito
                              ? const Color(0xFFFEF3C7)
                              : (isDark
                                    ? AppTheme.cardDarkSunken
                                    : const Color(0xFFEEF2FF))),
                    child: Icon(
                      excede
                          ? LucideIcons.alertTriangle
                          : (c.esCaserito
                                ? LucideIcons.star
                                : LucideIcons.user),
                      size: 16,
                      color: excede
                          ? AppTheme.alertRed
                          : (c.esCaserito
                                ? const Color(0xFFD97706)
                                : AppTheme.brandPrimary),
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
                                c.nombreCompleto,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: excede
                                      ? AppTheme.alertRed
                                      : textPrimary,
                                ),
                              ),
                            ),
                            if (c.esCaserito) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: const Color(0xFFFDE68A),
                                  ),
                                ),
                                child: Text(
                                  'Caserito',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          excede
                              ? 'Excede límite de crédito (S/ ${c.limiteCredito.toStringAsFixed(2)})'
                              : 'Disponible: S/ ${disponible.toStringAsFixed(2)}${c.telefono != null && c.telefono!.trim().isNotEmpty ? ' • ${c.telefono}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: excede
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: excede ? AppTheme.alertRed : textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (excede)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Límite',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.alertRed,
                        ),
                      ),
                    )
                  else
                    Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: textSecondary.withValues(alpha: 0.6),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
