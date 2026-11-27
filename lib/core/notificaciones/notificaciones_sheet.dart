import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme.dart';
import 'notificacion_service.dart';

/// Hoja modal ergonómica de Centro de Notificaciones en mostrador.
/// Calma Visual POS: Aislamiento por rol, filtrado rápido y acciones directas.
class NotificacionesSheet extends StatefulWidget {
  final VoidCallback? onAbrirPedidosWeb;
  final VoidCallback? onAbrirComprasInventario;

  const NotificacionesSheet({
    super.key,
    this.onAbrirPedidosWeb,
    this.onAbrirComprasInventario,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onAbrirPedidosWeb,
    VoidCallback? onAbrirComprasInventario,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NotificacionesSheet(
        onAbrirPedidosWeb: onAbrirPedidosWeb,
        onAbrirComprasInventario: onAbrirComprasInventario,
      ),
    );
  }

  @override
  State<NotificacionesSheet> createState() => _NotificacionesSheetState();
}

class _NotificacionesSheetState extends State<NotificacionesSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatearTiempo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgSurface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F0);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
        maxWidth: 640,
      ),
      margin: EdgeInsets.only(
        left: MediaQuery.of(context).size.width > 680 ? 20 : 0,
        right: MediaQuery.of(context).size.width > 680 ? 20 : 0,
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de agarre superior
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Cabecera Principal
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    LucideIcons.bellRing,
                    color: AppTheme.brandPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            'Centro de Alertas',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                          ValueListenableBuilder<bool>(
                            valueListenable:
                                NotificacionService.isConnectedNotifier,
                            builder: (context, connected, _) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: connected
                                      ? const Color(0xFF10B981)
                                            .withValues(alpha: 0.15)
                                      : Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: connected
                                            ? const Color(0xFF10B981)
                                            : Colors.amber,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      connected ? 'SSE Activo' : 'Conectando',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: connected
                                            ? const Color(0xFF10B981)
                                            : Colors.amber,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      Text(
                        'Avisos de mostrador y stock en tiempo real',
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
                IconButton(
                  tooltip: 'Marcar todo como leído',
                  icon: const Icon(LucideIcons.checkCheck, size: 20),
                  onPressed: () => NotificacionService.marcarTodasComoLeidas(),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Pestañas de Filtrado
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.brandPrimary,
              indicatorWeight: 3,
              labelColor: AppTheme.brandPrimary,
              unselectedLabelColor: AppTheme.getAdaptiveMutedText(isDark),
              labelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
              tabs: const [
                Tab(text: 'Todas'),
                Tab(
                  icon: Icon(LucideIcons.shoppingBag, size: 16),
                  text: 'Pedidos Web',
                ),
                Tab(
                  icon: Icon(LucideIcons.alertTriangle, size: 16),
                  text: 'Stock Crítico',
                ),
              ],
            ),
          ),

          // Lista de Notificaciones
          Expanded(
            child: ValueListenableBuilder<List<NotificacionItem>>(
              valueListenable: NotificacionService.notificacionesNotifier,
              builder: (context, lista, _) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildListaFiltrada(lista, null, isDark),
                    _buildListaFiltrada(lista, 'NUEVO_PEDIDO_WEB', isDark),
                    _buildListaFiltrada(lista, 'STOCK_CRITICO', isDark),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaFiltrada(
    List<NotificacionItem> todas,
    String? filtroTipo,
    bool isDark,
  ) {
    final filtradas = filtroTipo == null
        ? todas
        : todas.where((n) => n.tipo == filtroTipo).toList();

    if (filtradas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  filtroTipo == 'NUEVO_PEDIDO_WEB'
                      ? LucideIcons.shoppingBag
                      : filtroTipo == 'STOCK_CRITICO'
                      ? LucideIcons.boxes
                      : LucideIcons.bellOff,
                  size: 32,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'No hay notificaciones aquí',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                filtroTipo == 'NUEVO_PEDIDO_WEB'
                    ? 'Los pedidos que hagan los clientes por catálogo web aparecerán al instante.'
                    : filtroTipo == 'STOCK_CRITICO'
                    ? 'Te avisaremos cuando algún producto esté por agotarse en mostrador.'
                    : 'Estás al día con todos los avisos de tu bodega.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: filtradas.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
      itemBuilder: (ctx, index) {
        final notif = filtradas[index];
        return _buildNotificacionCard(notif, isDark);
      },
    );
  }

  Widget _buildNotificacionCard(NotificacionItem notif, bool isDark) {
    final bgCard = notif.leido
        ? (isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.6)
              : const Color(0xFFF8FAFC))
        : (isDark ? const Color(0xFF1E293B) : Colors.white);

    final borderColor = notif.leido
        ? (isDark ? Colors.white10 : const Color(0xFFE2E8F0))
        : (notif.esPedidoWeb
              ? const Color(0xFF10B981)
              : notif.esStockCritico
              ? const Color(0xFFEF4444)
              : AppTheme.brandPrimary);

    final iconColor = notif.esPedidoWeb
        ? const Color(0xFF10B981)
        : notif.esStockCritico
        ? const Color(0xFFEF4444)
        : AppTheme.brandPrimary;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (!notif.leido) {
          NotificacionService.marcarComoLeida(notif.idNotificacion);
        }
        if (notif.esPedidoWeb) {
          Navigator.pop(context);
          widget.onAbrirPedidosWeb?.call();
        } else if (notif.esStockCritico) {
          Navigator.pop(context);
          widget.onAbrirComprasInventario?.call();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor.withValues(alpha: notif.leido ? 0.3 : 0.9),
            width: notif.leido ? 1.0 : 1.6,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icono del Tipo de Notificación
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                notif.esPedidoWeb
                    ? LucideIcons.shoppingBag
                    : notif.esStockCritico
                    ? LucideIcons.alertTriangle
                    : LucideIcons.info,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Contenido
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.titulo,
                          style: GoogleFonts.outfit(
                            fontSize: 14.5,
                            fontWeight: notif.leido
                                ? FontWeight.w600
                                : FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (!notif.leido) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: iconColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        _formatearTiempo(notif.fechaCreacion),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.mensaje,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),

                  // Botón de acción rápida si es interactivo
                  if (notif.esPedidoWeb || notif.esStockCritico) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          notif.esPedidoWeb
                              ? 'Ver Pedido ➔'
                              : 'Reponer Stock ➔',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: iconColor,
                          ),
                        ),
                      ],
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
}
