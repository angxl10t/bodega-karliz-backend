import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../karliz_sound_service.dart';
import '../theme.dart';

/// Modal inteligente de escaneo de código de barras para Bodega KARLIZ.
/// Compatible con Android, iOS y Web.
/// Soporta modo de escaneo único (formulario) y modo continuo (caja / compras).
class KarlizBarcodeScannerModal extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool continuous;
  final FutureOr<String?> Function(String barcode)? onBarcodeScanned;

  const KarlizBarcodeScannerModal({
    super.key,
    this.title = 'Escanear Código de Barras',
    this.subtitle = 'Enfoque el código del producto dentro del marco',
    this.continuous = false,
    this.onBarcodeScanned,
  });

  /// Abre el escáner en modo de captura única y retorna el código de barras leído.
  /// Abre el escáner en modo de captura única y retorna el código de barras leído a pantalla completa.
  static Future<String?> scan(
    BuildContext context, {
    String title = 'Escanear Código de Barras',
    String subtitle = 'Enfoque el código del producto dentro del marco',
  }) {
    return Navigator.push<String>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => KarlizBarcodeScannerModal(
          title: title,
          subtitle: subtitle,
          continuous: false,
        ),
      ),
    );
  }

  /// Abre el escáner en modo continuo a pantalla completa (ideal para caja POS o recepción de compras).
  static Future<void> showContinuous(
    BuildContext context, {
    required FutureOr<String?> Function(String barcode) onBarcodeScanned,
    String title = 'Escáner de Caja Rápida',
    String subtitle = 'Escanee productos uno tras otro para agregarlos',
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => KarlizBarcodeScannerModal(
          title: title,
          subtitle: subtitle,
          continuous: true,
          onBarcodeScanned: onBarcodeScanned,
        ),
      ),
    );
  }

  @override
  State<KarlizBarcodeScannerModal> createState() => _KarlizBarcodeScannerModalState();
}

class _KarlizBarcodeScannerModalState extends State<KarlizBarcodeScannerModal>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _controller;
  late AnimationController _laserAnimController;
  late Animation<double> _laserPosition;

  bool _isTorchOn = false;
  bool _isProcessing = false;
  String _lastScannedCode = '';
  String? _feedbackMessage;
  int _scanCount = 0;

  @override
  void initState() {
    super.initState();
    KarlizSoundService.instance.init();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 1200,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserPosition = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _laserAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _laserAnimController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    if (capture.barcodes.isEmpty) return;

    final barcode = capture.barcodes.first;
    final code = barcode.rawValue?.trim() ?? '';
    if (code.isEmpty) return;

    _isProcessing = true;
    KarlizSoundService.instance.playBarcodeBeep();

    setState(() {
      _lastScannedCode = code;
      _scanCount++;
    });

    if (widget.continuous) {
      if (widget.onBarcodeScanned != null) {
        final feedback = await widget.onBarcodeScanned!(code);
        if (mounted) {
          setState(() {
            _feedbackMessage = feedback ?? 'Leído: $code';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _feedbackMessage = 'Código: $code';
          });
        }
      }

      // Pequeña pausa antes de permitir el siguiente escaneo
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    } else {
      // Modo único: cerrar devolviendo el código
      if (mounted) {
        Navigator.of(context).pop(code);
      }
    }
  }

  void _abrirDialogoManual() {
    final manualCtrl = TextEditingController(text: _lastScannedCode);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Ingreso Manual de Código',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Escriba el código de barras o SKU del producto:',
                style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: manualCtrl,
                autofocus: true,
                keyboardType: TextInputType.text,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 1.0,
                ),
                decoration: InputDecoration(
                  hintText: 'Ej. 7751234567890',
                  hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  prefixIcon: const Icon(LucideIcons.barcode, color: AppTheme.brandPrimary, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.brandPrimary, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: GoogleFonts.plusJakartaSans(color: Colors.white60),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                final text = manualCtrl.text.trim();
                Navigator.pop(ctx);
                if (text.isNotEmpty) {
                  KarlizSoundService.instance.playBarcodeBeep();
                  if (widget.continuous) {
                    _handleBarcode(BarcodeCapture(barcodes: [Barcode(rawValue: text)]));
                  } else {
                    Navigator.of(context).pop(text);
                  }
                }
              },
              child: Text(
                'Aceptar',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final scanAreaSize = (size.width * 0.72).clamp(240.0, 320.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0A0F1D),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0F1D),
        body: Stack(
          children: [
            // 1. CÁMARA (MobileScanner Fullscreen Edge-to-Edge)
            Positioned.fill(
              child: MobileScanner(
                controller: _controller,
                fit: BoxFit.cover,
                onDetect: _handleBarcode,
              errorBuilder: (context, error) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.cameraOff, size: 54, color: Color(0xFFEF4444)),
                        const SizedBox(height: 16),
                        Text(
                          'Cámara no disponible',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Verifique los permisos de cámara en Android o use el ingreso manual.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _abrirDialogoManual,
                          icon: const Icon(LucideIcons.keyboard, size: 18),
                          label: const Text('Ingresar Código Manualmente'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. CAPA OSCURA CON RECORTE CENTRAL (SCANNER OVERLAY)
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.62),
              BlendMode.srcOut,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: scanAreaSize,
                    height: scanAreaSize * 0.72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. MARCO VISUAL DEL ESCÁNER Y LÁSER ANIMADO
          Center(
            child: SizedBox(
              width: scanAreaSize,
              height: scanAreaSize * 0.72,
              child: Stack(
                children: [
                  // Esquinas decorativas
                  CustomPaint(
                    size: Size(scanAreaSize, scanAreaSize * 0.72),
                    painter: _ScannerCornersPainter(
                      color: _isProcessing ? AppTheme.accentGreen : AppTheme.brandPrimary,
                    ),
                  ),

                  // Línea láser animada
                  AnimatedBuilder(
                    animation: _laserPosition,
                    builder: (context, child) {
                      return Positioned(
                        top: (scanAreaSize * 0.72) * _laserPosition.value,
                        left: 12,
                        right: 12,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                (_isProcessing ? AppTheme.accentGreen : AppTheme.brandPrimary).withValues(alpha: 0.8),
                                _isProcessing ? AppTheme.accentGreen : const Color(0xFF2DD4BF),
                                (_isProcessing ? AppTheme.accentGreen : AppTheme.brandPrimary).withValues(alpha: 0.8),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_isProcessing ? AppTheme.accentGreen : AppTheme.brandPrimary).withValues(alpha: 0.6),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 4. CABECERA CON TÍTULO Y CONTROLES SUPERIORES (Llega hasta el borde superior)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, topPadding + 10, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.92),
                    Colors.black.withValues(alpha: 0.60),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.70, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.brandPrimary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.brandPrimary.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(LucideIcons.scanBarcode, color: Color(0xFF2DD4BF), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.all(8),
                    ),
                    icon: const Icon(LucideIcons.x, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),

          // 5. BARRA DE HERRAMIENTAS (Linterna, Cambiar Cámara, Teclado)
          Positioned(
            top: topPadding + 84,
            right: 18,
            child: Column(
              children: [
                _buildCircularButton(
                  icon: _isTorchOn ? LucideIcons.zap : LucideIcons.zapOff,
                  color: _isTorchOn ? const Color(0xFFFBBF24) : Colors.white,
                  bgColor: _isTorchOn ? const Color(0xFFFBBF24).withValues(alpha: 0.2) : Colors.black45,
                  tooltip: 'Linterna',
                  onTap: () async {
                    await _controller.toggleTorch();
                    setState(() => _isTorchOn = !_isTorchOn);
                  },
                ),
                const SizedBox(height: 12),
                _buildCircularButton(
                  icon: LucideIcons.switchCamera,
                  color: Colors.white,
                  bgColor: Colors.black45,
                  tooltip: 'Girar Cámara',
                  onTap: () => _controller.switchCamera(),
                ),
                const SizedBox(height: 12),
                _buildCircularButton(
                  icon: LucideIcons.keyboard,
                  color: const Color(0xFF2DD4BF),
                  bgColor: Colors.black45,
                  tooltip: 'Ingreso Manual',
                  onTap: _abrirDialogoManual,
                ),
              ],
            ),
          ),

          // 6. PIE DE PÁGINA (BANNER DE ESTADO & BOTONES DE CONTROL)
          Positioned(
            bottom: bottomPadding + 20,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_feedbackMessage != null || _lastScannedCode.isNotEmpty)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131A29).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isProcessing ? AppTheme.accentGreen : AppTheme.brandPrimary,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isProcessing ? LucideIcons.checkCircle2 : LucideIcons.barcode,
                          size: 18,
                          color: _isProcessing ? AppTheme.accentGreen : const Color(0xFF2DD4BF),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _feedbackMessage ?? 'Código: $_lastScannedCode',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Botón Terminar en Modo Continuo o Botón Ingreso Manual
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          backgroundColor: Colors.black38,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        onPressed: _abrirDialogoManual,
                        icon: const Icon(LucideIcons.keyboard, size: 18),
                        label: Text(
                          'Digitar Código',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                      ),
                    ),
                    if (widget.continuous) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 4,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(LucideIcons.checkCheck, size: 18),
                          label: Text(
                            'Listo ($_scanCount)',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 1.2),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

/// Dibuja las 4 esquinas del marco de escaneo con diseño futurista
class _ScannerCornersPainter extends CustomPainter {
  final Color color;
  _ScannerCornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 26.0;
    const radius = 18.0;

    // Superior Izquierda
    final pathTL = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(cornerLength, 0);
    canvas.drawPath(pathTL, paint);

    // Superior Derecha
    final pathTR = Path()
      ..moveTo(size.width - cornerLength, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, cornerLength);
    canvas.drawPath(pathTR, paint);

    // Inferior Izquierda
    final pathBL = Path()
      ..moveTo(0, size.height - cornerLength)
      ..lineTo(0, size.height - radius)
      ..quadraticBezierTo(0, size.height, radius, size.height)
      ..lineTo(cornerLength, size.height);
    canvas.drawPath(pathBL, paint);

    // Inferior Derecha
    final pathBR = Path()
      ..moveTo(size.width - cornerLength, size.height)
      ..lineTo(size.width - radius, size.height)
      ..quadraticBezierTo(size.width, size.height, size.width, size.height - radius)
      ..lineTo(size.width, size.height - cornerLength);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerCornersPainter oldDelegate) => oldDelegate.color != color;
}
