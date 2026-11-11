import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api_constants.dart';
import '../catalogo_imagenes_service.dart';
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
  final String? nombre;
  final String? codigoBarras;
  final String? categoria;
  final double size;
  final double borderRadius;
  final bool isDark;
  final double padding;
  final VoidCallback? onTap;

  const ProductImageWidget({
    super.key,
    required this.imagenUrl,
    this.nombre,
    this.codigoBarras,
    this.categoria,
    this.size = 46.0,
    this.borderRadius = 14.0,
    this.isDark = false,
    this.padding = 4.0,
    this.onTap,
  });

  static final Map<String, String> _resolvedUrlCache = {};

  String _resolverUrl(String rawUrl) {
    final cached = _resolvedUrlCache[rawUrl];
    if (cached != null) return cached;

    String clean = rawUrl.trim();

    // Optimizacion Unsplash: forzar tamano adecuado para miniaturas POS (10KB en vez de 1.8MB)
    if (clean.contains('images.unsplash.com')) {
      final uri = Uri.tryParse(clean);
      if (uri != null) {
        final qp = Map<String, String>.from(uri.queryParameters);
        qp['w'] = '260';
        qp['q'] = '80';
        qp['auto'] = 'format';
        clean = uri.replace(queryParameters: qp).toString();
      }
    }

    final isPackshot = clean.contains('packshots/');
    String resolved;

    if (kIsWeb) {
      // 1. Packshots estaticos alojados en la propia aplicacion web (Same-Origin)
      if (isPackshot) {
        if (clean.startsWith('http://') || clean.startsWith('https://')) {
          resolved = clean;
        } else {
          // Ruta relativa para servir desde el mismo origen
          resolved = clean.startsWith('/') ? clean.substring(1) : clean;
        }
      } else if (clean.contains('cajaya-pos.onrender.com') ||
          clean.contains('proxy-image')) {
        resolved = clean;
      } else if (clean.startsWith('http://') || clean.startsWith('https://')) {
        // URLs externas: canalizar por el proxy oficial con CORS abierto
        final encoded = Uri.encodeComponent(clean);
        resolved = '${ApiConstants.baseUrl}/productos/proxy-image?url=$encoded';
      } else {
        resolved = clean;
      }
    } else {
      // En dispositivos moviles (Android / iOS):
      if (isPackshot && !clean.startsWith('http')) {
        final path = clean.startsWith('/') ? clean.substring(1) : clean;
        resolved = 'https://cajaya-pos.onrender.com/$path';
      } else {
        resolved = clean;
      }
    }

    _resolvedUrlCache[rawUrl] = resolved;
    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    final catColor = CategoryHelper.getColor(categoria, isDark);
    final catIcon = CategoryHelper.getIcon(categoria);

    // 1. Determinar URL efectiva: si la URL viene vacia o generica, intentar auto-match inteligente por nombre/codigo
    String? rawUrl =
        (imagenUrl != null &&
            imagenUrl!.trim().isNotEmpty &&
            !imagenUrl!.contains('producto_generico'))
        ? imagenUrl!.trim()
        : null;

    bool fromCatalogSuggestion = false;
    if (rawUrl == null && (nombre != null || codigoBarras != null)) {
      final sug = CatalogoImagenesService.buscarSugerencia(
        codigoBarras: codigoBarras,
        nombre: nombre,
      );
      if (sug != null && sug.imagenUrl.isNotEmpty) {
        rawUrl = sug.imagenUrl;
        fromCatalogSuggestion = true;
      }
    }

    final hasUrl = rawUrl != null && rawUrl.isNotEmpty;

    Widget content;
    if (hasUrl) {
      final effectiveUrl = _resolverUrl(rawUrl);
      final cacheDim = (size * 2).round().clamp(80, 260);

      content = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDarkHighlight : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isDark
                ? AppTheme.borderDarkElevated
                : const Color(0xFFE2E8F0),
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
            gaplessPlayback: true,
            cacheWidth: cacheDim,
            cacheHeight: cacheDim,
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
              if (kDebugMode) {
                debugPrint(
                  'Error al cargar imagen de producto (): ',
                );
              }
              // Si fallo y no provino ya de la sugerencia oficial, intentar sugerencia
              if (!fromCatalogSuggestion && (nombre != null || codigoBarras != null)) {
                final fallbackSug = CatalogoImagenesService.buscarSugerencia(
                  codigoBarras: codigoBarras,
                  nombre: nombre,
                );
                if (fallbackSug != null && fallbackSug.imagenUrl != rawUrl) {
                  return Image.network(
                    _resolverUrl(fallbackSug.imagenUrl),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    cacheWidth: cacheDim,
                    cacheHeight: cacheDim,
                    errorBuilder: (_, _, _) =>
                        _buildCategoryFallback(catIcon, catColor),
                  );
                }
              }
              return _buildCategoryFallback(catIcon, catColor);
            },
          ),
        ),
      );
    } else {
      content = _buildCategoryFallback(catIcon, catColor);
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
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
        child: Icon(catIcon, size: size * 0.48, color: catColor),
      ),
    );
  }
}
