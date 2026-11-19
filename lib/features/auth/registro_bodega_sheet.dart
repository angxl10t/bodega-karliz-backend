import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'auth_service.dart';
import 'selector_plan_registro_modal.dart';
import '../../core/responsive_layout.dart';
import '../../core/theme.dart';
import '../../core/widgets/adaptive_modal.dart';

class RegistroBodegaSheet extends StatefulWidget {
  const RegistroBodegaSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AdaptiveModal.show(
      context: context,
      maxWidth: 620,
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
  final _emailCtrl = TextEditingController();
  final _adminUserCtrl = TextEditingController();
  final _adminPassCtrl = TextEditingController();

  final _authService = AuthService();
  String _selectedPlan = 'PRO';
  String _selectedGiro = 'BODEGA';
  String _selectedRegimen = 'NUEVO_RUS';
  bool _isLoading = false;
  bool _obscurePass = true;
  String _errorMessage = '';

  @override
  void dispose() {
    _nombreBodegaCtrl.dispose();
    _rucCtrl.dispose();
    _direccionCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
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
      direccion: _direccionCtrl.text.trim().isEmpty
          ? null
          : _direccionCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim().isEmpty
          ? null
          : _telefonoCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      adminUsername: _adminUserCtrl.text.trim(),
      adminPassword: _adminPassCtrl.text.trim(),
      regimenTributario: _selectedRegimen,
      giroNegocio: _selectedGiro,
      plan: _selectedPlan,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (res.success) {
      Navigator.pop(context); // Cierra modal
      context.go(
        '/home',
      ); // Ingresa al sistema con la nueva bodega aprovisionada
      final exitoMsg = _selectedPlan == 'PRO'
          ? '¡Bienvenido a tu nuevo sistema! Bodega creada con 1 mes gratis (30 días) de Plan Minimarket PRO.'
          : '¡Bienvenido a tu nuevo sistema! Bodega creada exitosamente con Plan Bodega Básico.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exitoMsg),
          backgroundColor: AppTheme.accentGreen,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      setState(() {
        _errorMessage =
            res.errorMessage ??
            'No se pudo crear la bodega. Verifica los datos.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = ResponsiveLayout.isTabletOrLarger(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final resolvedRadius = isWide
        ? BorderRadius.circular(24)
        : const BorderRadius.vertical(top: Radius.circular(28));

    return Align(
      alignment: isWide ? Alignment.center : Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.sizeOf(context).height * (isWide ? 0.88 : 0.92),
        ),
        child: Container(
          margin: EdgeInsets.only(bottom: isWide ? 0 : bottomInset),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            borderRadius: resolvedRadius,
            border: isDark
                ? Border.all(color: AppTheme.borderDarkElevated, width: 1.2)
                : Border.all(
                    color: isWide ? AppTheme.borderLight : Colors.transparent,
                    width: 1.0,
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.25),
                blurRadius: isWide ? 30 : 24,
                offset: isWide ? const Offset(0, 10) : const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Barra de arrastre solo en móvil
                if (!isWide) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else
                  const SizedBox(height: 16),

                // Header con título
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.brandPrimary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                LucideIcons.store,
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
                                    'Registrar mi Negocio',
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '1 mes gratis (30 días) • Configuración en 1 minuto',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      color: isDark
                                          ? AppTheme.textDarkSecondary
                                          : const Color(0xFF334155),
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
                              color: AppTheme.brandPrimary.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppTheme.brandPrimary.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.sparkles,
                                  color: AppTheme.brandPrimary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _obtenerTextoBannerGiro(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? AppTheme.brandLight
                                          : AppTheme.brandDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 0. Selector de Giro de Negocio Multinegocio
                          _buildGiroSelector(isDark),
                          const SizedBox(height: 18),

                          if (_errorMessage.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.alertRed.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.alertRed.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    LucideIcons.alertTriangle,
                                    color: AppTheme.alertRed,
                                    size: 18,
                                  ),
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
                              color: isDark
                                  ? AppTheme.textDarkSecondary
                                  : const Color(0xFF334155),
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
                              if (v == null || v.trim().isEmpty)
                                return 'El nombre de la bodega es obligatorio';
                              if (v.trim().length < 3)
                                return 'Mínimo 3 caracteres';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // 2. RUC / DNI & Teléfono
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isVeryNarrow = constraints.maxWidth < 320;
                              final rucField = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'RUC / DNI (Opcional)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
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
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(11),
                                    ],
                                    decoration: const InputDecoration(
                                      hintText: '8 u 11 dígitos',
                                      prefixIcon: Icon(
                                        LucideIcons.fileText,
                                        size: 18,
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty)
                                        return null;
                                      final clean = v.trim();
                                      if (!RegExp(r'^(?:[0-9]{8}|[0-9]{11})$')
                                          .hasMatch(clean)) {
                                        return 'Debe ser DNI (8 d.) o RUC (11 d.)';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              );

                              final telField = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Teléfono (Opcional)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
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
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(9),
                                    ],
                                    decoration: const InputDecoration(
                                      hintText: 'Ej. 987654321',
                                      prefixIcon: Icon(
                                        LucideIcons.phone,
                                        size: 18,
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty)
                                        return null;
                                      if (v.trim().length != 9) {
                                        return 'Debe tener 9 dígitos';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              );

                              if (isVeryNarrow) {
                                return Column(
                                  children: [
                                    rucField,
                                    const SizedBox(height: 14),
                                    telField,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: rucField),
                                  const SizedBox(width: 12),
                                  Expanded(child: telField),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 14),

                          // 3. Dirección
                          Text(
                            'Dirección de la Tienda (Opcional)',
                            style: GoogleFonts.outfit(
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
                            decoration: const InputDecoration(
                              hintText: 'Ej. Av. Primavera 123, Surco',
                              prefixIcon: Icon(LucideIcons.mapPin, size: 18),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3.1 Selector de Régimen SUNAT
                          _buildRegimenSelector(isDark),
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
                              color: isDark
                                  ? AppTheme.textDarkSecondary
                                  : const Color(0xFF334155),
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
                              if (v == null || v.trim().isEmpty)
                                return 'El usuario es obligatorio';
                              if (v.trim().length < 3)
                                return 'Mínimo 3 caracteres';
                              final clean = v.trim().toLowerCase();
                              if (clean == 'admin' || clean == 'superadmin') {
                                return 'El usuario "$clean" está reservado. Usa ej. admin_mitienda';
                              }
                              if (v.trim().contains(' '))
                                return 'No debe contener espacios';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          Text(
                            'Correo Electrónico (Para recuperación de clave y avisos)',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTheme.textDarkSecondary
                                  : const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'Ej. micorreo@gmail.com (Opcional)',
                              prefixIcon: Icon(LucideIcons.mail, size: 18),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final clean = v.trim();
                              if (!clean.contains('@') ||
                                  !clean.contains('.')) {
                                return 'Ingresa un correo electrónico válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          Text(
                            'Contraseña Inicial (mínimo 8 caracteres) *',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTheme.textDarkSecondary
                                  : const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _adminPassCtrl,
                            obscureText: _obscurePass,
                            decoration: InputDecoration(
                              hintText: 'Contraseña segura',
                              prefixIcon: const Icon(
                                LucideIcons.lock,
                                size: 18,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePass
                                      ? LucideIcons.eyeOff
                                      : LucideIcons.eye,
                                  size: 18,
                                  color: isDark
                                      ? AppTheme.textDarkSecondary
                                      : const Color(0xFF334155),
                                ),
                                onPressed: () => setState(
                                  () => _obscurePass = !_obscurePass,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'La contraseña es obligatoria';
                              if (v.trim().length < 8)
                                return 'Mínimo 8 caracteres por seguridad';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // 5. Selector de Plan con Acceso a Modal Comparativo
                          _buildPlanSelectorSection(isDark),
                          const SizedBox(height: 24),

                          // Botón Crear Bodega
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedPlan == 'PRO'
                                    ? AppTheme.accentGreen
                                    : AppTheme.brandPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _selectedPlan == 'PRO'
                                              ? LucideIcons.gift
                                              : LucideIcons.rocket,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            _selectedPlan == 'PRO'
                                                ? 'CREAR BODEGA & EMPEZAR (1 MES GRATIS)'
                                                : 'CREAR BODEGA (PLAN BÁSICO)',
                                            style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: 0.3,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }

  Future<void> _abrirModalSeleccionarPlan() async {
    final nuevoPlan = await SelectorPlanRegistroModal.show(
      context,
      planActual: _selectedPlan,
    );
    if (nuevoPlan != null && mounted) {
      setState(() => _selectedPlan = nuevoPlan);
    }
  }

  Widget _buildPlanSelectorSection(bool isDark) {
    final isPro = _selectedPlan == 'PRO';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado con acción rápida
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Plan de Suscripción',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            InkWell(
              onTap: _abrirModalSeleccionarPlan,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  children: [
                    Text(
                      'Ver comparativa',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.brandPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      LucideIcons.arrowRight,
                      size: 14,
                      color: AppTheme.brandPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Por defecto tu tienda inicia con 30 días gratis en Plan PRO (sin tarjeta).',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            color: isDark
                ? AppTheme.textDarkSecondary
                : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 10),

        // Tarjeta interactiva del plan actual seleccionado
        InkWell(
          onTap: _abrirModalSeleccionarPlan,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isPro
                  ? LinearGradient(
                      colors: isDark
                          ? [
                              const Color(0xFF14532D).withValues(alpha: 0.35),
                              const Color(0xFF0F172A),
                            ]
                          : [const Color(0xFFF0FDF4), Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isPro
                  ? null
                  : (isDark
                        ? AppTheme.cardDarkElevated
                        : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isPro
                    ? AppTheme.accentGreen.withValues(alpha: 0.7)
                    : (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1)),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isPro ? AppTheme.accentGreen : Colors.black)
                      .withValues(alpha: isDark ? 0.2 : 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isPro
                                    ? AppTheme.accentGreen
                                    : const Color(0xFF64748B))
                                .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isPro
                            ? '🔥 1 MES GRATIS (30 DÍAS) • SELECCIONADO'
                            : '🏪 PLAN BÁSICO SELECCIONADO',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isPro
                              ? (isDark
                                    ? const Color(0xFF4ADE80)
                                    : const Color(0xFF166534))
                              : AppTheme.getAdaptiveMutedText(isDark),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Cambiar',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.brandPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          LucideIcons.slidersHorizontal,
                          size: 14,
                          color: AppTheme.brandPrimary,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      isPro ? 'S/ 0.00' : 'S/ 39.00',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPro
                          ? 'el 1er mes (luego S/ 79/mes)'
                          : '/ mes (o S/ 99 trimestral)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getAdaptiveMutedText(isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                Text(
                  isPro ? 'Plan Minimarket PRO' : 'Plan Bodega Básico',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isPro
                        ? (isDark
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFF15803D))
                        : (isDark ? Colors.white : AppTheme.brandDark),
                  ),
                ),
                const SizedBox(height: 4),

                Text(
                  isPro
                      ? 'Catálogo ilimitado de productos • Catálogo Web oficial para clientes • Marketing de Barrio y Dashboard BI'
                      : 'Hasta 150 productos en inventario • POS rápido en mostrador • Modo Offline y arqueos de caja',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF475569),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),

                // Botón llamativo para abrir el modal de comparativa
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _abrirModalSeleccionarPlan,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(
                        color: AppTheme.brandPrimary.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(LucideIcons.slidersHorizontal, size: 15),
                    label: Text(
                      'VER TODAS LAS DIFERENCIAS DE LOS PLANES',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
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
      ],
    );
  }

  String _obtenerTextoBannerGiro() {
    switch (_selectedGiro) {
      case 'POLLERIA':
        return 'Tu pollería se creará con categorías de Brasas, Guarniciones y Bebidas, lista para cobrar en mostrador y salón.';
      case 'CHIFA':
        return 'Tu chifa se creará con categorías de Arroces Chaufas, Wantanes, Aeropuertos y Salteados listos para venta rápida.';
      case 'FASTFOOD':
        return 'Tu fast food se creará con categorías de Broaster, Salchipapas, Burgers y Jugos con stock inicial en 0.';
      case 'BODEGA':
      default:
        return 'Tu bodega se creará con las 12 categorías estándar (Bebidas, Lácteos, Abarrotes, etc.) listas para usar.';
    }
  }

  Widget _buildGiroSelector(bool isDark) {
    final giros = [
      {
        'key': 'BODEGA',
        'label': 'Bodega & Minimarket',
        'icon': LucideIcons.shoppingBag,
        'desc': 'Abarrotes, bebidas y golosinas',
      },
      {
        'key': 'POLLERIA',
        'label': 'Pollería & Brasas',
        'icon': LucideIcons.flame,
        'desc': 'Pollos a la brasa, papas y mostritos',
      },
      {
        'key': 'CHIFA',
        'label': 'Chifa & Oriental',
        'icon': LucideIcons.utensils,
        'desc': 'Chaufas, aeropuertos y wantanes',
      },
      {
        'key': 'FASTFOOD',
        'label': 'Fast Food & Sanguchería',
        'icon': LucideIcons.sandwich,
        'desc': 'Broaster, salchipapas y jugos',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Giro de tu Negocio *',
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Catálogo Automático',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.brandPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 450;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: giros.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isNarrow ? 1 : 2,
                mainAxisExtent: 68,
                crossAxisSpacing: 10,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final g = giros[index];
                final isSelected = _selectedGiro == g['key'];
                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedGiro = g['key'] as String;
                      final currentName = _nombreBodegaCtrl.text.trim();
                      if (currentName.isEmpty ||
                          currentName == 'Minimarket San Martín' ||
                          currentName == 'Pollería & Brasas San Martín' ||
                          currentName == 'Chifa Dragón Dorado' ||
                          currentName == 'La Esquina Broaster & Burger') {
                        if (_selectedGiro == 'POLLERIA') {
                          _nombreBodegaCtrl.text =
                              'Pollería & Brasas San Martín';
                        } else if (_selectedGiro == 'CHIFA') {
                          _nombreBodegaCtrl.text = 'Chifa Dragón Dorado';
                        } else if (_selectedGiro == 'FASTFOOD') {
                          _nombreBodegaCtrl.text =
                              'La Esquina Broaster & Burger';
                        } else {
                          _nombreBodegaCtrl.text = 'Minimarket San Martín';
                        }
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.brandPrimary.withValues(
                              alpha: isDark ? 0.22 : 0.08,
                            )
                          : (isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.brandPrimary
                            : (isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0)),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.brandPrimary
                                : (isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            g['icon'] as IconData,
                            size: 18,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                      ? Colors.white70
                                      : const Color(0xFF475569)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                g['label'] as String,
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                g['desc'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            LucideIcons.checkCircle2,
                            size: 16,
                            color: AppTheme.brandPrimary,
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildRegimenSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Régimen Tributario SUNAT (Opcional)',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppTheme.textDarkSecondary
                : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _selectedRegimen = 'NUEVO_RUS'),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedRegimen == 'NUEVO_RUS'
                        ? AppTheme.brandPrimary.withValues(
                            alpha: isDark ? 0.22 : 0.08,
                          )
                        : (isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _selectedRegimen == 'NUEVO_RUS'
                          ? AppTheme.brandPrimary
                          : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                      width: _selectedRegimen == 'NUEVO_RUS' ? 1.6 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.receipt,
                        size: 15,
                        color: _selectedRegimen == 'NUEVO_RUS'
                            ? AppTheme.brandPrimary
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Nuevo RUS (Tickets)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _selectedRegimen == 'NUEVO_RUS'
                              ? AppTheme.brandPrimary
                              : (isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () =>
                    setState(() => _selectedRegimen = 'MYPE_TRIBUTARIO'),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedRegimen == 'MYPE_TRIBUTARIO'
                        ? AppTheme.brandPrimary.withValues(
                            alpha: isDark ? 0.22 : 0.08,
                          )
                        : (isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _selectedRegimen == 'MYPE_TRIBUTARIO'
                          ? AppTheme.brandPrimary
                          : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                      width: _selectedRegimen == 'MYPE_TRIBUTARIO' ? 1.6 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.landmark,
                        size: 15,
                        color: _selectedRegimen == 'MYPE_TRIBUTARIO'
                            ? AppTheme.brandPrimary
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'MYPE (Facturas)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _selectedRegimen == 'MYPE_TRIBUTARIO'
                              ? AppTheme.brandPrimary
                              : (isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
