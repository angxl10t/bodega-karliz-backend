import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ScreenType { mobile, tablet, desktop }

class ResponsiveLayout {
  static const double mobileBreakpoint = 650.0;
  static const double tabletBreakpoint = 1024.0;
  static const double physicalTabletShortestSide = 600.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  static bool isTabletOrLarger(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mobileBreakpoint;

  /// Detecta si el dispositivo es físicamente una tablet usando el estándar de Android / iOS (sw600dp)
  static bool isPhysicalTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= physicalTabletShortestSide;

  /// Verifica si la pantalla está en orientación horizontal
  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  /// Configura la orientación óptima según el tipo de hardware:
  /// - Tablets: Orientación horizontal (Landscape) de mostrador POS.
  /// - Smartphones: Orientación vertical tradicional (Portrait).
  static Future<void> autoConfigureOrientation(BuildContext context) async {
    try {
      final isTabletDevice = isPhysicalTablet(context);
      if (isTabletDevice) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    } catch (_) {
      // No-op en entornos donde SystemChrome no aplique
    }
  }

  /// Fuerza el modo horizontal para tablet de mostrador
  static Future<void> lockLandscape() async {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (_) {}
  }

  /// Desbloquea todas las orientaciones si el usuario desea rotar libremente
  static Future<void> unlockOrientation() async {
    try {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    } catch (_) {}
  }

  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= tabletBreakpoint) return ScreenType.desktop;
    if (width >= mobileBreakpoint) return ScreenType.tablet;
    return ScreenType.mobile;
  }
}

/// Widget constructor adaptativo basado en LayoutBuilder
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints) mobile;
  final Widget Function(BuildContext context, BoxConstraints constraints)? tablet;
  final Widget Function(BuildContext context, BoxConstraints constraints)? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveLayout.tabletBreakpoint && desktop != null) {
          return desktop!(context, constraints);
        }
        if (constraints.maxWidth >= ResponsiveLayout.mobileBreakpoint && tablet != null) {
          return tablet!(context, constraints);
        }
        return mobile(context, constraints);
      },
    );
  }
}
