import 'catalogo_imagenes_service.dart';
import '../features/categorias/categoria_model.dart';

/// Categorías canónicas estándar reconocidas en el comercio minorista y bodegas peruanas.
enum CategoriaCanonica {
  bebidasGaseosas,
  licoresCervezas,
  lacteosHuevos,
  abarrotesDespensa,
  snacksPiqueos,
  golosinasChocolates,
  embutidosFiambres,
  panaderiaDesayunos,
  limpiezaHogar,
  cuidadoPersonal,
  farmaciaBotiquin,
  heladosCongelados,
  mascotas,
  frutasVerduras,
  cigarrillosTabaco,
  libreriaBazar,
}

/// Metadatos estructurados de una categoría canónica
class InfoCategoriaCanonica {
  final CategoriaCanonica canonica;
  final String prefijo;
  final String nombreEstandar;
  final List<String> aliases;
  final List<String> frasesClave;
  final List<String> palabrasClave;

  const InfoCategoriaCanonica({
    required this.canonica,
    required this.prefijo,
    required this.nombreEstandar,
    required this.aliases,
    required this.frasesClave,
    required this.palabrasClave,
  });
}

/// Resultado de recomendación analítica
class SugerenciaCategoriaResult {
  final Categoria categoria;
  final CategoriaCanonica canonica;
  final String prefijoCodigo;
  final double confianza; // 0.0 a 1.0
  final String origen; // 'catalogo_packshot' | 'keyword_semantico'

  const SugerenciaCategoriaResult({
    required this.categoria,
    required this.canonica,
    required this.prefijoCodigo,
    required this.confianza,
    required this.origen,
  });
}

/// Servicio Inteligente de Sugerencia y Recomendación Automática de Categorías
///
/// Motor semántico de alta precisión diseñado específicamente para bodegas y retail peruano.
/// Interpreta más de 500 marcas, variantes, productos de despensa y empaques típicos,
/// integrándose con el catálogo de Packshots oficiales y mapeando de forma flexible
/// a las categorías reales que la bodega tenga configuradas.
class CategoriaSuggesterService {
  CategoriaSuggesterService._();

  static const Map<CategoriaCanonica, InfoCategoriaCanonica> _catalogoCanonico = {
    CategoriaCanonica.bebidasGaseosas: InfoCategoriaCanonica(
      canonica: CategoriaCanonica.bebidasGaseosas,
      prefijo: 'GSE',
      nombreEstandar: 'Gaseosas y Bebidas',
      aliases: [
        'gaseosa', 'gaseosas', 'bebida', 'bebidas', 'agua', 'aguas',
        'refresco', 'refrescos', 'jugo', 'jugos', 'nectar', 'nectares',
        'rehidratante', 'rehidratantes', 'energizante', 'energizantes', 'soda'
      ],
      frasesClave: [
        'inka kola', 'inca kola', 'inka cola', 'coca cola', 'kola inglesa',
        'fanta naranja', 'fanta kolita', 'guarana antarctica', 'viva fanta',
        'triple kola', 'kola real', 'big cola', 'isaac kola', 'agua mineral',
        'agua con gas', 'agua sin gas', 'agua de mesa', 'bidon de agua',
        'agua san luis', 'agua cielo', 'agua san mateo', 'agua socosani',
        'agua loa', 'agua vida', 'agua benedictino', 'volt blue', 'volt maca',
        'volt ginseng', 'monster energy', 'red bull', 'frugos del valle',
        'del valle', 'chicha morada', 'te helado', 'ice tea', 'cifrut citrus',
        'pulp durazno', 'sporade maracuya', 'gatorade frutas', 'tampico citrus'
      ],
      palabrasClave: [
        'gaseosa', 'gaseosas', 'fanta', 'sprite', 'guarana', 'concordia',
        'perucola', 'ciel', 'cielo', 'sporade', 'gatorade', 'powerade',
        'volt', 'monster', 'ciclon', 'amper', 'frugos', 'pulp', 'cifrut',
        'tampico', 'zuko', 'tang', 'kanu', 'electrolit', 'electrolitos',
        'rehidratante', 'energizante', 'jugo', 'nectar'
      ],
    ),

    CategoriaCanonica.licoresCervezas: InfoCategoriaCanonica(
      canonica: CategoriaCanonica.licoresCervezas,
      prefijo: 'ALC',
      nombreEstandar: 'Cervezas y Licores',
      aliases: [
        'cerveza', 'cervezas', 'licor', 'licores', 'alcohol', 'alcoholes',
        'vino', 'vinos', 'pisco', 'piscos', 'trago', 'tragos', 'destilados'
      ],
      frasesClave: [
        'pilsen callao', 'cusqueña dorada', 'cusqueña negra', 'cusqueña trigo',
        'cusqueña doble malta', 'cerveza cristal', 'cerveza pilsen', 'cerveza cusqueña',
        'corona extra', 'stella artois', 'tres cruces', 'six pack cerveza',
        'santiago queirolo', 'vino queirolo', 'vino tabernero', 'vino ocucaje',
        'vino tacama', 'casillero del diablo', 'gato negro', 'fond de cave',
        'vino tinto', 'vino blanco', 'vino rose', 'vino borgoña', 'vino dulce',
        'pisco porton', 'cuatro gallos', 'pisco vargas', 'pisco biondi',
        'pisco sour', 'mosto verde', 'pisco quebranta', 'pisco acholado',
        'ron cartavio', 'cartavio black', 'cartavio selecto', 'flor de caña',
        'havana club', 'captain morgan', 'johnnie walker', 'red label',
        'black label', 'double black', 'gold label', 'chivas regal',
        'jack daniels', 'old parr', 'something special', 'ballantines',
        'vodka russkaya', 'vodka smirnoff', 'vodka absolut', 'gin tanqueray',
        'beefeater gin', 'bombay sapphire', 'jose cuervo', 'anis najar'
      ],
      palabrasClave: [
        'cerveza', 'cervezas', 'chela', 'chelas', 'pilsen', 'cusqueña', 'cusquena',
        'cristal', 'heineken', 'budweiser', 'miller', 'brahma', 'barbarian',
        'cumbres', 'chop', 'laton', 'vino', 'vinos', 'borgoña', 'tabernero',
        'queirolo', 'ocucaje', 'tacama', 'pisco', 'acholado', 'quebranta',
        'whisky', 'whiskey', 'chivas', 'vodka', 'russkaya', 'absolut',
        'smirnoff', 'tequila', 'cuervo', 'jagermeister', 'campari', 'baileys'
      ],
    ),

    CategoriaCanonica.lacteosHuevos: InfoCategoriaCanonica(
      canonica: CategoriaCanonica.lacteosHuevos,
      prefijo: 'LAC',
      nombreEstandar: 'Lácteos y Derivados',
      aliases: [
        'lacteo', 'lacteos', 'leche', 'leches', 'yogur', 'yogurt', 'yogurts',
        'mantequilla', 'mantequillas', 'queso', 'quesos', 'huevo', 'huevos'
      ],
      frasesClave: [
        'leche gloria', 'leche evaporada', 'leche entera', 'leche descremada',
        'leche semidescremada', 'leche sin lactosa', 'leche light', 'gloria azul',
        'gloria roja', 'gloria amarilla', 'gloria morada', 'leche laive',
        'pura vida', 'soy vida', 'bonle leche', 'ideal amanecer', 'ideal cremosita',
        'leche condensada', 'condensada nestle', 'leche en polvo', 'chocolatada gloria',
        'chocolatada laive', 'yogurt gloria', 'yogur gloria', 'yogurt laive',
        'yogurt danlac', 'yogurt milkito', 'yogurt griego', 'yogurt frutado',
        'yogurt bebible', 'mantequilla gloria', 'mantequilla laive', 'sello de oro',
        'queso fresco', 'queso andino', 'queso paria', 'queso edam',
        'queso mozzarella', 'queso gouda', 'queso mantecoso', 'queso crema',
        'queso parmesano', 'queso bonle', 'huevos rosados', 'huevos pardos',
        'cubeta de huevos', 'jaba de huevos', 'huevo de codorniz'
      ],
      palabrasClave: [
        'leche', 'leches', 'lactea', 'evaporada', 'chocolatada', 'yogur',
        'yogurt', 'yogurts', 'danlac', 'milkito', 'mantequilla', 'margarina',
        'manty', 'dorina', 'queso', 'quesos', 'mozzarella', 'parmesano',
        'huevo', 'huevos'
      ],
    ),

    CategoriaCanonica.abarrotesDespensa: InfoCategoriaCanonica(
      canonica: CategoriaCanonica.abarrotesDespensa,
      prefijo: 'ABA',
      nombreEstandar: 'Abarrotes y Despensa',
      aliases: [
        'abarrote', 'abarrotes', 'despensa', 'comestible', 'comestibles',
        'grano', 'granos', 'fideo', 'fideos', 'conserva', 'conservas'
      ],
      frasesClave: [
        'arroz costeño', 'arroz faraon', 'arroz paisana', 'arroz samana',
        'arroz extra', 'arroz superior', 'azucar rubia', 'azucar blanca',
        'azucar paramonga', 'aceite primor', 'primor premium', 'primor clasico',
        'aceite cocinero', 'aceite cilantro', 'aceite capri', 'aceite sao',
        'aceite vegetal', 'aceite de oliva', 'aceite de girasol',
        'don vittorio', 'fideos lavaggi', 'fideos molitalia', 'cabello de angel',
        'sopa de letras', 'filete de atun', 'grated de atun', 'lomito de atun',
        'atun gloria', 'atun fanny', 'atun campomar', 'atun primor',
        'atun bayovar', 'sardinas en tomate', 'duraznos al jugo', 'coctel de frutas',
        'lentejas costeño', 'frejol canario', 'frejol caballero', 'frejol panamito',
        'harina blanca flor', 'blanca flor', 'harina preparada', 'harina sin preparar',
        'polvo de hornear', 'salsa de tomate', 'pasta de tomate', 'tuco sibarita',
        'doña gusta', 'caldo maggi', 'caldo de gallina', 'sopa instantanea',
        'sillao kiko', 'salsa de soya', 'salsa de ostion', 'vinagre compadre',
        'mayonesa alacena', 'ketchup alacena', 'mostaza alacena', 'salsa tari',
        'salsa huancaina', 'sal emsal', 'sal de mesa', 'sal marina'
      ],
      palabrasClave: [
        'arroz', 'azucar', 'panela', 'chancaca', 'aceite', 'fideo', 'fideos',
        'tallarin', 'tallarines', 'spaghetti', 'espagueti', 'codito', 'canuto',
        'tornillo', 'corbata', 'molitalia', 'lavaggi', 'atun', 'grated',
        'lomito', 'caballa', 'sardina', 'sardinas', 'anchoveta', 'menestra',
        'menestras', 'lenteja', 'lentejas', 'frejol', 'frijol', 'garbanzo',
        'garbanzos', 'pallares', 'arvejita', 'alverja', 'harina', 'maicena',
        'chuño', 'sibarita', 'ajinomen', 'maruchan', 'ramen', 'ajinomoto',
        'umami', 'sillao', 'vinagre', 'alacena', 'mayonesa', 'ketchup',
        'mostaza', 'huancaina', 'uchucuta', 'comino', 'pimienta', 'palillo',
        'aceituna', 'aceitunas'
      ],
    ),

    CategoriaCanonica.snacksPiqueos: InfoCategoriaCanonica(
      canonica: CategoriaCanonica.snacksPiqueos,
      prefijo: 'SNK',
      nombreEstandar: 'Snacks y Piqueos',
      aliases: [
        'snack', 'snacks', 'piqueo', 'piqueos', 'frito', 'fritos',
        'chips', 'salado', 'salados'
      ],
      frasesClave: [
        'papas lays', 'lays clasicas', 'lays ondas', 'lays polleria',
        'inka chips', 'papas nativas', 'señor chon', 'papitas al hilo',
        'papas al hilo', 'papas fritas', 'doritos queso', 'doritos mega',
        'cheese tris', 'cuates picante', 'piqueo snax', 'frito lay',
        'chifles piuranos', 'chifle salado', 'chifle dulce', 'mani karinto',
        'mani salado', 'mani confitado', 'mani con pasas', 'habas fritas',
        'habas saladas', 'frutos secos', 'act ii', 'canchita popcorn',
        'club social', 'galletas ritz', 'galleta salticas'
      ],
      palabrasClave: [
        'snack', 'snacks', 'piqueo', 'piqueos', 'lays', 'doritos', 'cheetos',
        'chizito', 'chizitos', 'cuates', 'tortees', 'nachos', 'tostitos',
        'snax', 'pringles', 'tiyapuy', 'chifle', 'chifles', 'karinto',
        'canchita', 'popcorn'
      ],
    ),

    CategoriaCanonica.golosinasChocolates: InfoCategoriaCanonica(
      canonica: CategoriaCanonica.golosinasChocolates,
      prefijo: 'GLS',
      nombreEstandar: 'Golosinas y Chocolates',
      aliases: [
        'golosina', 'golosinas', 'chocolate', 'chocolates', 'dulce', 'dulces',
        'caramelo', 'caramelos', 'chupetin', 'chupetines', 'galleta dulce', 'confiteria'
      ],
      frasesClave: [
        'sublime clasico', 'sublime blanco', 'chocolate sublime', 'triangulo donofrio',
        'cua cua', 'doña pepa', 'dona pepa', 'beso de moza', 'ferrero rocher',
        'kit kat', 'galletas casino', 'casino menta', 'casino fresa',
        'casino chocolate', 'galletas margarita', 'galleta oreo', 'oreo original',
        'chocman', 'rellenitas', 'galletas morochas', 'mini chips',
        'halls menta', 'halls negro', 'halls cherry', 'chupetin chupete',
        'globo pop', 'chiclets adams', 'ositos mogul', 'gomitas fini',
        'gomitas trolli', 'bon o bon'
      ],
      palabrasClave: [
        'chocolate', 'chocolates', 'sublime', 'triangulo', 'princesa',
        'vizzio', 'hershey', 'hersheys', 'snickers', 'margarita', 'casino',
        'tentacion', 'oreo', 'morochas', 'chomp', 'wafer', 'wafers',
        'caramelo', 'caramelos', 'halls', 'chupetin', 'chupetines',
        'fruna', 'frunas', 'toffee', 'toffees', 'sugus', 'ambrosoli',
        'gomita', 'gomitas', 'chicle', 'chicles', 'bubbaloo', 'trident',
        'clorets', 'sparks', 'tic tac', 'mentas'
      ],
    ),

    CategoriaCanonica.embutidosFiambres: InfoCategoriaCanonica(
      canonica: CategoriaCanonica.embutidosFiambres,
      prefijo: 'EMB',
      nombreEstandar: 'Embutidos y Fiambrería',
      aliases: [
        'embutido', 'embutidos', 'fiambreria', 'fiambre', 'fiambres',
        'salchicheria', 'carniceria', 'embutidos y fiambreria'
      ],
      frasesClave: [
        'salchicha huachana', 'hot dog san fernando', 'hot dog braedt',
        'salchicha vienesa', 'salchicha de pollo', 'salchicha frankfurt',
        'jamonada especial', 'jamon ingles', 'jamon del pais', 'tocino ahumado',
        'tocino en tiras', 'chorizo parrillero', 'chorizo fino', 'chorizo cocktail',
        'chorizo amazonico', 'queso edam laive', 'edam laminado',
        'hamburguesa san fernando', 'nuggets de pollo', 'milanesa de pollo'
      ],
      palabrasClave: [
        'salchicha', 'salchichas', 'hotdog', 'hot dog', 'jamon', 'jamonada',
        'tocino', 'chorizo', 'chorizos', 'cabanossi', 'morcilla', 'mortadela',
        'braedt', 'otto kunz', 'suiza', 'nuggets', 'milanesa', 'pate'
      ],
    ),

    CategoriaCanonica.panaderiaDesayunos: InfoCategoriaCanonica(
      canonica: CategoriaCanonica.panaderiaDesayunos,
      prefijo: 'PAN',
      nombreEstandar: 'Panadería y Desayunos',
      aliases: [
        'panaderia', 'pan', 'desayuno', 'desayunos', 'reposteria',
        'cafeteria', 'infusion', 'infusiones'
      ],
      frasesClave: [
        'pan de molde', 'pan bimbo', 'pan integral', 'pan blanco', 'pan union',
        'pan hamburguesa', 'pan hot dog', 'pan pita', 'pan ciabatta',
        'pan frances', 'avena 3 ositos', 'tres ositos', 'avena quaker',
        'santa catalina', 'avena con maca', 'angel chock', 'angel flakes',
        'cereales angel', 'choco krispis', 'zucaritas', 'mermelada fanny',
        'mermelada gloria', 'dulce de leche', 'manjar blanco', 'miel de abeja',
        'nescafe tradicion', 'cafe altomayo', 'cafe kirma', 'cafe colcafe',
        'te herbi', 'herbi manzanilla', 'mccolins', 'cocoa winters', 'sol del cusco'
      ],
      palabrasClave: [
        'pan', 'panes', 'bimbo', 'tostada', 'tostadas', 'bizcocho', 'chancay',
        'queque', 'torta', 'pionono', 'paneton', 'avena', 'quaker', 'maca',
        'quinua', 'kiwicha', 'cereal', 'cereales', 'granola', 'mermelada',
        'manjar', 'algarrobina', 'miel', 'cafe', 'nescafe', 'altomayo',
        'kirma', 'colcafe', 'manzanilla', 'anis', 'infusion', 'cocoa'
      ],
    ),

    CategoriaCanonica.limpiezaHogar: InfoCategoriaCanonica(
      canonica: CategoriaCanonica.limpiezaHogar,
      prefijo: 'LMP',
      nombreEstandar: 'Limpieza y Cuidado del Hogar',
      aliases: [
        'limpieza', 'hogar', 'aseo hogar', 'desinfeccion', 'detergentes',
        'limpieza del hogar', 'cuidado del hogar'
      ],
      frasesClave: [
        'detergente ariel', 'detergente bolivar', 'detergente ace',
        'detergente opal', 'detergente marsella', 'lavavajilla ayudin',
        'sapolio lavavajilla', 'axion limon', 'pasta lavavajilla',
        'lejia clorox', 'lejia sapolio', 'lejia tradicional', 'lejia floral',
        'poett lavanda', 'mr musculo', 'cera liquida', 'suavizante suavitel',
        'scotch brite', 'bolsa de basura', 'bolsas negras', 'jabon de lavar',
        'mecha de trapeador', 'guantes de jebe'
      ],
      palabrasClave: [
        'detergente', 'detergentes', 'lavavajilla', 'lavavajillas', 'ayudin',
        'sapolio', 'axion', 'lejia', 'lejias', 'clorox', 'desinfectante',
        'poett', 'pinesol', 'lysol', 'suavitel', 'vanish', 'escoba',
        'recogedor', 'trapeador', 'esponja', 'viruta', 'ambientador', 'glade'
      ],
    ),

    CategoriaCanonica.cuidadoPersonal: InfoCategoriaCanonica(
      canonica: CategoriaCanonica.cuidadoPersonal,
      prefijo: 'CPD',
      nombreEstandar: 'Cuidado Personal y Dental',
      aliases: [
        'cuidado personal', 'personal', 'dental', 'aseo personal',
        'higiene', 'perfumeria', 'belleza'
      ],
      frasesClave: [
        'crema dental', 'pasta dental', 'colgate total', 'colgate triple accion',
        'kolynos super blanco', 'dento anticaries', 'cepillo dental',
        'enjuague bucal', 'listerine cool mint', 'hilo dental',
        'head & shoulders', 'head and shoulders', 'pantene pro-v',
        'sedal ceramidas', 'dove shampoo', 'savital keratina',
        'jabon dove', 'jabon camay', 'jabon protex', 'jabon nivea',
        'jabon rexona', 'desodorante rexona', 'rexona men', 'desodorante axe',
        'old spice', 'prestobarba gillette', 'maquina de afeitar',
        'espuma de afeitar', 'papel higienico', 'suave rinde mas',
        'papel noble', 'papel paracas', 'papel elite', 'toalla higienica',
        'toallas higienicas', 'nosotras invisible', 'kotex nocturna',
        'pañales huggies', 'pañales pampers', 'toallitas humedas',
        'preservativo piel', 'condones durex'
      ],
      palabrasClave: [
        'colgate', 'kolynos', 'dento', 'dentifrico', 'shampoo', 'champu',
        'acondicionador', 'pantene', 'sedal', 'savital', 'jabon', 'camay',
        'dove', 'protex', 'desodorante', 'antitranspirante', 'rexona', 'axe',
        'prestobarba', 'gillette', 'afeitadora', 'suave', 'paracas', 'kotex',
        'nosotras', 'ladysoft', 'pañales', 'panal', 'huggies', 'pampers',
        'preservativo', 'preservativos', 'durex'
      ],
    ),

    CategoriaCanonica.farmaciaBotiquin: InfoCategoriaCanonica(
      canonica: CategoriaCanonica.farmaciaBotiquin,
      prefijo: 'FAR',
      nombreEstandar: 'Farmacia y Botiquín',
      aliases: [
        'farmacia', 'botiquin', 'salud', 'medicamento', 'medicamentos',
        'medicina', 'medicinas'
      ],
      frasesClave: [
        'panadol antigripal', 'panadol forte', 'paracetamol 500mg',
        'sal de andrews', 'alcohol medicinal', 'alcohol 70', 'alcohol 96',
        'agua oxigenada', 'curitas hansaplast', 'vick vaporub'
      ],
      palabrasClave: [
        'paracetamol', 'panadol', 'ibuprofeno', 'aspirina', 'naproxeno',
        'apronax', 'bismutol', 'nastizol', 'kitadol', 'dolocordralan',
        'antalgina', 'mentolatum', 'curita', 'curitas', 'esparadrapo',
        'gasa', 'gasas', 'algodon', 'jeringa', 'pastilla', 'pastillas',
        'blister', 'capsula', 'capsulas'
      ],
    ),

    CategoriaCanonica.heladosCongelados: InfoCategoriaCanonica(
      canonica: CategoriaCanonica.heladosCongelados,
      prefijo: 'HLD',
      nombreEstandar: 'Helados y Congelados',
      aliases: [
        'helado', 'helados', 'congelado', 'congelados', 'postre', 'postres'
      ],
      frasesClave: [
        'peziduri lucuma', 'peziduri vainilla', 'peziduri tricolor',
        'frio rico', 'sin parar', 'jet donofrio', 'bombones donofrio',
        'sandwich helado', 'helado artika', 'bolsa de hielo', 'cubitos de hielo'
      ],
      palabrasClave: [
        'helado', 'helados', 'donofrio', "d'onofrio", 'peziduri', 'artika',
        'paleta', 'hielo'
      ],
    ),

    CategoriaCanonica.mascotas: InfoCategoriaCanonica(
      canonica: CategoriaCanonica.mascotas,
      prefijo: 'MAS',
      nombreEstandar: 'Mascotas y Pet Shop',
      aliases: [
        'mascota', 'mascotas', 'pet', 'perro', 'perros', 'gato', 'gatos',
        'animales'
      ],
      frasesClave: [
        'comida para perro', 'alimento para perro', 'comida para gato',
        'alimento para gato', 'croquetas perro', 'croquetas gato',
        'arena para gato', 'arena sanitaria'
      ],
      palabrasClave: [
        'ricocan', 'mimaskot', 'canbo', 'pedigree', 'whiskas', 'ricocat',
        'michicat', 'felix', 'friskies'
      ],
    ),

    CategoriaCanonica.frutasVerduras: InfoCategoriaCanonica(
      canonica: CategoriaCanonica.frutasVerduras,
      prefijo: 'FRU',
      nombreEstandar: 'Frutas y Verduras',
      aliases: [
        'fruta', 'frutas', 'verdura', 'verduras', 'fresco', 'frescos',
        'hortaliza', 'hortalizas', 'tuberculo', 'tuberculos'
      ],
      frasesClave: [
        'platano de seda', 'papa amarilla', 'papa canchan', 'papa huayro',
        'cebolla roja', 'palta fuerte', 'palta hass', 'manzana delicia'
      ],
      palabrasClave: [
        'platano', 'manzana', 'mandarina', 'naranja', 'limon', 'uva',
        'papaya', 'piña', 'sandia', 'fresa', 'palta', 'tomate', 'zanahoria',
        'choclo', 'lechuga', 'culantro', 'perejil', 'kion'
      ],
    ),

    CategoriaCanonica.cigarrillosTabaco: InfoCategoriaCanonica(
      canonica: CategoriaCanonica.cigarrillosTabaco,
      prefijo: 'CIG',
      nombreEstandar: 'Cigarrillos y Tabacos',
      aliases: [
        'cigarrillo', 'cigarrillos', 'cigarro', 'cigarros', 'tabaco', 'tabacos',
        'fosforo', 'fosforos'
      ],
      frasesClave: [
        'lucky strike', 'pall mall', 'fosforos la llama'
      ],
      palabrasClave: [
        'cigarro', 'cigarros', 'cigarrillo', 'cigarrillos', 'marlboro',
        'malboro', 'hamilton', 'winston', 'camel', 'tabaco', 'fosforo',
        'fosforos', 'encendedor', 'encendedores', 'tokai', 'clipper'
      ],
    ),

    CategoriaCanonica.libreriaBazar: InfoCategoriaCanonica(
      canonica: CategoriaCanonica.libreriaBazar,
      prefijo: 'LIB',
      nombreEstandar: 'Librería y Bazar',
      aliases: [
        'libreria', 'bazar', 'utiles', 'escolar', 'escolares', 'papeleria',
        'ferreteria'
      ],
      frasesClave: [
        'cuaderno standford', 'hojas bond', 'pila duracell', 'cinta scotch',
        'silicona liquida'
      ],
      palabrasClave: [
        'cuaderno', 'cuadernos', 'lapicero', 'lapiceros', 'lapiz', 'plumon',
        'borrador', 'tajador', 'regla', 'standford', 'minerva', 'pegamento',
        'uhu', 'pila', 'pilas', 'duracell', 'energizer', 'vela', 'velas'
      ],
    ),
  };

  /// Normaliza texto removiendo diacríticos y caracteres no alfanuméricos redundantes
  static String normalizar(String texto) {
    var out = texto.toLowerCase().trim();
    out = out.replaceAll('á', 'a')
             .replaceAll('é', 'e')
             .replaceAll('í', 'i')
             .replaceAll('ó', 'o')
             .replaceAll('ú', 'u')
             .replaceAll('ñ', 'n');
    return out;
  }

  /// Retorna el prefijo SKU recomendado (ej. GSE, ALC, LAC, ABA, etc.)
  static String getPrefixForCategory(String nombreCategoria) {
    final canonica = detectarCanonica(nombre: nombreCategoria);
    if (canonica != null) {
      final info = _catalogoCanonico[canonica];
      if (info != null) return info.prefijo;
    }

    final norm = normalizar(nombreCategoria)
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
    if (norm.length >= 3) {
      return norm.substring(0, 3);
    }
    return '${norm}GEN'.substring(0, 3);
  }

  /// Detecta la categoría canónica correspondiente a partir del nombre o código de barras
  static CategoriaCanonica? detectarCanonica({String? nombre, String? codigoBarras}) {
    // 1. Intenta por Código de Barras oficial verificado (máxima certeza 100%)
    if (codigoBarras != null && codigoBarras.trim().isNotEmpty) {
      final sugerencia = CatalogoImagenesService.buscarSugerencia(
        codigoBarras: codigoBarras,
      );
      if (sugerencia != null) {
        final catFromCatalog = _mapearTextoACanonica(sugerencia.categoria);
        if (catFromCatalog != null) {
          return catFromCatalog;
        }
      }
    }

    if (nombre == null || nombre.trim().isEmpty) return null;
    final normNombre = normalizar(nombre);
    if (normNombre.length < 2) return null;

    // Reglas semánticas contextuales de desambiguación para productos peruanos:
    final tieneAtunConservas = RegExp(r'\b(atun|filete|grated|lomito|caballa|sardina|conserva)\b').hasMatch(normNombre);
    final tieneMermelada = normNombre.contains('mermelada');
    final tieneHelado = RegExp(r'\b(helado|helados|peziduri|frio rico|sin parar|artika)\b').hasMatch(normNombre);
    final tieneAceite = normNombre.contains('aceite');
    final tienePapaSnack = RegExp(r'\b(lays|pringles|chips|ondas|al hilo|hilo)\b').hasMatch(normNombre);
    final tienePapaFresca = RegExp(r'\b(amarilla|canchan|huayro|blanca|kilo|kg)\b').hasMatch(normNombre);
    final tieneDetergente = normNombre.contains('detergente');

    Map<CategoriaCanonica, double> puntuaciones = {};

    for (final entry in _catalogoCanonico.entries) {
      final canonica = entry.key;
      final info = entry.value;
      double score = 0.0;

      // Evaluar frases compuestas (peso alto: 25 pts)
      for (final frase in info.frasesClave) {
        final normFrase = normalizar(frase);
        if (normNombre.contains(normFrase)) {
          score += 25.0;
        }
      }

      // Evaluar palabras clave (peso medio: 10 pts)
      for (final palabra in info.palabrasClave) {
        final normPalabra = normalizar(palabra);
        if (normPalabra.length <= 3) {
          if (RegExp('\\b${RegExp.escape(normPalabra)}\\b').hasMatch(normNombre)) {
            score += 10.0;
          }
        } else {
          if (RegExp('\\b${RegExp.escape(normPalabra)}').hasMatch(normNombre)) {
            score += 10.0;
          }
        }
      }

      // Evaluar aliases directos de categoría
      for (final alias in info.aliases) {
        final normAlias = normalizar(alias);
        if (normAlias.length <= 3) {
          if (RegExp('\\b${RegExp.escape(normAlias)}\\b').hasMatch(normNombre)) {
            score += 8.0;
          }
        } else if (normNombre.contains(normAlias)) {
          score += 8.0;
        }
      }

      // Ajustes y penalizaciones por desambiguación
      if (canonica == CategoriaCanonica.lacteosHuevos) {
        if (tieneAtunConservas) score -= 35.0;
        if (tieneMermelada) score -= 35.0;
      }
      if (canonica == CategoriaCanonica.abarrotesDespensa) {
        if (tieneAtunConservas) score += 30.0;
        if (tieneAceite) score += 20.0;
      }
      if (canonica == CategoriaCanonica.limpiezaHogar) {
        if (tieneAceite && !tieneDetergente) {
          // Evitar que "aceite" active el detergente "Ace"
          score -= 30.0;
        }
      }
      if (canonica == CategoriaCanonica.heladosCongelados && tieneHelado) {
        score += 30.0;
      }
      if (canonica == CategoriaCanonica.golosinasChocolates && tieneHelado) {
        score -= 20.0;
      }
      if (canonica == CategoriaCanonica.snacksPiqueos && tienePapaSnack) {
        score += 25.0;
      }
      if (canonica == CategoriaCanonica.frutasVerduras) {
        if (tienePapaSnack) score -= 30.0;
        if (tienePapaFresca) score += 25.0;
      }

      if (score > 0) {
        puntuaciones[canonica] = score;
      }
    }

    if (puntuaciones.isEmpty) return null;

    final sorted = puntuaciones.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final best = sorted.first;
    // Umbral mínimo de confianza semántica para evitar falsos positivos
    if (best.value >= 8.0) {
      return best.key;
    }

    return null;
  }

  /// Mapea un texto (ej. proveniente de catálogo o nombre libre) a una CategoriaCanonica
  static CategoriaCanonica? _mapearTextoACanonica(String texto) {
    final clean = normalizar(texto);

    if (clean.contains('gaseosa') || (clean.contains('bebida') && !clean.contains('alcoh'))) {
      return CategoriaCanonica.bebidasGaseosas;
    }
    if (clean.contains('alcoh') || clean.contains('cerveza') || clean.contains('licor') || clean.contains('vino') || clean.contains('pisco')) {
      return CategoriaCanonica.licoresCervezas;
    }
    if (clean.contains('lacteo') || clean.contains('leche') || clean.contains('yogur')) {
      return CategoriaCanonica.lacteosHuevos;
    }
    if (clean.contains('embutido') || clean.contains('fiambrer') || clean.contains('salchicha')) {
      return CategoriaCanonica.embutidosFiambres;
    }
    if (clean.contains('snack') || clean.contains('piqueo')) {
      return CategoriaCanonica.snacksPiqueos;
    }
    if (clean.contains('golosina') || clean.contains('chocolate') || clean.contains('dulce') || clean.contains('caramelo')) {
      return CategoriaCanonica.golosinasChocolates;
    }
    if (clean.contains('abarrote') || clean.contains('despensa') || clean.contains('fideo') || clean.contains('conserva')) {
      return CategoriaCanonica.abarrotesDespensa;
    }
    if (clean.contains('limpieza') || clean.contains('hogar') || clean.contains('detergente')) {
      return CategoriaCanonica.limpiezaHogar;
    }
    if (clean.contains('dental') || clean.contains('personal') || clean.contains('higiene')) {
      return CategoriaCanonica.cuidadoPersonal;
    }
    if (clean.contains('helado') || clean.contains('postre')) {
      return CategoriaCanonica.heladosCongelados;
    }
    if (clean.contains('panader') || clean.contains('desayuno') || clean.contains('pan')) {
      return CategoriaCanonica.panaderiaDesayunos;
    }
    if (clean.contains('farmacia') || clean.contains('botiquin') || clean.contains('salud')) {
      return CategoriaCanonica.farmaciaBotiquin;
    }
    if (clean.contains('mascota') || clean.contains('perro') || clean.contains('gato')) {
      return CategoriaCanonica.mascotas;
    }
    if (clean.contains('fruta') || clean.contains('verdura') || clean.contains('fresco')) {
      return CategoriaCanonica.frutasVerduras;
    }
    if (clean.contains('cigar') || clean.contains('tabaco') || clean.contains('fosforo')) {
      return CategoriaCanonica.cigarrillosTabaco;
    }
    if (clean.contains('librer') || clean.contains('bazar') || clean.contains('util')) {
      return CategoriaCanonica.libreriaBazar;
    }

    return null;
  }

  /// Mapea de forma inteligente una CategoriaCanonica a la lista de categorías reales de la bodega
  static Categoria? mapearACategoriaTienda(
    CategoriaCanonica canonica,
    List<Categoria> categoriasDisponibles,
  ) {
    if (categoriasDisponibles.isEmpty) return null;

    final info = _catalogoCanonico[canonica];
    if (info == null) return null;

    Categoria? mejorMatch;
    double maxScore = -1.0;

    for (final cat in categoriasDisponibles) {
      if (!cat.estado) continue;
      final clean = normalizar(cat.nombre);
      double score = 0.0;

      // 1. Coincidencia exacta con nombre estándar canónico
      if (clean == normalizar(info.nombreEstandar)) {
        score += 100.0;
      }

      // 2. Coincidencia con aliases principales de la categoría
      for (final alias in info.aliases) {
        final normAlias = normalizar(alias);
        if (clean.contains(normAlias)) {
          score += 40.0;
        }
      }

      // 3. Manejo de categorías combinadas frecuentes en bodegas:
      // Ej: "Snacks y Golosinas"
      if ((canonica == CategoriaCanonica.golosinasChocolates ||
           canonica == CategoriaCanonica.snacksPiqueos) &&
          (clean.contains('snack') && clean.contains('golosin'))) {
        score += 60.0;
      }

      // Ej: "Bebidas y Licores"
      if ((canonica == CategoriaCanonica.bebidasGaseosas ||
           canonica == CategoriaCanonica.licoresCervezas) &&
          (clean.contains('bebid') && clean.contains('licor'))) {
        score += 60.0;
      }

      // Ej: "Lácteos y Embutidos"
      if ((canonica == CategoriaCanonica.lacteosHuevos ||
           canonica == CategoriaCanonica.embutidosFiambres) &&
          (clean.contains('lacteo') && clean.contains('embutid'))) {
        score += 60.0;
      }

      // Ej: "Lácteos y Desayunos"
      if ((canonica == CategoriaCanonica.lacteosHuevos ||
           canonica == CategoriaCanonica.panaderiaDesayunos) &&
          (clean.contains('lacteo') && clean.contains('desayun'))) {
        score += 60.0;
      }

      if (score > maxScore) {
        maxScore = score;
        mejorMatch = cat;
      }
    }

    // Requiere al menos una coincidencia semántica positiva
    if (maxScore > 0) {
      return mejorMatch;
    }

    return null;
  }

  /// Método principal de recomendación: devuelve la categoría de la bodega sugerida o null
  static Categoria? sugerirCategoria({
    String? nombre,
    String? codigoBarras,
    required List<Categoria> categoriasDisponibles,
  }) {
    final res = analizarSugerencia(
      nombre: nombre,
      codigoBarras: codigoBarras,
      categoriasDisponibles: categoriasDisponibles,
    );
    return res?.categoria;
  }

  /// Análisis detallado con metadatos de confianza y origen de la sugerencia
  static SugerenciaCategoriaResult? analizarSugerencia({
    String? nombre,
    String? codigoBarras,
    required List<Categoria> categoriasDisponibles,
  }) {
    if (categoriasDisponibles.isEmpty) return null;

    // 1. Código de Barras verificado en catálogo oficial
    if (codigoBarras != null && codigoBarras.trim().isNotEmpty) {
      final sugerencia = CatalogoImagenesService.buscarSugerencia(
        codigoBarras: codigoBarras,
      );
      if (sugerencia != null) {
        final canonica = _mapearTextoACanonica(sugerencia.categoria);
        if (canonica != null) {
          final catTienda = mapearACategoriaTienda(canonica, categoriasDisponibles);
          if (catTienda != null) {
            return SugerenciaCategoriaResult(
              categoria: catTienda,
              canonica: canonica,
              prefijoCodigo: _catalogoCanonico[canonica]?.prefijo ?? 'GEN',
              confianza: 1.0,
              origen: 'catalogo_packshot',
            );
          }
        }
      }
    }

    // 2. Motor semántico analítico por palabras y marcas
    final canonica = detectarCanonica(nombre: nombre, codigoBarras: codigoBarras);
    if (canonica != null) {
      final catTienda = mapearACategoriaTienda(canonica, categoriasDisponibles);
      if (catTienda != null) {
        return SugerenciaCategoriaResult(
          categoria: catTienda,
          canonica: canonica,
          prefijoCodigo: _catalogoCanonico[canonica]?.prefijo ?? 'GEN',
          confianza: 0.90,
          origen: 'keyword_semantico',
        );
      }
    }

    return null;
  }
}
