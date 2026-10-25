import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/karliz_vectors.dart';

class KarlizNavItem {
  final Widget Function(Color color, double size)? iconWidgetBuilder;
  final IconData? icon;
  final String label;

  const KarlizNavItem({
    this.icon,
    this.iconWidgetBuilder,
    required this.label,
  });

  Widget buildIcon({required Color color, required double size}) {
    if (iconWidgetBuilder != null) {
      return iconWidgetBuilder!(color, size);
    }
    return Icon(icon, size: size, color: color);
  }
}

/// Barra de navegación flotante Pixel-Perfect con hendidura cóncava (Scooped Notch Cutout)
/// y botón circular elevado flotante que se desplaza orgánicamente entre secciones.
class KarlizPixelPerfectNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool isDark;

  const KarlizPixelPerfectNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isDark,
  });

  static final List<KarlizNavItem> items = [
    KarlizNavItem(
      iconWidgetBuilder: (c, s) => KarlizGridIcon(color: c, size: s),
      icon: LucideIcons.layoutGrid,
      label: 'Inicio',
    ),
    KarlizNavItem(
      iconWidgetBuilder: (c, s) => KarlizShoppingBagIcon(color: c, size: s),
      icon: LucideIcons.shoppingBag,
      label: 'POS',
    ),
    KarlizNavItem(
      iconWidgetBuilder: (c, s) => KarlizCashIcon(color: c, size: s),
      icon: LucideIcons.banknote,
      label: 'Caja',
    ),
    KarlizNavItem(
      iconWidgetBuilder: (c, s) => KarlizBoxIcon(color: c, size: s),
      icon: LucideIcons.boxes,
      label: 'Stock',
    ),
    KarlizNavItem(
      icon: LucideIcons.bookUser,
      label: 'Fiados',
    ),
  ];

  @override
  State<KarlizPixelPerfectNavBar> createState() => _KarlizPixelPerfectNavBarState();
}

class _KarlizPixelPerfectNavBarState extends State<KarlizPixelPerfectNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animPosition;
  double _currentTab = 0.0;
  double _targetTab = 0.0;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.selectedIndex.toDouble();
    _targetTab = _currentTab;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animPosition = Tween<double>(begin: _currentTab, end: _currentTab)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(KarlizPixelPerfectNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _targetTab = widget.selectedIndex.toDouble();
      _animPosition = Tween<double>(
        begin: _animPosition.value,
        end: _targetTab,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Paleta ejecutiva adaptada al modo claro y oscuro
    final barBg = isDark ? AppTheme.cardDark : Colors.white;
    final barBorder = isDark ? AppTheme.borderDark : const Color(0xFFE4E4E7);
    final activeColor = isDark ? AppTheme.brandLight : AppTheme.brandPrimary;
    final inactiveColor = isDark ? AppTheme.textDarkSecondary : const Color(0xFFA1A1AA);

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding > 0 ? bottomPadding : 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          const h = 84.0;
          const barTop = 18.0;
          const cornerRadius = 22.0;
          final pad = max(18.0, cornerRadius);
          final tabWidth = (w - 2 * pad) / KarlizPixelPerfectNavBar.items.length;
          final span = min(30.0, tabWidth * 0.44);

          return AnimatedBuilder(
            animation: _animPosition,
            builder: (context, child) {
              final activeTabVal = _animPosition.value;
              final cx = pad + (activeTabVal + 0.5) * tabWidth;

              return SizedBox(
                width: w,
                height: h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Superficie de la barra con la hendidura cóncava (Scoop Cutout)
                    CustomPaint(
                      size: Size(w, h),
                      painter: _ScoopedNavBarPainter(
                        cx: cx,
                        barTop: barTop,
                        notchDepth: 50.0,
                        span: span,
                        cornerRadius: cornerRadius,
                        backgroundColor: barBg,
                        borderColor: barBorder,
                        isDark: isDark,
                      ),
                    ),

                    // 2. Destinos interactivos e iconos
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: pad),
                        child: Row(
                          children: List.generate(
                            KarlizPixelPerfectNavBar.items.length,
                            (index) {
                              final item = KarlizPixelPerfectNavBar.items[index];
                              final isSelected = index == widget.selectedIndex;
                              final selectProgress = (1.0 - (activeTabVal - index).abs())
                                  .clamp(0.0, 1.0);

                              return Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    widget.onItemSelected(index);
                                  },
                                  child: Column(
                                    children: [
                                      const SizedBox(height: barTop + 6),

                                      // Icono inactivo en su posición de reposo
                                      SizedBox(
                                        height: 24,
                                        child: Center(
                                          child: Opacity(
                                            opacity: (1.0 - selectProgress).clamp(0.0, 1.0),
                                            child: item.buildIcon(
                                              size: 20,
                                              color: inactiveColor,
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 14),

                                      // Nombre de sección en la base inferior
                                      Text(
                                        item.label,
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? activeColor : inactiveColor,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // 3. Botón Circular Elevado Flotante (44px) dentro de la hendidura cóncava
                    Positioned(
                      left: cx - 22,
                      top: 0,
                      child: IgnorePointer(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isDark
                                ? const LinearGradient(
                                    colors: [AppTheme.brandPrimary, AppTheme.brandDark],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isDark ? null : Colors.white,
                            border: Border.all(
                              color: isDark ? AppTheme.brandLight : const Color(0xFFE4E4E7),
                              width: isDark ? 1.8 : 1.6,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? AppTheme.brandPrimary.withValues(alpha: 0.45)
                                    : Colors.black.withValues(alpha: 0.08),
                                blurRadius: isDark ? 14 : 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, anim) => FadeTransition(
                                opacity: anim,
                                child: ScaleTransition(scale: anim, child: child),
                              ),
                              child: KeyedSubtree(
                                key: ValueKey(widget.selectedIndex),
                                child: KarlizPixelPerfectNavBar.items[widget.selectedIndex].buildIcon(
                                  size: 21,
                                  color: isDark ? Colors.white : AppTheme.brandPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Dibuja la barra flotante con la hendidura cóncava (Scoop Notch Cutout)
class _ScoopedNavBarPainter extends CustomPainter {
  final double cx;
  final double barTop;
  final double notchDepth;
  final double span;
  final double cornerRadius;
  final Color backgroundColor;
  final Color borderColor;
  final bool isDark;

  _ScoopedNavBarPainter({
    required this.cx,
    required this.barTop,
    required this.notchDepth,
    required this.span,
    required this.cornerRadius,
    required this.backgroundColor,
    required this.borderColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path();
    // 1. Inicio en esquina inferior izquierda
    path.moveTo(cornerRadius, h);

    // 2. Borde inferior recto
    path.lineTo(w - cornerRadius, h);

    // 3. Esquina inferior derecha
    path.arcToPoint(
      Offset(w, h - cornerRadius),
      radius: Radius.circular(cornerRadius),
      clockwise: false,
    );

    // 4. Borde lateral derecho
    path.lineTo(w, barTop + cornerRadius);

    // 5. Esquina superior derecha
    path.arcToPoint(
      Offset(w - cornerRadius, barTop),
      radius: Radius.circular(cornerRadius),
      clockwise: false,
    );

    // 6. Borde superior hasta el inicio de la hendidura
    final xRight = cx + span;
    final xLeft = cx - span;

    path.lineTo(xRight, barTop);

    // 7. Hendidura Cóncava (Scoop / Cradle Cutout hacia abajo en el cuerpo de la barra)
    // De xRight bajando suavemente hasta el fondo del hueco en (cx, notchDepth)
    path.cubicTo(
      cx + span * 0.5, barTop,
      cx + span * 0.5, notchDepth,
      cx, notchDepth,
    );
    // De (cx, notchDepth) subiendo suavemente de vuelta a la línea plana en xLeft
    path.cubicTo(
      cx - span * 0.5, notchDepth,
      cx - span * 0.5, barTop,
      xLeft, barTop,
    );

    // 8. Borde superior desde xLeft hasta esquina superior izquierda
    path.lineTo(cornerRadius, barTop);

    // 9. Esquina superior izquierda
    path.arcToPoint(
      Offset(0, barTop + cornerRadius),
      radius: Radius.circular(cornerRadius),
      clockwise: false,
    );

    // 10. Borde lateral izquierdo
    path.lineTo(0, h - cornerRadius);

    // 11. Esquina inferior izquierda
    path.arcToPoint(
      Offset(cornerRadius, h),
      radius: Radius.circular(cornerRadius),
      clockwise: false,
    );

    path.close();

    // Sombra perimetral suave
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.35 : 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.save();
    canvas.translate(0, 4);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // Relleno de la superficie de la barra
    final fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Trazo de borde nítido
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ScoopedNavBarPainter oldDelegate) {
    return oldDelegate.cx != cx ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor;
  }
}
