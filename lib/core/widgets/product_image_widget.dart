import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../api_constants.dart';
import '../category_helper.dart';
import '../theme.dart';

/// Widget unificado y estandarizado para fotografía de productos en CajaYa Cloud POS.
///
/// Características de diseño:
/// - Formato frontal de estudio profesional (packshot 1:1)
/// - Contenedor neutral con safe-margin (padding) para no cortar siluetas ni etiquetas
/// - Renderizado con BoxFit.contain para mantener proporciones fidedignas
/// - Manejo inteligente de carga y errores de red
/// - Proxy automático en Web para evitar al 100% bloqueos de CORS del navegador
/// - Fallback estético al squircle temático de categoría (CategoryHelper)
class ProductImageWidget extends StatelessWidget {
  final String? imagenUrl;
  final String? categoria;
  final double size;
  final double borderRadius;
  final bool isDark;
  final double padding;
  final VoidCallback? onTap;

  const ProductImageWidget({
    super.key,
    required this.imagenUrl,
    this.categoria,
    this.size = 46.0,
    this.borderRadius = 14.0,
    this.isDark = false,
    this.padding = 4.0,
    this.onTap,
  });

  String _resolverUrl(String rawUrl) {
    final clean = rawUrl.trim();
    if (kIsWeb) {
      // En Web, los navegadores imponen CORS estricto sobre CanvasKit (Skia WebGL).
      // Redirigir a través del proxy oficial de CajaYa API garantiza que la imagen
      // se sirva siempre con Access-Control-Allow-Origin: * y cabeceras de caché.
      if (!clean.contains('proxy-image')) {
        final encoded = Uri.encodeComponent(clean);
        return '${ApiConstants.baseUrl}/productos/proxy-image?url=$encoded';
      }
    }
    return clean;
  }

  @override
  Widget build(BuildContext context) {
    final catColor = CategoryHelper.getColor(categoria, isDark);
    final catIcon = CategoryHelper.getIcon(categoria);

    final hasUrl = imagenUrl != null && imagenUrl!.trim().isNotEmpty;

    Widget content;
    if (hasUrl) {
      final effectiveUrl = _resolverUrl(imagenUrl!);

      content = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        padding: EdgeInsets.all(padding),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius - 2),
          child: Image.network(
            effectiveUrl,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: SizedBox(
                  width: size * 0.35,
                  height: size * 0.35,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            (loadingProgress.expectedTotalBytes ?? 1)
                        : null,
                    color: AppTheme.brandPrimary.withValues(alpha: 0.6),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              debugPrint('⚠️ Error al cargar imagen de producto ($effectiveUrl): $error');
              // Si la URL falla o no tiene internet, recurre al squircle temático oficial
              return _buildCategoryFallback(catIcon, catColor);
            },
          ),
        ),
      );
    } else {
      content = _buildCategoryFallback(catIcon, catColor);
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }

  Widget _buildCategoryFallback(IconData catIcon, Color catColor) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            catColor.withValues(alpha: isDark ? 0.28 : 0.16),
            catColor.withValues(alpha: isDark ? 0.12 : 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: catColor.withValues(alpha: isDark ? 0.4 : 0.25),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Icon(
          catIcon,
          size: size * 0.48,
          color: catColor,
        ),
      ),
    );
  }
}
