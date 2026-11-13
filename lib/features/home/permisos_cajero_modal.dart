import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/permisos_cajero_service.dart';
import '../../core/theme.dart';

class PermisosCajeroModal extends StatefulWidget {
  const PermisosCajeroModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PermisosCajeroModal(),
    );
  }

  @override
  State<PermisosCajeroModal> createState() => _PermisosCajeroModalState();
}

class _PermisosCajeroModalState extends State<PermisosCajeroModal> {
  bool _isSaving = false;

  late bool _verCostos;
  late bool _aplicarDescuentos;
  late bool _anularSinPin;
  late bool _modificarPrecios;
  late bool _verFinanzas;

  @override
  void initState() {
    super.initState();
    final p = PermisosCajeroService.currentPermisos;
    _verCostos = p.verCostosYMargen;
    _aplicarDescuentos = p.aplicarDescuentosManuales;
    _anularSinPin = p.anularVentasSinPin;
    _modificarPrecios = p.modificarPreciosVenta;
    _verFinanzas = p.verReportesFinanzas;
    _cargarPermisos();
  }

  Future<void> _cargarPermisos() async {
    final p = await PermisosCajeroService.obtenerPermisos();
    if (mounted) {
      setState(() {
        _verCostos = p.verCostosYMargen;
        _aplicarDescuentos = p.aplicarDescuentosManuales;
        _anularSinPin = p.anularVentasSinPin;
        _modificarPrecios = p.modificarPreciosVenta;
        _verFinanzas = p.verReportesFinanzas;
      });
    }
  }

  void _aplicarPreset(PermisosCajero preset) {
    HapticFeedback.selectionClick();
    setState(() {
      _verCostos = preset.verCostosYMargen;
      _aplicarDescuentos = preset.aplicarDescuentosManuales;
      _anularSinPin = preset.anularVentasSinPin;
      _modificarPrecios = preset.modificarPreciosVenta;
      _verFinanzas = preset.verReportesFinanzas;
    });
  }

  Future<void> _guardar() async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final nuevosPermisos = PermisosCajero(
      verCostosYMargen: _verCostos,
      aplicarDescuentosManuales: _aplicarDescuentos,
      anularVentasSinPin: _anularSinPin,
      modificarPreciosVenta: _modificarPrecios,
      verReportesFinanzas: _verFinanzas,
    );

    await PermisosCajeroService.guardarPermisos(nuevosPermisos);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.shieldCheck, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¡Permisos de Cajeros actualizados exitosamente!',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.accentGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDarkElevated : Colors.white;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra indicadora superior
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.borderDarkElevated
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cabecera con insignia de Rol
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      LucideIcons.shieldAlert,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Permisos de Cajero',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'ROL CAJERO',
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0284C7),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Controla qué acciones puede realizar el personal en turno sin solicitar el PIN del Administrador.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: isDark
                                ? AppTheme.textDarkSecondary
                                : const Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Barra de Presets Rápidos
              Text(
                'CONFIGURACIONES RÁPIDAS (PRESETS)',
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildPresetChip(
                      icon: LucideIcons.shield,
                      label: 'Máxima Seguridad',
                      subtitle: 'Solo cobro exacto',
                      isDark: isDark,
                      primaryColor: primaryColor,
                      onTap: () => _aplicarPreset(PermisosCajero.seguridadMaxima()),
                    ),
                    const SizedBox(width: 8),
                    _buildPresetChip(
                      icon: LucideIcons.badgeCheck,
                      label: 'Estándar Bodega',
                      subtitle: 'Recomendado',
                      isDark: isDark,
                      primaryColor: primaryColor,
                      onTap: () =>
                          _aplicarPreset(PermisosCajero.estandarRecomendado()),
                    ),
                    const SizedBox(width: 8),
                    _buildPresetChip(
                      icon: LucideIcons.userCheck,
                      label: 'Cajero Encargado',
                      subtitle: 'Mayor autonomía',
                      isDark: isDark,
                      primaryColor: primaryColor,
                      onTap: () => _aplicarPreset(PermisosCajero.cajeroEncargado()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Switch 1: Ver Costos de Compra y Margen
                _buildSwitchTile(
                  isDark: isDark,
                  primaryColor: primaryColor,
                  icon: LucideIcons.eye,
                  activeIconColor: const Color(0xFF8B5CF6),
                  title: 'Ver Costos de Compra y Margen',
                  subtitle:
                      'Permite al cajero ver el precio al por mayor (costo) y el porcentaje de ganancia en el inventario. Desactívalo para proteger la privacidad financiera.',
                  value: _verCostos,
                  onChanged: (val) => setState(() => _verCostos = val),
                ),
                const SizedBox(height: 10),

                // Switch 2: Aplicar Descuentos Manuales en Caja
                _buildSwitchTile(
                  isDark: isDark,
                  primaryColor: primaryColor,
                  icon: LucideIcons.badgePercent,
                  activeIconColor: const Color(0xFF10B981),
                  title: 'Aplicar Descuentos en Mostrador',
                  subtitle:
                      'Permite al cajero aplicar rebajas manuales o de cortesía a los clientes en el carrito sin solicitar el PIN del Administrador.',
                  value: _aplicarDescuentos,
                  onChanged: (val) => setState(() => _aplicarDescuentos = val),
                ),
                const SizedBox(height: 10),

                // Switch 3: Anular Ventas y Vaciar Carrito sin PIN
                _buildSwitchTile(
                  isDark: isDark,
                  primaryColor: primaryColor,
                  icon: LucideIcons.undo2,
                  activeIconColor: const Color(0xFFEF4444),
                  title: 'Anular Ventas sin PIN de Admin',
                  subtitle:
                      'Si está desactivado, el cajero deberá solicitar el PIN del Administrador cada vez que quiera vaciar el carrito o cancelar una venta en curso.',
                  value: _anularSinPin,
                  onChanged: (val) => setState(() => _anularSinPin = val),
                ),
                const SizedBox(height: 10),

                // Switch 4: Modificar Precios y Catálogo
                _buildSwitchTile(
                  isDark: isDark,
                  primaryColor: primaryColor,
                  icon: LucideIcons.tag,
                  activeIconColor: const Color(0xFFF59E0B),
                  title: 'Modificar Precios y Catálogo',
                  subtitle:
                      'Si está desactivado, el cajero solo puede consultar el inventario para cobrar, pero no puede crear productos ni cambiar precios sin PIN de Admin.',
                  value: _modificarPrecios,
                  onChanged: (val) => setState(() => _modificarPrecios = val),
                ),
                const SizedBox(height: 10),

                // Switch 5: Ver Reportes Financieros y BI
                _buildSwitchTile(
                  isDark: isDark,
                  primaryColor: primaryColor,
                  icon: LucideIcons.barChart3,
                  activeIconColor: const Color(0xFF3B82F6),
                  title: 'Acceso a Finanzas y Utilidades (BI)',
                  subtitle:
                      'Si está desactivado, bloquea el acceso a las pantallas de Inteligencia de Negocios, utilidades netas y métricas de rentabilidad.',
                  value: _verFinanzas,
                  onChanged: (val) => setState(() => _verFinanzas = val),
                ),
                const SizedBox(height: 20),

                // Botón Guardar
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(LucideIcons.save, size: 18),
                  label: Text(
                    _isSaving ? 'Guardando...' : 'Guardar Configuración de Permisos',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

  Widget _buildPresetChip({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isDark,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: primaryColor),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required bool isDark,
    required Color primaryColor,
    required IconData icon,
    required Color activeIconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? primaryColor.withValues(alpha: 0.35)
              : (isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (value ? activeIconColor : const Color(0xFF94A3B8))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: value ? activeIconColor : const Color(0xFF94A3B8),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeTrackColor: primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
