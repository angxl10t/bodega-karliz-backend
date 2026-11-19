import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/gastronomia_helper.dart';
import '../../../core/responsive_layout.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/adaptive_modal.dart';
import '../../productos/producto_model.dart';

/// Resultado de la selección de presa y acompañamientos
class PresaSeleccionResultado {
  final String presa;
  final String? ensalada;
  final String? papas;
  final String? notas;

  const PresaSeleccionResultado({
    required this.presa,
    this.ensalada,
    this.papas,
    this.notas,
  });

  /// Texto consolidado para la variante en ticket y comanda
  String get textoVariante => presa;

  /// Notas consolidadas de cocina
  String get textoNotasConsolidadas {
    final partes = <String>[];
    if (ensalada != null &&
        ensalada!.isNotEmpty &&
        !ensalada!.toLowerCase().contains('fresca')) {
      partes.add(ensalada!);
    }
    if (papas != null &&
        papas!.isNotEmpty &&
        !papas!.toLowerCase().contains('clásicas') &&
        !papas!.toLowerCase().contains('clasicas')) {
      partes.add(papas!);
    }
    if (notas != null && notas!.trim().isNotEmpty) {
      partes.add(notas!.trim());
    }
    return partes.join(', ');
  }
}

/// Modal táctil de selección de presa para Pollerías en el Punto de Venta (POS)
class SelectorPresaModal extends StatefulWidget {
  final Producto producto;
  final String? presaInicial;
  final String? ensaladaInicial;
  final String? notasIniciales;

  const SelectorPresaModal({
    super.key,
    required this.producto,
    this.presaInicial,
    this.ensaladaInicial,
    this.notasIniciales,
  });

  static Future<PresaSeleccionResultado?> show(
    BuildContext context, {
    required Producto producto,
    String? presaInicial,
    String? ensaladaInicial,
    String? notasIniciales,
  }) {
    return AdaptiveModal.show<PresaSeleccionResultado>(
      context: context,
      maxWidth: 520,
      builder: (ctx) => SelectorPresaModal(
        producto: producto,
        presaInicial: presaInicial,
        ensaladaInicial: ensaladaInicial,
        notasIniciales: notasIniciales,
      ),
    );
  }

  @override
  State<SelectorPresaModal> createState() => _SelectorPresaModalState();
}

class _SelectorPresaModalState extends State<SelectorPresaModal> {
  late String _presaSeleccionada;
  late String _ensaladaSeleccionada;
  late String _papasSeleccionadas;
  late TextEditingController _notasCtrl;

  late List<String> _opcionesPresa;
  late List<String> _opcionesEnsalada;
  late List<String> _opcionesPapas;

  @override
  void initState() {
    super.initState();
    _opcionesPresa = GastronomiaHelper.opcionesPresa(widget.producto.nombre);
    _opcionesEnsalada = GastronomiaHelper.opcionesEnsalada();
    _opcionesPapas = GastronomiaHelper.opcionesPapas();

    _presaSeleccionada =
        widget.presaInicial ??
        (_opcionesPresa.isNotEmpty ? _opcionesPresa.first : 'Pecho (con ala)');
    _ensaladaSeleccionada = widget.ensaladaInicial ?? _opcionesEnsalada.first;
    _papasSeleccionadas = _opcionesPapas.first;
    _notasCtrl = TextEditingController(text: widget.notasIniciales ?? '');
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  void _confirmar() {
    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      PresaSeleccionResultado(
        presa: _presaSeleccionada,
        ensalada: _ensaladaSeleccionada,
        papas: _papasSeleccionadas,
        notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = ResponsiveLayout.isTabletOrLarger(context);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Align(
      alignment: isWide ? Alignment.center : Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.90,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: isWide
                ? BorderRadius.circular(24)
                : const BorderRadius.vertical(top: Radius.circular(28)),
            border: isDark
                ? Border.all(color: AppTheme.borderDarkElevated, width: 1.2)
                : Border.all(
                    color: isWide ? AppTheme.borderLight : Colors.transparent,
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.25),
                blurRadius: isWide ? 30 : 20,
                offset: isWide ? const Offset(0, 10) : const Offset(0, -6),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            22,
            isWide ? 20 : 14,
            22,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isWide) ...[
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Cabecera con icono culinario
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        LucideIcons.drumstick,
                        color: Color(0xFFEA580C),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selecciona la Presa',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          Text(
                            widget.producto.nombre,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.textDarkSecondary
                                  : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        LucideIcons.x,
                        size: 20,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF64748B),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Sección 1: Presas principales (Cards grandes táctiles si hay opciones, o badge de corte clásico)
                if (_opcionesPresa.length > 1) ...[
                  Text(
                    'PRESA PRINCIPAL (SELECCIONAR)',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: const Color(0xFFEA580C),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(_opcionesPresa.length, (idx) {
                    final opcion = _opcionesPresa[idx];
                    final isSelected = _presaSeleccionada == opcion;
                    final esPecho = opcion.toLowerCase().contains('pecho');
                    final esPierna = opcion.toLowerCase().contains('pierna');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _presaSeleccionada = opcion);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFF97316)
                                        .withValues(alpha: isDark ? 0.22 : 0.12)
                                  : (isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFF97316)
                                    : (isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFE2E8F0)),
                                width: isSelected ? 2.0 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFF97316)
                                        : (isDark
                                              ? const Color(0xFF1E293B)
                                              : const Color(0xFFE2E8F0)),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    esPecho
                                        ? LucideIcons.flame
                                        : (esPierna
                                              ? LucideIcons.drumstick
                                              : LucideIcons.utensils),
                                    size: 18,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.white60
                                              : const Color(0xFF64748B)),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        opcion,
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: isSelected
                                              ? (isDark
                                                    ? Colors.white
                                                    : const Color(0xFFC2410C))
                                              : (isDark
                                                    ? Colors.white70
                                                    : AppTheme.textDark),
                                        ),
                                      ),
                                      Text(
                                        esPecho
                                            ? 'Parte jugosa con ala crujiente'
                                            : (esPierna
                                                  ? 'Pierna con encuentro tierno'
                                                  : 'Porción estándar'),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          color: isDark
                                              ? AppTheme.textDarkSecondary
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    LucideIcons.checkCircle2,
                                    color: Color(0xFFF97316),
                                    size: 22,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ] else ...[
                  // Forma clásica incluida (ej. 1/2 Pollo tradicional)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C)
                          .withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFEA580C)
                            .withValues(alpha: isDark ? 0.35 : 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.drumstick,
                            size: 18,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FORMA CLÁSICA INCLUIDA',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFEA580C),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _opcionesPresa.isNotEmpty
                                    ? _opcionesPresa.first
                                    : 'Pecho y Pierna (Clásico)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textDark,
                                ),
                              ),
                              Text(
                                'En medio pollo siempre se sirve medio corte tradicional (pecho y pierna).',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppTheme.textDarkSecondary
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          LucideIcons.checkCircle2,
                          size: 20,
                          color: Color(0xFF059669),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Sección 2: Ensalada
                Text(
                  'TIPO DE ENSALADA',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _opcionesEnsalada.map((ens) {
                    final isSel = _ensaladaSeleccionada == ens;
                    return ChoiceChip(
                      label: Text(ens),
                      selected: isSel,
                      selectedColor: const Color(0xFF16A34A)
                          .withValues(alpha: 0.2),
                      side: BorderSide(
                        color: isSel
                            ? const Color(0xFF16A34A)
                            : (isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1)),
                        width: isSel ? 1.5 : 1.0,
                      ),
                      labelStyle: TextStyle(
                        color: isSel
                            ? const Color(0xFF16A34A)
                            : (isDark
                                  ? Colors.white70
                                  : const Color(0xFF334155)),
                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 12,
                      ),
                      onSelected: (_) =>
                          setState(() => _ensaladaSeleccionada = ens),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Sección 3: Término de Papas
                Text(
                  'TÉRMINO DE PAPAS',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _opcionesPapas.map((papas) {
                    final isSel = _papasSeleccionadas == papas;
                    return ChoiceChip(
                      label: Text(papas),
                      selected: isSel,
                      selectedColor: const Color(0xFFD97706)
                          .withValues(alpha: 0.2),
                      side: BorderSide(
                        color: isSel
                            ? const Color(0xFFD97706)
                            : (isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1)),
                        width: isSel ? 1.5 : 1.0,
                      ),
                      labelStyle: TextStyle(
                        color: isSel
                            ? const Color(0xFFD97706)
                            : (isDark
                                  ? Colors.white70
                                  : const Color(0xFF334155)),
                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 12,
                      ),
                      onSelected: (_) =>
                          setState(() => _papasSeleccionadas = papas),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Sección 4: Nota rápida de cocina
                Text(
                  'INDICACIÓN DE COCINA (OPCIONAL)',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notasCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ej. Ají extra, piel crocante, sin mayonesa...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                  style: const TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 20),

                // Botón de acción
                ElevatedButton.icon(
                  onPressed: _confirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(LucideIcons.plus, size: 20),
                  label: Text(
                    'AGREGAR $_presaSeleccionada.toUpperCase() A LA ORDEN',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
