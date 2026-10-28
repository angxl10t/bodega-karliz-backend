import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme.dart';
import 'offline_models.dart';
import 'offline_sync_manager.dart';

class OfflineQueueSheet extends StatelessWidget {
  const OfflineQueueSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const OfflineQueueSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final syncManager = OfflineSyncManager.instance;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDarkElevated : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: isDark ? const Border(top: BorderSide(color: AppTheme.borderDarkElevated, width: 1.2)) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: ValueListenableBuilder<List<OfflineVenta>>(
            valueListenable: syncManager.pendingSalesNotifier,
            builder: (context, ventas, _) {
              final totalMonto = ventas.fold(0.0, (acc, v) => acc + v.total);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Manija superior
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.borderDarkElevated : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Cabecera
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.cloudOff, size: 20, color: Color(0xFFF59E0B)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cola de Ventas Offline',
                              style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Ventas firmadas en local sin conexión a internet',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
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
                  const SizedBox(height: 14),

                  // Resumen Financiero de la Cola
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Pendiente en Caja',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'S/ ${totalMonto.toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${ventas.length} venta(s)',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Lista de Ventas Pendientes
                  Expanded(
                    child: ventas.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(LucideIcons.cloudCheck, size: 48, color: AppTheme.accentGreen),
                                const SizedBox(height: 10),
                                Text(
                                  '¡Todo sincronizado con la nube!',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.accentGreen,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'No hay ventas locales pendientes de envío.',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: ventas.length,
                            separatorBuilder: (_, index) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final v = ventas[idx];
                              return Card(
                                margin: EdgeInsets.zero,
                                elevation: 0,
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(LucideIcons.ticket, size: 14, color: Color(0xFFD97706)),
                                              const SizedBox(width: 5),
                                              Text(
                                                v.localTicket,
                                                style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            'S/ ${v.total.toStringAsFixed(2)}',
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                              color: AppTheme.brandPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Cliente: ${v.clienteNombre} • ${v.metodoPago}',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${v.detalles.length} artículo(s) • ${v.fechaCreacion.hour.toString().padLeft(2, '0')}:${v.fechaCreacion.minute.toString().padLeft(2, '0')}',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                                      ),
                                      if (v.ultimoError != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Último aviso: ${v.ultimoError}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            color: AppTheme.alertRed,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),

                  // Botón Sincronizar Ahora
                  ValueListenableBuilder<bool>(
                    valueListenable: syncManager.isSyncingNotifier,
                    builder: (context, isSyncing, _) {
                      return SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: (isSyncing || ventas.isEmpty)
                              ? null
                              : () async {
                                  final res = await syncManager.syncPendingSales(isManual: true);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res.mensaje ?? 'Sincronización terminada'),
                                        backgroundColor: res.todosExitosos
                                            ? AppTheme.accentGreen
                                            : AppTheme.brandPrimary,
                                      ),
                                    );
                                  }
                                },
                          icon: isSyncing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(LucideIcons.refreshCw, size: 16),
                          label: Text(
                            isSyncing ? 'Sincronizando con la nube...' : 'Sincronizar Ahora',
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
