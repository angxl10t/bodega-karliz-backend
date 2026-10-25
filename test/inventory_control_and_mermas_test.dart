import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/movimientos/merma_model.dart';
import 'package:bodega_mobile/features/movimientos/auditoria_ciega_model.dart';

void main() {
  group('Control de Vencimientos con Alertas Semáforo Tests', () {
    test('Producto sin control de vencimiento retorna sinControl', () {
      final p = Producto(
        idProducto: 1,
        idCategoria: 1,
        codigo: 'PROD-001',
        nombre: 'Arroz Extra Costeño 1kg',
        precioVenta: 4.80,
        stockActual: 20,
        stockMinimo: 5,
        controlaVencimiento: false,
      );

      expect(p.semaforoVencimiento, equals(SemaforoVencimiento.sinControl));
      expect(p.diasParaVencer, isNull);
    });

    test('Producto con caducidad menor o igual a 7 días es Crítico (🔴)', () {
      final now = DateTime.now();
      final pCritico = Producto(
        idProducto: 2,
        idCategoria: 1,
        codigo: 'LAC-001',
        nombre: 'Leche Gloria UHT 1L',
        precioVenta: 5.20,
        stockActual: 15,
        stockMinimo: 5,
        controlaVencimiento: true,
        fechaVencimiento: now.add(const Duration(days: 4)),
      );

      expect(pCritico.semaforoVencimiento, equals(SemaforoVencimiento.critico));
      expect(pCritico.diasParaVencer, lessThanOrEqualTo(7));

      // Producto ya vencido (hace 2 días)
      final pVencido = pCritico.copyWith(
        fechaVencimiento: now.subtract(const Duration(days: 2)),
      );
      expect(pVencido.semaforoVencimiento, equals(SemaforoVencimiento.critico));
      expect(pVencido.diasParaVencer, lessThan(0));
    });

    test('Producto con caducidad entre 8 y 30 días es Atención/Riesgo (🟡)', () {
      final now = DateTime.now();
      final pAtencion = Producto(
        idProducto: 3,
        idCategoria: 2,
        codigo: 'EMB-001',
        nombre: 'Jamón Inglés San Fernando 250g',
        precioVenta: 9.50,
        stockActual: 10,
        stockMinimo: 3,
        controlaVencimiento: true,
        fechaVencimiento: now.add(const Duration(days: 20)),
      );

      expect(pAtencion.semaforoVencimiento, equals(SemaforoVencimiento.atencion));
      expect(pAtencion.diasParaVencer, inInclusiveRange(8, 30));
    });

    test('Producto con caducidad mayor a 60 días es Vigente (🟢)', () {
      final now = DateTime.now();
      final pVigente = Producto(
        idProducto: 4,
        idCategoria: 3,
        codigo: 'BEB-001',
        nombre: 'Cerveza Cusqueña Trigo 310ml',
        precioVenta: 6.50,
        stockActual: 30,
        stockMinimo: 10,
        controlaVencimiento: true,
        fechaVencimiento: now.add(const Duration(days: 120)),
      );

      expect(pVigente.semaforoVencimiento, equals(SemaforoVencimiento.vigente));
      expect(pVigente.diasParaVencer, greaterThan(60));
    });

    test('costoUnitarioEstimado usa precioCosto si existe o 75% de venta', () {
      final pConCosto = Producto(
        idProducto: 5,
        idCategoria: 1,
        codigo: 'P-05',
        nombre: 'Aceite Primor 1L',
        precioVenta: 10.00,
        precioCosto: 7.80,
        stockActual: 10,
        stockMinimo: 5,
      );
      expect(pConCosto.costoUnitarioEstimado, equals(7.80));

      final pSinCosto = Producto(
        idProducto: 6,
        idCategoria: 1,
        codigo: 'P-06',
        nombre: 'Galletas Soda Field',
        precioVenta: 1.00,
        stockActual: 50,
        stockMinimo: 10,
      );
      expect(pSinCosto.costoUnitarioEstimado, equals(0.75));
    });

    test('Serialización JSON de Producto preserva fechaVencimiento y precioCosto', () {
      final date = DateTime(2026, 12, 15);
      final prod = Producto(
        idProducto: 7,
        idCategoria: 1,
        codigo: 'LMP-001',
        nombre: 'Detergente Ariel 1kg',
        precioVenta: 12.00,
        precioCosto: 8.50,
        stockActual: 20,
        stockMinimo: 5,
        controlaVencimiento: true,
        fechaVencimiento: date,
      );

      final json = prod.toJson();
      expect(json['fechaVencimiento'], equals('2026-12-15'));
      expect(json['precioCosto'], equals(8.50));
      expect(json['controlaVencimiento'], isTrue);

      final decoded = Producto.fromJson(json);
      expect(decoded.fechaVencimiento?.year, equals(2026));
      expect(decoded.fechaVencimiento?.month, equals(12));
      expect(decoded.fechaVencimiento?.day, equals(15));
      expect(decoded.precioCosto, equals(8.50));
    });
  });

  group('Registro de Mermas y Desmedros Tests', () {
    test('MermaRegistro calcula costoTotal y motivoLegible correctamente', () {
      final merma = MermaRegistro(
        idMerma: 'MERMA-101',
        idProducto: 1,
        nombreProducto: 'Yogurt Gloria Fresa 1L',
        cantidad: 3.0,
        motivo: 'VENCIMIENTO',
        costoUnitario: 4.50,
        costoTotal: 13.50,
        observaciones: 'Lote caducado en vitrina refrigerada',
        usuarioResponsable: 'cajero_pedro',
        fecha: DateTime(2026, 10, 25, 10, 30),
      );

      expect(merma.costoTotal, equals(13.50));
      expect(merma.motivoLegible, equals('Vencimiento / Caducado'));

      final json = merma.toJson();
      expect(json['idMerma'], equals('MERMA-101'));
      expect(json['motivo'], equals('VENCIMIENTO'));

      final fromJson = MermaRegistro.fromJson(json);
      expect(fromJson.nombreProducto, equals('Yogurt Gloria Fresa 1L'));
      expect(fromJson.costoTotal, equals(13.50));
    });

    test('Motivos legibles de mermas se formatean adecuadamente', () {
      final mRotura = MermaRegistro(
        idMerma: '1',
        idProducto: 1,
        nombreProducto: 'Pisco',
        cantidad: 1,
        motivo: 'ROTURA',
        costoUnitario: 35.0,
        costoTotal: 35.0,
        usuarioResponsable: 'admin',
        fecha: DateTime.now(),
      );
      expect(mRotura.motivoLegible, equals('Rotura / Envase Roto'));

      final mConsumo = mRotura.copyWith(motivo: 'CONSUMO_INTERNO');
      expect(mConsumo.motivoLegible, equals('Consumo Interno'));

      final mDesmedro = mRotura.copyWith(motivo: 'ROBO_DESMEDRO');
      expect(mDesmedro.motivoLegible, equals('Desmedro / Pérdida'));
    });
  });

  group('Auditoría Ciega de Inventario Físico (Stock Audit) Tests', () {
    test('AuditoriaItem evalúa conteo ciego, diferencias y cuadres exactos', () {
      final itemCuadrado = AuditoriaItem(
        idProducto: 1,
        codigo: 'PROD-01',
        nombreProducto: 'Inca Kola 1.5L',
        stockSistema: 10.0,
        conteoFisico: 10.0,
        precioVenta: 7.50,
        precioCosto: 5.0,
      );

      expect(itemCuadrado.diferencia, equals(0.0));
      expect(itemCuadrado.esCuadreExacto, isTrue);
      expect(itemCuadrado.esFaltante, isFalse);
      expect(itemCuadrado.esSobrante, isFalse);
      expect(itemCuadrado.valorDiscrepancia, equals(0.0));

      final itemFaltante = itemCuadrado.copyWith(conteoFisico: 7.0);
      expect(itemFaltante.diferencia, equals(-3.0));
      expect(itemFaltante.esFaltante, isTrue);
      expect(itemFaltante.esCuadreExacto, isFalse);
      expect(itemFaltante.valorDiscrepancia, equals(-22.50));

      final itemSobrante = itemCuadrado.copyWith(conteoFisico: 12.0);
      expect(itemSobrante.diferencia, equals(2.0));
      expect(itemSobrante.esSobrante, isTrue);
      expect(itemSobrante.esCuadreExacto, isFalse);
      expect(itemSobrante.valorDiscrepancia, equals(15.0));
    });

    test('AuditoriaSesion agrega métricas consolidadas de auditoría física', () {
      final sesion = AuditoriaSesion(
        idAuditoria: 'AUDIT-20261025-01',
        titulo: 'Auditoría Mensual Octubre',
        usuarioResponsable: 'supervisor_juan',
        fechaInicio: DateTime.now(),
        estado: 'FINALIZADA',
        items: [
          AuditoriaItem(
            idProducto: 1,
            codigo: 'P-1',
            nombreProducto: 'Atún Primor',
            stockSistema: 20.0,
            conteoFisico: 20.0,
            precioVenta: 5.0,
            precioCosto: 4.0,
          ),
          AuditoriaItem(
            idProducto: 2,
            codigo: 'P-2',
            nombreProducto: 'Galletas Casino',
            stockSistema: 15.0,
            conteoFisico: 12.0, // Faltan 3 (-S/ 6.00)
            precioVenta: 2.0,
            precioCosto: 1.0,
          ),
          AuditoriaItem(
            idProducto: 3,
            codigo: 'P-3',
            nombreProducto: 'Jabón Bolívar',
            stockSistema: 10.0,
            conteoFisico: 14.0, // Sobran 4 (+S/ 16.00)
            precioVenta: 4.0,
            precioCosto: 3.0,
          ),
        ],
      );

      expect(sesion.totalCuadreExacto, equals(1));
      expect(sesion.totalFaltantes, equals(1));
      expect(sesion.totalSobrantes, equals(1));
      expect(sesion.discrepanciaNeta, equals(10.0)); // +16 - 6 = +10.00

      final json = sesion.toJson();
      expect(json['idAuditoria'], equals('AUDIT-20261025-01'));
      expect((json['items'] as List).length, equals(3));

      final fromJson = AuditoriaSesion.fromJson(json);
      expect(fromJson.totalCuadreExacto, equals(1));
      expect(fromJson.discrepanciaNeta, equals(10.0));
    });
  });
}
