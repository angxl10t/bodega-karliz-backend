import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'bodega_service.dart';
import '../../core/theme.dart';
import '../../core/theme_provider.dart';
import '../../core/cajaya_vectors.dart';

class ColorPreset {
  final String name;
  final String hex;
  final Color color;

  const ColorPreset(this.name, this.hex, this.color);
}

const List<ColorPreset> kColorPresets = [
  ColorPreset('Cobalto FinTech', '#2563EB', Color(0xFF2563EB)),
  ColorPreset('Esmeralda Boutique', '#0D9488', Color(0xFF0D9488)),
  ColorPreset('Índigo Real', '#4F46E5', Color(0xFF4F46E5)),
  ColorPreset('Rubí Moderno', '#E11D48', Color(0xFFE11D48)),
  ColorPreset('Violeta SaaS', '#7C3AED', Color(0xFF7C3AED)),
  ColorPreset('Ámbar Dinámico', '#D97706', Color(0xFFD97706)),
];

class ConfiguracionMarcaModal extends StatefulWidget {
  final bool isPro;
  final VoidCallback? onSaved;

  const ConfiguracionMarcaModal({
    super.key,
    required this.isPro,
    this.onSaved,
  });

  static Future<void> show(BuildContext context, {required bool isPro, VoidCallback? onSaved}) {
    return showDialog(
      context: context,
      builder: (ctx) => ConfiguracionMarcaModal(isPro: isPro, onSaved: onSaved),
    );
  }

  @override
  State<ConfiguracionMarcaModal> createState() => _ConfiguracionMarcaModalState();
}

class _ConfiguracionMarcaModalState extends State<ConfiguracionMarcaModal> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _rucCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _lemaCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();

  final _bodegaService = BodegaService();
  String _selectedHex = '#2563EB';
  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _rucCtrl.dispose();
    _direccionCtrl.dispose();
    _telefonoCtrl.dispose();
    _lemaCtrl.dispose();
    _logoUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    final info = await _bodegaService.obtenerMiBodega();
    if (mounted) {
      if (info != null) {
        _nombreCtrl.text = info.nombreComercial;
        _rucCtrl.text = info.rucDni ?? '';
        _direccionCtrl.text = info.direccion ?? '';
        _telefonoCtrl.text = info.telefono ?? '';
        _lemaCtrl.text = info.lemaComercial ?? '';
        _logoUrlCtrl.text = info.logoUrl ?? '';
        _selectedHex = info.colorPrimario;
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });

    try {
      final info = await _bodegaService.actualizarConfiguracion(
        nombreComercial: _nombreCtrl.text.trim(),
        rucDni: _rucCtrl.text.trim().isEmpty ? null : _rucCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
        lemaComercial: _lemaCtrl.text.trim().isEmpty ? null : _lemaCtrl.text.trim(),
        colorPrimario: _selectedHex,
        logoUrl: _logoUrlCtrl.text.trim().isEmpty ? null : _logoUrlCtrl.text.trim(),
      );

      if (mounted) {
        // Actualizar el ThemeProvider con la nueva paleta de acento elegida
        context.read<ThemeProvider>().setAccentColorFromHex(info.colorPrimario);

        widget.onSaved?.call();
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Identidad y marca de "${info.nombreComercial}" guardada con éxito!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: isDark ? const BorderSide(color: AppTheme.borderDarkElevated, width: 1.2) : BorderSide.none,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Encabezado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CajaYaLogoMark(
                          size: 36,
                          customColor: _parseHexToColor(_selectedHex),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Identidad & Marca',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : AppTheme.brandInk,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Personalización de comprobantes y colores',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 20, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              if (_isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_errorMessage.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.alertRed.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.alertRed.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.alertCircle, color: AppTheme.alertRed, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        color: AppTheme.alertRed,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // SECCIÓN 1: NIVEL 1 (DATOS DEL TICKET Y COMERCIO)
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(LucideIcons.printer, size: 14, color: AppTheme.brandPrimary),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Nivel 1: Datos en Comprobantes (Tickets)',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : AppTheme.textDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Nombre Comercial
                          Text(
                            'Nombre Comercial *',
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _nombreCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Ej. Minimarket San Martín',
                              prefixIcon: Icon(LucideIcons.store, size: 16),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'El nombre es obligatorio';
                              if (v.trim().length < 3) return 'Mínimo 3 caracteres';
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          // Lema Comercial / Tagline (Impreso en tickets)
                          Text(
                            'Lema o Eslogan Comercial (Pie/Cabecera de Ticket)',
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _lemaCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Ej. ¡Los mejores precios de tu barrio!',
                              prefixIcon: Icon(LucideIcons.sparkles, size: 16),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // RUC/DNI y Teléfono
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('RUC / DNI', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _rucCtrl,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(11),
                                      ],
                                      decoration: const InputDecoration(
                                        hintText: '11 u 8 dígitos',
                                        prefixIcon: Icon(LucideIcons.fileText, size: 16),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) return null;
                                        final clean = v.trim();
                                        if (!RegExp(r'^(?:[0-9]{8}|[0-9]{11})$').hasMatch(clean)) {
                                          return 'DNI (8 d.) o RUC (11 d.)';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Teléfono de Contacto', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _telefonoCtrl,
                                      keyboardType: TextInputType.phone,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(9),
                                      ],
                                      decoration: const InputDecoration(
                                        hintText: 'Ej. 987654321',
                                        prefixIcon: Icon(LucideIcons.phone, size: 16),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) return null;
                                        if (v.trim().length != 9) {
                                          return 'Debe tener 9 dígitos';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Dirección
                          Text(
                            'Dirección del Establecimiento',
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _direccionCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Ej. Jr. Las Begonias 450, Lince',
                              prefixIcon: Icon(LucideIcons.mapPin, size: 16),
                            ),
                          ),
                          const SizedBox(height: 18),

                          const Divider(),
                          const SizedBox(height: 8),

                          // SECCIÓN 2: NIVEL 2 (PALETA DE COLOR & BRANDING EXCLUSIVO PRO)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(LucideIcons.palette, size: 14, color: Color(0xFFD97706)),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Nivel 2: Paleta de Identidad & Color',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : AppTheme.textDark,
                                    ),
                                  ),
                                ],
                              ),
                              if (!widget.isPro)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.brandPrimary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.lock, size: 10, color: AppTheme.brandPrimary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'PLAN PRO',
                                        style: GoogleFonts.outfit(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.brandPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.isPro
                                ? 'Elige el color distintivo para botones, acentos e indicadores de tu tienda.'
                                : 'Tu tienda utiliza la paleta estándar Cobalto de CajaYa. Pasa al Plan Pro para desbloquear colores de marca personalizados.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Grilla de Paletas de Color
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: kColorPresets.map((preset) {
                              final isSelected = _selectedHex.toUpperCase() == preset.hex.toUpperCase();
                              final isDefault = preset.hex.toUpperCase() == '#2563EB';
                              final isLocked = !widget.isPro && !isDefault;

                              return InkWell(
                                onTap: () {
                                  if (isLocked) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('La personalización de paleta de colores exclusiva requiere el Plan Minimarket Pro.'),
                                        backgroundColor: AppTheme.brandPrimary,
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() => _selectedHex = preset.hex);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? preset.color.withValues(alpha: isDark ? 0.25 : 0.1)
                                        : (isDark ? AppTheme.cardDarkHighlight : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? preset.color : Colors.transparent,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: preset.color,
                                          shape: BoxShape.circle,
                                        ),
                                        child: isSelected
                                            ? const Center(child: Icon(Icons.check, size: 11, color: Colors.white))
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        preset.name,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isDark ? Colors.white : AppTheme.textDark,
                                        ),
                                      ),
                                      if (isLocked) ...[
                                        const SizedBox(width: 6),
                                        Icon(LucideIcons.lock, size: 12, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B)),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 14),

              // Botones de acción
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _parseHexToColor(_selectedHex),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('GUARDAR IDENTIDAD'),
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

  Color _parseHexToColor(String hex) {
    try {
      String clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        clean = 'FF$clean';
      }
      return Color(int.parse(clean, radix: 16));
    } catch (_) {
      return AppTheme.brandPrimary;
    }
  }
}
