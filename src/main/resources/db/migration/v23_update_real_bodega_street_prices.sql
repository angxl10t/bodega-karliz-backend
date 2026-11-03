-- ==============================================================================
-- MIGRACIÓN V23: ACTUALIZACIÓN DE PRECIOS A TARIFAS REALES DE BODEGA DE BARRIO PERUANA
-- Precios cómodos y competitivos de tienda de calle (no inflados de supermercado)
-- ==============================================================================

-- 1. Actualización por código de barras oficial para todas las bodegas existentes
UPDATE public.productos SET precio_venta = 3.00, precio_costo = 2.30 WHERE codigo_barras = '7750106001010'; -- Inca Kola 500ml
UPDATE public.productos SET precio_venta = 6.50, precio_costo = 5.20 WHERE codigo_barras = '7750106001027'; -- Inca Kola 1.5L
UPDATE public.productos SET precio_venta = 12.00, precio_costo = 9.80 WHERE codigo_barras = '7750106000013'; -- Inca Kola 3L
UPDATE public.productos SET precio_venta = 3.00, precio_costo = 2.30 WHERE codigo_barras = '7750106001034'; -- Inca Kola Zero 500ml
UPDATE public.productos SET precio_venta = 3.00, precio_costo = 2.30 WHERE codigo_barras = '7750106000025'; -- Coca Cola 500ml
UPDATE public.productos SET precio_venta = 6.50, precio_costo = 5.20 WHERE codigo_barras = '7750106002017'; -- Coca Cola 1.5L
UPDATE public.productos SET precio_venta = 12.00, precio_costo = 9.80 WHERE codigo_barras = '7751234567890'; -- Coca Cola 3L
UPDATE public.productos SET precio_venta = 3.00, precio_costo = 2.30 WHERE codigo_barras = '7750106000032'; -- Coca Cola Zero 500ml
UPDATE public.productos SET precio_venta = 2.50, precio_costo = 1.90 WHERE codigo_barras = '7750182220378'; -- Fanta 500ml
UPDATE public.productos SET precio_venta = 10.50, precio_costo = 8.40 WHERE codigo_barras = '7750182495301'; -- Fanta 3L
UPDATE public.productos SET precio_venta = 2.50, precio_costo = 1.90 WHERE codigo_barras = '7750182000321'; -- Sprite 500ml
UPDATE public.productos SET precio_venta = 10.50, precio_costo = 8.40 WHERE codigo_barras = '7750182000222'; -- Sprite 3L
UPDATE public.productos SET precio_venta = 2.20, precio_costo = 1.70 WHERE codigo_barras = '7753749003186'; -- Guaraná 450ml
UPDATE public.productos SET precio_venta = 9.50, precio_costo = 7.60 WHERE codigo_barras = '7753749003193'; -- Guaraná 3L
UPDATE public.productos SET precio_venta = 1.50, precio_costo = 1.10 WHERE codigo_barras = '7750106003014'; -- Agua San Luis 625ml
UPDATE public.productos SET precio_venta = 7.50, precio_costo = 5.80 WHERE codigo_barras = '7750106003021'; -- Agua San Luis 7L
UPDATE public.productos SET precio_venta = 1.50, precio_costo = 1.10 WHERE codigo_barras = '775117011953'; -- Agua San Mateo 600ml
UPDATE public.productos SET precio_venta = 2.20, precio_costo = 1.70 WHERE codigo_barras = '7750670010238'; -- Sporade Tropical 625ml
UPDATE public.productos SET precio_venta = 2.20, precio_costo = 1.70 WHERE codigo_barras = '7750670010245'; -- Sporade Maracuyá 625ml
UPDATE public.productos SET precio_venta = 6.00, precio_costo = 4.80 WHERE codigo_barras = '7750670010412'; -- Cifrut 3L
UPDATE public.productos SET precio_venta = 1.50, precio_costo = 1.10 WHERE codigo_barras = '7750670010429'; -- Cifrut 500ml
UPDATE public.productos SET precio_venta = 8.50, precio_costo = 6.80 WHERE codigo_barras = '90162602'; -- Red Bull 355ml
UPDATE public.productos SET precio_venta = 2.20, precio_costo = 1.70 WHERE codigo_barras = '7750182000406'; -- Pepsi 500ml
UPDATE public.productos SET precio_venta = 5.50, precio_costo = 4.30 WHERE codigo_barras = '7750182000413'; -- Pepsi 1.5L
UPDATE public.productos SET precio_venta = 9.00, precio_costo = 7.20 WHERE codigo_barras = '7750182000420'; -- Pepsi 3L
UPDATE public.productos SET precio_venta = 2.20, precio_costo = 1.70 WHERE codigo_barras = '7750182000437'; -- 7Up 500ml
UPDATE public.productos SET precio_venta = 9.00, precio_costo = 7.20 WHERE codigo_barras = '7750182000444'; -- 7Up 3L
UPDATE public.productos SET precio_venta = 1.80, precio_costo = 1.30 WHERE codigo_barras = '7750182000451'; -- Concordia 500ml
UPDATE public.productos SET precio_venta = 7.00, precio_costo = 5.50 WHERE codigo_barras = '7750182000468'; -- Concordia 3L
UPDATE public.productos SET precio_venta = 6.00, precio_costo = 4.70 WHERE codigo_barras = '7750670010115'; -- KR Cola 3L
UPDATE public.productos SET precio_venta = 6.00, precio_costo = 4.70 WHERE codigo_barras = '7750670010122'; -- KR Piña 3L
UPDATE public.productos SET precio_venta = 2.50, precio_costo = 1.90 WHERE codigo_barras = '7753749003209'; -- Guaraná Lata
UPDATE public.productos SET precio_venta = 5.80, precio_costo = 4.60 WHERE codigo_barras = '7753749003216'; -- Guaraná 1.5L
UPDATE public.productos SET precio_venta = 5.80, precio_costo = 4.50 WHERE codigo_barras = '7750106000049'; -- Canada Dry 1.5L
UPDATE public.productos SET precio_venta = 7.50, precio_costo = 5.80 WHERE codigo_barras = '70847811169'; -- Monster 473ml
UPDATE public.productos SET precio_venta = 7.50, precio_costo = 5.80 WHERE codigo_barras = '70847022909'; -- Monster Ultra
UPDATE public.productos SET precio_venta = 2.00, precio_costo = 1.50 WHERE codigo_barras = '7750670010511'; -- Volt Blue 300ml
UPDATE public.productos SET precio_venta = 2.00, precio_costo = 1.50 WHERE codigo_barras = '7750670010528'; -- Volt Maca 300ml
UPDATE public.productos SET precio_venta = 2.00, precio_costo = 1.50 WHERE codigo_barras = '7750670010535'; -- Volt Ginseng 300ml
UPDATE public.productos SET precio_venta = 3.80, precio_costo = 2.90 WHERE codigo_barras = '7750106008019'; -- Frugos Durazno 1L
UPDATE public.productos SET precio_venta = 3.80, precio_costo = 2.90 WHERE codigo_barras = '7750106008033'; -- Frugos Mango 1L
UPDATE public.productos SET precio_venta = 3.80, precio_costo = 2.90 WHERE codigo_barras = '7750106008040'; -- Frugos Naranja 1L
UPDATE public.productos SET precio_venta = 1.80, precio_costo = 1.30 WHERE codigo_barras = '7750670010320'; -- Pulp 300ml
UPDATE public.productos SET precio_venta = 3.50, precio_costo = 2.70 WHERE codigo_barras = '7750670010313'; -- Pulp 1L
UPDATE public.productos SET precio_venta = 2.80, precio_costo = 2.10 WHERE codigo_barras = '7750800001012'; -- Tampico 1L
UPDATE public.productos SET precio_venta = 6.50, precio_costo = 5.00 WHERE codigo_barras = '7750800001029'; -- Tampico 3L
UPDATE public.productos SET precio_venta = 1.20, precio_costo = 0.80 WHERE codigo_barras = '7750670010016'; -- Agua Cielo 625ml
UPDATE public.productos SET precio_venta = 6.50, precio_costo = 5.00 WHERE codigo_barras = '7750670010030'; -- Agua Cielo 7L
UPDATE public.productos SET precio_venta = 2.80, precio_costo = 2.10 WHERE codigo_barras = '7750182000604'; -- Gatorade Blue 500ml
UPDATE public.productos SET precio_venta = 2.80, precio_costo = 2.10 WHERE codigo_barras = '7750182000611'; -- Gatorade Tropical 500ml

-- 2. Cervezas y Licores
UPDATE public.productos SET precio_venta = 6.50, precio_costo = 5.20 WHERE codigo_barras = '7750111006014'; -- Pilsen 630ml
UPDATE public.productos SET precio_venta = 4.20, precio_costo = 3.30 WHERE codigo_barras = '7750111006038'; -- Pilsen Lata 355ml
UPDATE public.productos SET precio_venta = 6.50, precio_costo = 5.10 WHERE codigo_barras = '7750111006021'; -- Cristal 650ml
UPDATE public.productos SET precio_venta = 4.20, precio_costo = 3.30 WHERE codigo_barras = '7750111006045'; -- Cristal Lata 355ml
UPDATE public.productos SET precio_venta = 5.50, precio_costo = 4.30 WHERE codigo_barras = '7750106006022'; -- Cusqueña Dorada 310ml
UPDATE public.productos SET precio_venta = 5.50, precio_costo = 4.30 WHERE codigo_barras = '7750106006015'; -- Cusqueña Trigo 310ml
UPDATE public.productos SET precio_venta = 6.50, precio_costo = 5.00 WHERE codigo_barras = '750106419166'; -- Corona 355ml
UPDATE public.productos SET precio_venta = 7.00, precio_costo = 5.40 WHERE codigo_barras = '7891991000826'; -- Stella Artois 330ml
UPDATE public.productos SET precio_venta = 28.00, precio_costo = 22.50 WHERE codigo_barras = '7750174000018'; -- Pisco Queirolo 750ml
UPDATE public.productos SET precio_venta = 24.00, precio_costo = 19.00 WHERE codigo_barras = '7750148000012'; -- Ron Cartavio 750ml
UPDATE public.productos SET precio_venta = 21.00, precio_costo = 16.80 WHERE codigo_barras = '7750170000012'; -- Vino Tabernero 750ml
UPDATE public.productos SET precio_venta = 49.00, precio_costo = 39.00 WHERE codigo_barras = '5000267014005'; -- Red Label 750ml
UPDATE public.productos SET precio_venta = 10.50, precio_costo = 8.20 WHERE codigo_barras IN ('849607000100', '849607000117', '849607000124', '849607000131'); -- Four Loko 473ml
UPDATE public.productos SET precio_venta = 5.20, precio_costo = 4.00 WHERE codigo_barras IN ('7750111006502', '7750111006519', '7750111006526'); -- Mike's Hard
UPDATE public.productos SET precio_venta = 6.50, precio_costo = 5.00 WHERE codigo_barras = '5000291020010'; -- Smirnoff Ice 275ml
UPDATE public.productos SET precio_venta = 6.50, precio_costo = 5.00 WHERE codigo_barras = '7750170000203'; -- Chilcano Tabernero
UPDATE public.productos SET precio_venta = 22.00, precio_costo = 17.50 WHERE codigo_barras = '7750170000302'; -- Pisco Sour Tabernero

-- 3. Snacks y Piqueos
UPDATE public.productos SET precio_venta = 4.00, precio_costo = 3.10 WHERE codigo_barras = '7758574005541'; -- Lay's Clásicas 140g
UPDATE public.productos SET precio_venta = 4.20, precio_costo = 3.20 WHERE codigo_barras = '7758574005558'; -- Lay's Onduladas 150g
UPDATE public.productos SET precio_venta = 1.80, precio_costo = 1.35 WHERE codigo_barras = '7758574005510'; -- Doritos 45g
UPDATE public.productos SET precio_venta = 3.00, precio_costo = 2.30 WHERE codigo_barras = '7758574005527'; -- Cheese Tris 150g
UPDATE public.productos SET precio_venta = 3.00, precio_costo = 2.30 WHERE codigo_barras = '7758574005534'; -- Chizitos 120g
UPDATE public.productos SET precio_venta = 2.00, precio_costo = 1.50 WHERE codigo_barras = '7750670010818'; -- Cuates 100g
UPDATE public.productos SET precio_venta = 3.00, precio_costo = 2.30 WHERE codigo_barras = '7750670010825'; -- Tortees 140g
UPDATE public.productos SET precio_venta = 2.00, precio_costo = 1.50 WHERE codigo_barras = '7758574005565'; -- Piqueo Snax 55g
UPDATE public.productos SET precio_venta = 2.50, precio_costo = 1.90 WHERE codigo_barras = '7750670010832'; -- Chifle Piurano 100g
UPDATE public.productos SET precio_venta = 2.00, precio_costo = 1.50 WHERE codigo_barras = '7750670010849'; -- Maní Karinto 100g

-- 4. Lácteos y Derivados
UPDATE public.productos SET precio_venta = 4.20, precio_costo = 3.65 WHERE codigo_barras = '7750108003013'; -- Leche Gloria Azul 400g
UPDATE public.productos SET precio_venta = 4.20, precio_costo = 3.65 WHERE codigo_barras = '7750108003020'; -- Leche Gloria Roja 400g
UPDATE public.productos SET precio_venta = 4.20, precio_costo = 3.65 WHERE codigo_barras = '7750108003037'; -- Leche Gloria Light 400g
UPDATE public.productos SET precio_venta = 4.30, precio_costo = 3.70 WHERE codigo_barras = '7750108003044'; -- Leche Gloria Sin Lactosa 400g
UPDATE public.productos SET precio_venta = 5.20, precio_costo = 4.20 WHERE codigo_barras = '7750108003051'; -- Chocolatada Gloria 1L
UPDATE public.productos SET precio_venta = 6.20, precio_costo = 5.00 WHERE codigo_barras = '7750108003068'; -- Yogur Gloria Fresa 1L
UPDATE public.productos SET precio_venta = 6.20, precio_costo = 5.00 WHERE codigo_barras = '7750108003075'; -- Yogur Gloria Vainilla 1L
UPDATE public.productos SET precio_venta = 7.50, precio_costo = 6.00 WHERE codigo_barras = '7750108003082'; -- Mantequilla Laive 200g
UPDATE public.productos SET precio_venta = 3.80, precio_costo = 2.90 WHERE codigo_barras = '7750108003099'; -- Margarina Manty 225g
UPDATE public.productos SET precio_venta = 5.80, precio_costo = 4.60 WHERE codigo_barras = '7613036615402'; -- Leche Condensada Nestlé 393g

-- 5. Abarrotes y Despensa
UPDATE public.productos SET precio_venta = 4.50, precio_costo = 3.80 WHERE codigo_barras = '7750109004041'; -- Arroz Costeño 1kg
UPDATE public.productos SET precio_venta = 4.30, precio_costo = 3.65 WHERE codigo_barras = '7750109004058'; -- Arroz Faraón 1kg
UPDATE public.productos SET precio_venta = 8.50, precio_costo = 7.20 WHERE codigo_barras = '7750109004065'; -- Aceite Primor 900ml
UPDATE public.productos SET precio_venta = 7.50, precio_costo = 6.30 WHERE codigo_barras = '7750109004089'; -- Aceite Cocinero 900ml
UPDATE public.productos SET precio_venta = 3.80, precio_costo = 3.20 WHERE codigo_barras = '7750109004096'; -- Azúcar Paramonga 1kg
UPDATE public.productos SET precio_venta = 2.80, precio_costo = 2.20 WHERE codigo_barras = '7750109004010'; -- Fideos Don Vittorio Spaghetti 450g
UPDATE public.productos SET precio_venta = 3.00, precio_costo = 2.30 WHERE codigo_barras = '7750114002088'; -- Fideos Molitalia Spaghetti 500g
UPDATE public.productos SET precio_venta = 2.80, precio_costo = 2.20 WHERE codigo_barras = '7750109004027'; -- Fideos Don Vittorio Codito 450g
UPDATE public.productos SET precio_venta = 2.30, precio_costo = 1.80 WHERE codigo_barras = '7750109004034'; -- Fideos Lavaggi Canuto 450g
UPDATE public.productos SET precio_venta = 5.20, precio_costo = 4.20 WHERE codigo_barras IN ('7750109004072', '7750109004172'); -- Atún Primor 140g/170g
UPDATE public.productos SET precio_venta = 4.80, precio_costo = 3.80 WHERE codigo_barras = '7750109004102'; -- Atún Fanny 140g
UPDATE public.productos SET precio_venta = 9.80, precio_costo = 7.80 WHERE codigo_barras = '7750109004119'; -- Mayonesa Alacena 850g
UPDATE public.productos SET precio_venta = 4.80, precio_costo = 3.80 WHERE codigo_barras = '7750243030335'; -- Crema Tarí 400g
UPDATE public.productos SET precio_venta = 5.80, precio_costo = 4.60 WHERE codigo_barras = '7750114006079'; -- Salsa Uchucuta 400g
UPDATE public.productos SET precio_venta = 2.80, precio_costo = 2.20 WHERE codigo_barras = '7750109004126'; -- Tuco Sibarita 260g
UPDATE public.productos SET precio_venta = 1.50, precio_costo = 1.00 WHERE codigo_barras = '7750109004133'; -- Sal Emsal 1kg

-- 6. Golosinas y Chocolates
UPDATE public.productos SET precio_venta = 3.80, precio_costo = 3.00 WHERE codigo_barras = '7613036615303'; -- Sublime 100g
UPDATE public.productos SET precio_venta = 2.00, precio_costo = 1.50 WHERE codigo_barras = '7613036615310'; -- Triángulo 30g
UPDATE public.productos SET precio_venta = 1.00, precio_costo = 0.70 WHERE codigo_barras = '7750115010035'; -- Cua Cua 18g
UPDATE public.productos SET precio_venta = 1.00, precio_costo = 0.70 WHERE codigo_barras = '7750115010042'; -- Doña Pepa 23g
UPDATE public.productos SET precio_venta = 1.00, precio_costo = 0.75 WHERE codigo_barras = '7750115010059'; -- Casino 68g
UPDATE public.productos SET precio_venta = 1.00, precio_costo = 0.75 WHERE codigo_barras = '7750115010066'; -- Margarita 80g
UPDATE public.productos SET precio_venta = 1.00, precio_costo = 0.75 WHERE codigo_barras = '7750115010073'; -- Tentación 70g
UPDATE public.productos SET precio_venta = 2.50, precio_costo = 1.90 WHERE codigo_barras = '7750115010080'; -- Oreo Tubo 108g
UPDATE public.productos SET precio_venta = 1.00, precio_costo = 0.70 WHERE codigo_barras = '7750115010097'; -- Halls Menta
UPDATE public.productos SET precio_venta = 2.50, precio_costo = 1.90 WHERE codigo_barras = '7750115010103'; -- Chicho 100g

-- 7. Embutidos y Fiambrería
UPDATE public.productos SET precio_venta = 5.80, precio_costo = 4.60 WHERE codigo_barras = '7750107002016'; -- Hot Dog San Fernando 500g
UPDATE public.productos SET precio_venta = 6.50, precio_costo = 5.10 WHERE codigo_barras = '7750107002023'; -- Jamonada San Fernando 450g
UPDATE public.productos SET precio_venta = 4.80, precio_costo = 3.80 WHERE codigo_barras = '7750107002030'; -- Salchicha Huachana 250g
UPDATE public.productos SET precio_venta = 8.50, precio_costo = 6.80 WHERE codigo_barras = '7750107002047'; -- Tocino Braedt 170g
UPDATE public.productos SET precio_venta = 7.50, precio_costo = 5.90 WHERE codigo_barras = '7750107002054'; -- Chorizo Parrillero x4
UPDATE public.productos SET precio_venta = 8.50, precio_costo = 6.80 WHERE codigo_barras = '7750107002061'; -- Queso Edam Laive 200g
UPDATE public.productos SET precio_venta = 9.50, precio_costo = 7.60 WHERE codigo_barras = '7750107002078'; -- Queso Bonlé 400g
UPDATE public.productos SET precio_venta = 8.20, precio_costo = 6.50 WHERE codigo_barras = '7750107002085'; -- Jamón del País 150g

-- 8. Panadería y Desayuno
UPDATE public.productos SET precio_venta = 4.80, precio_costo = 3.80 WHERE codigo_barras = '7750116011018'; -- Pan Blanco Bimbo 400g
UPDATE public.productos SET precio_venta = 7.50, precio_costo = 6.00 WHERE codigo_barras = '7501000133404'; -- Pan Artesano Bimbo 500g
UPDATE public.productos SET precio_venta = 6.50, precio_costo = 5.10 WHERE codigo_barras = '7750727014189'; -- Pan Bimbo Blanco 590g
UPDATE public.productos SET precio_venta = 5.20, precio_costo = 4.10 WHERE codigo_barras = '7750116011025'; -- Pan Integral Bimbo 400g
UPDATE public.productos SET precio_venta = 4.50, precio_costo = 3.50 WHERE codigo_barras = '7750116011032'; -- Mermelada Gloria 310g
UPDATE public.productos SET precio_venta = 7.50, precio_costo = 6.00 WHERE codigo_barras = '7750116011049'; -- Café Nescafé 50g
UPDATE public.productos SET precio_venta = 2.00, precio_costo = 1.50 WHERE codigo_barras = '7750116011056'; -- Avena 3 Ositos 250g
UPDATE public.productos SET precio_venta = 2.80, precio_costo = 2.10 WHERE codigo_barras = '7750116011063'; -- Té Herbi x25
UPDATE public.productos SET precio_venta = 2.80, precio_costo = 2.10 WHERE codigo_barras = '7750116011070'; -- Manzanilla Herbi x25

-- 9. Limpieza y Cuidado del Hogar
UPDATE public.productos SET precio_venta = 8.50, precio_costo = 6.90 WHERE codigo_barras = '7750114009015'; -- Detergente Bolívar 850g
UPDATE public.productos SET precio_venta = 7.50, precio_costo = 6.00 WHERE codigo_barras = '7750114009022'; -- Detergente Ace 750g
UPDATE public.productos SET precio_venta = 7.50, precio_costo = 6.00 WHERE codigo_barras = '7750114009039'; -- Detergente Opal 750g
UPDATE public.productos SET precio_venta = 5.80, precio_costo = 4.50 WHERE codigo_barras = '7759918006163'; -- Ayudín Líquido 900ml
UPDATE public.productos SET precio_venta = 4.50, precio_costo = 3.50 WHERE codigo_barras = '7750114009046'; -- Sapolio Líquido 750ml
UPDATE public.productos SET precio_venta = 3.20, precio_costo = 2.50 WHERE codigo_barras = '7750114009060'; -- Clorox 1L
UPDATE public.productos SET precio_venta = 4.50, precio_costo = 3.50 WHERE codigo_barras = '7750114009077'; -- Poett 900ml
UPDATE public.productos SET precio_venta = 5.50, precio_costo = 4.30 WHERE codigo_barras = '7750114009084'; -- Suavitel 850ml
UPDATE public.productos SET precio_venta = 1.80, precio_costo = 1.30 WHERE codigo_barras = '7750114009091'; -- Esponja Scotch Brite
UPDATE public.productos SET precio_venta = 2.50, precio_costo = 1.80 WHERE codigo_barras = '7750114009107'; -- Bolsas Basura x10

-- 10. Cuidado Personal y Dental
UPDATE public.productos SET precio_venta = 4.50, precio_costo = 3.50 WHERE codigo_barras = '7750113008025'; -- Colgate Total 12 75ml
UPDATE public.productos SET precio_venta = 3.50, precio_costo = 2.60 WHERE codigo_barras = '7750113008032'; -- Colgate Triple Acción 75ml
UPDATE public.productos SET precio_venta = 3.00, precio_costo = 2.20 WHERE codigo_barras = '7750113008018'; -- Kolynos 120g
UPDATE public.productos SET precio_venta = 3.50, precio_costo = 2.50 WHERE codigo_barras = '7750113008049'; -- Cepillo Colgate
UPDATE public.productos SET precio_venta = 3.20, precio_costo = 2.40 WHERE codigo_barras = '7750113008056'; -- Jabón Dove 90g
UPDATE public.productos SET precio_venta = 2.50, precio_costo = 1.80 WHERE codigo_barras = '7750113008063'; -- Jabón Camay 125g
UPDATE public.productos SET precio_venta = 14.50, precio_costo = 11.50 WHERE codigo_barras = '7750113008070'; -- H&S 375ml
UPDATE public.productos SET precio_venta = 14.50, precio_costo = 11.50 WHERE codigo_barras = '7750113008087'; -- Pantene 375ml
UPDATE public.productos SET precio_venta = 10.50, precio_costo = 8.40 WHERE codigo_barras = '7750113008094'; -- Rexona Men 150ml
UPDATE public.productos SET precio_venta = 10.50, precio_costo = 8.40 WHERE codigo_barras = '7750113008100'; -- Rexona Women 150ml
UPDATE public.productos SET precio_venta = 5.00, precio_costo = 3.90 WHERE codigo_barras = '7750113008117'; -- Papel Suave x4
UPDATE public.productos SET precio_venta = 6.00, precio_costo = 4.70 WHERE codigo_barras = '7750113008148'; -- Papel Elite x4
UPDATE public.productos SET precio_venta = 5.50, precio_costo = 4.30 WHERE codigo_barras = '7750113008162'; -- Papel Paracas x4
UPDATE public.productos SET precio_venta = 3.50, precio_costo = 2.70 WHERE codigo_barras = '7750113008124'; -- Toallas Nosotras x10

-- 11. Helados y Congelados
UPDATE public.productos SET precio_venta = 2.50, precio_costo = 1.90 WHERE codigo_barras = '7750110005017'; -- Sublime Paleta
UPDATE public.productos SET precio_venta = 2.50, precio_costo = 1.90 WHERE codigo_barras = '7750110005178'; -- Sándwich D'Onofrio
UPDATE public.productos SET precio_venta = 2.50, precio_costo = 1.90 WHERE codigo_barras = '7750110005062'; -- Jet Chocolate
UPDATE public.productos SET precio_venta = 4.00, precio_costo = 3.00 WHERE codigo_barras = '7750110005024'; -- Sin Parar Lúcuma
UPDATE public.productos SET precio_venta = 4.50, precio_costo = 3.40 WHERE codigo_barras = '7750110005031'; -- Frío Rico Vainilla
UPDATE public.productos SET precio_venta = 5.50, precio_costo = 4.20 WHERE codigo_barras = '7750110005048'; -- Bombones x8
UPDATE public.productos SET precio_venta = 10.50, precio_costo = 8.40 WHERE codigo_barras = '7750110005055'; -- Peziduri 900ml

-- 12. Cigarrillos y Tabaco
UPDATE public.productos SET precio_venta = 18.00, precio_costo = 15.00 WHERE codigo_barras = '7750112007028'; -- Lucky Strike 20
UPDATE public.productos SET precio_venta = 19.00, precio_costo = 16.00 WHERE codigo_barras = '7751201001169'; -- Marlboro 20
UPDATE public.productos SET precio_venta = 15.00, precio_costo = 12.50 WHERE codigo_barras = '7750112007035'; -- Hamilton 20
UPDATE public.productos SET precio_venta = 15.00, precio_costo = 12.50 WHERE codigo_barras = '7750112007042'; -- Pall Mall 20
UPDATE public.productos SET precio_venta = 2.00, precio_costo = 1.40 WHERE codigo_barras = '7750112007059'; -- Fósforos x10
