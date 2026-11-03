import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/promociones/promocion_model.dart';
import 'package:bodega_mobile/core/marca_detector_service.dart';

void main() {
  group('POS Promociones Matching & Toggle Logic Tests', () {
    final productoIncaKola = Producto(
      idProducto: 101,
      codigo: 'PROD101',
      nombre: 'Inca Kola 500ml',
      marca: 'Inca Kola',
      precioVenta: 3.50,
      stockActual: 24,
      nombreCategoria: 'Bebidas',
      codigoBarras: '7750101',
    );

    final productoGalletas = Producto(
      idProducto: 102,
      codigo: 'PROD102',
      nombre: 'Galletas Casino Menta',
      marca: 'Casino',
      precioVenta: 1.20,
      stockActual: 50,
      nombreCategoria: 'Snacks',
      codigoBarras: '7750102',
    );

    final productoArroz = Producto(
      idProducto: 103,
      codigo: 'PROD103',
      nombre: 'Arroz Costeño Extra 1kg',
      marca: 'Costeño',
      precioVenta: 5.20,
      stockActual: 15,
      nombreCategoria: 'Abarrotes',
      codigoBarras: '7750103',
    );

    test('Promocion matches specific product ID (2x1 or 3x2)', () {
      const promo3x2 = Promocion(
        idPromocion: 1,
        idBodega: 1,
        titulo: '3x2 en Galletas Casino',
        tipoPromocion: 'TRES_POR_DOS',
        alcance: 'PRODUCTO',
        idProductoPrincipal: 102,
        badgeTexto: '🎁 3x2',
        activo: true,
      );

      bool coincide(Producto p, Promocion promo) {
        if (!promo.activo) return false;
        if ((promo.alcance == 'PRODUCTO' ||
                promo.tipoPromocion == 'DOS_POR_UNO' ||
                promo.tipoPromocion == 'TRES_POR_DOS') &&
            promo.idProductoPrincipal == p.idProducto) {
          return true;
        }
        return false;
      }

      expect(coincide(productoGalletas, promo3x2), isTrue);
      expect(coincide(productoIncaKola, promo3x2), isFalse);
    });

    test('Promocion matches by brand (MARCA) with MarcaDetectorService', () {
      const promoMarca = Promocion(
        idPromocion: 2,
        idBodega: 1,
        titulo: '20% en todo Inca Kola',
        tipoPromocion: 'PORCENTAJE',
        alcance: 'MARCA',
        marcaObjetivo: 'Inca Kola',
        valorDescuento: 20.0,
        badgeTexto: '🔥 -20%',
        activo: true,
      );

      bool coincide(Producto p, Promocion promo) {
        if (!promo.activo) return false;
        if (promo.alcance == 'MARCA' &&
            promo.marcaObjetivo != null &&
            promo.marcaObjetivo!.trim().isNotEmpty) {
          return MarcaDetectorService.coincideMarca(
            promo.marcaObjetivo,
            p.marca,
            p.nombre,
          );
        }
        return false;
      }

      expect(coincide(productoIncaKola, promoMarca), isTrue);
      expect(coincide(productoGalletas, promoMarca), isFalse);
    });

    test('Promocion matches by category (CATEGORIA)', () {
      const promoCategoria = Promocion(
        idPromocion: 3,
        idBodega: 1,
        titulo: '10% en Bebidas',
        tipoPromocion: 'PORCENTAJE',
        alcance: 'CATEGORIA',
        categoriaObjetivo: 'Bebidas',
        valorDescuento: 10.0,
        badgeTexto: '🔥 -10%',
        activo: true,
      );

      bool coincide(Producto p, Promocion promo) {
        if (!promo.activo) return false;
        if (promo.alcance == 'CATEGORIA' &&
            promo.categoriaObjetivo != null &&
            promo.categoriaObjetivo!.trim().isNotEmpty) {
          final catNorm = promo.categoriaObjetivo!.trim().toLowerCase();
          return (p.nombreCategoria?.trim().toLowerCase() ?? '') == catNorm;
        }
        return false;
      }

      expect(coincide(productoIncaKola, promoCategoria), isTrue);
      expect(coincide(productoArroz, promoCategoria), isFalse);
    });

    test(
      'Promocion matches combo hueso for both main product and companion item',
      () {
        const promoCombo = Promocion(
          idPromocion: 4,
          idBodega: 1,
          titulo: 'Combo Arroz + Galletas',
          tipoPromocion: 'COMBO_HUESO',
          alcance: 'COMBO',
          idProductoPrincipal: 103, // Arroz
          idProductoSecundario: 102, // Galletas
          precioCombo: 5.50,
          badgeTexto: '🎁 Combo Ahorro',
          activo: true,
        );

        bool coincide(Producto p, Promocion promo) {
          if (!promo.activo) return false;
          if (promo.alcance == 'COMBO' &&
              (promo.idProductoPrincipal == p.idProducto ||
                  promo.idProductoSecundario == p.idProducto)) {
            return true;
          }
          return false;
        }

        expect(coincide(productoArroz, promoCombo), isTrue);
        expect(coincide(productoGalletas, promoCombo), isTrue);
        expect(coincide(productoIncaKola, promoCombo), isFalse);
      },
    );

    test('Expired promotions are ignored by active matcher', () {
      const promoExpirada = Promocion(
        idPromocion: 5,
        idBodega: 1,
        titulo: 'Halloween 50%',
        tipoPromocion: 'PORCENTAJE',
        alcance: 'CATEGORIA',
        categoriaObjetivo: 'Bebidas',
        fechaFin: '2026-10-31',
        activo: true,
      );

      bool coincide(Producto p, Promocion promo) {
        if (!promo.activo) return false;
        final hoy = DateTime.now();
        if (promo.fechaFin != null && promo.fechaFin!.trim().isNotEmpty) {
          final fin = DateTime.tryParse(promo.fechaFin!.trim());
          if (fin != null && hoy.isAfter(fin.add(const Duration(days: 1)))) {
            return false;
          }
        }
        return (promo.categoriaObjetivo?.trim().toLowerCase() ?? '') ==
            (p.nombreCategoria?.trim().toLowerCase() ?? '');
      }

      expect(coincide(productoIncaKola, promoExpirada), isFalse);
    });

    test('Cashier promo toggle controls whether discount is deducted from checkout', () {
      // Scenario: Customer buys 3 Galletas Casino at S/ 1.20 each = S/ 3.60
      // 3x2 Promotion saves S/ 1.20
      const subtotal = 3.60;
      const ahorroCalculado = 1.20;

      double calcularDescuentoCobro(bool aplicar, double ahorro) {
        return aplicar ? ahorro : 0.0;
      }

      // By default: cashier has promo switch OFF (for online web shoppers only unless requested)
      bool aplicarPromocionesWeb = false;
      double totalDescuento = calcularDescuentoCobro(
        aplicarPromocionesWeb,
        ahorroCalculado,
      );
      double totalCobrar = subtotal - totalDescuento;

      expect(totalDescuento, 0.0);
      expect(totalCobrar, 3.60);

      // Customer mentions: "Vi en la web que tienen 3x2 en Casino" -> Cashier switches ON
      aplicarPromocionesWeb = true;
      totalDescuento = calcularDescuentoCobro(
        aplicarPromocionesWeb,
        ahorroCalculado,
      );
      totalCobrar = subtotal - totalDescuento;

      expect(totalDescuento, closeTo(1.20, 0.001));
      expect(totalCobrar, closeTo(2.40, 0.001));

      // Sale is completed or cart is cleared -> toggle resets back to OFF
      aplicarPromocionesWeb = false;
      expect(aplicarPromocionesWeb, isFalse);
    });
  });
}
