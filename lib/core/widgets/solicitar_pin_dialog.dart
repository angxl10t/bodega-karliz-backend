import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../lock_service.dart';
import '../theme.dart';

class SolicitarPinDialog {
  static Future<bool> mostrar(
    BuildContext context, {
    String titulo = 'Autorización Requerida',
    String mensaje =
        'Ingresa el PIN de Administrador para autorizar esta operación.',
  }) async {
    final hasPin = await LockService().hasPin();
    if (!hasPin) {
      if (!context.mounted) return false;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(LucideIcons.shieldAlert, color: AppTheme.alertRed, size: 22),
              SizedBox(width: 8),
              Text('PIN No Configurado'),
            ],
          ),
          content: const Text(
            'Esta operación requiere autorización con PIN de Administrador, pero aún no se ha configurado un PIN en este terminal.\n\nPor favor, ingresa a Configuración del Terminal para crear tu PIN de 4 dígitos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return false;
    }

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          _SolicitarPinDialogWidget(titulo: titulo, mensaje: mensaje),
    );

    return result ?? false;
  }
}

class _SolicitarPinDialogWidget extends StatefulWidget {
  final String titulo;
  final String mensaje;

  const _SolicitarPinDialogWidget({
    required this.titulo,
    required this.mensaje,
  });

  @override
  State<_SolicitarPinDialogWidget> createState() =>
      _SolicitarPinDialogWidgetState();
}

class _SolicitarPinDialogWidgetState extends State<_SolicitarPinDialogWidget> {
  late final TextEditingController _pinController;
  bool _obscureText = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _validarYEnviar() async {
    final enteredPin = _pinController.text.trim();
    if (enteredPin.isEmpty) {
      setState(() => _errorText = 'Ingresa el PIN');
      return;
    }
    final hasPin = await LockService().hasPin();
    final ok = hasPin ? await LockService().verifyPin(enteredPin) : false;
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _errorText = 'PIN incorrecto');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
      ),
      title: Row(
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
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.titulo,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.textDark,
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
            widget.mensaje,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              height: 1.4,
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: _obscureText,
            maxLength: 6,
            autofocus: true,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
            decoration: InputDecoration(
              hintText: '••••',
              counterText: '',
              errorText: _errorText,
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF131B29)
                  : const Color(0xFFF8FAFC),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureText ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppTheme.brandPrimary,
                  width: 2,
                ),
              ),
            ),
            onSubmitted: (_) => _validarYEnviar(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancelar',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.brandPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: _validarYEnviar,
          child: Text(
            'Autorizar',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
