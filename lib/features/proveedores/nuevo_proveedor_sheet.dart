import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/responsive_layout.dart';
import '../../core/theme.dart';
import '../../core/widgets/adaptive_modal.dart';
import 'proveedor_model.dart';
import 'proveedor_service.dart';

class NuevoProveedorSheet extends StatefulWidget {
  final Function(Proveedor nuevoProveedor)? onProveedorCreado;

  const NuevoProveedorSheet({super.key, this.onProveedorCreado});

  static Future<Proveedor?> show(
    BuildContext context, {
    Function(Proveedor)? onCreado,
  }) {
    return AdaptiveModal.show<Proveedor>(
      context: context,
      maxWidth: 560,
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

  static const List<Map<String, String>> _proveedoresOficialesPeru = [
    {
      'ruc': '20100107510',
      'nombre': 'Arca Continental Lindley S.A. (Coca-Cola / Inca Kola)',
      'alias': 'Coca-Cola / Inca Kola',
      'direccion': 'Av. Javier Prado Este 4200, Surco, Lima',
      'telefono': '01-311-5000',
    },
    {
      'ruc': '20100113610',
      'nombre': 'Unión de Cervecerías Peruanas Backus y Johnston S.A.A.',
      'alias': 'Backus (Pilsen / Cristal)',
      'direccion': 'Av. Nicolás Ayllón 3986, Ate, Lima',
      'telefono': '01-311-3000',
    },
    {
      'ruc': '20100055237',
      'nombre': 'Alicorp S.A.A. (Primor / AlaCena / Bolívar)',
      'alias': 'Alicorp',
      'direccion': 'Av. Argentina 4793, Carmen de la Legua, Callao',
      'telefono': '01-315-0800',
    },
    {
      'ruc': '20100190797',
      'nombre': 'Leche Gloria S.A.',
      'alias': 'Gloria',
      'direccion': 'Av. República de Panamá 2461, La Victoria, Lima',
      'telefono': '01-470-7170',
    },
    {
      'ruc': '20100177072',
      'nombre': 'Nestlé Perú S.A. (D\'Onofrio / Sublime / Maggi)',
      'alias': 'Nestlé / D\'Onofrio',
      'direccion': 'Calle Luis Galvani 493, Industrial Vulcano, Ate',
      'telefono': '0800-10-210',
    },
    {
      'ruc': '20297868790',
      'nombre': 'Pepsico Alimentos Perú S.R.L. / CBC (Lay\'s / Pepsi)',
      'alias': 'Pepsico / Lay\'s',
      'direccion': 'Av. Francisco Bolognesi 505, Santa Anita, Lima',
      'telefono': '01-618-2000',
    },
    {
      'ruc': '20100122978',
      'nombre': 'Mondelez Perú S.A. (Oreo / Field / Trident)',
      'alias': 'Mondelez / Field',
      'direccion': 'Av. Venezuela 2470, Bellavista, Callao',
      'telefono': '01-219-4000',
    },
    {
      'ruc': '20100154308',
      'nombre': 'San Fernando S.A. (Embutidos, Huevos y Aves)',
      'alias': 'San Fernando',
      'direccion': 'Av. República de Panamá 4295, Surquillo, Lima',
      'telefono': '01-213-5300',
    },
    {
      'ruc': '20331061901',
      'nombre': 'Ajeper S.A. (Grupo AJE - Big Cola / KR / Sporade)',
      'alias': 'AJE (Sporade / KR)',
      'direccion': 'Av. Los Conquistadores 1144, San Isidro, Lima',
      'telefono': '01-211-5300',
    },
    {
      'ruc': '20383070465',
      'nombre': 'Bimbo del Perú S.A.',
      'alias': 'Bimbo',
      'direccion': 'Av. Venezuela 2470, Cercado de Lima',
      'telefono': '01-315-7700',
    },
    {
      'ruc': '20100035121',
      'nombre': 'Molitalia S.A. (Costa / Ambrosoli / Fanny)',
      'alias': 'Molitalia',
      'direccion': 'Av. Venezuela 2850, Cercado de Lima',
      'telefono': '01-513-5000',
    },
    {
      'ruc': '20100127163',
      'nombre': 'Procter & Gamble del Perú S.R.L. (P&G / Ayudín / Ariel)',
      'alias': 'P&G (Ayudín / Ariel)',
      'direccion': 'Av. República de Colombia 791, San Isidro, Lima',
      'telefono': '0800-55-791',
    },
    {
      'ruc': '20100141664',
      'nombre': 'Rinti S.A. (Ricocan & Ricocat)',
      'alias': 'Rinti (Ricocan)',
      'direccion': 'Av. Minerales 540, Cercado de Lima',
      'telefono': '01-619-0200',
    },
  ];

  void _seleccionarProveedorOficial(Map<String, String> prov) {
    setState(() {
      _rucCtrl.text = prov['ruc'] ?? '';
      _razonSocialCtrl.text = prov['nombre'] ?? '';
      _direccionCtrl.text = prov['direccion'] ?? '';
      _telefonoCtrl.text = prov['telefono'] ?? '';
    });
  }

  void _generarRucDemo() {
    final random = Random();
    final p =
        _proveedoresOficialesPeru[random.nextInt(
          _proveedoresOficialesPeru.length,
        )];
    _seleccionarProveedorOficial(p);
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
              const Icon(
                LucideIcons.checkCircle,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¡Distribuidor "$razonSocial" registrado!',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.accentGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.error ?? 'Error al registrar proveedor. Verifica el RUC (único) y tu conexión.',
          ),
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

    final isWide = ResponsiveLayout.isTabletOrLarger(context);
    final resolvedRadius = isWide
        ? BorderRadius.circular(24)
        : const BorderRadius.vertical(top: Radius.circular(32));

    return Align(
      alignment: isWide ? Alignment.center : Alignment.bottomCenter,
      heightFactor: isWide ? 1.0 : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * (isWide ? 0.88 : 0.90),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDarkElevated : Colors.white,
            borderRadius: resolvedRadius,
            border: isDark
                ? Border.all(color: AppTheme.borderDarkElevated, width: 1.2)
                : Border.all(
                    color: isWide ? AppTheme.borderLight : Colors.transparent,
                    width: 1.0,
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.2),
                blurRadius: isWide ? 32 : 30,
                offset: isWide ? const Offset(0, 10) : const Offset(0, -6),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: isWide ? 20 : 14,
            bottom: 22 + bottomInset,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barra superior de agarre solo en móvil
                  if (!isWide) ...[
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
                    const SizedBox(height: 18),
                  ],

                  // Cabecera del modal
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.surfaceTintDark
                              : AppTheme.surfaceTint,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          LucideIcons.building2,
                          color: AppTheme.brandPrimary,
                          size: 22,
                        ),
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
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textDark,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Registrar distribuidor o mayorista para compras',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          LucideIcons.x,
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF334155),
                          size: 20,
                        ),
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
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _rucCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 20,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: 'Ej. 20601234567',
                                prefixIcon: const Icon(
                                  LucideIcons.fileText,
                                  size: 18,
                                ),
                                filled: true,
                                fillColor: inputBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty)
                                  return 'El RUC/DNI es obligatorio';
                                final clean = val.trim();
                                if (!RegExp(r'^(?:[0-9]{8}|[0-9]{11})$')
                                    .hasMatch(clean)) {
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            side: const BorderSide(
                              color: AppTheme.brandPrimary,
                              width: 1.2,
                            ),
                            foregroundColor: AppTheme.brandPrimary,
                          ),
                          icon: const Icon(LucideIcons.sparkles, size: 15),
                          label: Text(
                            'Demo',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: _generarRucDemo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Distribuidores oficiales frecuentes:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _proveedoresOficialesPeru.map((p) {
                        final isSelected = _rucCtrl.text.trim() == p['ruc'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(p['alias'] ?? p['ruc']!),
                            labelStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                        ? Colors.white70
                                        : const Color(0xFF334155)),
                            ),
                            backgroundColor: isSelected
                                ? AppTheme.brandPrimary
                                : (isDark
                                      ? AppTheme.cardDarkSunken
                                      : const Color(0xFFF1F5F9)),
                            side: BorderSide(
                              color: isSelected
                                  ? AppTheme.brandPrimary
                                  : (isDark
                                        ? AppTheme.borderDark
                                        : const Color(0xFFE2E8F0)),
                            ),
                            onPressed: () => _seleccionarProveedorOficial(p),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Razón Social
                  Text(
                    'Razón Social / Empresa *',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _razonSocialCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
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
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Ingresa la razón social'
                        : null,
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
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _telefonoCtrl,
                              keyboardType: TextInputType.phone,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Ej. 987654321',
                                prefixIcon: const Icon(
                                  LucideIcons.phone,
                                  size: 18,
                                ),
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
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _direccionCtrl,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Ej. Av. Los Próceres 120',
                                prefixIcon: const Icon(
                                  LucideIcons.mapPin,
                                  size: 18,
                                ),
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

                  // Botones Cancelar y Guardar
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            onPressed: _isGuardando
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark
                                    ? AppTheme.borderDark
                                    : AppTheme.borderLight,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(27),
                              ),
                            ),
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _isGuardando ? null : _guardarProveedor,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.brandPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(27),
                              ),
                              elevation: 3,
                              shadowColor: AppTheme.brandPrimary.withValues(
                                alpha: 0.35,
                              ),
                            ),
                            icon: _isGuardando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(LucideIcons.checkCheck, size: 20),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _isGuardando ? 'GUARDANDO...' : 'REGISTRAR',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
