import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import 'proveedor_model.dart';
import 'proveedor_service.dart';

class NuevoProveedorSheet extends StatefulWidget {
  final Function(Proveedor nuevoProveedor)? onProveedorCreado;

  const NuevoProveedorSheet({
    super.key,
    this.onProveedorCreado,
  });

  static Future<Proveedor?> show(BuildContext context, {Function(Proveedor)? onCreado}) {
    return showModalBottomSheet<Proveedor>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NuevoProveedorSheet(onProveedorCreado: onCreado),
    );
  }

  @override
  State<NuevoProveedorSheet> createState() => _NuevoProveedorSheetState();
}

class _NuevoProveedorSheetState extends State<NuevoProveedorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _rucCtrl = TextEditingController();
  final _razonSocialCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  final ProveedorService _proveedorService = ProveedorService();
  bool _isGuardando = false;

  @override
  void dispose() {
    _rucCtrl.dispose();
    _razonSocialCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  void _generarRucDemo() {
    final random = Random();
    final rucDemo = '20${100000000 + random.nextInt(899999999)}';
    setState(() {
      _rucCtrl.text = rucDemo;
      if (_razonSocialCtrl.text.isEmpty) {
        _razonSocialCtrl.text = 'Distribuidora Central S.A.C.';
      }
      if (_telefonoCtrl.text.isEmpty) {
        _telefonoCtrl.text = '987${100000 + random.nextInt(899999)}';
      }
      if (_direccionCtrl.text.isEmpty) {
        _direccionCtrl.text = 'Av. Industrial 450, Lima';
      }
    });
  }

  Future<void> _guardarProveedor() async {
    if (_isGuardando) return;
    if (!_formKey.currentState!.validate()) return;

    final ruc = _rucCtrl.text.trim();
    final razonSocial = _razonSocialCtrl.text.trim();
    final telefono = _telefonoCtrl.text.trim();
    final direccion = _direccionCtrl.text.trim();

    setState(() => _isGuardando = true);

    final nuevo = Proveedor(
      ruc: ruc,
      razonSocial: razonSocial,
      telefono: telefono.isNotEmpty ? telefono : null,
      direccion: direccion.isNotEmpty ? direccion : null,
      estado: true,
    );

    final res = await _proveedorService.crearProveedorConDetalle(nuevo);

    if (!mounted) return;
    setState(() => _isGuardando = false);

    if (res.ok) {
      final proveedorGuardado = res.proveedor ?? nuevo;
      if (widget.onProveedorCreado != null) {
        widget.onProveedorCreado!(proveedorGuardado);
      }
      Navigator.pop(context, proveedorGuardado);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.checkCircle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¡Distribuidor "$razonSocial" registrado!',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.accentGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.error ?? 'Error al registrar proveedor. Verifica el RUC (único) y tu conexión.'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final inputBg = isDark ? AppTheme.cardDarkSunken : const Color(0xFFF5F6F8);
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkElevated : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 14,
        bottom: 22 + bottomInset,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra superior de agarre
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.borderDarkElevated : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Cabecera del modal
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceTintDark : AppTheme.surfaceTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(LucideIcons.building2, color: AppTheme.brandPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nuevo Proveedor',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textDark,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Registrar distribuidor o mayorista para compras',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, color: AppTheme.textMuted, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // RUC con botón autocompletar demo
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RUC o DNI *',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _rucCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 20,
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'Ej. 20601234567',
                            prefixIcon: const Icon(LucideIcons.fileText, size: 18),
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(color: borderColor),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'El RUC/DNI es obligatorio';
                            final clean = val.trim();
                            if (!RegExp(r'^(?:[0-9]{8}|[0-9]{11})$').hasMatch(clean)) {
                              return 'Debe ser DNI (8 dígitos) o RUC (11 dígitos)';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 25),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        side: const BorderSide(color: AppTheme.brandPrimary, width: 1.2),
                        foregroundColor: AppTheme.brandPrimary,
                      ),
                      icon: const Icon(LucideIcons.sparkles, size: 15),
                      label: Text(
                        'Demo',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      onPressed: _generarRucDemo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Razón Social
              Text(
                'Razón Social / Empresa *',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _razonSocialCtrl,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Ej. Distribuidora Gloria S.A.',
                  prefixIcon: const Icon(LucideIcons.building, size: 18),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingresa la razón social' : null,
              ),
              const SizedBox(height: 16),

              // Fila Teléfono y Dirección
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Teléfono / WhatsApp',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _telefonoCtrl,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Ej. 987654321',
                            prefixIcon: const Icon(LucideIcons.phone, size: 18),
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(color: borderColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dirección (Opcional)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _direccionCtrl,
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Ej. Av. Los Próceres 120',
                            prefixIcon: const Icon(LucideIcons.mapPin, size: 18),
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(color: borderColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Botón Guardar
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isGuardando ? null : _guardarProveedor,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                    elevation: 3,
                    shadowColor: AppTheme.brandPrimary.withValues(alpha: 0.35),
                  ),
                  icon: _isGuardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.checkCheck, size: 20),
                  label: Text(
                    _isGuardando ? 'GUARDANDO...' : 'REGISTRAR PROVEEDOR',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
