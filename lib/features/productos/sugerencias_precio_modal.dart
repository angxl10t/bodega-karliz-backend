import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../home/bodega_service.dart';

class SugerenciasPrecioModal extends StatefulWidget {
  final VoidCallback? onActualizado;

  const SugerenciasPrecioModal({super.key, this.onActualizado});

  static Future<void> show(BuildContext context, {VoidCallback? onActualizado}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SugerenciasPrecioModal(onActualizado: onActualizado),
    );
  }

  @override
  State<SugerenciasPrecioModal> createState() => _SugerenciasPrecioModalState();
}

class _SugerenciasPrecioModalState extends State<SugerenciasPrecioModal> {
  final BodegaService _bodegaService = BodegaService();
  List<SugerenciaPrecioItem> _sugerencias = [];
  bool _isLoading = true;
  bool _isProcessingBatch = false;

  @override
  void initState() {
    super.initState();
    _cargarSugerencias();
  }

  Future<void> _cargarSugerencias() async {
    setState(() => _isLoading = true);
    try {
      final items = await _bodegaService.listarMisSugerenciasPrecio(estado: 'PENDIENTE');
      if (mounted) {
        setState(() {
          _sugerencias = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _aceptarIndividual(SugerenciaPrecioItem item) async {
    try {
      await _bodegaService.aceptarSugerenciaPrecio(item.idSugerencia);
      if (!mounted) return;
      setState(() {
        _sugerencias.removeWhere((s) => s.idSugerencia == item.idSugerencia);
      });
      widget.onActualizado?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se actualizó el producto "${item.nombreActual}" al precio sugerido.'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al aceptar sugerencia: $e'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
    }
  }

  Future<void> _rechazarIndividual(SugerenciaPrecioItem item) async {
    try {
      await _bodegaService.rechazarSugerenciaPrecio(item.idSugerencia);
      if (!mounted) return;
      setState(() {
        _sugerencias.removeWhere((s) => s.idSugerencia == item.idSugerencia);
      });
      widget.onActualizado?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sugerencia rechazada. Tu precio se mantuvo sin cambios.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al rechazar sugerencia: $e'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
    }
  }

  Future<void> _aceptarTodas() async {
    if (_sugerencias.isEmpty) return;
    setState(() => _isProcessingBatch = true);
    try {
      final total = await _bodegaService.aceptarTodasSugerenciasPrecio();
      if (!mounted) return;
      setState(() {
        _sugerencias.clear();
        _isProcessingBatch = false;
      });
      widget.onActualizado?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Se aplicaron $total sugerencias exitosamente!'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingBatch = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar sugerencias: $e'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
    }
  }

  Future<void> _rechazarTodas() async {
    if (_sugerencias.isEmpty) return;
    setState(() => _isProcessingBatch = true);
    try {
      final total = await _bodegaService.rechazarTodasSugerenciasPrecio();
      if (!mounted) return;
      setState(() {
        _sugerencias.clear();
        _isProcessingBatch = false;
      });
      widget.onActualizado?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se descartaron $total sugerencias.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingBatch = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al rechazar sugerencias: $e'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Container(
      constraints: BoxConstraints(
        maxHeight: size.height * 0.88,
        maxWidth: 720,
      ),
      margin: EdgeInsets.symmetric(
        horizontal: size.width > 720 ? (size.width - 720) / 2 : 0,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkElevated : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de agarre superior
          Container(
            width: 44,
            height: 4.5,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Cabecera del Modal
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    LucideIcons.sparkles,
                    color: Color(0xFF7C3AED),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sugerencias del SuperAdmin',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Actualizaciones propuestas para tus productos. Tú decides si aceptarlas.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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

          // Botones de acción masiva (si hay varias)
          if (_sugerencias.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${_sugerencias.length} pendientes',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(LucideIcons.x, size: 15),
                    label: const Text('Rechazar Todas'),
                    onPressed: _isProcessingBatch ? null : _rechazarTodas,
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(LucideIcons.checkCheck, size: 15),
                    label: const Text('Aceptar Todas'),
                    onPressed: _isProcessingBatch ? null : _aceptarTodas,
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // Contenido: Lista o Vacío
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sugerencias.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.badgeCheck,
                                color: Color(0xFF10B981),
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              '¡Estás al día!',
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No hay sugerencias de precios o datos pendientes de revisar.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _sugerencias.length,
                        separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _sugerencias[index];
                          return _buildCardSugerencia(item, isDark);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSugerencia(SugerenciaPrecioItem item, bool isDark) {
    final diffVenta = item.precioVentaSugerido - item.precioVentaActual;
    final esAlza = diffVenta > 0;
    final tieneCambioNombre = item.nombreSugerido != null &&
        item.nombreSugerido!.trim().isNotEmpty &&
        item.nombreSugerido != item.nombreActual;
    final tieneCambioMarca = item.marcaSugerida != null &&
        item.marcaSugerida!.trim().isNotEmpty &&
        item.marcaSugerida != item.marcaActual;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera Producto (Foto + Nombres)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: item.imagenUrl != null && item.imagenUrl!.isNotEmpty
                      ? Image.network(
                          item.imagenUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => const Icon(
                            LucideIcons.package,
                            size: 22,
                            color: Color(0xFF94A3B8),
                          ),
                        )
                      : const Icon(
                          LucideIcons.package,
                          size: 22,
                          color: Color(0xFF94A3B8),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nombreActual,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      if (tieneCambioNombre)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '➔ Nombre sugerido: ${item.nombreSugerido}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.scanBarcode,
                            size: 13,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.codigoBarras,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          if (tieneCambioMarca) ...[
                            const SizedBox(width: 8),
                            Text(
                              'Marca: ${item.marcaActual ?? '-'} ➔ ${item.marcaSugerida}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF7C3AED),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Comparativa de Precios
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.3) : const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF4338CA).withValues(alpha: 0.4) : const Color(0xFFDDD6FE),
                ),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Precio Actual',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        'S/ ${item.precioVentaActual.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.lineThrough,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  const Icon(LucideIcons.arrowRight, size: 16, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Precio Sugerido',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF7C3AED),
                        ),
                      ),
                      Text(
                        'S/ ${item.precioVentaSugerido.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: esAlza
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      esAlza
                          ? '+S/ ${diffVenta.toStringAsFixed(2)}'
                          : '-S/ ${(-diffVenta).toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: esAlza ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Motivo del SuperAdmin (si existe)
            if (item.motivo != null && item.motivo!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.messageSquareQuote,
                    size: 14,
                    color: Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.motivo!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Botones de Acción Individuales
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(LucideIcons.x, size: 15),
                  label: const Text('Rechazar'),
                  onPressed: () => _rechazarIndividual(item),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    elevation: 0,
                  ),
                  icon: const Icon(LucideIcons.check, size: 16),
                  label: const Text('Aceptar Sugerencia'),
                  onPressed: () => _aceptarIndividual(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
