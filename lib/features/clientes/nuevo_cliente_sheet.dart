import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../ventas/documento_service.dart';
import 'cliente_model.dart';
import 'cliente_service.dart';

class NuevoClienteSheet extends StatefulWidget {
  final Cliente? clienteExistente;
  final VoidCallback? onGuardado;
  final ValueChanged<Cliente>? onCreated;

  const NuevoClienteSheet({
    super.key,
    this.clienteExistente,
    this.onGuardado,
    this.onCreated,
  });

  static Future<Cliente?> show(
    BuildContext context, {
    Cliente? cliente,
    VoidCallback? onGuardado,
    ValueChanged<Cliente>? onCreated,
  }) {
    return showModalBottomSheet<Cliente>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NuevoClienteSheet(
        clienteExistente: cliente,
        onGuardado: onGuardado,
        onCreated: onCreated,
      ),
    );
  }

  @override
  State<NuevoClienteSheet> createState() => _NuevoClienteSheetState();
}

class _NuevoClienteSheetState extends State<NuevoClienteSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _docCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _dirCtrl = TextEditingController();
  final _limiteCtrl = TextEditingController(text: '200');
  final _notasCtrl = TextEditingController();

  final ClienteService _clienteService = ClienteService();
  final DocumentoService _docService = DocumentoService();

  bool _isConsultandoDoc = false;
  bool _isGuardando = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    final c = widget.clienteExistente;
    if (c != null) {
      _nombreCtrl.text = c.nombreCompleto;
      _docCtrl.text = c.documento ?? '';
      _telCtrl.text = c.telefono ?? '';
      _dirCtrl.text = c.direccion ?? '';
      _limiteCtrl.text = c.limiteCredito.toStringAsFixed(0);
      _notasCtrl.text = c.notas ?? '';
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _docCtrl.dispose();
    _telCtrl.dispose();
    _dirCtrl.dispose();
    _limiteCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _consultarDocumento() async {
    final doc = _docCtrl.text.trim();
    if (doc.length != 8 && doc.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un DNI (8 dígitos) o RUC (11 dígitos)')),
      );
      return;
    }

    setState(() {
      _isConsultandoDoc = true;
      _errorMsg = null;
    });

    try {
      if (doc.length == 8) {
        final res = await _docService.consultarDni(doc);
        if (res != null && res.encontrado && res.nombreCompleto.isNotEmpty) {
          _nombreCtrl.text = res.nombreCompleto;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se encontraron datos para este DNI')),
            );
          }
        }
      } else {
        final res = await _docService.consultarRuc(doc);
        if (res != null && res.encontrado && res.razonSocial.isNotEmpty) {
          _nombreCtrl.text = res.razonSocial;
          if (res.direccion != null && res.direccion!.isNotEmpty) {
            _dirCtrl.text = res.direccion!;
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se encontraron datos para este RUC')),
            );
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isConsultandoDoc = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isGuardando = true;
      _errorMsg = null;
    });

    final limite = double.tryParse(_limiteCtrl.text.trim()) ?? 200.0;
    final data = {
      'nombreCompleto': _nombreCtrl.text.trim(),
      'documento': _docCtrl.text.trim().isNotEmpty ? _docCtrl.text.trim() : null,
      'telefono': _telCtrl.text.trim().isNotEmpty ? _telCtrl.text.trim() : null,
      'direccion': _dirCtrl.text.trim().isNotEmpty ? _dirCtrl.text.trim() : null,
      'limiteCredito': limite,
      'notas': _notasCtrl.text.trim().isNotEmpty ? _notasCtrl.text.trim() : null,
    };

    try {
      Cliente cGuardado;
      if (widget.clienteExistente != null) {
        cGuardado = await _clienteService.actualizarCliente(widget.clienteExistente!.idCliente!, data);
      } else {
        cGuardado = await _clienteService.crearCliente(data);
      }
      widget.onGuardado?.call();
      widget.onCreated?.call(cGuardado);
      if (mounted) {
        Navigator.pop(context, cGuardado);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString().replaceFirst('Exception: ', '');
          _isGuardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final esEdicion = widget.clienteExistente != null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDarkElevated : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: isDark ? const Border(top: BorderSide(color: AppTheme.borderDarkElevated, width: 1.2)) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 16),

              // Encabezado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.userPlus, size: 20, color: AppTheme.brandPrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          esEdicion ? 'Editar Vecino / Cliente' : 'Registrar Nuevo Vecino',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        Text(
                          'Libreta de Fiados y Cuentas por Cobrar',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x, size: 20),
                    color: isDark ? Colors.white60 : Colors.black45,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (_errorMsg != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.alertRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.alertRed.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.alertTriangle, size: 16, color: AppTheme.alertRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMsg!,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppTheme.alertRed, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              // Fila 1: DNI / RUC con Botón de Consulta Automática
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _docCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 11,
                      decoration: InputDecoration(
                        labelText: 'DNI o RUC (Opcional)',
                        hintText: '8 u 11 dígitos',
                        counterText: '',
                        prefixIcon: const Icon(LucideIcons.idCard, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppTheme.cardDarkHighlight : const Color(0xFFF1F5F9),
                          foregroundColor: isDark ? Colors.white : AppTheme.brandPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: isDark ? AppTheme.borderDarkElevated : const Color(0xFFCBD5E1)),
                          ),
                        ),
                        onPressed: _isConsultandoDoc ? null : _consultarDocumento,
                        icon: _isConsultandoDoc
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(LucideIcons.search, size: 16),
                        label: Text('Buscar', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Fila 2: Nombre Completo
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el nombre completo' : null,
                decoration: InputDecoration(
                  labelText: 'Nombre y Apellidos *',
                  hintText: 'Ej. Don Carlos Mendoza',
                  prefixIcon: const Icon(LucideIcons.user, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),

              // Fila 3: Teléfono / WhatsApp + Límite de Crédito
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _telCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'WhatsApp / Celular',
                        hintText: '9XXXXXXXX',
                        prefixIcon: const Icon(LucideIcons.phone, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _limiteCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Límite S/',
                        hintText: '200',
                        prefixIcon: const Icon(LucideIcons.badgePercent, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Fila 4: Dirección / Domicilio
              TextFormField(
                controller: _dirCtrl,
                decoration: InputDecoration(
                  labelText: 'Dirección / Referencia de Casa',
                  hintText: 'Ej. Mz B Lote 4 / 2do piso',
                  prefixIcon: const Icon(LucideIcons.mapPin, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),

              // Fila 5: Notas de Confianza / Fechas de Pago
              TextFormField(
                controller: _notasCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notas de Vecindad (Opcional)',
                  hintText: 'Ej. Paga quincenas, vecino de confianza...',
                  prefixIcon: const Icon(LucideIcons.stickyNote, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 22),

              // Botones Cancelar y Guardar
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isGuardando ? null : () => Navigator.pop(context),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isGuardando ? null : _guardar,
                        icon: _isGuardando
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(LucideIcons.check, size: 18),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            esEdicion ? 'Actualizar Datos' : 'Registrar Vecino',
                            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
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
