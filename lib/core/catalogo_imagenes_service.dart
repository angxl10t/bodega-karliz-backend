/// Servicio Inteligente de Catálogo de Imágenes de Estudio Frontales para Bodegas
///
/// Provee fotografías profesionales de estudio en vista frontal pura (Packshots 1:1)
/// servidas directamente desde la infraestructura local de CajaYa Cloud POS (Same-Origin).
/// 100% libre de CORS, sin bloqueos de CanvasKit y con carga instantánea (<20ms).
class ProductoStudioFoto {
  final String id;
  final String nombre;
  final String marca;
  final String categoria;
  final String imagenUrl;
  final List<String> codigosBarras;
  final List<String> keywords;

  const ProductoStudioFoto({
    required this.id,
    required this.nombre,
    required this.marca,
    required this.categoria,
    required this.imagenUrl,
    required this.codigosBarras,
    required this.keywords,
  });
}

class CatalogoImagenesService {
  CatalogoImagenesService._();

  static const String _basePath = 'packshots';

  /// Catálogo maestro de fotografías de estudio en vista frontal pura (Packshots oficiales)
  static final List<ProductoStudioFoto> _catalogoMaestro = [
    // --- BEBIDAS Y GASEOSAS ---
    ProductoStudioFoto(
      id: 'coca_cola_500ml',
      nombre: 'Coca Cola Sabor Original 500ml',
      marca: 'Coca Cola',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/coca_cola_500ml.png',
      codigosBarras: ['7750106000025'],
      keywords: ['500ml', 'coca', 'cola', 'gaseosa', 'original', 'sabor'],
    ),
    ProductoStudioFoto(
      id: 'coca_cola_3l',
      nombre: 'Coca Cola Sabor Original 3 Litros',
      marca: 'Coca Cola',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/coca_cola_3l.png',
      codigosBarras: ['7751234567890', '7750106002024', '7750182001250'],
      keywords: ['3l', '3lt', '3litros', 'coca', 'cola', 'gaseosa', 'original', 'familiar'],
    ),
    ProductoStudioFoto(
      id: 'inka_kola_500ml',
      nombre: 'Inca Kola Sabor Original 500ml',
      marca: 'Inca Kola',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/inka_kola_500ml.png',
      codigosBarras: ['7750106001010', '7750106000018'],
      keywords: ['500ml', 'dorada', 'gaseosa', 'inca', 'kola', 'original'],
    ),
    ProductoStudioFoto(
      id: 'inka_kola_3l',
      nombre: 'Inca Kola Sabor Original 3 Litros',
      marca: 'Inca Kola',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/inka_kola_3l.png',
      codigosBarras: ['7750106000013', '7750182001243'],
      keywords: ['3l', '3lt', '3litros', 'dorada', 'gaseosa', 'inca', 'kola', 'original', 'familiar'],
    ),
    ProductoStudioFoto(
      id: 'fanta_500ml',
      nombre: 'Gaseosa Fanta Naranja 500ml',
      marca: 'Fanta',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/fanta_500ml.png',
      codigosBarras: ['7750182220378', '7750106004011'],
      keywords: ['500ml', 'fanta', 'gaseosa', 'naranja'],
    ),
    ProductoStudioFoto(
      id: 'fanta_3l',
      nombre: 'Gaseosa Fanta Naranja 3 Litros',
      marca: 'Fanta',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/fanta_3l.png',
      codigosBarras: ['7750182495301', '7750106004028'],
      keywords: ['3l', '3lt', '3litros', 'fanta', 'gaseosa', 'naranja', 'familiar'],
    ),
    ProductoStudioFoto(
      id: 'sprite_500ml',
      nombre: 'Gaseosa Sprite Lima Limón 500ml',
      marca: 'Sprite',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/sprite_500ml.png',
      codigosBarras: ['7750182000321', '7750106005018'],
      keywords: ['500ml', 'gaseosa', 'lima', 'limon', 'sprite'],
    ),
    ProductoStudioFoto(
      id: 'sprite_3l',
      nombre: 'Gaseosa Sprite Lima Limón 3 Litros',
      marca: 'Sprite',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/sprite_3l.png',
      codigosBarras: ['7750182000222', '7750106005025'],
      keywords: ['3l', '3lt', '3litros', 'gaseosa', 'lima', 'limon', 'sprite', 'familiar'],
    ),
    ProductoStudioFoto(
      id: 'guarana',
      nombre: 'Gaseosa Guaraná Backus 450ml',
      marca: 'Backus',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/guarana_450ml.png',
      codigosBarras: ['7753749003186', '7750106007012'],
      keywords: ['450ml', 'backus', 'gaseosa', 'guarana'],
    ),
    ProductoStudioFoto(
      id: 'sporade',
      nombre: 'Bebida Rehidratante Sporade Tropical 625ml',
      marca: 'Sporade',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/sporade.png',
      codigosBarras: ['7750670010238'],
      keywords: ['625ml', 'bebida', 'rehidratante', 'sporade', 'tropical'],
    ),
    ProductoStudioFoto(
      id: 'cifrut',
      nombre: 'Bebida de Frutas Cifrut Citrus Punch 3 Litros',
      marca: 'Cifrut',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/cifrut.png',
      codigosBarras: ['7750670010412'],
      keywords: ['3l', '3litros', 'citrus', 'punch', 'cifrut', 'frutas', 'bebida'],
    ),
    ProductoStudioFoto(
      id: 'agua_san_mateo',
      nombre: 'Agua Mineral San Mateo Sin Gas 600ml',
      marca: 'San Mateo',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/agua_san_mateo_600ml.png',
      codigosBarras: ['77530967', '775117011953', '775386598917', '775544203715', '775620527268'],
      keywords: ['600ml', 'agua', 'gas', 'manantial', 'mateo', 'mineral', 'san', 'sin'],
    ),
    ProductoStudioFoto(
      id: 'agua_san_luis',
      nombre: 'Agua San Luis Sin Gas Bidón con Caño 7 Litros',
      marca: 'San Luis',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/agua_san_luis.png',
      codigosBarras: ['7750106003014', '7750106003021'],
      keywords: ['7l', '7litros', 'agua', 'bidon', 'cano', 'gas', 'luis', 'mesa', 'san', 'sin'],
    ),
    ProductoStudioFoto(
      id: 'red_bull',
      nombre: 'Bebida Energizante Red Bull Lata 355ml',
      marca: 'Red Bull',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/red_bull.png',
      codigosBarras: ['90162602'],
      keywords: ['355ml', 'bull', 'energizante', 'lata', 'red'],
    ),
    ProductoStudioFoto(
      id: 'inka_kola_1_5l',
      nombre: 'Inca Kola Sabor Original 1.5 Litros',
      marca: 'Inca Kola',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/inka_kola.png',
      codigosBarras: ['7750106001027'],
      keywords: ['1.5l', '1.5lt', 'inka', 'kola', 'original', 'gaseosa'],
    ),
    ProductoStudioFoto(
      id: 'inka_kola_zero_500ml',
      nombre: 'Inca Kola Sin Azúcar Zero 500ml',
      marca: 'Inca Kola',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/inka_kola_500ml.png',
      codigosBarras: ['7750106001034'],
      keywords: ['500ml', 'zero', 'sin azucar', 'inka', 'kola', 'gaseosa'],
    ),
    ProductoStudioFoto(
      id: 'coca_cola_1_5l',
      nombre: 'Coca Cola Sabor Original 1.5 Litros',
      marca: 'Coca Cola',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/coca_cola.png',
      codigosBarras: ['7750106002017'],
      keywords: ['1.5l', '1.5lt', 'coca', 'cola', 'original', 'gaseosa'],
    ),
    ProductoStudioFoto(
      id: 'coca_cola_zero_500ml',
      nombre: 'Coca Cola Sin Azúcar Zero 500ml',
      marca: 'Coca Cola',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/coca_cola_500ml.png',
      codigosBarras: ['7750106000032'],
      keywords: ['500ml', 'zero', 'sin azucar', 'coca', 'cola', 'gaseosa'],
    ),
    ProductoStudioFoto(
      id: 'guarana_3l',
      nombre: 'Gaseosa Guaraná Backus 3 Litros',
      marca: 'Backus',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/guarana.png',
      codigosBarras: ['7753749003193'],
      keywords: ['3l', '3lt', 'guarana', 'backus', 'familiar', 'gaseosa'],
    ),
    ProductoStudioFoto(
      id: 'sporade_maracuya',
      nombre: 'Bebida Rehidratante Sporade Maracuyá 625ml',
      marca: 'Sporade',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/sporade.png',
      codigosBarras: ['7750670010245'],
      keywords: ['625ml', 'sporade', 'maracuya', 'rehidratante', 'bebida'],
    ),
    ProductoStudioFoto(
      id: 'cifrut_500ml',
      nombre: 'Bebida de Frutas Cifrut Citrus Punch 500ml',
      marca: 'Cifrut',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/cifrut.png',
      codigosBarras: ['7750670010429'],
      keywords: ['500ml', 'cifrut', 'citrus', 'punch', 'frutas', 'bebida'],
    ),
    ProductoStudioFoto(
      id: 'agua_san_luis_625ml',
      nombre: 'Agua San Luis 625ml Sin Gas',
      marca: 'San Luis',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/agua_san_luis.png',
      codigosBarras: ['7750106003014'],
      keywords: ['625ml', 'agua', 'san', 'luis', 'sin', 'gas', 'mesa'],
    ),
    ProductoStudioFoto(
      id: 'pepsi_500ml',
      nombre: 'Gaseosa Pepsi Sabor Original 500ml',
      marca: 'Pepsi',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/pepsi_500ml.png',
      codigosBarras: ['7750182000406'],
      keywords: ['500ml', 'pepsi', 'gaseosa', 'original', 'sabor', 'negra'],
    ),
    ProductoStudioFoto(
      id: 'pepsi_1_5l',
      nombre: 'Gaseosa Pepsi Sabor Original 1.5 Litros',
      marca: 'Pepsi',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/pepsi.png',
      codigosBarras: ['7750182000413'],
      keywords: ['1.5l', '1.5lt', 'pepsi', 'gaseosa', 'original', 'mediana'],
    ),
    ProductoStudioFoto(
      id: 'pepsi_3l',
      nombre: 'Gaseosa Pepsi Sabor Original 3 Litros',
      marca: 'Pepsi',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/pepsi_3l.png',
      codigosBarras: ['7750182000420'],
      keywords: ['3l', '3lt', '3litros', 'pepsi', 'gaseosa', 'original', 'familiar'],
    ),
    ProductoStudioFoto(
      id: 'seven_up_500ml',
      nombre: 'Gaseosa 7Up Lima Limón 500ml',
      marca: '7Up',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/seven_up.png',
      codigosBarras: ['7750182000437'],
      keywords: ['500ml', '7up', 'seven', 'up', 'lima', 'limon', 'gaseosa'],
    ),
    ProductoStudioFoto(
      id: 'seven_up_3l',
      nombre: 'Gaseosa 7Up Lima Limón 3 Litros',
      marca: '7Up',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/seven_up.png',
      codigosBarras: ['7750182000444'],
      keywords: ['3l', '3lt', '3litros', '7up', 'seven', 'up', 'lima', 'limon', 'familiar'],
    ),
    ProductoStudioFoto(
      id: 'concordia_pina_500ml',
      nombre: 'Gaseosa Concordia Piña 500ml',
      marca: 'Concordia',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/concordia_pina.png',
      codigosBarras: ['7750182000451'],
      keywords: ['500ml', 'concordia', 'pina', 'amarilla', 'gaseosa'],
    ),
    ProductoStudioFoto(
      id: 'concordia_pina_3l',
      nombre: 'Gaseosa Concordia Piña 3 Litros',
      marca: 'Concordia',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/concordia_pina.png',
      codigosBarras: ['7750182000468'],
      keywords: ['3l', '3lt', '3litros', 'concordia', 'pina', 'amarilla', 'familiar'],
    ),
    ProductoStudioFoto(
      id: 'kr_cola_3l',
      nombre: 'Gaseosa Kola Real KR Cola Negra 3 Litros',
      marca: 'Kola Real',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/kr_cola.png',
      codigosBarras: ['7750670010115'],
      keywords: ['3l', '3lt', 'kr', 'kola', 'real', 'negra', 'cola', 'familiar'],
    ),
    ProductoStudioFoto(
      id: 'kr_pina_3l',
      nombre: 'Gaseosa Kola Real KR Piña 3 Litros',
      marca: 'Kola Real',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/kr_pina.png',
      codigosBarras: ['7750670010122'],
      keywords: ['3l', '3lt', 'kr', 'kola', 'real', 'pina', 'amarilla', 'familiar'],
    ),
    ProductoStudioFoto(
      id: 'guarana_lata_355ml',
      nombre: 'Gaseosa Guaraná Backus Lata 355ml',
      marca: 'Backus',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/guarana_450ml.png',
      codigosBarras: ['7753749003209'],
      keywords: ['355ml', 'guarana', 'backus', 'lata', 'gaseosa'],
    ),
    ProductoStudioFoto(
      id: 'guarana_1_5l',
      nombre: 'Gaseosa Guaraná Backus 1.5 Litros',
      marca: 'Backus',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/guarana.png',
      codigosBarras: ['7753749003216'],
      keywords: ['1.5l', '1.5lt', 'guarana', 'backus', 'mediana', 'gaseosa'],
    ),
    ProductoStudioFoto(
      id: 'canada_dry_1_5l',
      nombre: 'Gaseosa Canada Dry Ginger Ale 1.5L',
      marca: 'Canada Dry',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/canada_dry.png',
      codigosBarras: ['7750106000049'],
      keywords: ['1.5l', 'canada', 'dry', 'ginger', 'ale', 'gaseosa'],
    ),
    ProductoStudioFoto(
      id: 'monster_energy_473ml',
      nombre: 'Bebida Energizante Monster Energy 473ml',
      marca: 'Monster Energy',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/monster_energy.png',
      codigosBarras: ['70847811169'],
      keywords: ['473ml', 'monster', 'energy', 'verde', 'lata', 'energizante'],
    ),
    ProductoStudioFoto(
      id: 'monster_energy_ultra_473ml',
      nombre: 'Bebida Energizante Monster Ultra White 473ml',
      marca: 'Monster Energy',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/monster_energy_ultra.png',
      codigosBarras: ['70847022909'],
      keywords: ['473ml', 'monster', 'ultra', 'white', 'blanca', 'zero', 'lata', 'energizante'],
    ),
    ProductoStudioFoto(
      id: 'volt_blue_300ml',
      nombre: 'Bebida Energizante Volt Blue Energy 300ml',
      marca: 'Volt',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/volt_blue.png',
      codigosBarras: ['7750670010511'],
      keywords: ['300ml', 'volt', 'blue', 'azul', 'energizante', 'aje'],
    ),
    ProductoStudioFoto(
      id: 'volt_maca_300ml',
      nombre: 'Bebida Energizante Volt Maca 300ml',
      marca: 'Volt',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/volt_maca.png',
      codigosBarras: ['7750670010528'],
      keywords: ['300ml', 'volt', 'maca', 'amarillo', 'energizante', 'aje'],
    ),
    ProductoStudioFoto(
      id: 'volt_ginseng_300ml',
      nombre: 'Bebida Energizante Volt Ginseng 300ml',
      marca: 'Volt',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/volt_ginseng.png',
      codigosBarras: ['7750670010535'],
      keywords: ['300ml', 'volt', 'ginseng', 'rojo', 'energizante', 'aje'],
    ),
    ProductoStudioFoto(
      id: 'frugos_durazno_1l',
      nombre: 'Jugo Frugos del Valle Durazno 1 Litro',
      marca: 'Frugos',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/frugos_durazno.png',
      codigosBarras: ['7750106008019'],
      keywords: ['1l', '1litro', 'frugos', 'valle', 'durazno', 'jugo', 'nectar'],
    ),
    ProductoStudioFoto(
      id: 'frugos_mango_1l',
      nombre: 'Jugo Frugos del Valle Mango 1 Litro',
      marca: 'Frugos',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/frugos_mango.png',
      codigosBarras: ['7750106008033'],
      keywords: ['1l', '1litro', 'frugos', 'valle', 'mango', 'jugo', 'nectar'],
    ),
    ProductoStudioFoto(
      id: 'frugos_naranja_1l',
      nombre: 'Jugo Frugos del Valle Naranja 1 Litro',
      marca: 'Frugos',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/frugos_naranja.png',
      codigosBarras: ['7750106008040'],
      keywords: ['1l', '1litro', 'frugos', 'valle', 'naranja', 'jugo', 'citrico'],
    ),
    ProductoStudioFoto(
      id: 'pulp_durazno_300ml',
      nombre: 'Néctar Pulp Durazno Botella 300ml',
      marca: 'Pulp',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/pulp_durazno.png',
      codigosBarras: ['7750670010320'],
      keywords: ['300ml', 'pulp', 'durazno', 'nectar', 'jugo', 'aje'],
    ),
    ProductoStudioFoto(
      id: 'pulp_durazno_1l',
      nombre: 'Néctar Pulp Durazno Caja 1 Litro',
      marca: 'Pulp',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/pulp_durazno.png',
      codigosBarras: ['7750670010313'],
      keywords: ['1l', '1litro', 'pulp', 'durazno', 'caja', 'nectar', 'aje'],
    ),
    ProductoStudioFoto(
      id: 'tampico_1l',
      nombre: 'Bebida de Frutas Tampico Citrus 1 Litro',
      marca: 'Tampico',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/tampico.png',
      codigosBarras: ['7750800001012'],
      keywords: ['1l', '1litro', 'tampico', 'citrus', 'punch', 'frutas', 'jugo'],
    ),
    ProductoStudioFoto(
      id: 'tampico_3l',
      nombre: 'Bebida de Frutas Tampico Citrus 3 Litros',
      marca: 'Tampico',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/tampico_3l.png',
      codigosBarras: ['7750800001029'],
      keywords: ['3l', '3lt', '3litros', 'tampico', 'galonera', 'citrus', 'familiar'],
    ),
    ProductoStudioFoto(
      id: 'agua_cielo_625ml',
      nombre: 'Agua Cielo Sin Gas 625ml',
      marca: 'Cielo',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/agua_cielo.png',
      codigosBarras: ['7750670010016'],
      keywords: ['625ml', 'cielo', 'agua', 'pura', 'sin', 'gas', 'aje'],
    ),
    ProductoStudioFoto(
      id: 'agua_cielo_7l',
      nombre: 'Agua Cielo Sin Gas Bidón 7 Litros',
      marca: 'Cielo',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/agua_cielo_7l.png',
      codigosBarras: ['7750670010030'],
      keywords: ['7l', '7litros', 'bidon', 'cielo', 'agua', 'pura', 'sin', 'gas'],
    ),
    ProductoStudioFoto(
      id: 'gatorade_cool_blue_500ml',
      nombre: 'Bebida Rehidratante Gatorade Cool Blue 500ml',
      marca: 'Gatorade',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/gatorade_cool_blue.png',
      codigosBarras: ['7750182000604'],
      keywords: ['500ml', 'gatorade', 'cool', 'blue', 'azul', 'rehidratante', 'isotónica'],
    ),
    ProductoStudioFoto(
      id: 'gatorade_tropical_500ml',
      nombre: 'Bebida Rehidratante Gatorade Tropical 500ml',
      marca: 'Gatorade',
      categoria: 'Gaseosas y Bebidas',
      imagenUrl: '$_basePath/gatorade_tropical.png',
      codigosBarras: ['7750182000611'],
      keywords: ['500ml', 'gatorade', 'tropical', 'rojo', 'rehidratante', 'isotónica'],
    ),

    // --- BEBIDAS ALCOHÓLICAS Y LICORES ---
    ProductoStudioFoto(
      id: 'cerveza_cristal',
      nombre: 'Cerveza Cristal Bicolor Botella 330ml',
      marca: 'Cristal',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/cerveza_cristal.png',
      codigosBarras: ['7753749003650', '7750111006021'],
      keywords: ['330ml', 'bicolor', 'botella', 'cerveza', 'cristal'],
    ),
    ProductoStudioFoto(
      id: 'cerveza_cristal_lata',
      nombre: 'Cerveza Cristal Lata 355ml',
      marca: 'Cristal',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/cerveza_cristal_lata.png',
      codigosBarras: ['7753749001984', '7750111006212'],
      keywords: ['355ml', 'cerveza', 'cristal', 'lata'],
    ),
    ProductoStudioFoto(
      id: 'cerveza_pilsen',
      nombre: 'Cerveza Pilsen Callao Six Pack Botellas 305ml',
      marca: 'Pilsen Callao',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/cerveza_pilsen.png',
      codigosBarras: ['7753749005968', '7750111006014'],
      keywords: ['305ml', 'botellas', 'callao', 'cerveza', 'pilsen', 'sixpack', 'pack'],
    ),
    ProductoStudioFoto(
      id: 'cerveza_cusquena',
      nombre: 'Cerveza Cusqueña Trigo Lata 473ml',
      marca: 'Cusqueña',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/cerveza_cusquena.png',
      codigosBarras: ['7750106006015'],
      keywords: ['473ml', 'cerveza', 'cusquena', 'lata', 'trigo'],
    ),
    ProductoStudioFoto(
      id: 'cerveza_cusquena_dorada',
      nombre: 'Cerveza Cusqueña Dorada Botella 310ml',
      marca: 'Cusqueña',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/cerveza_cusquena_dorada.png',
      codigosBarras: ['7753749005357', '7750106006022'],
      keywords: ['310ml', 'botella', 'cerveza', 'cusquena', 'dorada'],
    ),
    ProductoStudioFoto(
      id: 'cerveza_stella',
      nombre: 'Cerveza Stella Artois Botella 330ml',
      marca: 'Stella Artois',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/cerveza_stella.png',
      codigosBarras: ['7750111006045'],
      keywords: ['330ml', 'artois', 'botella', 'cerveza', 'stella'],
    ),
    ProductoStudioFoto(
      id: 'ron_cartavio',
      nombre: 'Ron Cartavio Black Botella 1 Litro',
      marca: 'Cartavio',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/ron_cartavio.png',
      codigosBarras: ['7750111006052', '7750148000012'],
      keywords: ['1l', '1litro', '750ml', 'black', 'botella', 'cartavio', 'ron'],
    ),
    ProductoStudioFoto(
      id: 'cerveza_pilsen_630ml',
      nombre: 'Cerveza Pilsen Callao 630ml Retornable',
      marca: 'Pilsen Callao',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/cerveza_pilsen.png',
      codigosBarras: ['7750111006014'],
      keywords: ['630ml', 'pilsen', 'callao', 'retornable', 'cerveza', 'botella'],
    ),
    ProductoStudioFoto(
      id: 'cerveza_pilsen_lata_355ml',
      nombre: 'Cerveza Pilsen Callao 355ml Lata',
      marca: 'Pilsen Callao',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/cerveza_pilsen.png',
      codigosBarras: ['7750111006038'],
      keywords: ['355ml', 'pilsen', 'callao', 'lata', 'cerveza'],
    ),
    ProductoStudioFoto(
      id: 'cerveza_cristal_650ml',
      nombre: 'Cerveza Cristal 650ml Retornable',
      marca: 'Cristal',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/cerveza_cristal.png',
      codigosBarras: ['7750111006021'],
      keywords: ['650ml', 'cristal', 'retornable', 'cerveza', 'botella'],
    ),
    ProductoStudioFoto(
      id: 'cerveza_corona_355ml',
      nombre: 'Cerveza Corona Extra Botella 355ml',
      marca: 'Corona',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/cerveza_corona.png',
      codigosBarras: ['750106419166'],
      keywords: ['355ml', 'corona', 'extra', 'botella', 'cerveza', 'importada'],
    ),
    ProductoStudioFoto(
      id: 'pisco_queirolo_750ml',
      nombre: 'Pisco Queirolo Quebranta 750ml',
      marca: 'Santiago Queirolo',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/pisco_queirolo.png',
      codigosBarras: ['7750174000018'],
      keywords: ['750ml', 'pisco', 'queirolo', 'quebranta', 'pisco peruano'],
    ),
    ProductoStudioFoto(
      id: 'vino_tabernero_750ml',
      nombre: 'Vino Tabernero Borgoña Tinto 750ml',
      marca: 'Tabernero',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/vino_tabernero.png',
      codigosBarras: ['7750170000012'],
      keywords: ['750ml', 'vino', 'tabernero', 'borgona', 'tinto'],
    ),
    ProductoStudioFoto(
      id: 'whisky_red_label',
      nombre: 'Whisky Johnnie Walker Red Label 750ml',
      marca: 'Johnnie Walker',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/whisky_johnnie_walker.png',
      codigosBarras: ['5000267014005'],
      keywords: ['750ml', 'whisky', 'johnnie', 'walker', 'red', 'label'],
    ),
    ProductoStudioFoto(
      id: 'four_loko_gold',
      nombre: 'Bebida Alcohólica Four Loko Gold Lata 473ml',
      marca: 'Four Loko',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/four_loko_gold.png',
      codigosBarras: ['849607000100'],
      keywords: ['473ml', 'four', 'loko', 'gold', 'dorado', '12%', 'lata', 'alcopop'],
    ),
    ProductoStudioFoto(
      id: 'four_loko_sandia',
      nombre: 'Bebida Alcohólica Four Loko Sandía Lata 473ml',
      marca: 'Four Loko',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/four_loko_sandia.png',
      codigosBarras: ['849607000117'],
      keywords: ['473ml', 'four', 'loko', 'sandia', 'rojo', 'watermelon', '12%', 'lata'],
    ),
    ProductoStudioFoto(
      id: 'four_loko_blue',
      nombre: 'Bebida Alcohólica Four Loko Blue Lata 473ml',
      marca: 'Four Loko',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/four_loko_blue.png',
      codigosBarras: ['849607000124'],
      keywords: ['473ml', 'four', 'loko', 'blue', 'azul', 'uva', '12%', 'lata'],
    ),
    ProductoStudioFoto(
      id: 'four_loko_black',
      nombre: 'Bebida Alcohólica Four Loko Black Lata 473ml',
      marca: 'Four Loko',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/four_loko_black.png',
      codigosBarras: ['849607000131'],
      keywords: ['473ml', 'four', 'loko', 'black', 'negro', '12%', 'lata'],
    ),
    ProductoStudioFoto(
      id: 'mikes_hard_lemonade',
      nombre: "Bebida Preparada Mike's Hard Lemonade 350ml",
      marca: "Mike's",
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/mikes_hard_lemonade.png',
      codigosBarras: ['7750111006502'],
      keywords: ['350ml', 'mikes', 'mike', 'hard', 'lemonade', 'limonada', 'lata', '5%'],
    ),
    ProductoStudioFoto(
      id: 'mikes_fresa',
      nombre: "Bebida Preparada Mike's Hard Strawberry 350ml",
      marca: "Mike's",
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/mikes_fresa.png',
      codigosBarras: ['7750111006519'],
      keywords: ['350ml', 'mikes', 'mike', 'hard', 'fresa', 'strawberry', 'lata', 'rosada'],
    ),
    ProductoStudioFoto(
      id: 'mikes_maracuya',
      nombre: "Bebida Preparada Mike's Hard Maracuyá 350ml",
      marca: "Mike's",
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/mikes_maracuya.png',
      codigosBarras: ['7750111006526'],
      keywords: ['350ml', 'mikes', 'mike', 'hard', 'maracuya', 'passion', 'lata'],
    ),
    ProductoStudioFoto(
      id: 'smirnoff_ice',
      nombre: 'Bebida Preparada Smirnoff Ice Original 275ml',
      marca: 'Smirnoff',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/smirnoff_ice.png',
      codigosBarras: ['5000291020010', '5000291020027'],
      keywords: ['275ml', '355ml', 'smirnoff', 'ice', 'vodka', 'limon', 'botella'],
    ),
    ProductoStudioFoto(
      id: 'chilcano_tabernero',
      nombre: 'Chilcano de Pisco Tabernero Lata 310ml',
      marca: 'Tabernero',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/chilcano_tabernero.png',
      codigosBarras: ['7750170000203'],
      keywords: ['310ml', 'chilcano', 'tabernero', 'pisco', 'lata', 'preparado'],
    ),
    ProductoStudioFoto(
      id: 'pisco_sour_tabernero',
      nombre: 'Pisco Sour Tabernero Botella 700ml',
      marca: 'Tabernero',
      categoria: 'Bebidas Alcohólicas',
      imagenUrl: '$_basePath/pisco_sour_tabernero.png',
      codigosBarras: ['7750170000302'],
      keywords: ['700ml', 'pisco', 'sour', 'tabernero', 'coctel', 'botella'],
    ),

    // --- SNACKS Y PIQUEOS ---
    ProductoStudioFoto(
      id: 'lays_clasicas',
      nombre: "Papas Fritas Lay's Clásicas Sal Bolsa 140g",
      marca: "Lay's",
      categoria: 'Snacks y Piqueos',
      imagenUrl: '$_basePath/lays_clasicas_140g.png',
      codigosBarras: ['7758574005541', '7750106009999', '7750106009982'],
      keywords: ['140g', 'clasicas', 'fritas', 'lays', 'papas', 'sal', 'snack'],
    ),
    ProductoStudioFoto(
      id: 'lays_onduladas',
      nombre: "Papas Fritas Lay's Ondas Clásicas Bolsa 130g",
      marca: "Lay's",
      categoria: 'Snacks y Piqueos',
      imagenUrl: '$_basePath/lays_onduladas.png',
      codigosBarras: ['7750106009975'],
      keywords: ['130g', 'clasicas', 'lays', 'ondas', 'onduladas', 'papas'],
    ),
    ProductoStudioFoto(
      id: 'piqueo_snax',
      nombre: 'Snack Piqueo Snax Original Bolsa 55g',
      marca: 'Piqueo Snax',
      categoria: 'Snacks y Piqueos',
      imagenUrl: '$_basePath/piqueo_snax_55g.png',
      codigosBarras: ['7758574004230', '7750106009968'],
      keywords: ['55g', 'mix', 'original', 'piqueo', 'snack', 'snax'],
    ),
    ProductoStudioFoto(
      id: 'cheese_tris',
      nombre: 'Snack Cheese Tris Queso Bolsa 44g',
      marca: 'Cheese Tris',
      categoria: 'Snacks y Piqueos',
      imagenUrl: '$_basePath/cheese_tris_44g.png',
      codigosBarras: ['7758574005619', '7750106009944', '7750106009937'],
      keywords: ['44g', 'cheese', 'maiz', 'queso', 'snack', 'tris'],
    ),
    ProductoStudioFoto(
      id: 'doritos_queso',
      nombre: 'Tortilla Chips Doritos Queso Atrevido 45g',
      marca: 'Doritos',
      categoria: 'Snacks y Piqueos',
      imagenUrl: '$_basePath/doritos_queso_45g.png',
      codigosBarras: ['7758574004445', '7750106009951'],
      keywords: ['45g', 'atrevido', 'chips', 'doritos', 'mega', 'queso', 'tortilla'],
    ),
    ProductoStudioFoto(
      id: 'cuates_picantes',
      nombre: 'Hojuelas de Maíz Los Cuates Picante 100g',
      marca: 'Cuates',
      categoria: 'Snacks y Piqueos',
      imagenUrl: '$_basePath/cuates_picantes_100g.png',
      codigosBarras: ['7750106009913', '7750106009906'],
      keywords: ['100g', 'cuates', 'hojuelas', 'maiz', 'picante', 'tortillas'],
    ),
    ProductoStudioFoto(
      id: 'tortees_picantes',
      nombre: 'Tor-Tees Sabor Picante Bolsa 71g',
      marca: 'Karinto',
      categoria: 'Snacks y Piqueos',
      imagenUrl: '$_basePath/tortees_picantes.png',
      codigosBarras: ['7750106009920'],
      keywords: ['71g', 'karinto', 'picante', 'snack', 'tortees'],
    ),
    ProductoStudioFoto(
      id: 'mani_karinto',
      nombre: 'Maní Salado Crocante Karinto 200g',
      marca: 'Karinto',
      categoria: 'Snacks y Piqueos',
      imagenUrl: '$_basePath/mani_karinto.png',
      codigosBarras: ['7750106009890'],
      keywords: ['200g', 'crocante', 'karinto', 'mani', 'salado'],
    ),
    ProductoStudioFoto(
      id: 'chifle_piurano',
      nombre: 'Chifles Máxima Estilo Piurano Bolsa 750g',
      marca: 'Máxima',
      categoria: 'Snacks y Piqueos',
      imagenUrl: '$_basePath/chifle_piurano.png',
      codigosBarras: ['7750106009883'],
      keywords: ['750g', 'chifles', 'maxima', 'piurano', 'platano'],
    ),

    // --- LÁCTEOS Y DERIVADOS ---
    ProductoStudioFoto(
      id: 'leche_gloria_azul',
      nombre: 'Leche Gloria Azul Evaporada Entera 395g',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: '$_basePath/leche_gloria_azul.png',
      codigosBarras: ['7750108003013', '7750243000012', '7750108003112'],
      keywords: ['395g', '400g', 'azul', 'entera', 'evaporada', 'gloria', 'leche'],
    ),
    ProductoStudioFoto(
      id: 'leche_gloria_roja',
      nombre: 'Leche Gloria Roja Entera 395g',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: '$_basePath/leche_gloria_roja.png',
      codigosBarras: ['7750108003020'],
      keywords: ['395g', '400g', 'entera', 'gloria', 'leche', 'roja'],
    ),
    ProductoStudioFoto(
      id: 'leche_gloria_light',
      nombre: 'Leche Gloria Light 395g',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: '$_basePath/leche_gloria_light.png',
      codigosBarras: ['7750108003037'],
      keywords: ['395g', '400g', 'gloria', 'leche', 'light', 'semidescremada'],
    ),
    ProductoStudioFoto(
      id: 'leche_gloria_sin_lactosa',
      nombre: 'Leche Gloria Sin Lactosa 395g',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: '$_basePath/leche_gloria_sin_lactosa.png',
      codigosBarras: ['7750108003044'],
      keywords: ['395g', '400g', 'gloria', 'lactosa', 'leche', 'sin'],
    ),
    ProductoStudioFoto(
      id: 'leche_chocolatada_gloria',
      nombre: 'Leche Chocolatada Gloria UHT Caja 946ml',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: '$_basePath/leche_chocolatada_gloria.png',
      codigosBarras: ['7750108003051', '7750108003150'],
      keywords: ['1l', '946ml', 'caja', 'chocolate', 'chocolatada', 'gloria', 'leche', 'uht'],
    ),
    ProductoStudioFoto(
      id: 'leche_condensada_nestle',
      nombre: 'Leche Condensada Nestlé Lata 393g',
      marca: 'Nestlé',
      categoria: 'Lácteos y Derivados',
      imagenUrl: '$_basePath/leche_condensada_nestle.png',
      codigosBarras: ['7750108003099'],
      keywords: ['393g', 'condensada', 'lata', 'leche', 'nestle'],
    ),
    ProductoStudioFoto(
      id: 'yogur_gloria_fresa',
      nombre: 'Yogurt Bebible Gloria Fresa Botella 1Kg',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: '$_basePath/yogur_gloria_fresa.png',
      codigosBarras: ['7750108003068', '7750108003082'],
      keywords: ['1kg', '1l', 'bebible', 'fresa', 'gloria', 'yogur', 'yogurt'],
    ),
    ProductoStudioFoto(
      id: 'yogur_gloria_vainilla',
      nombre: 'Yogurt Gloria Vainilla Botella 1Kg',
      marca: 'Gloria',
      categoria: 'Lácteos y Derivados',
      imagenUrl: '$_basePath/yogur_gloria_vainilla.png',
      codigosBarras: ['7751271033718', '7750108003075'],
      keywords: ['1kg', '1l', 'gloria', 'vainilla', 'yogur', 'yogurt'],
    ),

    // --- EMBUTIDOS Y FIAMBRERÍA ---
    ProductoStudioFoto(
      id: 'salchicha_huachana',
      nombre: 'Salchicha Huachana San Fernando 250g',
      marca: 'San Fernando',
      categoria: 'Embutidos y Fiambrería',
      imagenUrl: '$_basePath/salchicha_huachana.png',
      codigosBarras: ['7750107002030'],
      keywords: ['250g', 'fernando', 'huachana', 'salchicha', 'san'],
    ),
    ProductoStudioFoto(
      id: 'tocino_braedt',
      nombre: 'Tocino Ahumado en Tiras Braedt 170g',
      marca: 'Braedt',
      categoria: 'Embutidos y Fiambrería',
      imagenUrl: '$_basePath/tocino_braedt.png',
      codigosBarras: ['7750107002047'],
      keywords: ['170g', 'ahumado', 'braedt', 'tiras', 'tocino'],
    ),
    ProductoStudioFoto(
      id: 'chorizo_parrillero',
      nombre: 'Chorizo Parrillero San Fernando pack x4',
      marca: 'San Fernando',
      categoria: 'Embutidos y Fiambrería',
      imagenUrl: '$_basePath/chorizo_parrillero.png',
      codigosBarras: ['7750107002054'],
      keywords: ['chorizo', 'fernando', 'pack', 'parrillero', 'san'],
    ),
    ProductoStudioFoto(
      id: 'queso_edam',
      nombre: 'Queso Edam Laive Tajadas 180g',
      marca: 'Laive',
      categoria: 'Embutidos y Fiambrería',
      imagenUrl: '$_basePath/queso_edam.png',
      codigosBarras: ['7750107002061'],
      keywords: ['180g', '200g', 'edam', 'laive', 'queso', 'tajadas'],
    ),
    ProductoStudioFoto(
      id: 'queso_fresco_bonle',
      nombre: 'Queso Fresco Bonlé Gloria 400g',
      marca: 'Gloria',
      categoria: 'Embutidos y Fiambrería',
      imagenUrl: '$_basePath/queso_fresco_bonle.png',
      codigosBarras: ['7750107002078'],
      keywords: ['400g', 'bonle', 'fresco', 'gloria', 'queso'],
    ),
    ProductoStudioFoto(
      id: 'jamon_del_pais',
      nombre: 'Jamón del País Braedt 150g',
      marca: 'Braedt',
      categoria: 'Embutidos y Fiambrería',
      imagenUrl: '$_basePath/jamon_del_pais.png',
      codigosBarras: ['7750107002085'],
      keywords: ['150g', 'braedt', 'jamon', 'pais'],
    ),
    ProductoStudioFoto(
      id: 'jamonada_san_fernando',
      nombre: 'Jamonada de Pollo San Fernando 450g',
      marca: 'San Fernando',
      categoria: 'Embutidos y Fiambrería',
      imagenUrl: '$_basePath/jamonada_san_fernando.png',
      codigosBarras: ['7750107002023'],
      keywords: ['450g', 'fernando', 'jamonada', 'pollo', 'san'],
    ),
    ProductoStudioFoto(
      id: 'hot_dog_san_fernando',
      nombre: 'Hot Dog de Pollo San Fernando 500g',
      marca: 'San Fernando',
      categoria: 'Embutidos y Fiambrería',
      imagenUrl: '$_basePath/hot_dog_san_fernando.png',
      codigosBarras: ['7750107002016'],
      keywords: ['500g', 'dog', 'fernando', 'hot', 'pollo', 'san'],
    ),

    // --- ABARROTES Y DESPENSA ---
    ProductoStudioFoto(
      id: 'arroz_costeno',
      nombre: 'Arroz Extra Costeño Bolsa 3kg',
      marca: 'Costeño',
      categoria: 'Abarrotes y Despensa',
      imagenUrl: '$_basePath/arroz_costeno.png',
      codigosBarras: ['7750109004041', '7755139246890', '7755139161759', '7750109004141', '7750109004240'],
      keywords: ['1kg', '3kg', '5kg', '750g', 'arroz', 'costeno', 'extra'],
    ),
    ProductoStudioFoto(
      id: 'arroz_faraon',
      nombre: 'Arroz Extra Añejo Faraón Saco 5kg',
      marca: 'Faraón',
      categoria: 'Abarrotes y Despensa',
      imagenUrl: '$_basePath/arroz_faraon.png',
      codigosBarras: ['7758950001099', '7754294000071', '7750109004058'],
      keywords: ['5kg', '750g', 'anejo', 'arroz', 'extra', 'faraon', 'naranja'],
    ),
    ProductoStudioFoto(
      id: 'aceite_primor',
      nombre: 'Aceite Vegetal Primor Premium 900ml',
      marca: 'Primor',
      categoria: 'Abarrotes y Despensa',
      imagenUrl: '$_basePath/aceite_primor.png',
      codigosBarras: ['7750109004065', '7750109004102'],
      keywords: ['1l', '900ml', 'aceite', 'premium', 'primor', 'vegetal'],
    ),
    ProductoStudioFoto(
      id: 'fideos_spaghetti_don_vittorio',
      nombre: 'Fideos Spaghetti Don Vittorio Duopack 950g',
      marca: 'Don Vittorio',
      categoria: 'Abarrotes y Despensa',
      imagenUrl: '$_basePath/fideos_spaghetti_don_vittorio.png',
      codigosBarras: ['7750109004010'],
      keywords: ['450g', '950g', 'don', 'fideos', 'spaghetti', 'vittorio'],
    ),
    ProductoStudioFoto(
      id: 'fideos_codito_don_vittorio',
      nombre: 'Fideos Don Vittorio Codo Rayado 250g',
      marca: 'Don Vittorio',
      categoria: 'Abarrotes y Despensa',
      imagenUrl: '$_basePath/fideos_codito_don_vittorio.png',
      codigosBarras: ['7750109004027', '7750109004225'],
      keywords: ['250g', '450g', 'codo', 'codito', 'don', 'fideos', 'rayado', 'vittorio'],
    ),
    ProductoStudioFoto(
      id: 'fideos_canuto_lavaggi',
      nombre: 'Fideos Cuisine & Co. Canuto Rayado 450g',
      marca: 'Cuisine & Co.',
      categoria: 'Abarrotes y Despensa',
      imagenUrl: '$_basePath/fideos_canuto_lavaggi.png',
      codigosBarras: ['7750109004034', '7750109004218'],
      keywords: ['450g', 'canuto', 'cuisine', 'fideos', 'lavaggi', 'rayado'],
    ),
    ProductoStudioFoto(
      id: 'atun_primor',
      nombre: 'Trozos de Atún Primor en Aceite 140g',
      marca: 'Primor',
      categoria: 'Abarrotes y Despensa',
      imagenUrl: '$_basePath/atun_primor.png',
      codigosBarras: ['7750109004072', '7750109004172'],
      keywords: ['140g', '170g', 'aceite', 'atun', 'primor', 'trozos'],
    ),
    ProductoStudioFoto(
      id: 'atun_fanny',
      nombre: 'Trozos de Atún en Aceite Vegetal Fanny 140g',
      marca: 'Fanny',
      categoria: 'Abarrotes y Despensa',
      imagenUrl: '$_basePath/atun_fanny.png',
      codigosBarras: ['7750885020343', '7750109004089'],
      keywords: ['140g', '170g', 'aceite', 'atun', 'fanny', 'trozos', 'filete'],
    ),
    ProductoStudioFoto(
      id: 'mayonesa_alacena',
      nombre: 'Mayonesa AlaCena Regular Doypack 850g',
      marca: 'AlaCena',
      categoria: 'Abarrotes y Despensa',
      imagenUrl: '$_basePath/mayonesa_alacena.png',
      codigosBarras: ['7750243072366', '7750109004164', '7750109004190'],
      keywords: ['850g', '950g', '95g', 'alacena', 'doypack', 'mayonesa', 'regular'],
    ),
    ProductoStudioFoto(
      id: 'crema_tari',
      nombre: 'Crema de Ají Tarí AlaCena Doypack 400g',
      marca: 'AlaCena',
      categoria: 'Abarrotes y Despensa',
      imagenUrl: '$_basePath/crema_tari.png',
      codigosBarras: ['7750243030335', '7750109004140', '7750114009146'],
      keywords: ['400g', '85g', 'aji', 'alacena', 'crema', 'doypack', 'tari'],
    ),

    // --- PANADERÍA Y DESAYUNO ---
    ProductoStudioFoto(
      id: 'pan_bimbo_blanco',
      nombre: 'Pan de Molde Bimbo Blanco Familiar 590g',
      marca: 'Bimbo',
      categoria: 'Panadería y Desayuno',
      imagenUrl: '$_basePath/pan_bimbo_blanco.png',
      codigosBarras: ['7750727014189', '7750116011018', '7750116011117'],
      keywords: ['400g', '590g', '650g', 'bimbo', 'blanco', 'familiar', 'molde', 'pan'],
    ),
    ProductoStudioFoto(
      id: 'pan_bimbo_integral',
      nombre: 'Pan de Molde 100% Integral Bimbo 620g',
      marca: 'Bimbo',
      categoria: 'Panadería y Desayuno',
      imagenUrl: '$_basePath/pan_bimbo_integral.png',
      codigosBarras: ['7750116011025'],
      keywords: ['400g', '620g', 'bimbo', 'integral', 'molde', 'pan'],
    ),
    ProductoStudioFoto(
      id: 'avena_tres_ositos',
      nombre: 'Avena Clásica Precocida Tres Ositos Bolsa 500g',
      marca: 'Tres Ositos',
      categoria: 'Panadería y Desayuno',
      imagenUrl: '$_basePath/avena_tres_ositos.png',
      codigosBarras: ['7750116011056'],
      keywords: ['135g', '250g', '500g', 'avena', 'ositos', 'precocida', 'tres'],
    ),
    ProductoStudioFoto(
      id: 'cafe_nescafe',
      nombre: 'Café Soluble Nescafé Tradición Frasco 50g',
      marca: 'Nescafé',
      categoria: 'Panadería y Desayuno',
      imagenUrl: '$_basePath/cafe_nescafe.png',
      codigosBarras: ['7750116011049', '7750116011148'],
      keywords: ['100g', '50g', 'cafe', 'frasco', 'nescafe', 'soluble', 'tradicion'],
    ),
    ProductoStudioFoto(
      id: 'mermelada_gloria',
      nombre: 'Mermelada de Fresa Gloria Vaso 310g',
      marca: 'Gloria',
      categoria: 'Panadería y Desayuno',
      imagenUrl: '$_basePath/mermelada_gloria.png',
      codigosBarras: ['7750116011032'],
      keywords: ['310g', 'fresa', 'gloria', 'mermelada', 'vaso'],
    ),

    // --- GOLOSINAS Y CHOCOLATES ---
    ProductoStudioFoto(
      id: 'chocolate_sublime',
      nombre: 'Chocolate con Leche Sublime Clásico Tableta 100g',
      marca: 'Nestlé',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/chocolate_sublime.png',
      codigosBarras: ['7613036615303', '7750115010011', '7750115010110'],
      keywords: ['100g', '30g', 'chocolate', 'clasico', 'leche', 'nestle', 'sublime', 'tableta'],
    ),
    ProductoStudioFoto(
      id: 'chocolate_triangulo',
      nombre: "Brownie Clásico Triángulo D'Onofrio 50g",
      marca: "D'Onofrio",
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/chocolate_triangulo.png',
      codigosBarras: ['7750115010028'],
      keywords: ['30g', '50g', 'brownie', 'chocolate', 'donofrio', 'triangulo'],
    ),
    ProductoStudioFoto(
      id: 'galleta_oreo',
      nombre: 'Galletas Oreo Original Taco 135g',
      marca: 'Oreo',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/galleta_oreo.png',
      codigosBarras: ['7622202217494', '7622201685683', '7750115010080'],
      keywords: ['108g', '135g', '36g', 'galleta', 'galletas', 'oreo', 'original', 'taco', 'tubo'],
    ),
    ProductoStudioFoto(
      id: 'galleta_casino',
      nombre: 'Galletas Casino Sabor a Fresa 129g',
      marca: 'Victoria',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/galleta_casino.png',
      codigosBarras: ['7750115010059', '7750115010158', '7750115010257'],
      keywords: ['129g', '68g', 'casino', 'fresa', 'galleta', 'galletas', 'victoria'],
    ),
    ProductoStudioFoto(
      id: 'galleta_margarita',
      nombre: 'Galletas Margarita Victoria Pack x6 246g',
      marca: 'Victoria',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/galleta_margarita.png',
      codigosBarras: ['7750115010066'],
      keywords: ['246g', '80g', 'clasica', 'galleta', 'galletas', 'margarita', 'victoria'],
    ),
    ProductoStudioFoto(
      id: 'galleta_tentacion',
      nombre: 'Galletas Tentación Chocolate Victoria Pack x6 258g',
      marca: 'Victoria',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/galleta_tentacion.png',
      codigosBarras: ['7750115010073'],
      keywords: ['258g', '70g', 'chocolate', 'galleta', 'galletas', 'tentacion', 'victoria'],
    ),
    ProductoStudioFoto(
      id: 'galleta_dona_pepa',
      nombre: 'Galleta Doña Pepa Field 23g',
      marca: 'Field',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/galleta_dona_pepa.png',
      codigosBarras: ['7750115010042'],
      keywords: ['23g', 'chocolate', 'dona', 'field', 'galleta', 'grageas', 'pepa'],
    ),
    ProductoStudioFoto(
      id: 'galleta_cua_cua',
      nombre: 'Wafer Cua Cua Field Chocolate 18g',
      marca: 'Field',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/galleta_cua_cua.png',
      codigosBarras: ['7750115010035'],
      keywords: ['18g', 'chocolate', 'cua', 'field', 'galleta', 'wafer'],
    ),
    ProductoStudioFoto(
      id: 'halls_menta',
      nombre: 'Pastillas Halls Extra Fuerte Menta',
      marca: 'Halls',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/halls_menta.png',
      codigosBarras: ['7750115010097'],
      keywords: ['fuerte', 'halls', 'menta', 'pastillas'],
    ),
    ProductoStudioFoto(
      id: 'caramelos_chicho',
      nombre: 'Caramelos Ambrosoli Gajos Surtidos Bolsa 390g',
      marca: 'Ambrosoli',
      categoria: 'Golosinas y Chocolates',
      imagenUrl: '$_basePath/caramelos_chicho.png',
      codigosBarras: ['7750115010103'],
      keywords: ['100g', '390g', 'ambrosoli', 'caramelos', 'chicho', 'fruta', 'gajos', 'surtidos'],
    ),

    // --- HELADOS Y CONGELADOS ---
    ProductoStudioFoto(
      id: 'helado_sublime',
      nombre: "Helado Sublime D'Onofrio Paleta",
      marca: "D'Onofrio",
      categoria: 'Helados y Congelados',
      imagenUrl: '$_basePath/helado_sublime.png',
      codigosBarras: ['7750110005017'],
      keywords: ['donofrio', 'helado', 'paleta', 'sublime'],
    ),
    ProductoStudioFoto(
      id: 'helado_jet',
      nombre: "Helado Jet Chocolate D'Onofrio Paleta",
      marca: "D'Onofrio",
      categoria: 'Helados y Congelados',
      imagenUrl: '$_basePath/helado_jet.png',
      codigosBarras: ['7750110005062'],
      keywords: ['chocolate', 'donofrio', 'helado', 'jet', 'paleta'],
    ),
    ProductoStudioFoto(
      id: 'helado_frio_rico',
      nombre: "Helado Frío Rico D'Onofrio Multipack Vainilla Caja x4",
      marca: "D'Onofrio",
      categoria: 'Helados y Congelados',
      imagenUrl: '$_basePath/helado_frio_rico.png',
      codigosBarras: ['7613287065261', '7750110005031'],
      keywords: ['cono', 'donofrio', 'frio', 'helado', 'multipack', 'rico', 'vainilla'],
    ),
    ProductoStudioFoto(
      id: 'helado_peziduri_tricolor',
      nombre: "Helado Peziduri Tricolor D'Onofrio Pote 900ml",
      marca: "D'Onofrio",
      categoria: 'Helados y Congelados',
      imagenUrl: '$_basePath/helado_peziduri_tricolor.png',
      codigosBarras: ['7613287023568', '7750110005048'],
      keywords: ['1l', '2.2l', '900ml', 'donofrio', 'helado', 'peziduri', 'pote', 'tricolor'],
    ),
    ProductoStudioFoto(
      id: 'helado_peziduri_vainilla',
      nombre: "Helado Peziduri Vainilla D'Onofrio Pote 900ml",
      marca: "D'Onofrio",
      categoria: 'Helados y Congelados',
      imagenUrl: '$_basePath/helado_peziduri_vainilla.png',
      codigosBarras: ['7750110005055'],
      keywords: ['1l', '900ml', 'donofrio', 'helado', 'peziduri', 'pote', 'vainilla'],
    ),
    ProductoStudioFoto(
      id: 'helado_sin_parar',
      nombre: 'Helado Cuisine & Co. Lúcuma Chips 900ml',
      marca: 'Cuisine & Co.',
      categoria: 'Helados y Congelados',
      imagenUrl: '$_basePath/helado_sin_parar.png',
      codigosBarras: ['7750110005024'],
      keywords: ['900ml', 'chips', 'cuisine', 'donofrio', 'helado', 'lucuma', 'parar', 'sin'],
    ),

    // --- LIMPIEZA Y CUIDADO DEL HOGAR ---
    ProductoStudioFoto(
      id: 'detergente_bolivar',
      nombre: 'Detergente Bolívar Cuidado Total Bolsa 9kg',
      marca: 'Bolívar',
      categoria: 'Limpieza y Cuidado del Hogar',
      imagenUrl: '$_basePath/detergente_bolivar.png',
      codigosBarras: ['7750114009015', '7750114009114'],
      keywords: ['2.6kg', '850g', '9kg', 'activo', 'blanco', 'bolivar', 'cuidado', 'detergente', 'total'],
    ),
    ProductoStudioFoto(
      id: 'detergente_ace',
      nombre: 'Detergente Ace Regular Bolsa 1.7kg',
      marca: 'Ace',
      categoria: 'Limpieza y Cuidado del Hogar',
      imagenUrl: '$_basePath/detergente_ace.png',
      codigosBarras: ['7750114009022'],
      keywords: ['1.7kg', '800g', 'ace', 'detergente', 'polvo', 'regular'],
    ),
    ProductoStudioFoto(
      id: 'detergente_opal',
      nombre: 'Detergente Opal Ultra Bolsa 730g',
      marca: 'Opal',
      categoria: 'Limpieza y Cuidado del Hogar',
      imagenUrl: '$_basePath/detergente_opal.png',
      codigosBarras: ['7750114009039', '7750243080590'],
      keywords: ['730g', '750g', 'detergente', 'opal', 'ultra'],
    ),
    ProductoStudioFoto(
      id: 'suavizante_suavitel',
      nombre: 'Suavizante Suavitel Fresca Primavera 2.3L',
      marca: 'Suavitel',
      categoria: 'Limpieza y Cuidado del Hogar',
      imagenUrl: '$_basePath/suavizante_suavitel.png',
      codigosBarras: ['7750114009046'],
      keywords: ['2.3l', '850ml', 'fresca', 'primavera', 'suavizante', 'suavitel'],
    ),
    ProductoStudioFoto(
      id: 'limpiador_poett',
      nombre: 'Limpiador Líquido Poett Lavanda Maxigalón 4.5L',
      marca: 'Poett',
      categoria: 'Limpieza y Cuidado del Hogar',
      imagenUrl: '$_basePath/limpiador_poett.png',
      codigosBarras: ['7750114009053'],
      keywords: ['4.5l', '900ml', 'lavanda', 'limpiador', 'liquido', 'maxigalon', 'poett'],
    ),
    ProductoStudioFoto(
      id: 'lejia_clorox',
      nombre: 'Lejía Clorox Tradicional 1 Litro',
      marca: 'Clorox',
      categoria: 'Limpieza y Cuidado del Hogar',
      imagenUrl: '$_basePath/lejia_clorox.png',
      codigosBarras: ['7750114009060', '7750114009169'],
      keywords: ['1l', '2l', 'clorox', 'desinfectante', 'lejia', 'tradicional'],
    ),
    ProductoStudioFoto(
      id: 'lavavajilla_ayudin',
      nombre: 'Lavavajilla Líquido Ayudín Lima Limón 900ml',
      marca: 'Ayudín',
      categoria: 'Limpieza y Cuidado del Hogar',
      imagenUrl: '$_basePath/lavavajilla_ayudin.png',
      codigosBarras: ['7759918006163', '7750114009077', '7750114009213'],
      keywords: ['350g', '900ml', 'ayudin', 'lavavajilla', 'lima', 'limon', 'liquido', 'pasta'],
    ),
    ProductoStudioFoto(
      id: 'lavavajilla_sapolio',
      nombre: 'Lavavajilla en Pasta Sapolio Limón 800g',
      marca: 'Sapolio',
      categoria: 'Limpieza y Cuidado del Hogar',
      imagenUrl: '$_basePath/lavavajilla_sapolio.png',
      codigosBarras: ['7750114009084'],
      keywords: ['800g', 'lavavajilla', 'limon', 'pasta', 'sapolio'],
    ),

    // --- CUIDADO PERSONAL Y DENTAL ---
    ProductoStudioFoto(
      id: 'colgate_total12',
      nombre: 'Crema Dental Colgate Total 12 Limpieza 75ml',
      marca: 'Colgate',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/colgate_total12.png',
      codigosBarras: ['7750113008025'],
      keywords: ['12', '75ml', 'colgate', 'crema', 'dental', 'total'],
    ),
    ProductoStudioFoto(
      id: 'colgate_triple_accion',
      nombre: 'Crema Dental Colgate Triple Acción 150ml',
      marca: 'Colgate',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/colgate_triple_accion.png',
      codigosBarras: ['7750113008032'],
      keywords: ['150ml', '75ml', 'accion', 'colgate', 'crema', 'dental', 'triple'],
    ),
    ProductoStudioFoto(
      id: 'cepillo_colgate',
      nombre: 'Cepillo Dental Colgate Zig Zag Medio',
      marca: 'Colgate',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/cepillo_colgate.png',
      codigosBarras: ['7750113008049'],
      keywords: ['cepillo', 'colgate', 'dental', 'medio', 'zag', 'zig'],
    ),
    ProductoStudioFoto(
      id: 'shampoo_head_shoulders',
      nombre: 'Shampoo Head & Shoulders Hidratación 1L',
      marca: 'Head & Shoulders',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/shampoo_head_shoulders.png',
      codigosBarras: ['7750113008056'],
      keywords: ['1l', '375ml', 'head', 'hidratacion', 'shampoo', 'shoulders'],
    ),
    ProductoStudioFoto(
      id: 'shampoo_pantene',
      nombre: 'Shampoo Pantene Restauración 700ml',
      marca: 'Pantene',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/shampoo_pantene.png',
      codigosBarras: ['7750113008063'],
      keywords: ['400ml', '700ml', 'pantene', 'restauracion', 'shampoo'],
    ),
    ProductoStudioFoto(
      id: 'jabon_palmolive',
      nombre: 'Jabón Palmolive Naturals Oliva 3 unid',
      marca: 'Palmolive',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/jabon_palmolive.png',
      codigosBarras: ['7750113008070'],
      keywords: ['jabon', 'naturals', 'oliva', 'palmolive', 'unid'],
    ),
    ProductoStudioFoto(
      id: 'jabon_camay',
      nombre: 'Jabón Camay Romántica 3 unid',
      marca: 'Camay',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/jabon_camay.png',
      codigosBarras: ['7750113008087'],
      keywords: ['camay', 'jabon', 'romantica', 'unid'],
    ),
    ProductoStudioFoto(
      id: 'desodorante_rexona',
      nombre: 'Desodorante Rexona Men Antibacterial Aerosol 150ml',
      marca: 'Rexona',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/desodorante_rexona.png',
      codigosBarras: ['7750113008094'],
      keywords: ['150ml', 'aerosol', 'antibacterial', 'desodorante', 'men', 'rexona'],
    ),
    ProductoStudioFoto(
      id: 'desodorante_axe',
      nombre: 'Desodorante Axe Black Aerosol 150ml',
      marca: 'Axe',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/desodorante_axe.png',
      codigosBarras: ['7750113008100'],
      keywords: ['150ml', 'aerosol', 'axe', 'black', 'desodorante'],
    ),
    ProductoStudioFoto(
      id: 'papel_higienico_suave',
      nombre: 'Papel Higiénico Suave Rindemax x4 rollos',
      marca: 'Suave',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/papel_higienico_suave.png',
      codigosBarras: ['7750113008117'],
      keywords: ['higienico', 'papel', 'rindemax', 'rollos', 'suave'],
    ),
    ProductoStudioFoto(
      id: 'papel_higienico_elite',
      nombre: 'Papel Higiénico Elite Doble Hoja x4 rollos',
      marca: 'Elite',
      categoria: 'Cuidado Personal y Dental',
      imagenUrl: '$_basePath/papel_higienico_elite.png',
      codigosBarras: ['7750113008124'],
      keywords: ['doble', 'elite', 'higienico', 'hoja', 'papel', 'rollos'],
    ),

    // --- CIGARRILLOS Y TABACO ---
    ProductoStudioFoto(
      id: 'cigarros_marlboro_20',
      nombre: 'Cigarrillos Marlboro Summer Mix Cajetilla 20',
      marca: 'Marlboro',
      categoria: 'Cigarrillos y Tabaco',
      imagenUrl: '$_basePath/cigarros_marlboro_20.png',
      codigosBarras: ['7751201001169', '7750112007011'],
      keywords: ['20', 'cajetilla', 'cigarros', 'cigarrillos', 'hamilton', 'marlboro', 'mix', 'summer'],
    ),
    ProductoStudioFoto(
      id: 'cigarros_lucky_strike',
      nombre: 'Cigarros Lucky Strike Double Click Box x20',
      marca: 'Lucky Strike',
      categoria: 'Cigarrillos y Tabaco',
      imagenUrl: '$_basePath/cigarros_lucky_strike.png',
      codigosBarras: ['77561725', '7750112007028'],
      keywords: ['20', 'box', 'cigarros', 'click', 'double', 'lucky', 'strike'],
    ),
    ProductoStudioFoto(
      id: 'cigarros_pall_mall',
      nombre: 'Cigarros Pall Mall Click Box x20',
      marca: 'Pall Mall',
      categoria: 'Cigarrillos y Tabaco',
      imagenUrl: '$_basePath/cigarros_pall_mall.png',
      codigosBarras: ['7750112007035'],
      keywords: ['20', 'box', 'cigarros', 'click', 'mall', 'pall'],
    ),
  ];

  static String _normalizar(String input) {
    var out = input.toLowerCase().trim();
    out = out.replaceAll('á', 'a')
             .replaceAll('é', 'e')
             .replaceAll('í', 'i')
             .replaceAll('ó', 'o')
             .replaceAll('ú', 'u')
             .replaceAll('ñ', 'n');
    return out;
  }

  /// Stopwords puramente gramaticales. Los tamaños, unidades y formatos
  /// (500ml, 3L, 140g) NUNCA deben ser stopwords porque son discriminadores clave.
  static const Set<String> _stopwords = {
    'de', 'en', 'la', 'el', 'los', 'las', 'del', 'con', 'sin', 'por', 'para',
    'y', 'un', 'una', 'al', 'o'
  };

  /// Extrae unidades de volumen o peso normalizadas (ej: "500ml", "3l", "140g")
  static Set<String> _extraerTamanos(String texto) {
    var norm = _normalizar(texto);
    norm = norm.replaceAllMapped(RegExp(r'(\d+(?:\.\d+)?)\s*(?:l|lt|litro|litros)\b'), (m) => '${m[1]}l');
    norm = norm.replaceAllMapped(RegExp(r'(\d+(?:\.\d+)?)\s*(?:ml|mililitros)\b'), (m) => '${m[1]}ml');
    norm = norm.replaceAllMapped(RegExp(r'(\d+(?:\.\d+)?)\s*(?:g|gr|gramos)\b'), (m) => '${m[1]}g');
    norm = norm.replaceAllMapped(RegExp(r'(\d+(?:\.\d+)?)\s*(?:kg|kilos)\b'), (m) => '${m[1]}kg');

    final matches = RegExp(r'\b\d+(?:\.\d+)?[a-z]+\b').allMatches(norm);
    final results = <String>{};
    for (final m in matches) {
      final val = m.group(0)!;
      if (val.endsWith('ml') || val.endsWith('l') || val.endsWith('g') || val.endsWith('kg')) {
        results.add(val);
      }
    }
    return results;
  }

  /// Busca una foto oficial de estudio por código de barras o por nombre del producto
  static ProductoStudioFoto? buscarSugerencia({String? codigoBarras, String? nombre}) {
    // 1. Prioridad: Coincidencia exacta por Código de Barras (EAN-13)
    if (codigoBarras != null && codigoBarras.trim().isNotEmpty) {
      final code = codigoBarras.trim();
      for (final item in _catalogoMaestro) {
        if (item.codigosBarras.contains(code)) {
          return item;
        }
      }
    }

    // 2. Coincidencia inteligente ponderada por Nombre / Keywords / Tamaño
    if (nombre != null && nombre.trim().isNotEmpty) {
      final normNombre = _normalizar(nombre);
      if (normNombre.length >= 3) {
        final querySizes = _extraerTamanos(normNombre);

        final tokens = normNombre
            .split(RegExp(r'[^a-zA-Z0-9]+'))
            .where((t) => t.isNotEmpty && !_stopwords.contains(t))
            .toSet();

        ProductoStudioFoto? mejorItem;
        int mejorScore = 0;

        for (final item in _catalogoMaestro) {
          int score = 0;
          final normItemNombre = _normalizar(item.nombre);
          final normMarca = _normalizar(item.marca);
          final itemSizes = _extraerTamanos(normItemNombre);

          // Ponderación por Marca
          if (normMarca.length >= 3 && !_stopwords.contains(normMarca) && normNombre.contains(normMarca)) {
            score += 4;
          }

          // Ponderación por coincidencia directa de Nombre
          if (normNombre.contains(normItemNombre) || (normNombre.length >= 6 && normItemNombre.contains(normNombre))) {
            score += 5;
          }

          // Ponderación discriminatoria por TAMAÑO (ml, L, g, kg)
          // Si el usuario especificó tamaño y coincide con el producto: +6 puntos
          // Si especificó tamaño y difiere diametralmente (ej: 500ml vs 3L): penalización de -8 puntos
          if (querySizes.isNotEmpty && itemSizes.isNotEmpty) {
            final coinciden = querySizes.intersection(itemSizes);
            if (coinciden.isNotEmpty) {
              score += 6;
            } else {
              score -= 8;
            }
          }

          // Ponderación por tokens y keywords
          for (final kw in item.keywords) {
            final normKw = _normalizar(kw);
            if (_stopwords.contains(normKw) || normKw.length < 2) continue;
            if (tokens.contains(normKw)) {
              score += 2;
            } else if (normKw.length >= 4 && normNombre.contains(normKw)) {
              score += 1;
            }
          }

          if (score > mejorScore) {
            mejorScore = score;
            mejorItem = item;
          }
        }

        if (mejorScore >= 4) {
          return mejorItem;
        }
      }
    }

    return null;
  }

  /// Retorna todo el catálogo maestro organizado para la galería de estudio
  static List<ProductoStudioFoto> getCatalogoMaestro() {
    return List.unmodifiable(_catalogoMaestro);
  }

  /// Busca en el catálogo maestro por texto
  static List<ProductoStudioFoto> buscarEnCatalogo(String query) {
    if (query.trim().isEmpty) return getCatalogoMaestro();
    final norm = _normalizar(query);
    return _catalogoMaestro.where((item) {
      if (_normalizar(item.nombre).contains(norm)) return true;
      if (_normalizar(item.marca).contains(norm)) return true;
      if (_normalizar(item.categoria).contains(norm)) return true;
      for (final kw in item.keywords) {
        if (_normalizar(kw).contains(norm)) return true;
      }
      return false;
    }).toList();
  }
}
