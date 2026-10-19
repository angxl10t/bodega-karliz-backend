import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../productos/producto_model.dart';
import '../productos/producto_service.dart';
import '../productos/nuevo_producto_sheet.dart';
import '../movimientos/kardex_screen.dart';
import '../auth/auth_service.dart';
import '../home/plan_y_personal_sheet.dart';
import '../ventas/venta_model.dart';
import '../ventas/venta_service.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int tabIndex) onNavigateTab;

  const DashboardScreen({
    super.key,
    required this.onNavigateTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ProductoService _productoService = ProductoService();
  final VentaService _ventaService = VentaService();
  List<Producto> _productos = [];
  CierreCaja? _cierreHoy;
  String _nombreBodega = 'CajaYa POS';
  String _username = 'Usuario';
  String _userRol = 'ADMIN';
  String _plan = 'PRO';
  String _ruc = '';
  String _telefono = '';
  String _direccion = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    ProductoService.productosRevision.addListener(_onProductosRevisionChanged);
    VentaService.ventasRevision.addListener(_onVentasRevisionChanged);
    _cargarDatos();
  }

  @override
  void dispose() {
    ProductoService.productosRevision.removeListener(_onProductosRevisionChanged);
    VentaService.ventasRevision.removeListener(_onVentasRevisionChanged);
    super.dispose();
  }

  void _onProductosRevisionChanged() {
    if (mounted) {
      _cargarDatos(forceRefresh: true);
    }
  }

  void _onVentasRevisionChanged() {
    if (mounted) {
      _cargarCierreHoy();
    }
  }

  Future<void> _cargarCierreHoy() async {
    final cierre = await _ventaService.getCierreCajaHoy();
    if (mounted) {
      setState(() => _cierreHoy = cierre);
    }
  }

  Future<void> _cargarDatos({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final auth = AuthService();
    final results = await Future.wait([
      _productoService.getProductos(forceRefresh: forceRefresh),
      _ventaService.getCierreCajaHoy(),
      auth.getNombreBodega(),
      auth.getUsername(),
      auth.getUserRole(),
      auth.getPlanBodega(),
      auth.getRucBodega(),
      auth.getTelefonoBodega(),
      auth.getDireccionBodega(),
    ]);
    if (mounted) {
      setState(() {
        _productos = results[0] as List<Producto>;
        _cierreHoy = results[1] as CierreCaja?;
        _nombreBodega = (results[2] as String?) ?? 'CajaYa POS';
        _username = (results[3] as String?) ?? 'Usuario';
        _userRol = (results[4] as String?) ?? 'ADMIN';
        _plan = (results[5] as String?) ?? 'PRO';
        _ruc = (results[6] as String?) ?? '';
        _telefono = (results[7] as String?) ?? '';
        _direccion = (results[8] as String?) ?? '';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Métricas calculadas en tiempo real
    final int totalProductos = _productos.length;
    final double stockTotalUnidades = _productos.fold(0.0, (acc, p) => acc + p.stockActual);
    final double valorInventario = _productos.fold(0.0, (acc, p) => acc + (p.stockActual * p.precioVenta));
    final List<Producto> productosCriticos = _productos.where((p) => p.stockActual <= 5).toList();
    final List<Producto> productosBajos = _productos.where((p) => p.stockActual > 5 && p.stockActual <= 10).toList();
    final int totalAlertas = productosCriticos.length + productosBajos.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () => _cargarDatos(forceRefresh: true),
        color: AppTheme.brandPrimary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.brandPrimary))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Ejecutivo Rebrandeado CajaYa
                    _buildGreetingBanner(isDark),
                    const SizedBox(height: 14),

                    // Alerta de Quiebre de Stock Inminente (Acceso directo a reabastecimiento)
                    if (productosCriticos.isNotEmpty) ...[
                      _buildStockAlertBanner(productosCriticos, isDark),
                      const SizedBox(height: 14),
                    ],

                    // Banner Didáctico de Orientación
                    const DidacticBanner(
                      title: 'Consejo del Turno',
                      description: 'Gestiona tu turno desde las 5 pestañas inferiores: cobra en POS, cuadra en Caja, y repón desde Stock o Compras.',
                    ),
                    const SizedBox(height: 20),

                    // Título de Métricas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Métricas Clave del Negocio',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        Text(
                          'Actualizado hoy (En vivo)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: AppTheme.accentGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Cuadrícula de KPIs Responsiva
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildMetricTile(
                              constraints: constraints,
                              title: 'Ventas de Hoy',
                              value: 'S/ ${(_cierreHoy?.totalVentas ?? 0.0).toStringAsFixed(2)}',
                              subtitle: '${_cierreHoy?.cantidadVentas ?? 0} ventas hoy (En vivo)',
                              icon: LucideIcons.badgePercent,
                              accentColor: AppTheme.accentGreen,
                              isDark: isDark,
                              onTap: () => widget.onNavigateTab(2), // Tab Arqueo
                            ),
                            _buildMetricTile(
                              constraints: constraints,
                              title: 'Valor en Mercadería',
                              value: 'S/ ${valorInventario.toStringAsFixed(2)}',
                              subtitle: '${stockTotalUnidades % 1 == 0 ? stockTotalUnidades.toInt().toString() : stockTotalUnidades.toStringAsFixed(2)} unidades valorizadas',
                              icon: LucideIcons.wallet,
                              accentColor: AppTheme.brandPrimary,
                              isDark: isDark,
                              onTap: () => widget.onNavigateTab(3), // Tab Inventario
                            ),
                            _buildMetricTile(
                              constraints: constraints,
                              title: 'Catálogo Activo',
                              value: '$totalProductos Items',
                              subtitle: 'Productos registrados',
                              icon: LucideIcons.boxes,
                              accentColor: AppTheme.infoIndigo,
                              isDark: isDark,
                              onTap: () => widget.onNavigateTab(3), // Tab Inventario
                            ),
                            _buildMetricTile(
                              constraints: constraints,
                              title: 'Stock Crítico (≤ 5 u.)',
                              value: '${productosCriticos.length}',
                              subtitle: productosCriticos.isNotEmpty ? 'Requiere pedido urgente' : 'Sin faltantes',
                              icon: LucideIcons.alertCircle,
                              accentColor: AppTheme.alertRed,
                              isDark: isDark,
                              onTap: () => widget.onNavigateTab(3), // Tab Inventario
                            ),
                            _buildMetricTile(
                              constraints: constraints,
                              title: 'Stock Bajo (6-10 u.)',
                              value: '${productosBajos.length}',
                              subtitle: 'Próximos a reponer',
                              icon: LucideIcons.clock,
                              accentColor: AppTheme.warningAmber,
                              isDark: isDark,
                              onTap: () => widget.onNavigateTab(3), // Tab Inventario
                            ),
                          ],
                        );
                      },
                    ),

                    // Tarjeta en Directo de Canales de Pago
                    _buildPaymentBreakdownCard(isDark),
                    const SizedBox(height: 24),

                    // Accesos Rápidos Inteligentes
                    Text(
                      'Operaciones Principales',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double btnWidth = constraints.maxWidth >= 850
                            ? (constraints.maxWidth - 20) / 3
                            : (constraints.maxWidth >= 480
                                ? (constraints.maxWidth - 10) / 2
                                : constraints.maxWidth);

                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildQuickActionBtn(
                              width: btnWidth,
                              title: 'Cobrar en POS',
                              subtitle: 'Terminal de Venta',
                              icon: LucideIcons.shoppingBag,
                              color: AppTheme.brandPrimary,
                              isDark: isDark,
                              onTap: () => widget.onNavigateTab(1), // Tab POS
                            ),
                            _buildQuickActionBtn(
                              width: btnWidth,
                              title: 'Arqueo de Caja',
                              subtitle: 'Corte & Historial',
                              icon: LucideIcons.banknote,
                              color: AppTheme.accentGreen,
                              isDark: isDark,
                              onTap: () => widget.onNavigateTab(2), // Tab Caja
                            ),
                            _buildQuickActionBtn(
                              width: btnWidth,
                              title: 'Ver Inventario',
                              subtitle: 'Stock & Filtros',
                              icon: LucideIcons.boxes,
                              color: AppTheme.infoIndigo,
                              isDark: isDark,
                              onTap: () => widget.onNavigateTab(3), // Tab Stock
                            ),
                            _buildQuickActionBtn(
                              width: btnWidth,
                              title: 'Compras & Lotes',
                              subtitle: 'Ingreso Proveedores',
                              icon: LucideIcons.truck,
                              color: const Color(0xFF0284C7),
                              isDark: isDark,
                              onTap: () => widget.onNavigateTab(4), // Tab Compras
                            ),
                            _buildQuickActionBtn(
                              width: btnWidth,
                              title: 'Kardex Auditoría',
                              subtitle: 'Historial de Movimientos',
                              icon: LucideIcons.fileSpreadsheet,
                              color: const Color(0xFF0D9488),
                              isDark: isDark,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const KardexScreen()),
                                );
                              },
                            ),
                            _buildQuickActionBtn(
                              width: btnWidth,
                              title: '+ Nuevo Producto',
                              subtitle: 'Crear en Catálogo',
                              icon: LucideIcons.plusCircle,
                              color: AppTheme.brandPrimary,
                              isDark: isDark,
                              onTap: () => NuevoProductoSheet.show(context, _cargarDatos),
                            ),
                            _buildQuickActionBtn(
                              width: btnWidth,
                              title: 'Personal & Cajeros',
                              subtitle: 'Turnos & Accesos',
                              icon: LucideIcons.users,
                              color: const Color(0xFF6366F1),
                              isDark: isDark,
                              onTap: () => PlanYPersonalSheet.show(
                                context,
                                nombreBodega: _nombreBodega,
                                plan: _plan,
                                currentUsername: _username,
                                userRol: _userRol,
                                onPlanUpdated: () => _cargarDatos(forceRefresh: true),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 26),

                    // Alertas de Reposición
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Alertas de Reposición',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        if (totalAlertas > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.alertRed.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$totalAlertas productos por agotar',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.alertRed,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (productosCriticos.isEmpty && productosBajos.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.cardDark : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? AppTheme.borderDark : const Color(0xFFD1FAE5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Color(0xFFD1FAE5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.checkCircle, color: AppTheme.accentGreen, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '¡Inventario en Estado Óptimo!',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : AppTheme.textDark,
                                    ),
                                  ),
                                  Text(
                                    'Todos los productos tienen existencias saludables.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final items = [...productosCriticos, ...productosBajos].take(6).toList();
                          final double itemWidth = constraints.maxWidth >= 750
                              ? (constraints.maxWidth - 10) / 2
                              : constraints.maxWidth;

                          return Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: items.map((p) {
                              final isCritico = p.stockActual <= 5;
                              final color = isCritico ? AppTheme.alertRed : AppTheme.warningAmber;

                              return Container(
                                width: itemWidth,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.cardDark : Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isCritico ? LucideIcons.alertCircle : LucideIcons.alertTriangle,
                                        color: color,
                                        size: 17,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.nombre,
                                            style: GoogleFonts.outfit(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : AppTheme.textDark,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Código: ${p.codigo}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: AppTheme.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${p.stockActual % 1 == 0 ? p.stockActual.toInt().toString() : p.stockActual.toStringAsFixed(2)} u.',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildGreetingBanner(bool isDark) {
    final String initial = _username.isNotEmpty ? _username[0].toUpperCase() : 'U';
    final bool isAdmin = _userRol.toUpperCase() == 'ADMIN' || _userRol.toUpperCase() == 'SUPERADMIN';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppTheme.cardDarkElevated, AppTheme.cardDark]
              : [AppTheme.brandInk, const Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : const Color(0xFF334155),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila Superior: Badges de Bodega, Plan y Estado en Vivo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Badge de Bodega
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.store, size: 12, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _nombreBodega,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFF1F5F9),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Badges de Plan y Live Sync
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge Plan
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (_plan == 'PRO' ? const Color(0xFF38BDF8) : AppTheme.brandPrimary).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (_plan == 'PRO' ? const Color(0xFF38BDF8) : AppTheme.brandPrimary).withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _plan == 'PRO' ? LucideIcons.sparkles : LucideIcons.shield,
                          size: 10.5,
                          color: _plan == 'PRO' ? const Color(0xFF38BDF8) : Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _plan == 'PRO' ? 'PLAN PRO' : 'PLAN BODEGA',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Live Dot
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.accentGreen.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.accentGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'En Vivo',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF86EFAC),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Fila Principal: Avatar de Usuario + Saludo y Rol Ampliados
          Row(
            children: [
              InkWell(
                onTap: () {
                  PlanYPersonalSheet.show(
                    context,
                    nombreBodega: _nombreBodega,
                    plan: _plan,
                    currentUsername: _username,
                    userRol: _userRol,
                    onPlanUpdated: () => _cargarDatos(forceRefresh: true),
                  );
                },
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.brandPrimary, Color(0xFF0EA5E9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.brandPrimary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Textos de Bienvenida del Usuario
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¡Bienvenido, $_username! 👋',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          isAdmin ? LucideIcons.shieldCheck : LucideIcons.userCheck,
                          size: 13,
                          color: const Color(0xFF60A5FA),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            isAdmin
                                ? 'Administrador General • Acceso Total'
                                : 'Operador de Tienda • Turno Activo',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF93C5FD),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
            ],
          ),
          const SizedBox(height: 14),

          // Barra Inferior de Datos de Turno y Fiscales
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _ruc.isNotEmpty ? LucideIcons.fileText : LucideIcons.layers,
                  size: 13,
                  color: const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    () {
                      if (_ruc.isNotEmpty && _telefono.isNotEmpty) {
                        return 'RUC: $_ruc • Tel: $_telefono';
                      } else if (_ruc.isNotEmpty) {
                        return 'RUC: $_ruc • ${_direccion.isNotEmpty ? _direccion : 'CajaYa Cloud POS'}';
                      } else if (_telefono.isNotEmpty) {
                        return 'Tel: $_telefono • CajaYa Cloud POS';
                      } else {
                        return 'CajaYa Cloud POS • Ventas, caja e inventario en tiempo real';
                      }
                    }(),
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFCBD5E1),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.checkCheck, size: 11, color: AppTheme.accentGreen),
                      const SizedBox(width: 4),
                      Text(
                        'POS Activo',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFE2E8F0),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockAlertBanner(List<Producto> criticos, bool isDark) {
    if (criticos.isEmpty) return const SizedBox.shrink();

    final topCriticos = criticos.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A1215) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.alertRed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.triangleAlert, color: AppTheme.alertRed, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alerta de Quiebre de Stock Inminente',
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                      ),
                    ),
                    Text(
                      '${criticos.length} productos con existencias en nivel crítico (≤ 5 unidades).',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.alertRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () => widget.onNavigateTab(3), // Tab Inventario
                icon: const Icon(LucideIcons.boxes, size: 14),
                label: Text(
                  'Reponer',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: topCriticos.map((p) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3F171A) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.nombre,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.alertRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${p.stockActual.toInt()} u.',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.alertRed,
                        ),
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

  Widget _buildPaymentBreakdownCard(bool isDark) {
    final double totalVentas = _cierreHoy?.totalVentas ?? 0.0;
    final int cantVentas = _cierreHoy?.cantidadVentas ?? 0;
    final double ef = _cierreHoy?.totalEfectivo ?? 0.0;
    final double yp = _cierreHoy?.totalYape ?? 0.0;
    final double pl = _cierreHoy?.totalPlin ?? 0.0;
    final double tj = _cierreHoy?.totalTarjeta ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1,
        ),
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
                      color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.circleDollarSign, color: AppTheme.brandPrimary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flujo de Caja en Directo (Hoy)',
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        '$cantVentas cobros sincronizados • Total S/ ${totalVentas.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.brandPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => widget.onNavigateTab(2), // Tab Arqueo de Caja
                icon: const Icon(LucideIcons.arrowRight, size: 14),
                label: Text(
                  'Ver Cuadre',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Mini tiles por canal
          LayoutBuilder(
            builder: (context, constraints) {
              final double tileWidth = constraints.maxWidth >= 700
                  ? (constraints.maxWidth - 30) / 4
                  : (constraints.maxWidth > 380
                      ? (constraints.maxWidth - 10) / 2
                      : constraints.maxWidth);

              Widget buildChannelBox(String nombre, double monto, Color color, IconData icon) {
                return Container(
                  width: tileWidth,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.12 : 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                            Text(
                              'S/ ${monto.toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  buildChannelBox('Efectivo', ef, AppTheme.accentGreen, LucideIcons.banknote),
                  buildChannelBox('Yape', yp, const Color(0xFF732283), LucideIcons.smartphone),
                  buildChannelBox('Plin', pl, const Color(0xFF0084FF), LucideIcons.smartphone),
                  buildChannelBox('Tarjeta', tj, const Color(0xFF6366F1), LucideIcons.creditCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required BoxConstraints constraints,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    final double cardWidth = constraints.maxWidth >= 1100
        ? (constraints.maxWidth - 40) / 5
        : (constraints.maxWidth >= 720
            ? (constraints.maxWidth - 20) / 3
            : (constraints.maxWidth > 460
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth));

    final card = Container(
      width: cardWidth,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: card,
        ),
      );
    }
    return card;
  }

  Widget _buildQuickActionBtn({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
    double? width,
  }) {
    final card = Material(
      color: isDark ? AppTheme.cardDark : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  color: AppTheme.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );

    if (width != null) return card;
    return Expanded(child: card);
  }
}
