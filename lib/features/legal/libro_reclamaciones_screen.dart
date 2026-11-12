// ignore_for_file: deprecated_member_use
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:http/http.dart' as http;

import '../../core/api_constants.dart';
import '../../core/theme.dart';
import '../../core/cajaya_vectors.dart';

class LibroReclamacionesScreen extends StatefulWidget {
  final String? tiendaNombre;
  final int? idBodega;

  const LibroReclamacionesScreen({super.key, this.tiendaNombre, this.idBodega});

  @override
  State<LibroReclamacionesScreen> createState() =>
      _LibroReclamacionesScreenState();
}

class _LibroReclamacionesScreenState extends State<LibroReclamacionesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controladores Formulario
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _numDocCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _descBienCtrl = TextEditingController();
  final _detalleCtrl = TextEditingController();
  final _pedidoCtrl = TextEditingController();

  String _tipoDoc = 'DNI';
  String _tipoReclamacion = 'RECLAMO'; // 'RECLAMO' o 'QUEJA'
  String _tipoBien = 'PRODUCTO'; // 'PRODUCTO' o 'SERVICIO'
  bool _aceptaTerminos = false;
  bool _isSubmitting = false;

  // Consulta de Reclamo
  final _codigoConsultaCtrl = TextEditingController();
  bool _isSearching = false;
  Map<String, dynamic>? _reclamoConsultado;
  String? _errorConsulta;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nombreCtrl.dispose();
    _numDocCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _montoCtrl.dispose();
    _descBienCtrl.dispose();
    _detalleCtrl.dispose();
    _pedidoCtrl.dispose();
    _codigoConsultaCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarReclamo() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_aceptaTerminos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debes confirmar que los datos consignados son verdaderos.',
          ),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final double? monto = double.tryParse(_montoCtrl.text.trim());
      final Map<String, dynamic> body = {
        if (widget.idBodega != null) 'idBodega': widget.idBodega,
        'nombreReclamante': _nombreCtrl.text.trim(),
        'tipoDocumento': _tipoDoc,
        'numeroDocumento': _numDocCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'direccion': _direccionCtrl.text.trim(),
        'tipo': _tipoReclamacion,
        'tipoBien': _tipoBien,
        'montoReclamado': monto ?? 0.0,
        'descripcionBien': _descBienCtrl.text.trim(),
        'detalleReclamacion': _detalleCtrl.text.trim(),
        'pedidoReclamante': _pedidoCtrl.text.trim(),
      };

      final uri = Uri.parse('${ApiConstants.baseUrl}/public/reclamaciones');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(body),
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final String codigo = data['codigoReclamacion'] ?? 'REC-REGISTRADO';

        if (mounted) {
          _mostrarDialogoExito(codigo);
          _limpiarFormulario();
        }
      } else {
        throw Exception('Error del servidor: ${resp.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo registrar la reclamación: ${e.toString().replaceAll("Exception: ", "")}',
            ),
            backgroundColor: AppTheme.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _limpiarFormulario() {
    _formKey.currentState?.reset();
    _nombreCtrl.clear();
    _numDocCtrl.clear();
    _emailCtrl.clear();
    _telefonoCtrl.clear();
    _direccionCtrl.clear();
    _montoCtrl.clear();
    _descBienCtrl.clear();
    _detalleCtrl.clear();
    _pedidoCtrl.clear();
    setState(() {
      _aceptaTerminos = false;
    });
  }

  void _mostrarDialogoExito(String codigo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.checkCircle2,
                color: AppTheme.accentGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hoja de Reclamación Generada',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu reclamación ha sido registrada formalmente bajo el Código:',
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Center(
                child: SelectableText(
                  codigo,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.brandPrimary,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '• Plazo legal de respuesta: Máximo 15 días hábiles conforme al Código de Protección y Defensa del Consumidor (Ley N° 29571).\n• Hemos enviado una constancia electrónica al correo registrado.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: AppTheme.getAdaptiveMutedText(
                  Theme.of(context).brightness == Brightness.dark,
                ),
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: codigo));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Código copiado al portapapeles')),
              );
            },
            icon: const Icon(LucideIcons.copy, size: 15),
            label: const Text('Copiar Código'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _consultarReclamo() async {
    final cod = _codigoConsultaCtrl.text.trim().toUpperCase();
    if (cod.isEmpty) {
      setState(() => _errorConsulta = 'Ingresa el código de reclamación');
      return;
    }

    setState(() {
      _isSearching = true;
      _errorConsulta = null;
      _reclamoConsultado = null;
    });

    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/public/reclamaciones/${Uri.encodeComponent(cod)}',
      );
      final resp = await http.get(uri);

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        setState(() {
          _reclamoConsultado = data;
          _isSearching = false;
        });
      } else {
        setState(() {
          _errorConsulta =
              'No se encontró ninguna reclamación con el código ingresado.';
          _isSearching = false;
        });
      }
    } catch (_) {
      setState(() {
        _errorConsulta = 'Error al consultar. Verifica tu conexión a internet.';
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String proveedorNombre =
        widget.tiendaNombre != null && widget.tiendaNombre!.isNotEmpty
        ? widget.tiendaNombre!
        : 'CajaYa Cloud POS (Plataforma)';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CajaYaLogoMark(size: 26),
            const SizedBox(width: 8),
            Text(
              'Libro de Reclamaciones',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.brandPrimary,
          indicatorColor: AppTheme.brandPrimary,
          tabs: const [
            Tab(
              icon: Icon(LucideIcons.fileText, size: 18),
              text: 'Registrar Reclamo',
            ),
            Tab(
              icon: Icon(LucideIcons.search, size: 18),
              text: 'Consultar Estado',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pestaña 1: Formulario
          _buildFormularioReclamo(isDark, proveedorNombre),
          // Pestaña 2: Consulta
          _buildConsultaReclamo(isDark),
        ],
      ),
    );
  }

  Widget _buildFormularioReclamo(bool isDark, String proveedorNombre) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner Legal INDECOPI
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.shieldCheck,
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
                              'Libro de Reclamaciones Virtual - INDECOPI',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Conforme a lo establecido en el Código de Protección y Defensa del Consumidor (Ley N° 29571) y el D.S. N° 011-2011-PCM.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Establecimiento / Proveedor: $proveedorNombre',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.brandPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 1. Datos del Consumidor
                _buildSeccionHeader(
                  '1. IDENTIFICACIÓN DEL CONSUMIDOR RECLAMANTE',
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre y Apellidos completos *',
                    prefixIcon: Icon(LucideIcons.user, size: 18),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa tu nombre completo'
                      : null,
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: DropdownButtonFormField<String>(
                        initialValue: _tipoDoc,
                        decoration: const InputDecoration(labelText: 'Doc.'),
                        items: const [
                          DropdownMenuItem(value: 'DNI', child: Text('DNI')),
                          DropdownMenuItem(value: 'CE', child: Text('C.E.')),
                          DropdownMenuItem(value: 'RUC', child: Text('RUC')),
                          DropdownMenuItem(
                            value: 'PASAPORTE',
                            child: Text('Pasaporte'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _tipoDoc = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _numDocCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Número de Documento *',
                          prefixIcon: Icon(LucideIcons.idCard, size: 18),
                        ),
                        validator: (v) => (v == null || v.trim().length < 4)
                            ? 'Documento inválido'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo Electrónico *',
                          prefixIcon: Icon(LucideIcons.mail, size: 18),
                          helperText:
                              'Enviaremos copia de la hoja de reclamación',
                        ),
                        validator: (v) =>
                            (v == null || !v.contains('@') || !v.contains('.'))
                            ? 'Ingresa un correo válido'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _telefonoCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono / WhatsApp',
                          prefixIcon: Icon(LucideIcons.phone, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _direccionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Domicilio / Dirección del Consumidor',
                    prefixIcon: Icon(LucideIcons.mapPin, size: 18),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Identificación del Bien
                _buildSeccionHeader('2. IDENTIFICACIÓN DEL BIEN CONTRATADO'),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Producto'),
                        value: 'PRODUCTO',
                        groupValue: _tipoBien,
                        onChanged: (v) => setState(() => _tipoBien = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Servicio'),
                        value: 'SERVICIO',
                        groupValue: _tipoBien,
                        onChanged: (v) => setState(() => _tipoBien = v!),
                      ),
                    ),
                  ],
                ),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _descBienCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Descripción del Producto o Servicio',
                          hintText: 'Ej: Abarrotes, Bebida, Suscripción...',
                          prefixIcon: Icon(LucideIcons.shoppingBag, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _montoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Monto Reclamado (S/)',
                          prefixIcon: Icon(
                            LucideIcons.circleDollarSign,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 3. Detalle de la Reclamación
                _buildSeccionHeader('3. DETALLE DE LA RECLAMACIÓN Y PEDIDO'),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: Text(
                          'RECLAMO',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: const Text(
                          'Disconformidad relacionada a los bienes o servicios adquiridos.',
                        ),
                        value: 'RECLAMO',
                        groupValue: _tipoReclamacion,
                        onChanged: (v) => setState(() => _tipoReclamacion = v!),
                      ),
                      RadioListTile<String>(
                        title: Text(
                          'QUEJA',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: const Text(
                          'Malestar o descontento respecto a la atención al público.',
                        ),
                        value: 'QUEJA',
                        groupValue: _tipoReclamacion,
                        onChanged: (v) => setState(() => _tipoReclamacion = v!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _detalleCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Detalle de los hechos *',
                    hintText: 'Explica de forma clara lo ocurrido con el producto o atención...',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? 'Describe los hechos con mayor detalle (mín. 10 caracteres)'
                      : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _pedidoCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Pedido o Pretensión concreta del consumidor *',
                    hintText: 'Ej: Devolución de dinero, cambio de producto, disculpas...',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().length < 5)
                      ? 'Indica qué solicitas como solución'
                      : null,
                ),
                const SizedBox(height: 14),

                CheckboxListTile(
                  value: _aceptaTerminos,
                  onChanged: (v) =>
                      setState(() => _aceptaTerminos = v ?? false),
                  title: Text(
                    'Declaro ser el titular del reclamo y que la información brindada es veraz conforme a la Ley N° 29571.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 18),

                ElevatedButton(
                  onPressed: _isSubmitting ? null : _enviarReclamo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'REGISTRAR HOJA DE RECLAMACIÓN',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConsultaReclamo(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Consulta el Estado de tu Reclamo o Queja',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ingresa el código correlativo de tu hoja de reclamación (Ej: REC-2026-00001).',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _codigoConsultaCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Código de Reclamación',
                        hintText: 'REC-2026-XXXXX',
                        prefixIcon: Icon(LucideIcons.fileSearch, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isSearching ? null : _consultarReclamo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Consultar'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_errorConsulta != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.alertRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.alertRed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.alertCircle,
                        color: AppTheme.alertRed,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorConsulta!,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.alertRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_reclamoConsultado != null) ...[
                _buildDetalleReclamoConsultado(isDark, _reclamoConsultado!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetalleReclamoConsultado(
    bool isDark,
    Map<String, dynamic> reclamo,
  ) {
    final String codigo = reclamo['codigoReclamacion'] ?? '';
    final String estado = reclamo['estado'] ?? 'PENDIENTE';
    final String tipo = reclamo['tipo'] ?? 'RECLAMO';
    final String reclamante = reclamo['nombreReclamante'] ?? '';
    final String fecha =
        reclamo['fechaReclamo']?.toString().substring(0, 10) ?? '';
    final String respuesta = reclamo['respuestaProveedor'] ?? '';
    final int diasRestantes = reclamo['diasHabilesRestantes'] ?? 0;

    Color badgeColor = const Color(0xFFF59E0B);
    if (estado == 'ATENDIDO') badgeColor = AppTheme.accentGreen;
    if (estado == 'EN_PROCESO') badgeColor = const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                codigo,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.brandPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  estado,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          Text(
            'Tipo: $tipo • Reclamante: $reclamante',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Fecha de Registro: $fecha',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppTheme.getAdaptiveMutedText(isDark),
            ),
          ),
          if (estado != 'ATENDIDO') ...[
            const SizedBox(height: 6),
            Text(
              'Plazo Legal: Quedan $diasRestantes días hábiles para emitir respuesta oficial.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFD97706),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'RESPUESTA OFICIAL DEL PROVEEDOR:',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.getAdaptiveMutedText(isDark),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(
              respuesta.isNotEmpty ? respuesta : 'Tu reclamación se encuentra en etapa de evaluación. El proveedor responderá dentro del plazo legal.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                fontStyle: respuesta.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionHeader(String titulo) {
    return Text(
      titulo,
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppTheme.brandPrimary,
        letterSpacing: 0.5,
      ),
    );
  }
}
