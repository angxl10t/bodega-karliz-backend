import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'auth_service.dart';
import '../../core/theme.dart';

class RegistroBodegaSheet extends StatefulWidget {
  const RegistroBodegaSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const RegistroBodegaSheet(),
    );
  }

  @override
  State<RegistroBodegaSheet> createState() => _RegistroBodegaSheetState();
}

class _RegistroBodegaSheetState extends State<RegistroBodegaSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreBodegaCtrl = TextEditingController();
  final _rucCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _adminUserCtrl = TextEditingController();
  final _adminPassCtrl = TextEditingController();

  final _authService = AuthService();
  String _selectedPlan = 'PRO';
  bool _isLoading = false;
  bool _obscurePass = true;
  String _errorMessage = '';

  @override
  void dispose() {
    _nombreBodegaCtrl.dispose();
    _rucCtrl.dispose();
    _direccionCtrl.dispose();
    _telefonoCtrl.dispose();
    _adminUserCtrl.dispose();
    _adminPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final res = await _authService.registrarBodega(
      nombreComercial: _nombreBodegaCtrl.text.trim(),
      ruc: _rucCtrl.text.trim().isEmpty ? null : _rucCtrl.text.trim(),
      direccion: _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
      adminUsername: _adminUserCtrl.text.trim(),
      adminPassword: _adminPassCtrl.text.trim(),
      plan: _selectedPlan,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (res.success) {
      Navigator.pop(context); // Cierra modal
      context.go('/home'); // Ingresa al sistema con la nueva bodega aprovisionada
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Bienvenido a tu nuevo sistema! Bodega creada con 14 días gratis de Plan $_selectedPlan.'),
          backgroundColor: AppTheme.accentGreen,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      setState(() {
        _errorMessage = res.errorMessage ?? 'No se pudo crear la bodega. Verifica los datos.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barra de arrastre
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 14),

            // Header con título
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.store, color: AppTheme.brandPrimary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registrar mi Negocio',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          Text(
                            '14 días gratis • Configuración en 1 minuto',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 20, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),

            // Formulario scrolleable
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner de bienvenida & autoconfiguración
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.brandPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.brandPrimary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.sparkles, color: AppTheme.brandPrimary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tu bodega se creará con las 12 categorías estándar (Bebidas, Lácteos, Abarrotes, etc.) listas para usar.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppTheme.brandLight : AppTheme.brandDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_errorMessage.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.alertRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.alertRed.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.alertTriangle, color: AppTheme.alertRed, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.alertRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 1. Nombre Comercial
                      Text(
                        'Nombre de la Bodega o Minimarket *',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nombreBodegaCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ej. Minimarket San Martín',
                          prefixIcon: Icon(LucideIcons.store, size: 18),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'El nombre de la bodega es obligatorio';
                          if (v.trim().length < 3) return 'Mínimo 3 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // 2. RUC / DNI & Teléfono
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'RUC / DNI (Opcional)',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _rucCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(11),
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: '8 u 11 dígitos',
                                    prefixIcon: Icon(LucideIcons.fileText, size: 18),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return null;
                                    final clean = v.trim();
                                    if (!RegExp(r'^(?:[0-9]{8}|[0-9]{11})$').hasMatch(clean)) {
                                      return 'Debe ser DNI (8 d.) o RUC (11 d.)';
                                    }
                                    return null;
                                  },
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
                                  'Teléfono (Opcional)',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _telefonoCtrl,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(9),
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: 'Ej. 987654321',
                                    prefixIcon: Icon(LucideIcons.phone, size: 18),
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
                      const SizedBox(height: 14),

                      // 3. Dirección
                      Text(
                        'Dirección de la Tienda (Opcional)',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _direccionCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ej. Av. Primavera 123, Surco',
                          prefixIcon: Icon(LucideIcons.mapPin, size: 18),
                        ),
                      ),
                      const SizedBox(height: 18),

                      const Divider(),
                      const SizedBox(height: 8),

                      // 4. Credenciales de Administrador
                      Text(
                        'Cuenta Administradora (Dueño)',
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.brandPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Text(
                        'Usuario Administrador *',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _adminUserCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ej. admin_sanmartin',
                          prefixIcon: Icon(LucideIcons.user, size: 18),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'El usuario es obligatorio';
                          if (v.trim().length < 3) return 'Mínimo 3 caracteres';
                          if (v.trim().contains(' ')) return 'No debe contener espacios';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      Text(
                        'Contraseña Inicial (mínimo 8 caracteres) *',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _adminPassCtrl,
                        obscureText: _obscurePass,
                        decoration: InputDecoration(
                          hintText: 'Contraseña segura',
                          prefixIcon: const Icon(LucideIcons.lock, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePass ? LucideIcons.eyeOff : LucideIcons.eye,
                              size: 18,
                              color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                            ),
                            onPressed: () => setState(() => _obscurePass = !_obscurePass),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'La contraseña es obligatoria';
                          if (v.trim().length < 8) return 'Mínimo 8 caracteres por seguridad';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // 5. Selector de Plan
                      Text(
                        'Selecciona tu Plan Inicial',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: _buildPlanOption(
                              id: 'BASICO',
                              title: 'Plan Bodega',
                              price: 'S/ 50 /mes',
                              badge: 'Admin + 2 Cajeros',
                              features: 'POS rápido, Stock, Caja y Tickets',
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildPlanOption(
                              id: 'PRO',
                              title: 'Plan Minimarket Pro',
                              price: 'S/ 100 /mes',
                              badge: 'Cajeros Ilimitados',
                              features: 'Turnos, Kardex antifraude, Marca propia',
                              isPopular: true,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Botón Crear Bodega
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(LucideIcons.rocket, size: 20, color: Colors.white),
                                    const SizedBox(width: 10),
                                    Text(
                                      'CREAR BODEGA & EMPEZAR',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanOption({
    required String id,
    required String title,
    required String price,
    required String badge,
    required String features,
    bool isPopular = false,
    required bool isDark,
  }) {
    final isSelected = _selectedPlan == id;
    final cardBg = isSelected
        ? AppTheme.brandPrimary.withValues(alpha: isDark ? 0.2 : 0.08)
        : (isDark ? AppTheme.cardDarkElevated : const Color(0xFFF8FAFC));
    final borderColor = isSelected
        ? AppTheme.brandPrimary
        : (isDark ? AppTheme.borderDark : AppTheme.borderLight);

    return InkWell(
      onTap: () => setState(() => _selectedPlan = id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPopular)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'RECOMENDADO',
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                if (isSelected)
                  const Icon(LucideIcons.checkCircle2, color: AppTheme.brandPrimary, size: 16),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              price,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.brandPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF475569),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              features,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
