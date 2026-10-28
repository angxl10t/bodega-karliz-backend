import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/core/categoria_suggester_service.dart';
import 'package:bodega_mobile/features/categorias/categoria_model.dart';

void main() {
  group('CategoriaSuggesterService - Detección Canónica Inteligente', () {
    test('Detecta Bebidas & Gaseosas peruanas correctamente', () {
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Inka Kola 500ml no retornable'),
        CategoriaCanonica.bebidasGaseosas,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Coca Cola Sin Azúcar 1.5L'),
        CategoriaCanonica.bebidasGaseosas,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Agua Cielo sin gas 625ml'),
        CategoriaCanonica.bebidasGaseosas,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Agua San Mateo con gas 600ml'),
        CategoriaCanonica.bebidasGaseosas,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Volt Blue Maca energizante 300ml'),
        CategoriaCanonica.bebidasGaseosas,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Sporade Maracuyá 500ml'),
        CategoriaCanonica.bebidasGaseosas,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Frugos del Valle Durazno 1L'),
        CategoriaCanonica.bebidasGaseosas,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Refresco Zuko Chicha Morada sobre'),
        CategoriaCanonica.bebidasGaseosas,
      );
    });

    test('Detecta Cervezas & Licores peruanos correctamente', () {
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Cerveza Pilsen Callao 310ml six pack'),
        CategoriaCanonica.licoresCervezas,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Cusqueña Trigo botella 330ml'),
        CategoriaCanonica.licoresCervezas,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Cerveza Cristal lata 355ml'),
        CategoriaCanonica.licoresCervezas,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Vino Santiago Queirolo Borgoña 750ml'),
        CategoriaCanonica.licoresCervezas,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Pisco Portón Acholado Mosto Verde'),
        CategoriaCanonica.licoresCervezas,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Ron Cartavio Black 750ml'),
        CategoriaCanonica.licoresCervezas,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Whisky Johnnie Walker Red Label 750ml'),
        CategoriaCanonica.licoresCervezas,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Vodka Russkaya 750ml'),
        CategoriaCanonica.licoresCervezas,
      );
    });

    test('Detecta Lácteos y Huevos con desambiguación de Gloria y San Fernando', () {
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Leche Gloria Evaporada Azul 400g'),
        CategoriaCanonica.lacteosHuevos,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Leche Gloria Sin Lactosa 400g'),
        CategoriaCanonica.lacteosHuevos,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Yogurt Danlac Fresa 1L'),
        CategoriaCanonica.lacteosHuevos,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Margarina Manty 200g'),
        CategoriaCanonica.lacteosHuevos,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Huevos Pardos cubeta x30'),
        CategoriaCanonica.lacteosHuevos,
      );
    });

    test('Desambiguación: Atún Gloria es Abarrotes, no Lácteos', () {
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Atún Gloria Grated en agua y sal 170g'),
        CategoriaCanonica.abarrotesDespensa,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Filete de Atún Campomar en aceite'),
        CategoriaCanonica.abarrotesDespensa,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Lomito de Atún Fanny 170g'),
        CategoriaCanonica.abarrotesDespensa,
      );
    });

    test('Detecta Abarrotes y Despensa correctamente', () {
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Arroz Costeño Extra 1kg'),
        CategoriaCanonica.abarrotesDespensa,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Azúcar Rubia Paramonga 1kg'),
        CategoriaCanonica.abarrotesDespensa,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Aceite Primor Premium 900ml'),
        CategoriaCanonica.abarrotesDespensa,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Fideos Don Vittorio Spaghetti 500g'),
        CategoriaCanonica.abarrotesDespensa,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Lentejas Costeño 500g'),
        CategoriaCanonica.abarrotesDespensa,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Harina Blanca Flor preparada 1kg'),
        CategoriaCanonica.abarrotesDespensa,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Sillao Kiko 500ml'),
        CategoriaCanonica.abarrotesDespensa,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Mayonesa Alacena doy pack 950g'),
        CategoriaCanonica.abarrotesDespensa,
      );
    });

    test('Detecta Snacks & Piqueos vs Frutas & Verduras', () {
      // Snacks
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Papas Lays Clásicas 160g'),
        CategoriaCanonica.snacksPiqueos,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Doritos Queso Mega 200g'),
        CategoriaCanonica.snacksPiqueos,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Cheese Tris 150g'),
        CategoriaCanonica.snacksPiqueos,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Cuates Picante 90g'),
        CategoriaCanonica.snacksPiqueos,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Chifles Piuranos Salados 100g'),
        CategoriaCanonica.snacksPiqueos,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Maní Karinto Salado 100g'),
        CategoriaCanonica.snacksPiqueos,
      );

      // Verduras frescas
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Papa Amarilla seleccionada kg'),
        CategoriaCanonica.frutasVerduras,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Plátano de Seda kg'),
        CategoriaCanonica.frutasVerduras,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Cebolla Roja malla 1kg'),
        CategoriaCanonica.frutasVerduras,
      );
    });

    test('Detecta Golosinas & Chocolates vs Helados', () {
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Chocolate Sublime Clásico 30g'),
        CategoriaCanonica.golosinasChocolates,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Galletas Margarita pack x6'),
        CategoriaCanonica.golosinasChocolates,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Galletas Casino Menta x6'),
        CategoriaCanonica.golosinasChocolates,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Galleta Oreo Original 108g'),
        CategoriaCanonica.golosinasChocolates,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Caramelos Halls Menta Extra Fuerte'),
        CategoriaCanonica.golosinasChocolates,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Chupetín Globo Pop bolsa x24'),
        CategoriaCanonica.golosinasChocolates,
      );

      // Helados
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Helado Peziduri Lúcuma Donofrio 1L'),
        CategoriaCanonica.heladosCongelados,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Frio Rico Vainilla Donofrio'),
        CategoriaCanonica.heladosCongelados,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Helado Artika Aguaje paleta'),
        CategoriaCanonica.heladosCongelados,
      );
    });

    test('Detecta Embutidos y Fiambrería correctamente', () {
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Salchicha Huachana Laive 250g'),
        CategoriaCanonica.embutidosFiambres,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Hot Dog San Fernando de Pollo pack x6'),
        CategoriaCanonica.embutidosFiambres,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Jamonada Especial San Fernando 250g'),
        CategoriaCanonica.embutidosFiambres,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Tocino Ahumado Braedt 170g'),
        CategoriaCanonica.embutidosFiambres,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Chorizo Parrillero San Fernando x4'),
        CategoriaCanonica.embutidosFiambres,
      );
    });

    test('Detecta Limpieza vs Aceite de cocina', () {
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Detergente Ace Floral 500g'),
        CategoriaCanonica.limpiezaHogar,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Detergente Ariel Doble Poder 1kg'),
        CategoriaCanonica.limpiezaHogar,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Lavavajilla Ayudín Limón pasta 350g'),
        CategoriaCanonica.limpiezaHogar,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Lejía Clorox Tradicional 1L'),
        CategoriaCanonica.limpiezaHogar,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Limpiador Poett Lavanda 900ml'),
        CategoriaCanonica.limpiezaHogar,
      );

      // Aceite Cocinero NO debe caer en Limpieza por la palabra "aceite"
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Aceite Cocinero Vegetal 1L'),
        CategoriaCanonica.abarrotesDespensa,
      );
    });

    test('Detecta Cuidado Personal y Dental', () {
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Crema Dental Colgate Total 12 75ml'),
        CategoriaCanonica.cuidadoPersonal,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Pasta Dental Kolynos Súper Blanco 120g'),
        CategoriaCanonica.cuidadoPersonal,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Shampoo Head & Shoulders Limpieza 375ml'),
        CategoriaCanonica.cuidadoPersonal,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Jabón Dove Original barra 90g'),
        CategoriaCanonica.cuidadoPersonal,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Desodorante Rexona Men Cobalt spray'),
        CategoriaCanonica.cuidadoPersonal,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Prestobarba Gillette Ultragrip x2'),
        CategoriaCanonica.cuidadoPersonal,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Papel Higiénico Suave Rinde Más pack x4'),
        CategoriaCanonica.cuidadoPersonal,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Toallas Higiénicas Nosotras Buenas Noches'),
        CategoriaCanonica.cuidadoPersonal,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Pañales Huggies Natural Care M x36'),
        CategoriaCanonica.cuidadoPersonal,
      );
    });

    test('Detecta Farmacia, Mascotas, Cigarrillos y Librería', () {
      // Farmacia
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Paracetamol 500mg caja x100'),
        CategoriaCanonica.farmaciaBotiquin,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Panadol Antigripal sobre x2'),
        CategoriaCanonica.farmaciaBotiquin,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Sal de Andrews sobre 5g'),
        CategoriaCanonica.farmaciaBotiquin,
      );

      // Mascotas
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Comida para Perro Ricocan Adultos Carne 1kg'),
        CategoriaCanonica.mascotas,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Alimento Gato Whiskas Pollo 500g'),
        CategoriaCanonica.mascotas,
      );

      // Cigarrillos
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Cigarrillos Lucky Strike Double Click 20'),
        CategoriaCanonica.cigarrillosTabaco,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Fósforos La Llama caja x10'),
        CategoriaCanonica.cigarrillosTabaco,
      );

      // Librería
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Cuaderno Standford Cuadriculado 100h'),
        CategoriaCanonica.libreriaBazar,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Pilas Duracell AA blister x4'),
        CategoriaCanonica.libreriaBazar,
      );
    });

    test('Retorna null para productos desconocidos sin forzar categorías falsas', () {
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Mueble de cocina de madera'),
        isNull,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'Llave inglesa de 12 pulgadas'),
        isNull,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: 'xyz123'),
        isNull,
      );
      expect(
        CategoriaSuggesterService.detectarCanonica(nombre: ''),
        isNull,
      );
    });
  });

  group('CategoriaSuggesterService - Mapeo Semántico a Categorías de Bodega', () {
    final catBebidas = Categoria(idCategoria: 1, nombre: 'Bebidas y Gaseosas');
    final catSnacksGolosinas = Categoria(idCategoria: 2, nombre: 'Snacks y Golosinas');
    final catAbarrotes = Categoria(idCategoria: 3, nombre: 'Abarrotes y Despensa');
    final catLimpieza = Categoria(idCategoria: 4, nombre: 'Limpieza y Cuidado del Hogar');
    final catLacteos = Categoria(idCategoria: 5, nombre: 'Lácteos y Derivados');

    final categoriasBodega = [
      catBebidas,
      catSnacksGolosinas,
      catAbarrotes,
      catLimpieza,
      catLacteos,
    ];

    test('Mapea tanto Snacks (Lays) como Golosinas (Sublime) a "Snacks y Golosinas" sin caer en Bebidas', () {
      final resLays = CategoriaSuggesterService.sugerirCategoria(
        nombre: 'Papas Lays Clásicas 160g',
        categoriasDisponibles: categoriasBodega,
      );
      expect(resLays?.idCategoria, equals(2));
      expect(resLays?.nombre, equals('Snacks y Golosinas'));

      final resSublime = CategoriaSuggesterService.sugerirCategoria(
        nombre: 'Chocolate Sublime Clásico 30g',
        categoriasDisponibles: categoriasBodega,
      );
      expect(resSublime?.idCategoria, equals(2));
      expect(resSublime?.nombre, equals('Snacks y Golosinas'));

      final resOreo = CategoriaSuggesterService.sugerirCategoria(
        nombre: 'Galletas Oreo Original',
        categoriasDisponibles: categoriasBodega,
      );
      expect(resOreo?.idCategoria, equals(2));
      expect(resOreo?.nombre, equals('Snacks y Golosinas'));
    });

    test('Mapea correctamente a "Abarrotes y Despensa"', () {
      final resArroz = CategoriaSuggesterService.sugerirCategoria(
        nombre: 'Arroz Costeño Extra 1kg',
        categoriasDisponibles: categoriasBodega,
      );
      expect(resArroz?.idCategoria, equals(3));
      expect(resArroz?.nombre, equals('Abarrotes y Despensa'));

      final resAtun = CategoriaSuggesterService.sugerirCategoria(
        nombre: 'Atún Gloria Grated en agua',
        categoriasDisponibles: categoriasBodega,
      );
      expect(resAtun?.idCategoria, equals(3));
      expect(resAtun?.nombre, equals('Abarrotes y Despensa'));
    });

    test('Mapea correctamente a "Lácteos y Derivados"', () {
      final resLeche = CategoriaSuggesterService.sugerirCategoria(
        nombre: 'Leche Gloria Evaporada Azul 400g',
        categoriasDisponibles: categoriasBodega,
      );
      expect(resLeche?.idCategoria, equals(5));
      expect(resLeche?.nombre, equals('Lácteos y Derivados'));
    });

    test('Cuando la bodega no tiene una categoría adecuada, no fuerza falsamente la primera', () {
      final categoriasRestringidas = [
        Categoria(idCategoria: 1, nombre: 'Bebidas y Gaseosas'),
        Categoria(idCategoria: 2, nombre: 'Abarrotes'),
      ];

      final resDetergente = CategoriaSuggesterService.sugerirCategoria(
        nombre: 'Detergente Ariel 1kg',
        categoriasDisponibles: categoriasRestringidas,
      );
      // No debe ser Bebidas y Gaseosas
      expect(resDetergente, isNull);
    });

    test('Reconoce Código de Barras oficial de Packshot y sugiere categoría con 100% certeza', () {
      // 7750107002030 corresponde a Salchicha Huachana Laive 250g en CatalogoImagenesService
      final categoriasConEmbutidos = [
        ...categoriasBodega,
        Categoria(idCategoria: 6, nombre: 'Embutidos y Fiambrería'),
      ];

      final resBarcode = CategoriaSuggesterService.analizarSugerencia(
        codigoBarras: '7750107002030',
        categoriasDisponibles: categoriasConEmbutidos,
      );

      expect(resBarcode, isNotNull);
      expect(resBarcode?.categoria.idCategoria, equals(6));
      expect(resBarcode?.origen, equals('catalogo_packshot'));
      expect(resBarcode?.confianza, equals(1.0));
      expect(resBarcode?.prefijoCodigo, equals('EMB'));
    });
  });

  group('CategoriaSuggesterService - Prefijos SKU para Códigos', () {
    test('Calcula prefijos canónicos apropiados', () {
      expect(CategoriaSuggesterService.getPrefixForCategory('Bebidas y Gaseosas'), equals('GSE'));
      expect(CategoriaSuggesterService.getPrefixForCategory('Cervezas y Licores'), equals('ALC'));
      expect(CategoriaSuggesterService.getPrefixForCategory('Lácteos y Derivados'), equals('LAC'));
      expect(CategoriaSuggesterService.getPrefixForCategory('Abarrotes y Despensa'), equals('ABA'));
      expect(CategoriaSuggesterService.getPrefixForCategory('Snacks y Piqueos'), equals('SNK'));
      expect(CategoriaSuggesterService.getPrefixForCategory('Golosinas y Chocolates'), equals('GLS'));
      expect(CategoriaSuggesterService.getPrefixForCategory('Embutidos y Fiambrería'), equals('EMB'));
      expect(CategoriaSuggesterService.getPrefixForCategory('Limpieza del Hogar'), equals('LMP'));
      expect(CategoriaSuggesterService.getPrefixForCategory('Cuidado Personal'), equals('CPD'));
      expect(CategoriaSuggesterService.getPrefixForCategory('Farmacia y Botiquín'), equals('FAR'));
    });
  });
}
