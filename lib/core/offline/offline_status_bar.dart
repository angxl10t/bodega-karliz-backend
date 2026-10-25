import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'offline_models.dart';
import 'offline_queue_sheet.dart';
import 'offline_sync_manager.dart';

class OfflineStatusBar extends StatelessWidget {
  const OfflineStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final syncManager = OfflineSyncManager.instance;

    return ValueListenableBuilder<List<OfflineVenta>>(
      valueListenable: syncManager.pendingSalesNotifier,
      builder: (context, ventas, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: syncManager.isOfflineNotifier,
          builder: (context, isOffline, _) {
            final tienePendientes = ventas.isNotEmpty;
            if (!isOffline && !tienePendientes) {
              return const SizedBox.shrink();
            }

            final totalMonto = ventas.fold(0.0, (acc, v) => acc + v.total);

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF271B0A) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF92400E) : const Color(0xFFFBBF24),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD97706).withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      tienePendientes ? LucideIcons.cloudOff : LucideIcons.wifiOff,
                      size: 16,
                      color: const Color(0xFFD97706),
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
                            Text(
                              isOffline ? 'MODO OFFLINE (SIN RED)' : 'VENTAS PENDIENTES DE ENVÍO',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFD97706),
                                letterSpacing: 0.3,
                              ),
                            ),
                            if (tienePendientes) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${ventas.length}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          tienePendientes
                              ? '${ventas.length} venta(s) guardadas localmente (S/ ${totalMonto.toStringAsFixed(2)})'
                              : 'Catálogo local activo. Las ventas se guardarán de forma segura.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<bool>(
                    valueListenable: syncManager.isSyncingNotifier,
                    builder: (context, isSyncing, _) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => OfflineQueueSheet.show(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSyncing)
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              else
                                const Icon(LucideIcons.refreshCw, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                isSyncing ? 'Enviando...' : 'Ver Cola',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
