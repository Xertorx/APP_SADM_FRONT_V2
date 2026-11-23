import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sadm/models/mascota.dart';
import 'package:sadm/models/publicacion_pendiente.dart';
import 'package:sadm/screens/admin_mascotas_screen.dart';
import 'package:sadm/services/admin_mascotas_service.dart';
import 'package:sadm/services/api_exception.dart';
import 'package:sadm/services/auth_session.dart';
import 'package:sadm/services/mascota_service.dart';
import 'package:sadm/theme/app_theme.dart';

Map<String, dynamic> _publicacion({
  int id = 12,
  String estado = 'PENDIENTE_REVISION',
}) => {
  'id': id,
  'nombre': 'Luna',
  'especie': 'PERRO',
  'raza': 'Criolla',
  'edad': 3,
  'unidadEdad': 'ANIOS',
  'tamano': 'MEDIANO',
  'sexo': 'HEMBRA',
  'temperamento': ['TRANQUILO'],
  'historialSalud': 'Vacunas al día',
  'ubicacion': 'Bogotá, Suba',
  'latitud': 4.65,
  'longitud': -74.1,
  'estado': estado,
  'fechaPublicacion': '2026-10-25T10:00:00Z',
  'fotosIds': [9, 10],
  'dador': {
    'id': 5,
    'nombre': 'Ana',
    'apellido': 'Pérez',
    'correo': 'ana@example.com',
    'rol': 'USUARIO',
    'estado': 'ACTIVO',
  },
};

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _envelope(
  Object data, {
  String message = 'Operación correcta',
}) => {'status': 200, 'message': message, 'data': data};

Future<void> _abrir(
  WidgetTester tester,
  Widget screen, {
  double alto = 2200,
}) async {
  tester.view.physicalSize = Size(900, alto);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: screen));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    AuthSession.iniciar('token-de-prueba');
    AuthSession.rol = 'ADMINISTRADOR';
  });
  tearDown(AuthSession.limpiar);

  group('PublicacionPendiente', () {
    test('interpreta los datos de mascota, fotos, coordenadas y dador', () {
      final item = PublicacionPendiente.fromJson(_publicacion());
      expect(item.id, 12);
      expect(item.mascota.datosClave, 'Perro · Criolla · 3 años · Mediano');
      expect(item.mascota.historialSalud, 'Vacunas al día');
      expect(item.mascota.galeria, hasLength(2));
      expect(item.latitud, 4.65);
      expect(item.longitud, -74.1);
      expect(item.nombreDador, 'Ana Pérez');
      expect(item.correoDador, 'ana@example.com');
      expect(item.rolDador, 'USUARIO');
    });
  });

  group('AdminMascotasService', () {
    test('GET pendientes envía el JWT y traduce la lista del sobre', () async {
      late http.Request request;
      final service = AdminMascotasService(
        client: MockClient((r) async {
          request = r;
          return _json(_envelope([_publicacion()]));
        }),
      );

      final pendientes = await service.listarPendientes();

      expect(request.method, 'GET');
      expect(request.url.path, endsWith('/admin/mascotas/pendientes'));
      expect(request.headers['Authorization'], 'Bearer token-de-prueba');
      expect(pendientes.single.id, 12);
    });

    test('aprobar y rechazar usan las rutas y el motivo trimmeado', () async {
      final requests = <http.Request>[];
      final service = AdminMascotasService(
        client: MockClient((r) async {
          requests.add(r);
          return _json(_envelope({}, message: 'Publicación procesada'));
        }),
      );

      expect(await service.aprobar(12), 'Publicación procesada');
      expect(
        await service.rechazar(12, '  Falta información  '),
        'Publicación procesada',
      );

      expect(requests[0].method, 'POST');
      expect(requests[0].url.path, endsWith('/admin/mascotas/12/aprobar'));
      expect(requests[0].headers['Authorization'], 'Bearer token-de-prueba');
      expect(requests[1].method, 'DELETE');
      expect(requests[1].url.path, endsWith('/admin/mascotas/12'));
      expect(requests[1].headers['Content-Type'], contains('application/json'));
      expect(jsonDecode(requests[1].body), {'motivo': 'Falta información'});
    });

    test('mapea 400, 401, 403, 404 y 409', () async {
      Future<void> valida(int status, Type tipo) async {
        final service = AdminMascotasService(
          client: MockClient(
            (_) async => _json({'message': 'Error backend'}, status),
          ),
        );
        await expectLater(
          service.aprobar(12),
          throwsA(
            isA<ApiException>().having((e) => e.runtimeType, 'tipo', tipo),
          ),
        );
      }

      await valida(400, ValidationException);
      await valida(401, NoAutenticadoException);
      await valida(403, SinPermisosException);
      await valida(404, NotFoundException);
      await valida(409, ConflictoException);
    });

    test('usa el detalle de validación enviado en data para los 400', () async {
      final service = AdminMascotasService(
        client: MockClient(
          (_) async => _json({
            'status': 400,
            'data': {'motivo': 'El motivo es obligatorio'},
          }, 400),
        ),
      );
      await expectLater(
        service.rechazar(12, ''),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'El motivo es obligatorio',
          ),
        ),
      );
    });

    test('PUT de moderación envía datos como parte JSON en multipart al endpoint admin', () async {
      late http.BaseRequest request;
      late String body;
      final client = MockClient.streaming((r, stream) async {
        request = r;
        body = utf8.decode(await stream.toBytes());
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(_envelope({})))),
          200,
        );
      });
      final service = MascotaService(client: client);

      await service.actualizarModeracion(
        12,
        const Mascota(
          idDador: 5,
          nombre: 'Luna corregida',
          especie: 'PERRO',
          edad: 3,
          unidadEdad: 'ANIOS',
          tamano: 'MEDIANO',
          sexo: 'HEMBRA',
          temperamento: ['TRANQUILO'],
          ubicacion: 'Bogotá',
          latitud: 4.65,
          longitud: -74.1,
        ),
        const [],
      );

      expect(request, isA<http.MultipartRequest>());
      expect(request.method, 'PUT');
      expect(request.url.path, endsWith('/admin/mascotas/12'));
      expect(request.headers['Authorization'], 'Bearer token-de-prueba');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      expect(body, contains('name="datos"'));
      expect(body, contains('"nombre":"Luna corregida"'));
      expect(body, contains('"idDador":5'));
      expect(body, isNot(contains('"estado"')));
      expect(body, isNot(contains('"rol"')));
    });
  });

  group('AdminMascotasScreen', () {
    late int getCalls;
    late List<http.Request> requests;
    late bool failApprove;

    AdminMascotasService fakeService() => AdminMascotasService(
      client: MockClient((r) async {
        requests.add(r);
        if (r.method == 'GET') {
          getCalls++;
          return _json(_envelope([_publicacion()]));
        }
        if (r.method == 'POST' &&
            r.url.path.endsWith('/aprobar') &&
            failApprove) {
          return _json({'message': 'El estado cambió'}, 409);
        }
        return _json(_envelope({}, message: 'Servidor: listo'));
      }),
    );

    setUp(() {
      getCalls = 0;
      requests = [];
      failApprove = false;
    });

    testWidgets(
      'carga y muestra información principal, dador y acceso a vista previa',
      (tester) async {
        await _abrir(tester, AdminMascotasScreen(service: fakeService()));

        expect(getCalls, 1);
        expect(find.text('Luna'), findsOneWidget);
        expect(find.textContaining('Ana Pérez'), findsOneWidget);
        expect(find.textContaining('Bogotá, Suba'), findsOneWidget);
        expect(find.text('Vista previa completa'), findsOneWidget);

        await tester.tap(find.text('Vista previa completa'));
        await tester.pumpAndSettle();
        expect(find.text('Datos del dador'), findsOneWidget);
        expect(find.text('Correo: ana@example.com'), findsOneWidget);
        expect(find.text('Historial de salud: Vacunas al día'), findsOneWidget);
        expect(find.text('Coordenadas: 4.65, -74.1'), findsOneWidget);
      },
    );

    testWidgets(
      'sin rol administrador bloquea el acceso sin consultar el API',
      (tester) async {
        AuthSession.rol = 'USUARIO';
        await _abrir(tester, AdminMascotasScreen(service: fakeService()));

        expect(find.textContaining('Solo un administrador'), findsOneWidget);
        expect(getCalls, 0);
      },
    );

    testWidgets(
      'aprobar confirma, usa el mensaje del servidor y retira solo tras éxito',
      (tester) async {
        await _abrir(tester, AdminMascotasScreen(service: fakeService()));

        await tester.tap(find.byKey(const Key('aprobar-12')));
        await tester.pumpAndSettle();
        expect(
          find.text('¿Confirmas aprobar la publicación de Luna?'),
          findsOneWidget,
        );
        expect(requests.where((r) => r.url.path.endsWith('/aprobar')), isEmpty);

        await tester.tap(find.byKey(const Key('confirmar-aprobar')));
        await tester.pumpAndSettle();
        expect(requests.last.url.path, endsWith('/admin/mascotas/12/aprobar'));
        expect(find.text('Luna'), findsNothing);
        expect(find.text('Servidor: listo'), findsOneWidget);
      },
    );

    testWidgets(
      'un 409 conserva la publicación y permite actualizar la lista',
      (tester) async {
        failApprove = true;
        await _abrir(tester, AdminMascotasScreen(service: fakeService()));

        await tester.tap(find.byKey(const Key('aprobar-12')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirmar-aprobar')));
        await tester.pumpAndSettle();

        expect(find.text('Luna'), findsOneWidget);
        expect(find.text('El estado cambió'), findsOneWidget);
        expect(find.text('Actualizar lista'), findsOneWidget);
        await tester.tap(find.text('Actualizar lista'));
        await tester.pumpAndSettle();
        expect(getCalls, 2);
      },
    );

    testWidgets(
      'rechazo no acepta motivo vacío y envía el motivo válido trimmeado',
      (tester) async {
        await _abrir(tester, AdminMascotasScreen(service: fakeService()));

        await tester.tap(find.byKey(const Key('rechazar-12')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirmar-rechazar')));
        await tester.pumpAndSettle();
        expect(find.text('El motivo es obligatorio.'), findsOneWidget);
        expect(requests.where((r) => r.method == 'DELETE'), isEmpty);

        await tester.enterText(
          find.byKey(const Key('motivo-rechazo')),
          '  Falta información  ',
        );
        await tester.tap(find.byKey(const Key('confirmar-rechazar')));
        await tester.pumpAndSettle();

        final request = requests.last;
        expect(request.method, 'DELETE');
        expect(jsonDecode(request.body), {'motivo': 'Falta información'});
        expect(find.text('Luna'), findsNothing);
        expect(find.text('Servidor: listo'), findsOneWidget);
      },
    );

    testWidgets('lista vacía ofrece su estado vacío', (tester) async {
      final empty = AdminMascotasService(
        client: MockClient((_) async => _json(_envelope([]))),
      );
      await _abrir(tester, AdminMascotasScreen(service: empty));
      expect(
        find.text('No hay publicaciones pendientes de moderación.'),
        findsOneWidget,
      );
    });

    testWidgets('error de carga muestra el mensaje y permite reintentar', (
      tester,
    ) async {
      var attempts = 0;
      final service = AdminMascotasService(
        client: MockClient((_) async {
          attempts++;
          return attempts == 1
              ? _json({'message': 'Servicio no disponible'}, 500)
              : _json(_envelope([_publicacion()]));
        }),
      );
      await _abrir(tester, AdminMascotasScreen(service: service));

      expect(find.text('Servicio no disponible'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('Luna'), findsOneWidget);
    });

    testWidgets(
      'editar abre el formulario precargado y conserva publicación pendiente',
      (tester) async {
        late http.BaseRequest updateRequest;
        final mascotaClient = MockClient.streaming((r, stream) async {
          updateRequest = r;
          await stream.drain<void>();
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode(_envelope({})))),
            200,
          );
        });

        await _abrir(
          tester,
          AdminMascotasScreen(
            service: fakeService(),
            mascotaService: MascotaService(client: mascotaClient),
          ),
        );

        await tester.tap(find.byKey(const Key('editar-12')));
        await tester.pumpAndSettle();
        expect(find.text('Corregir publicación'), findsOneWidget);
        expect(find.text('Luna'), findsOneWidget);
        await tester.tap(find.text('Guardar cambios'));
        await tester.pumpAndSettle();

        expect(updateRequest.url.path, endsWith('/admin/mascotas/12'));
        expect(getCalls, 2);
        expect(find.text('Luna'), findsOneWidget);
        expect(
          find.text(
            'Publicación editada y enviada nuevamente al flujo de moderación.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
