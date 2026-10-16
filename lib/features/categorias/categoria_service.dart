import 'dart:convert';
import '../../core/api_client.dart';
import 'categoria_model.dart';

class CategoriaService {
  final ApiClient _apiClient = ApiClient();

  static List<Categoria>? _cachedCategorias;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(seconds: 60);

  static void invalidateCache() {
    _cachedCategorias = null;
    _cacheTimestamp = null;
  }

  Future<List<Categoria>> getCategorias({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCategorias != null && _cacheTimestamp != null) {
      if (DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
        return List<Categoria>.from(_cachedCategorias!);
      }
    }

    try {
      final response = await _apiClient.get('/categorias');
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        final cats = jsonList.map((json) => Categoria.fromJson(json)).toList();
        _cachedCategorias = cats;
        _cacheTimestamp = DateTime.now();
        return List<Categoria>.from(cats);
      }
      return _cachedCategorias != null ? List<Categoria>.from(_cachedCategorias!) : [];
    } catch (e) {
      return _cachedCategorias != null ? List<Categoria>.from(_cachedCategorias!) : [];
    }
  }

  Future<Categoria?> crearCategoria(String nombre, [String? descripcion]) async {
    try {
      final response = await _apiClient.post('/categorias', {
        'nombre': nombre,
        'descripcion': descripcion ?? 'Categoría de productos',
        'estado': true,
      });
      if (response.statusCode == 201 || response.statusCode == 200) {
        invalidateCache();
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return Categoria.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
