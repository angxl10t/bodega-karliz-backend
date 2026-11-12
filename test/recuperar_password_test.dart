import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/auth/login_screen.dart';
import 'package:bodega_mobile/features/auth/recuperar_password_modal.dart';
import 'package:bodega_mobile/features/home/usuarios_service.dart';

void main() {
  group('UsuarioItem - Email Model Tests', () {
    test('Parsea correctamente campo email cuando viene del backend', () {
      final json = {
        'idUsuario': 12,
        'username': 'bodega-karliz',
        'nombreCompleto': 'Bodega Karliz SAC',
        'email': 'karliz@bodega.pe',
        'rol': 'ADMIN',
        'estado': true,
        'idBodega': 1,
        'nombreBodega': 'Bodega Karliz',
        'planBodega': 'PRO',
      };

      final usuario = UsuarioItem.fromJson(json);

      expect(usuario.idUsuario, 12);
      expect(usuario.username, 'bodega-karliz');
      expect(usuario.email, 'karliz@bodega.pe');
      expect(usuario.rol, 'ADMIN');
      expect(usuario.estado, isTrue);
    });

    test('Parsea correctamente cuando email es nulo', () {
      final json = {
        'idUsuario': 15,
        'username': 'cajero1',
        'rol': 'CAJERO',
        'estado': true,
      };

      final usuario = UsuarioItem.fromJson(json);

      expect(usuario.idUsuario, 15);
      expect(usuario.username, 'cajero1');
      expect(usuario.email, isNull);
    });
  });

  group('RecuperarPasswordModal Widget Tests', () {
    testWidgets(
      'Renderiza Paso 1 (Identificación) con campo para usuario o correo',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: RecuperarPasswordModal(initialIdentificador: 'bodega-test'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Título y encabezado
        expect(find.text('¿Olvidaste tu Contraseña?'), findsOneWidget);
        expect(find.text('Usuario o Correo Electrónico'), findsOneWidget);
        expect(find.text('bodega-test'), findsOneWidget);
        expect(find.text('ENVIAR CÓDIGO DE SEGURIDAD'), findsOneWidget);
        expect(find.text('Cancelar y volver al login'), findsOneWidget);
      },
    );

    testWidgets('Muestra error de validación cuando el campo está vacío', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RecuperarPasswordModal())),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('ENVIAR CÓDIGO DE SEGURIDAD'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ingresa tu usuario o correo electrónico.'),
        findsOneWidget,
      );
    });
  });

  group('LoginScreen - Enlace de Recuperación', () {
    testWidgets(
      'LoginScreen muestra enlace interactivo ¿Olvidaste tu contraseña?',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

        await tester.pumpAndSettle();

        // Verifica presencia del enlace
        expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);

        // Desplaza hasta el enlace y pulsa para abrir el modal
        await tester.ensureVisible(find.text('¿Olvidaste tu contraseña?'));
        await tester.tap(find.text('¿Olvidaste tu contraseña?'));
        await tester.pumpAndSettle();

        // El modal de recuperación debe desplegarse
        expect(find.text('¿Olvidaste tu Contraseña?'), findsOneWidget);
        expect(find.text('ENVIAR CÓDIGO DE SEGURIDAD'), findsOneWidget);
      },
    );
  });
}
