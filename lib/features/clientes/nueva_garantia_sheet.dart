import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import 'cliente_model.dart';
import 'garantia_botella_service.dart';

class NuevaGarantiaSheet extends StatefulWidget {
  final List<Cliente> clientesDisponibles;
  final VoidCallback onGuardado;

  const NuevaGarantiaSheet({
    super.key,
    required this.clientesDisponibles,
    required this.onGuardado,
  });

  static void show(
    BuildContext context, {
    required List<Cliente> clientesDisponibles,
    required VoidCallback onGuardado,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NuevaGarantiaSheet(
        clientesDisponibles: clientesDisponibles,
        onGuardado: onGuardado,
      ),
    );
  }

  @override
  State<NuevaGarantiaSheet> createState() => _NuevaGarantiaSheetState();
}

class _NuevaGarantiaSheetState extends State<NuevaGarantiaSheet> {
  final GarantiaBotellaService _service = GarantiaBotellaService();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _telefonoCtrl = TextEditingController();
  final TextEditingController _montoCtrl = TextEditingController(text: '4.00');
  final TextEditingController _notasCtrl = TextEditingController();

  Cliente? _clienteSeleccionado;
  int _cantidadBotellas = 2;
  String _tipoBotella = 'Cerveza 650ml';
  double _montoUnitarioSugerido = 2.00;
  bool _guardando = false;

  final List<String> _tiposBotellasComunes = [
    'Cerveza 650ml',
    'Cerveza 1L',
    'Gaseosa 1L / 1.5L',
    'Personal Vidrio',
    'Bidón / Galonera',
    'Otro Envase',
  ];

  @override
  void initState() {
    super.initState();
    _recalcularMonto();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _montoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  void _recalcularMonto() {
    final total = _cantidadBotellas * _montoUnitarioSugerido;
    _montoCtrl.text = total.toStringAsFixed(2);
  }

  void _seleccionarCliente(Cliente? c) {
    setState(() {
      _clienteSeleccionado = c;
      if (c != null) {
        _nombreCtrl.text = c.nombreCompleto;
        if (c.telefono != null && c.telefono!.isNotEmpty) {
          _telefonoCtrl.text = c.telefono!;
        }
      }
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un monto de garantía válido en dinero')),
      );
      return;
    }

    setState(() => _guardando = true);
    HapticFeedback.mediumImpact();

    try {
      await _service.crearGarantia({
        'nombrePersona': _nombreCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
        'idCliente': _clienteSeleccionado?.idCliente,
        'cantidadBotellas': _cantidadBotellas,
        'montoGarantia': monto,
        'tipoBotella': _tipoBotella,
        'notas': _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onGuardado();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Garantía de $_cantidadBotellas botellas registrada para ${_nombreCtrl.text.trim()}!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCard = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra superior de agarre
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Título con ícono representativo de botella retornable
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(LucideIcons.wine, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dejar Dinero por Botellas',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        Text(
                          'Garantía en custodia que se devuelve al entregar el envase',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Selector opcional de Vecino Registrado
              if (widget.clientesDisponibles.isNotEmpty) ...[
                Text(
                  'Vincular con Vecino de Libreta (Opcional)',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Cliente?>(
                      isExpanded: true,
                      value: _clienteSeleccionado,
                      hint: Text(
                        'Seleccionar vecino de la lista (o escribir abajo)',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: isDark ? Colors.white54 : AppTheme.textMuted),
                      ),
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: [
                        DropdownMenuItem<Cliente?>(
                          value: null,
                          child: Text(
                            '-- Persona no registrada (escribir nombre manual) --',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ),
                        ...widget.clientesDisponibles.map(
                          (c) => DropdownMenuItem<Cliente?>(
                            value: c,
                            child: Text(
                              '${c.nombreCompleto} ${c.telefono != null ? "(${c.telefono})" : ""}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                      onChanged: _seleccionarCliente,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Nombre de la Persona
              Text(
                'Nombre de la Persona *',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Ej. Don Carlos, Vecino del 2do piso',
                  prefixIcon: const Icon(LucideIcons.user, size: 18),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingrese el nombre de la persona';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Teléfono (Opcional)
              Text(
                'Teléfono / Celular (Opcional)',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _telefonoCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Ej. 987654321',
                  prefixIcon: const Icon(LucideIcons.phone, size: 18),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              // Cantidad de Botellas
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cantidad de Botellas',
                          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Botellas de vidrio que se lleva',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: isDark ? Colors.white54 : AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.minus, size: 16),
                          onPressed: _cantidadBotellas > 1
                              ? () {
                                  setState(() {
                                    _cantidadBotellas--;
                                    _recalcularMonto();
                                  });
                                }
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: Text(
                            '$_cantidadBotellas',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.plus, size: 16),
                          onPressed: () {
                            setState(() {
                              _cantidadBotellas++;
                              _recalcularMonto();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Presets rápidos de cantidad
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [1, 2, 3, 4, 6, 12].map((num) {
                  final isSel = _cantidadBotellas == num;
                  return ChoiceChip(
                    label: Text('$num ${num == 1 ? "botella" : "botellas"}'),
                    selected: isSel,
                    selectedColor: AppTheme.brandPrimary,
                    labelStyle: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isSel ? Colors.white : (isDark ? Colors.white70 : AppTheme.textDark),
                    ),
                    onSelected: (sel) {
                      if (sel) {
                        setState(() {
                          _cantidadBotellas = num;
                          _recalcularMonto();
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Tipo de Botella / Envase
              Text(
                'Tipo de Envase / Botella',
                style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tiposBotellasComunes.map((tipo) {
                  final isSel = _tipoBotella == tipo;
                  return FilterChip(
                    label: Text(tipo),
                    selected: isSel,
                    selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
                    checkmarkColor: const Color(0xFF2563EB),
                    labelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isSel ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : AppTheme.textDark),
                    ),
                    onSelected: (sel) {
                      if (sel) {
                        setState(() {
                          _tipoBotella = tipo;
                          if (tipo.contains('Cerveza')) {
                            _montoUnitarioSugerido = 2.00;
                          } else if (tipo.contains('Gaseosa')) {
                            _montoUnitarioSugerido = 2.00;
                          } else if (tipo.contains('Bidón')) {
                            _montoUnitarioSugerido = 10.00;
                          }
                          _recalcularMonto();
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Monto en Dinero Dejado en Garantía
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monto en Dinero Dejado (S/) *',
                          style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Total retenido que se devolverá al cliente',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: isDark ? Colors.white54 : AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A)),
                decoration: InputDecoration(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text('S/', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Ingrese el monto de dinero';
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Chips de sugerencia de precio unitario
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [1.50, 2.00, 2.50, 3.00, 4.00, 5.00].map((p) {
                  return ActionChip(
                    label: Text('S/ ${p.toStringAsFixed(2)} c/u'),
                    backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    labelStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                    onPressed: () {
                      setState(() {
                        _montoUnitarioSugerido = p;
                        _recalcularMonto();
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Notas / Observaciones
              Text(
                'Notas u Observaciones (Opcional)',
                style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notasCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Ej. Dejó billete de S/ 10, botellas de Cristal retornables',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),

              // Botón Guardar
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  icon: _guardando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(LucideIcons.check, size: 18),
                  label: Text(
                    _guardando ? 'Guardando garantía...' : 'Registrar Garantía de Botellas',
                    style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                  onPressed: _guardando ? null : _guardar,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
