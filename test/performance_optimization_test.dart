import 'dart:async';
import 'dart:convert';

import 'package:bodega_mobile/core/api_client.dart';
import 'package:bodega_mobile/core/catalogo_imagenes_service.dart';
import 'package:bodega_mobile/core/categoria_suggester_service.dart';
import 'package:bodega_mobile/core/offline/offline_catalog_service.dart';
import 'package:bodega_mobile/features/clientes/cliente_service.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/productos/producto_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Coalesced Service Requests (Single-Flight)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      OfflineCatalogService().clearMemoryCache();
      ProductoService.invalidateCache();
      ClienteService.invalidateCache();
    });

    test(
      'ProductoService coalesce múltiples llamadas concurrentes en una sola petición HTTP y retorna copias aisladas',
      () async {
        int networkCalls = 0;
        final requestStarted = Completer<void>();
        final completer = Completer<void>();

        final mockHttp = MockClient((request) async {
          networkCalls++;
          if (!requestStarted.isCompleted) {
            requestStarted.complete();
          }
          await completer.future;
          return http.Response(
            jsonEncode([
              {
                'idProducto': 1,
                'idCategoria': 2,
                'codigo': 'BEB-001',
                'nombre': 'Inca Kola 500ml',
                'precioVenta': 3.5,
                'stockActual': 24.0,
              },
              {
                'idProducto': 2,
                'idCategoria': 2,
                'codigo': 'BEB-002',
                'nombre': 'Coca Cola 500ml',
                'precioVenta': 3.5,
                'stockActual': 18.0,
              },
            ]),
            200,
          );
        });

        final service = ProductoService(apiClient: ApiClient(client: mockHttp));
        final futures = List.generate(5, (_) => service.getProductos());

        await requestStarted.future;
        expect(networkCalls, equals(1));

        completer.complete();
        final results = await Future.wait(futures);

        expect(networkCalls, equals(1));
        expect(results, hasLength(5));
        for (final list in results) {
          expect(list, hasLength(2));
        }

        // Mutar una copia retornada no debe alterar la caché ni otras copias
        results.first.clear();
        final fromCache = await service.getProductos();
        expect(fromCache, hasLength(2));
        expect(networkCalls, equals(1));
      },
    );

    test(
      'ProductoService invalidateCache evita que una respuesta obsoleta en vuelo contamine la caché',
      () async {
        int networkCalls = 0;
        final firstStarted = Completer<void>();
        final firstCompleter = Completer<http.Response>();

        final mockHttp = MockClient((request) async {
          networkCalls++;
          if (networkCalls == 1) {
            if (!firstStarted.isCompleted) {
              firstStarted.complete();
            }
            return firstCompleter.future;
          }
          return http.Response(
            jsonEncode([
              {
                'idProducto': 99,
                'idCategoria': 1,
                'codigo': 'NEW-99',
                'nombre': 'Producto Actualizado',
                'precioVenta': 10.0,
                'stockActual': 5.0,
              },
            ]),
            200,
          );
        });

        final service = ProductoService(apiClient: ApiClient(client: mockHttp));
        final staleFuture = service.getProductos();
        await firstStarted.future;

        // Mientras la primera petición sigue en vuelo, invalidamos por escritura local
        ProductoService.invalidateCache();

        final freshList = await service.getProductos();
        expect(freshList.single.codigo, equals('NEW-99'));

        // Completar la petición antigua no debe sobreescribir el catálogo nuevo
        firstCompleter.complete(
          http.Response(
            jsonEncode([
              {
                'idProducto': 1,
                'idCategoria': 1,
                'codigo': 'OLD-01',
                'nombre': 'Producto Obsoleto',
                'precioVenta': 2.0,
                'stockActual': 1.0,
              },
            ]),
            200,
          ),
        );
        await staleFuture;

        final cachedAfter = await service.getProductos();
        expect(cachedAfter.single.codigo, equals('NEW-99'));
      },
    );

    test(
      'ClienteService coalesce llamadas concurrentes sin filtro y ejecuta búsquedas filtradas independientemente',
      () async {
        int unfilteredCalls = 0;
        int filteredCalls = 0;
        final unfilteredStarted = Completer<void>();
        final filteredDone = Completer<void>();
        final gate = Completer<void>();

        final mockHttp = MockClient((request) async {
          if (request.url.query.isNotEmpty) {
            filteredCalls++;
            if (!filteredDone.isCompleted) {
              filteredDone.complete();
            }
            return http.Response(
              jsonEncode([
                {
                  'idCliente': 20,
                  'nombreCompleto': 'Carlos Filtro',
                  'saldoDeudor': 12.0,
                },
              ]),
              200,
            );
          }
          unfilteredCalls++;
          if (!unfilteredStarted.isCompleted) {
            unfilteredStarted.complete();
          }
          await gate.future;
          return http.Response(
            jsonEncode([
              {
                'idCliente': 10,
                'nombreCompleto': 'Ana Cliente',
                'saldoDeudor': 0.0,
              },
            ]),
            200,
          );
        });

        final service = ClienteService(apiClient: ApiClient(client: mockHttp));
        final futures = List.generate(4, (_) => service.getClientes());
        final filteredFuture = service.getClientes(query: 'Carlos');

        await Future.wait([unfilteredStarted.future, filteredDone.future]);
        expect(unfilteredCalls, equals(1));
        expect(filteredCalls, equals(1));

        gate.complete();
        final results = await Future.wait(futures);
        final filteredResult = await filteredFuture;

        expect(unfilteredCalls, equals(1));
        expect(results, hasLength(4));
        expect(results.first.single.nombreCompleto, equals('Ana Cliente'));
        expect(filteredResult.single.nombreCompleto, equals('Carlos Filtro'));
      },
    );
  });

  group('OfflineCatalogService Fingerprint Deduplication', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      OfflineCatalogService().clearMemoryCache();
    });

    test(
      'saveCatalog omite escrituras redundantes en SharedPreferences si el contenido no cambió y persiste cuando cambia',
      () async {
        final service = OfflineCatalogService();
        final catalogA = [
          Producto(
            idProducto: 1,
            idCategoria: 2,
            nombreCategoria: 'Bebidas',
            codigo: 'BEB-01',
            nombre: 'Agua San Luis 625ml',
            precioVenta: 2.0,
            stockActual: 30.0,
          ),
        ];

        await service.saveCatalog(catalogA, idBodega: 'tenant_1');
        final prefs = await SharedPreferences.getInstance();
        final tsFirst = prefs.getString('cajaya_offline_catalog_ts_tenant_1');
        expect(tsFirst, isNotNull);

        await Future<void>.delayed(const Duration(milliseconds: 15));

        // Guardar el mismo contenido exacto debe omitir re-escritura en disco
        await service.saveCatalog([
          Producto(
            idProducto: 1,
            idCategoria: 2,
            nombreCategoria: 'Bebidas',
            codigo: 'BEB-01',
            nombre: 'Agua San Luis 625ml',
            precioVenta: 2.0,
            stockActual: 30.0,
          ),
        ], idBodega: 'tenant_1');

        final tsSecond = prefs.getString('cajaya_offline_catalog_ts_tenant_1');
        expect(tsSecond, equals(tsFirst));

        await Future<void>.delayed(const Duration(milliseconds: 15));

        // Cualquier cambio de precio/stock sí debe persistirse
        await service.saveCatalog([
          catalogA.first.copyWith(stockActual: 25.0),
        ], idBodega: 'tenant_1');

        final tsThird = prefs.getString('cajaya_offline_catalog_ts_tenant_1');
        expect(tsThird, isNot(equals(tsFirst)));
      },
    );
  });

  group('Optimización de Normalización, Cache y Sugerencias', () {
    test(
      'CategoriaSuggesterService.normalizar y detectarCanonica mantienen precisión y determinismo tras múltiples llamadas cacheadas',
      () {
        expect(
          CategoriaSuggesterService.normalizar('  Árbol Ñoño Élite Óptimo Útil  '),
          equals('arbol nono elite optimo util'),
        );

        for (int i = 0; i < 3; i++) {
          expect(
            CategoriaSuggesterService.detectarCanonica(
              nombre: 'Filete de Atún Primor 170g',
            ),
            equals(CategoriaCanonica.abarrotesDespensa),
          );
          expect(
            CategoriaSuggesterService.detectarCanonica(
              nombre: 'Papas Lays Clásicas 140g',
            ),
            equals(CategoriaCanonica.snacksPiqueos),
          );
          expect(
            CategoriaSuggesterService.detectarCanonica(
              nombre: 'Helado Peziduri D\'Onofrio 900ml',
            ),
            equals(CategoriaCanonica.heladosCongelados),
          );
        }
      },
    );

    test(
      'CatalogoImagenesService mantiene diferenciación de tamaños y búsqueda en catálogo con caché acotada',
      () {
        CatalogoImagenesService.limpiarCache();
        final small = CatalogoImagenesService.buscarSugerencia(
          nombre: 'Coca Cola 500ml',
        );
        final large = CatalogoImagenesService.buscarSugerencia(
          nombre: 'Coca Cola 3 Litros',
        );

        expect(small, isNotNull);
        expect(large, isNotNull);
        expect(small!.imagenUrl, isNot(equals(large!.imagenUrl)));

        final cachedRepeat = CatalogoImagenesService.buscarSugerencia(
          nombre: 'Coca Cola 500ml',
        );
        expect(cachedRepeat?.imagenUrl, equals(small.imagenUrl));
      },
    );
  });
}
