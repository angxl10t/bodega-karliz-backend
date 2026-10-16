import 'package:flutter/material.dart';

/// Iconos vectoriales puros dibujados en Canvas directo (Pure Dart).
/// Garantizan renderizado al 100% en Shorebird OTA, Web y APK sin depender
/// de fuentes externas (.ttf) ni verse afectados por tree-shaking de iconos.

/// 1. Cuatro cuadrados (2x2 Grid) para Inicio / Dashboard
class KarlizGridIcon extends StatelessWidget {
  final double size;
  final Color color;

  const KarlizGridIcon({
    super.key,
    this.size = 20,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _KarlizGridPainter(color: color),
      ),
    );
  }
}

class _KarlizGridPainter extends CustomPainter {
  final Color color;
  _KarlizGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final gap = size.width * 0.16;
    final boxSize = (size.width - gap) / 2;
    final radius = Radius.circular(boxSize * 0.32);

    // Superior izquierdo
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, boxSize, boxSize), radius),
      paint,
    );
    // Superior derecho
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(boxSize + gap, 0, boxSize, boxSize), radius),
      paint,
    );
    // Inferior izquierdo
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, boxSize + gap, boxSize, boxSize), radius),
      paint,
    );
    // Inferior derecho
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(boxSize + gap, boxSize + gap, boxSize, boxSize), radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _KarlizGridPainter oldDelegate) => oldDelegate.color != color;
}

/// 2. Icono de Bodega / Tienda Market con toldo y puerta
class KarlizStoreIcon extends StatelessWidget {
  final double size;
  final Color color;

  const KarlizStoreIcon({
    super.key,
    this.size = 20,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _KarlizStorePainter(color: color),
      ),
    );
  }
}

class _KarlizStorePainter extends CustomPainter {
  final Color color;
  _KarlizStorePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Toldo superior (Awning)
    final awningPath = Path()
      ..moveTo(w * 0.16, h * 0.26)
      ..lineTo(w * 0.84, h * 0.26)
      ..lineTo(w * 0.90, h * 0.48)
      ..quadraticBezierTo(w * 0.77, h * 0.54, w * 0.64, h * 0.48)
      ..quadraticBezierTo(w * 0.50, h * 0.54, w * 0.36, h * 0.48)
      ..quadraticBezierTo(w * 0.23, h * 0.54, w * 0.10, h * 0.48)
      ..close();
    canvas.drawPath(awningPath, strokePaint);

    // Paredes y base de la tienda
    final wallsPath = Path()
      ..moveTo(w * 0.20, h * 0.49)
      ..lineTo(w * 0.20, h * 0.84)
      ..lineTo(w * 0.80, h * 0.84)
      ..lineTo(w * 0.80, h * 0.49);
    canvas.drawPath(wallsPath, strokePaint);

    // Puerta central arqueada
    final doorRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.39, h * 0.57, w * 0.22, h * 0.27),
      topLeft: Radius.circular(w * 0.08),
      topRight: Radius.circular(w * 0.08),
    );
    canvas.drawRRect(doorRect, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _KarlizStorePainter oldDelegate) => oldDelegate.color != color;
}

/// 3. Escudo de Administrador con Checkmark (Shield Check)
class KarlizShieldIcon extends StatelessWidget {
  final double size;
  final Color color;

  const KarlizShieldIcon({
    super.key,
    this.size = 18,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _KarlizShieldPainter(color: color),
      ),
    );
  }
}

class _KarlizShieldPainter extends CustomPainter {
  final Color color;
  _KarlizShieldPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.095
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Contorno exterior del escudo
    final shield = Path()
      ..moveTo(w * 0.50, h * 0.12)
      ..lineTo(w * 0.82, h * 0.24)
      ..cubicTo(w * 0.82, h * 0.58, w * 0.68, h * 0.80, w * 0.50, h * 0.90)
      ..cubicTo(w * 0.32, h * 0.80, w * 0.18, h * 0.58, w * 0.18, h * 0.24)
      ..close();
    canvas.drawPath(shield, strokePaint);

    // Checkmark central
    final check = Path()
      ..moveTo(w * 0.36, h * 0.50)
      ..lineTo(w * 0.46, h * 0.60)
      ..lineTo(w * 0.65, h * 0.38);
    canvas.drawPath(check, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _KarlizShieldPainter oldDelegate) => oldDelegate.color != color;
}

/// 4. Bolsa de compras para POS
class KarlizShoppingBagIcon extends StatelessWidget {
  final double size;
  final Color color;

  const KarlizShoppingBagIcon({
    super.key,
    this.size = 20,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _KarlizShoppingBagPainter(color: color),
      ),
    );
  }
}

class _KarlizShoppingBagPainter extends CustomPainter {
  final Color color;
  _KarlizShoppingBagPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Cuerpo de la bolsa
    final bag = Path()
      ..moveTo(w * 0.20, h * 0.34)
      ..lineTo(w * 0.80, h * 0.34)
      ..lineTo(w * 0.84, h * 0.86)
      ..quadraticBezierTo(w * 0.84, h * 0.90, w * 0.80, h * 0.90)
      ..lineTo(w * 0.20, h * 0.90)
      ..quadraticBezierTo(w * 0.16, h * 0.90, w * 0.16, h * 0.86)
      ..close();
    canvas.drawPath(bag, strokePaint);

    // Asa arqueada
    final handle = Path()
      ..moveTo(w * 0.36, h * 0.34)
      ..cubicTo(w * 0.36, h * 0.14, w * 0.64, h * 0.14, w * 0.64, h * 0.34);
    canvas.drawPath(handle, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _KarlizShoppingBagPainter oldDelegate) => oldDelegate.color != color;
}

/// 5. Billete / Efectivo para Caja
class KarlizCashIcon extends StatelessWidget {
  final double size;
  final Color color;

  const KarlizCashIcon({
    super.key,
    this.size = 20,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _KarlizCashPainter(color: color),
      ),
    );
  }
}

class _KarlizCashPainter extends CustomPainter {
  final Color color;
  _KarlizCashPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Rectángulo del billete
    final billRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.28, w * 0.76, h * 0.50),
      Radius.circular(w * 0.10),
    );
    canvas.drawRRect(billRect, strokePaint);

    // Círculo central
    canvas.drawCircle(Offset(w * 0.50, h * 0.53), w * 0.12, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _KarlizCashPainter oldDelegate) => oldDelegate.color != color;
}

/// 6. Caja de cartón para Almacén / Stock
class KarlizBoxIcon extends StatelessWidget {
  final double size;
  final Color color;

  const KarlizBoxIcon({
    super.key,
    this.size = 20,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _KarlizBoxPainter(color: color),
      ),
    );
  }
}

class _KarlizBoxPainter extends CustomPainter {
  final Color color;
  _KarlizBoxPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Contorno de la caja
    final box = Path()
      ..moveTo(w * 0.50, h * 0.15)
      ..lineTo(w * 0.86, h * 0.33)
      ..lineTo(w * 0.86, h * 0.73)
      ..lineTo(w * 0.50, h * 0.90)
      ..lineTo(w * 0.14, h * 0.73)
      ..lineTo(w * 0.14, h * 0.33)
      ..close();
    canvas.drawPath(box, strokePaint);

    // Líneas internas
    canvas.drawLine(Offset(w * 0.50, h * 0.15), Offset(w * 0.50, h * 0.90), strokePaint);
    canvas.drawLine(Offset(w * 0.14, h * 0.33), Offset(w * 0.50, h * 0.51), strokePaint);
    canvas.drawLine(Offset(w * 0.86, h * 0.33), Offset(w * 0.50, h * 0.51), strokePaint);
  }

  @override
  bool shouldRepaint(covariant _KarlizBoxPainter oldDelegate) => oldDelegate.color != color;
}

/// 7. Camión de reparto para Compras / Proveedores
class KarlizTruckIcon extends StatelessWidget {
  final double size;
  final Color color;

  const KarlizTruckIcon({
    super.key,
    this.size = 20,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _KarlizTruckPainter(color: color),
      ),
    );
  }
}

class _KarlizTruckPainter extends CustomPainter {
  final Color color;
  _KarlizTruckPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Contenedor de carga
    final cargo = Path()
      ..moveTo(w * 0.12, h * 0.32)
      ..lineTo(w * 0.60, h * 0.32)
      ..lineTo(w * 0.60, h * 0.72)
      ..lineTo(w * 0.12, h * 0.72)
      ..close();
    canvas.drawPath(cargo, strokePaint);

    // Cabina del camión
    final cabin = Path()
      ..moveTo(w * 0.60, h * 0.44)
      ..lineTo(w * 0.76, h * 0.44)
      ..lineTo(w * 0.88, h * 0.58)
      ..lineTo(w * 0.88, h * 0.72)
      ..lineTo(w * 0.60, h * 0.72);
    canvas.drawPath(cabin, strokePaint);

    // Rueda 1
    canvas.drawCircle(Offset(w * 0.28, h * 0.76), w * 0.08, strokePaint);
    // Rueda 2
    canvas.drawCircle(Offset(w * 0.74, h * 0.76), w * 0.08, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _KarlizTruckPainter oldDelegate) => oldDelegate.color != color;
}
