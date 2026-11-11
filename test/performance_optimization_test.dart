import 'dart:async';
import 'dart:convert';

import 'package:bodega_mobile/core/api_client.dart';
import 'package:bodega_mobile/core/catalogo_imagenes_service.dart';
import 'package:bodega_mobile/core/categoria_suggester_service.dart';
import 'package:bodega_mobile/core/offline/offline_catalog_service.dart';
import 'package:bodega_mobile/core/secure_storage_service.dart';
import 'package:bodega_mobile/features/auth/auth_service.dart';
import 'package:bodega_mobile/features/catalogo/pedido_web_service.dart';
import 'package:bodega_mobile/features/categorias/categoria_service.dart';
import 'package:bodega_mobile/features/clientes/cliente_service.dart';
import 'package:bodega_mobile/features/home/bodega_service.dart';
import 'package:bodega_mobile/features/clientes/garantia_botella_service.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/productos/producto_service.dart';
import 'package:bodega_mobile/features/proveedores/proveedor_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  group('Coalesced Services & Multi-Tenant Session Cache Isolation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AuthService.clearAllSessionState();
      PedidoWebService.setApiClientForTest(ApiClient());
    });

    tearDown(() {
      AuthService.clearAllSessionState();
      PedidoWebService.setApiClientForTest(ApiClient());
    });

    test(
      'CategoriaService coalesce llamadas concurrentes en una sola petición HTTP y limpia cache con epoch',
      () async {
        int calls = 0;
        final started = Completer<void>();
        final release = Completer<void>();

        final mockHttp = MockClient((request) async {
          calls++;
          if (!started.isCompleted) started.complete();
          await release.future;
          return http.Response(
            jsonEncode([
              {'idCategoria': 1, 'nombre': 'Bebidas', 'estado': true},
              {'idCategoria': 2, 'nombre': 'Lácteos', 'estado': true},
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });

        final service = CategoriaService(apiClient: ApiClient(client: mockHttp));
        final futures = List.generate(5, (_) => service.getCategorias());

        await started.future;
        expect(calls, equals(1));

        release.complete();
        final res = await Future.wait(futures);
        expect(calls, equals(1));
        expect(res, hasLength(5));
        for (final list in res) {
          expect(list, hasLength(2));
        }

        // Segunda lectura dentro del TTL reutiliza caché
        await service.getCategorias();
        expect(calls, equals(1));

        // Invalidación fuerza recarga
        CategoriaService.invalidateCache();
        await service.getCategorias();
        expect(calls, equals(2));
      },
    );

    test(
      'ProveedorService coalesce llamadas concurrentes en una sola petición HTTP',
      () async {
        int calls = 0;
        final started = Completer<void>();
        final release = Completer<void>();

        final mockHttp = MockClient((request) async {
          calls++;
          if (!started.isCompleted) started.complete();
          await release.future;
          return http.Response(
            jsonEncode([
              {
                'idProveedor': 10,
                'ruc': '20100047218',
                'razonSocial': 'Alicorp S.A.A.',
                'estado': true,
              },
            ]),
            200,
          );
        });

        final service = ProveedorService(apiClient: ApiClient(client: mockHttp));
        final futures = List.generate(4, (_) => service.getProveedores());

        await started.future;
        expect(calls, equals(1));

        release.complete();
        final res = await Future.wait(futures);
        expect(calls, equals(1));
        expect(res, hasLength(4));
        expect(res.first.first.razonSocial, equals('Alicorp S.A.A.'));
      },
    );

    test(
      'GarantiaBotellaService coalesce consultas sin filtro y respeta invalidación',
      () async {
        int calls = 0;
        final started = Completer<void>();
        final release = Completer<void>();

        final mockHttp = MockClient((request) async {
          calls++;
          if (!started.isCompleted) started.complete();
          await release.future;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode([
                {
                  'idGarantia': 7,
                  'nombrePersona': 'Carlos Ñahui',
                  'cantidadBotellas': 2,
                  'montoGarantia': 4.0,
                  'estado': 'PENDIENTE',
                },
              ]),
            ),
            200,
          );
        });

        final service = GarantiaBotellaService(
          apiClient: ApiClient(client: mockHttp),
        );
        final futures = List.generate(4, (_) => service.getGarantias());

        await started.future;
        expect(calls, equals(1));

        release.complete();
        final res = await Future.wait(futures);
        expect(calls, equals(1));
        expect(res, hasLength(4));
        expect(res.first.first.nombrePersona, equals('Carlos Ñahui'));
      },
    );

    test(
      'SecureStorageService.clearAuth resetea todos los cachés multi-tenant y rol en memoria',
      () async {
        int catCalls = 0;
        int provCalls = 0;
        int garCalls = 0;
        int prodCalls = 0;

        final catMock = MockClient((_) async {
          catCalls++;
          return http.Response(
            jsonEncode([
              {
                'idCategoria': catCalls,
                'nombre': 'Cat $catCalls',
                'estado': true,
              },
            ]),
            200,
          );
        });
        final provMock = MockClient((_) async {
          provCalls++;
          return http.Response(
            jsonEncode([
              {
                'idProveedor': provCalls,
                'ruc': '20123456789',
                'razonSocial': 'Prov $provCalls',
                'estado': true,
              },
            ]),
            200,
          );
        });
        final garMock = MockClient((_) async {
          garCalls++;
          return http.Response(
            jsonEncode([
              {
                'idGarantia': garCalls,
                'nombrePersona': 'Gar $garCalls',
                'cantidadBotellas': 1,
                'montoGarantia': 2.0,
                'estado': 'PENDIENTE',
              },
            ]),
            200,
          );
        });
        final prodMock = MockClient((_) async {
          prodCalls++;
          return http.Response(
            jsonEncode([
              {
                'idProducto': prodCalls,
                'idCategoria': 1,
                'codigo': 'P-$prodCalls',
                'nombre': 'Prod $prodCalls',
                'precioVenta': 5.0,
                'stockActual': 10.0,
              },
            ]),
            200,
          );
        });

        final catSvc = CategoriaService(apiClient: ApiClient(client: catMock));
        final provSvc = ProveedorService(
          apiClient: ApiClient(client: provMock),
        );
        final garSvc = GarantiaBotellaService(
          apiClient: ApiClient(client: garMock),
        );
        final prodSvc = ProductoService(apiClient: ApiClient(client: prodMock));
        // Garantiza que AuthService registre su callback de sesión en este test
        AuthService();
        AuthService.setCachedRol('ADMIN');

        await catSvc.getCategorias();
        await provSvc.getProveedores();
        await garSvc.getGarantias();
        await prodSvc.getProductos();

        expect((await catSvc.getCategorias()).first.nombre, equals('Cat 1'));
        expect(catCalls, equals(1));
        expect(provCalls, equals(1));
        expect(garCalls, equals(1));
        expect(prodCalls, equals(1));

        await SecureStorageService.clearAuth();

        expect(AuthService.cachedUserRole, equals('CAJERO'));
        expect((await catSvc.getCategorias()).first.nombre, equals('Cat 2'));
        expect(
          (await provSvc.getProveedores()).first.razonSocial,
          equals('Prov 2'),
        );
        expect(
          (await garSvc.getGarantias()).first.nombrePersona,
          equals('Gar 2'),
        );
        expect((await prodSvc.getProductos()).first.nombre, equals('Prod 2'));
        expect(catCalls, equals(2));
        expect(provCalls, equals(2));
        expect(garCalls, equals(2));
        expect(prodCalls, equals(2));
      },
    );

    test(
      'PedidoWebService decodifica UTF-8 correctamente y resetSession limpia estado y pedidos',
      () async {
        final mockHttp = MockClient((request) async {
          if (request.url.path.contains('/revision')) {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'hayCambio': true,
                  'revision': 5,
                  'conteoPendientes': 1,
                }),
              ),
              200,
            );
          }
          return http.Response.bytes(
            utf8.encode(
              jsonEncode([
                {
                  'idPedidoWeb': 99,
                  'codigoPedido': '#W-1099',
                  'nombreCliente': 'María Peña Ñahui',
                  'notas': 'Con piña y ají',
                  'total': 15.5,
                  'estado': 'PENDIENTE',
                  'items': [],
                },
              ]),
            ),
            200,
          );
        });

        PedidoWebService.setApiClientForTest(ApiClient(client: mockHttp));
        await PedidoWebService.sincronizarConNube();

        expect(PedidoWebService.pedidos, hasLength(1));
        expect(
          PedidoWebService.pedidos.first.nombreCliente,
          equals('María Peña Ñahui'),
        );
        expect(PedidoWebService.pedidos.first.notas, equals('Con piña y ají'));
        expect(PedidoWebService.pedidosPendientesCountNotifier.value, equals(1));

        await SecureStorageService.clearAuth();

        expect(PedidoWebService.pedidos, isEmpty);
        expect(PedidoWebService.pedidosPendientesCountNotifier.value, equals(0));
        expect(PedidoWebService.estaSincronizandoNotifier.value, isFalse);
      },
    );
  });

  group('BodegaService, OfflineBatch & SecureStorage JWT Cache Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      SecureStorageService.clearMemoryCache();
      BodegaService.clearCache();
      OfflineCatalogService().clearMemoryCache();
    });

    test(
      'BodegaService.obtenerMiBodega coalesce concurrentes, respeta TTL y limpia con clearCache',
      () async {
        int calls = 0;
        final started = Completer<void>();
        final gate = Completer<void>();

        final mockHttp = MockClient((request) async {
          calls++;
          if (!started.isCompleted) started.complete();
          await gate.future;
          return http.Response(
            jsonEncode({
              'idBodega': 10,
              'nombreComercial': 'Bodega Call $calls',
              'colorPrimario': '#2563EB',
              'plan': 'PRO',
              'estado': true,
              'regimenTributario': 'NUEVO_RUS',
            }),
            200,
          );
        });

        final service = BodegaService(client: ApiClient(client: mockHttp));
        final futures = List.generate(4, (_) => service.obtenerMiBodega());

        await started.future;
        expect(calls, equals(1));

        gate.complete();
        final infos = await Future.wait(futures);
        expect(calls, equals(1));
        for (final info in infos) {
          expect(info?.nombreComercial, equals('Bodega Call 1'));
        }

        final cached = await service.obtenerMiBodega();
        expect(cached?.nombreComercial, equals('Bodega Call 1'));
        expect(calls, equals(1));

        BodegaService.clearCache();
        final refreshed = await service.obtenerMiBodega();
        expect(refreshed?.nombreComercial, equals('Bodega Call 2'));
        expect(calls, equals(2));
      },
    );

    test(
      'OfflineCatalogService.deductBatchLocally descuenta varios SKUs en una pasada y emite 1 revision',
      () async {
        final catalog = OfflineCatalogService();
        await catalog.saveCatalog([
          Producto(
            idProducto: 101,
            codigo: 'P101',
            nombre: 'Arroz 1kg',
            precioVenta: 4.5,
            stockActual: 10.0,
          ),
          Producto(
            idProducto: 102,
            codigo: 'P102',
            nombre: 'Azucar 1kg',
            precioVenta: 4.0,
            stockActual: 8.0,
          ),
        ], idBodega: '10');

        int revisionBumps = 0;
        void onRev() => revisionBumps++;
        ProductoService.productosRevision.addListener(onRev);
        try {
          await catalog.deductBatchLocally(
            {101: 3.0, 102: 2.5},
            idBodega: '10',
          );
        } finally {
          ProductoService.productosRevision.removeListener(onRev);
        }

        expect(revisionBumps, equals(1));
        final updated = await catalog.getCachedCatalog(idBodega: '10');
        expect(
          updated.firstWhere((p) => p.idProducto == 101).stockActual,
          closeTo(7.0, 0.001),
        );
        expect(
          updated.firstWhere((p) => p.idProducto == 102).stockActual,
          closeTo(5.5, 0.001),
        );
      },
    );

    test(
      'SecureStorageService cachea jwt_token en memoria y lo invalida en clearAuth',
      () async {
        await SecureStorageService.write('jwt_token', 'jwt-en-memoria');
        // Mutar storage mock subyacente: read debe devolver el valor cacheado en memoria
        FlutterSecureStorage.setMockInitialValues({'jwt_token': 'jwt-disco-viejo'});
        expect(await SecureStorageService.read('jwt_token'), equals('jwt-en-memoria'));

        await SecureStorageService.clearAuth();
        FlutterSecureStorage.setMockInitialValues({'jwt_token': 'jwt-nuevo'});
        expect(await SecureStorageService.read('jwt_token'), equals('jwt-nuevo'));
      },
    );
  });
}
