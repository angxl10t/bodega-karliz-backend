import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../catalogo_imagenes_service.dart';
import '../theme.dart';
import 'product_image_widget.dart';

/// Modal para seleccionar o cambiar la foto de un producto.
/// Ofrece:
/// 1. Galería oficial de Packshots de estudio (vista frontal pura) para bodegas
/// 2. Entrada para URL personalizada de imagen
/// 3. Opción para quitar la imagen
class CatalogoFotoPickerModal extends StatefulWidget {
  final String? initialUrl;
  final String? productName;
  final String? categoryName;
  final ValueChanged<String?> onFotoSeleccionada;

  const CatalogoFotoPickerModal({
    super.key,
    this.initialUrl,
    this.productName,
    this.categoryName,
    required this.onFotoSeleccionada,
  });

  static Future<void> show({
    required BuildContext context,
    String? initialUrl,
    String? productName,
    String? categoryName,
    required ValueChanged<String?> onFotoSeleccionada,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CatalogoFotoPickerModal(
        initialUrl: initialUrl,
        productName: productName,
        categoryName: categoryName,
        onFotoSeleccionada: onFotoSeleccionada,
      ),
    );
  }

  @override
  State<CatalogoFotoPickerModal> createState() => _CatalogoFotoPickerModalState();
}

class _CatalogoFotoPickerModalState extends State<CatalogoFotoPickerModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _urlCtrl = TextEditingController();

  List<ProductoStudioFoto> _resultados = [];
  String? _selectedUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedUrl = widget.initialUrl;
    if (widget.initialUrl != null) {
      _urlCtrl.text = widget.initialUrl!;
    }

    // Si viene con un nombre de producto, precargar búsqueda
    final queryInicial = widget.productName?.trim() ?? '';
    if (queryInicial.isNotEmpty) {
      _searchCtrl.text = queryInicial;
      _resultados = CatalogoImagenesService.buscarEnCatalogo(queryInicial);
      if (_resultados.isEmpty) {
        _resultados = CatalogoImagenesService.getCatalogoMaestro();
      }
    } else {
      _resultados = CatalogoImagenesService.getCatalogoMaestro();
    }

    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _resultados = CatalogoImagenesService.buscarEnCatalogo(_searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _urlCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDarkElevated : Colors.white;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: isDark ? const Border(top: BorderSide(color: AppTheme.borderDarkElevated, width: 1.2)) : null,
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.borderDarkElevated : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceTintDark : AppTheme.surfaceTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.camera, color: AppTheme.brandPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Foto del Producto',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'Formato profesional de estudio (Vista Frontal 1:1)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: isDark ? Colors.white : AppTheme.brandPrimary,
              unselectedLabelColor: isDark ? AppTheme.textDarkSecondary : const Color(0xFF475569),
              labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
              indicator: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.sparkles, size: 15),
                      SizedBox(width: 6),
                      Text('Catálogo Oficial'),
                    ],
                  ),
                ),
                Tab(
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.link, size: 15),
                      SizedBox(width: 6),
                      Text('URL Propia'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Catálogo Oficial de Packshots
                _buildCatalogoTab(isDark, borderColor),

                // Tab 2: URL Personalizada
                _buildUrlTab(isDark, borderColor),
              ],
            ),
          ),

          // Footer Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                if (_selectedUrl != null && _selectedUrl!.isNotEmpty) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.alertRed,
                      side: const BorderSide(color: AppTheme.alertRed, width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    icon: const Icon(LucideIcons.trash2, size: 16),
                    label: Text(
                      'Quitar Foto',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    onPressed: () {
                      widget.onFotoSeleccionada(null);
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      widget.onFotoSeleccionada(_selectedUrl);
                      Navigator.pop(context);
                    },
                    child: Text(
                      _selectedUrl != null && _selectedUrl!.isNotEmpty
                          ? 'Aplicar Foto Seleccionada'
                          : 'Cerrar sin Cambios',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogoTab(bool isDark, Color borderColor) {
    return Column(
      children: [
        // Buscador
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: TextField(
            controller: _searchCtrl,
            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Buscar packshot (ej. Inca Kola, Gloria, Primor)...',
              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppTheme.brandPrimary),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              filled: true,
              fillColor: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.brandPrimary, width: 1.5),
              ),
            ),
          ),
        ),

        // Info Banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.brandPrimary.withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.brandPrimary.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.checkCircle2, size: 16, color: AppTheme.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fotos oficiales de vista frontal con fondo neutro de alta resolución.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Grid de productos de catálogo
        Expanded(
          child: _resultados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.imageOff, size: 40, color: AppTheme.textMuted),
                      const SizedBox(height: 8),
                      Text(
                        'No se encontraron fotos oficiales para esa búsqueda.',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Puedes ingresar una URL personalizada en la siguiente pestaña.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 130,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: _resultados.length,
                  itemBuilder: (context, index) {
                    final item = _resultados[index];
                    final isSelected = _selectedUrl == item.imagenUrl;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedUrl = item.imagenUrl;
                          _urlCtrl.text = item.imagenUrl;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131B2A) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.brandPrimary
                                : (isDark ? const Color(0xFF243044) : const Color(0xFFE2E8F0)),
                            width: isSelected ? 2.2 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.brandPrimary.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            // Imagen 1:1
                            Expanded(
                              child: Stack(
                                children: [
                                  Center(
                                    child: ProductImageWidget(
                                      imagenUrl: item.imagenUrl,
                                      categoria: item.categoria,
                                      size: 80,
                                      borderRadius: 12,
                                      isDark: isDark,
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: AppTheme.brandPrimary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          LucideIcons.check,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.nombre,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppTheme.textDark,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.marca,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.brandPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUrlTab(bool isDark, Color borderColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enlace directo de la fotografía',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pega una URL directa de imagen (PNG, JPG, WEBP). Se recomienda formato cuadrado y fondo blanco/neutro.',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _urlCtrl,
            style: GoogleFonts.plusJakartaSans(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'https://ejemplo.com/producto-frontal.png',
              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              prefixIcon: const Icon(LucideIcons.link2, size: 18, color: AppTheme.brandPrimary),
              suffixIcon: _urlCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.checkCircle, size: 18, color: AppTheme.accentGreen),
                      onPressed: () {
                        setState(() {
                          _selectedUrl = _urlCtrl.text.trim();
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _selectedUrl = val.trim().isNotEmpty ? val.trim() : null;
              });
            },
          ),
          const SizedBox(height: 20),

          // Preview
          Center(
            child: Column(
              children: [
                Text(
                  'Vista Previa (Formato Frontal 1:1)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                ProductImageWidget(
                  imagenUrl: _selectedUrl,
                  categoria: widget.categoryName,
                  size: 110,
                  borderRadius: 20,
                  isDark: isDark,
                  padding: 8,
                ),
                const SizedBox(height: 12),
                if (_selectedUrl != null && _selectedUrl!.isNotEmpty)
                  Text(
                    'Se mostrará centrada y adaptada en el Punto de Venta.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: AppTheme.accentGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
