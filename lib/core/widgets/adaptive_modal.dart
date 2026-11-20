import 'package:flutter/material.dart';

import '../responsive_layout.dart';
import '../theme.dart';

/// Sistema de Modales Adaptativos Ergonómicos para CajaYa Cloud POS.
///
/// En pantallas móviles (< 650dp):
/// Se despliega como un Bottom Sheet ergonómico para uso con el pulgar,
/// anclado abajo, con esquinas superiores redondeadas y manija superior de arrastre.
///
/// En pantallas Desktop / Tablet / Web (>= 650dp):
/// Se presenta como un Modal Dialog flotante centrado, con ancho ergonómico
/// acotado (520–640dp), bordes redondeados completos (24dp), elevación sutil,
/// borde de contraste fintech y SIN manijas móviles de arrastre ("silueta de teléfono"),
/// optimizado para uso con ratón y teclado.
class AdaptiveModal {
  AdaptiveModal._();

  /// Despliega un modal adaptativo respondiendo al factor de forma del dispositivo.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
    double maxWidth = 560,
    bool useRootNavigator = false,
    RouteSettings? routeSettings,
  }) {
    final bool isWide = ResponsiveLayout.isTabletOrLarger(context);

    if (isWide) {
      return showDialog<T>(
        context: context,
        useRootNavigator: useRootNavigator,
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.55),
        routeSettings: routeSettings,
        builder: (dialogCtx) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
              side: BorderSide.none,
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Center(
                widthFactor: 1.0,
                heightFactor: 1.0,
                child: builder(dialogCtx),
              ),
            ),
          );
        },
      );
    } else {
      return showModalBottomSheet<T>(
        context: context,
        useRootNavigator: useRootNavigator,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide.none,
        ),
        clipBehavior: Clip.none,
        barrierColor: barrierColor,
        routeSettings: routeSettings,
        builder: builder,
      );
    }
  }
}

/// Tirador de arrastre / Drag handle adaptativo.
///
/// Solo se renderiza en pantallas móviles (< 650dp). En pantallas de escritorio,
/// laptops o tablets se oculta por completo ([SizedBox.shrink]) para evitar
/// siluetas visuales de teléfono en aplicaciones de escritorio / web.
class AdaptiveDragHandle extends StatelessWidget {
  final Color? color;
  final double width;
  final double height;
  final EdgeInsetsGeometry margin;

  const AdaptiveDragHandle({
    super.key,
    this.color,
    this.width = 44,
    this.height = 4.5,
    this.margin = const EdgeInsets.only(top: 2, bottom: 16),
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveLayout.isTabletOrLarger(context)) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        margin: margin,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color:
              color ??
              (isDark ? AppTheme.borderDarkElevated : const Color(0xFFCBD5E1)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

/// Envoltorio o contenedor estructural unificado para modales.
///
/// Gestiona bordes, sombras, alineación y anchos máximos tanto para
/// la vista de escritorio (diálogo flotante centrado) como para móvil (bottom sheet).
class AdaptiveModalFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double maxHeightFactor;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final bool showDragHandle;

  const AdaptiveModalFrame({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.maxHeightFactor = 0.90,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
    this.showDragHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = ResponsiveLayout.isTabletOrLarger(context);
    final cardBg =
        backgroundColor ?? (isDark ? AppTheme.cardDarkElevated : Colors.white);

    final resolvedRadius =
        borderRadius ??
        (isWide
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(top: Radius.circular(28)));

    return Align(
      alignment: isWide ? Alignment.center : Alignment.bottomCenter,
      heightFactor: isWide ? 1.0 : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: resolvedRadius,
              border: isDark
                  ? Border.all(color: AppTheme.borderDarkElevated, width: 1.2)
                  : Border.all(
                      color: isWide ? AppTheme.borderLight : Colors.transparent,
                      width: 1.0,
                    ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
                  blurRadius: isWide ? 32 : 24,
                  offset: isWide ? const Offset(0, 10) : const Offset(0, -4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: resolvedRadius,
              child: SafeArea(
                top: isWide,
                bottom: !isWide,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showDragHandle) const AdaptiveDragHandle(),
                    Flexible(
                      child: padding != null
                          ? Padding(padding: padding!, child: child)
                          : child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
