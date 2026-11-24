import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/formulario_postulacion.dart';
import 'api_exception.dart';
import 'auth_session.dart';

/// Etapa 1 del proceso de adopción: formulario del adoptante y evaluación del dador.
class FormularioPostulacionService {
  FormularioPostulacionService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 15);

  Uri _formulario(int postulacionId, [String sufijo = '']) => Uri.parse(
    '${AppConfig.baseUrl}/postulaciones/$postulacionId/formulario$sufijo',
  );

  Map<String, String> get _headersJson => {
    ...AuthSession.headers,
    'Content-Type': 'application/json; charset=utf-8',
  };

  // ---------------------------------------------------------------- adoptante

  /// `GET /api/postulaciones/{id}/formulario`.
  Future<FormularioPostulacion> consultar(int postulacionId) async {
    final response = await _enviar(
      () =>
          _client.get(_formulario(postulacionId), headers: AuthSession.headers),
    );
    return _objeto(response, FormularioPostulacion.fromJson);
  }

  /// `PUT /api/postulaciones/{id}/formulario`: guarda un borrador.
  Future<FormularioPostulacion> guardarBorrador(
    int postulacionId,
    Map<int, RespuestaFormulario> respuestas,
  ) async {
    final response = await _enviar(
      () => _client.put(
        _formulario(postulacionId),
        headers: _headersJson,
        body: jsonEncode(_cuerpoRespuestas(respuestas)),
      ),
    );
    return _objeto(response, FormularioPostulacion.fromJson);
  }

  /// `POST /api/postulaciones/{id}/formulario/enviar`: envío definitivo.
  Future<({FormularioPostulacion formulario, String? mensaje})> enviar(
    int postulacionId,
    Map<int, RespuestaFormulario> respuestas,
  ) async {
    final response = await _enviar(
      () => _client.post(
        _formulario(postulacionId, '/enviar'),
        headers: _headersJson,
        body: jsonEncode(_cuerpoRespuestas(respuestas)),
      ),
    );
    final formulario = _objeto(response, FormularioPostulacion.fromJson);
    return (
      formulario: formulario,
      mensaje: _mensaje(_decodificar(response.bodyBytes)),
    );
  }

  Map<String, dynamic> _cuerpoRespuestas(
    Map<int, RespuestaFormulario> respuestas,
  ) => {
    'respuestas': [
      for (final entrada in respuestas.entries)
        {
          'preguntaId': entrada.key,
          'valor': entrada.value.valor,
          'opciones': entrada.value.opciones,
        },
    ],
  };

  // ---------------------------------------------------------------- dador

  /// `GET /api/mascotas/{id}/postulaciones`.
  Future<List<Postulante>> listarPostulantes(int mascotaId) async {
    final response = await _enviar(
      () => _client.get(
        Uri.parse('${AppConfig.baseUrl}/mascotas/$mascotaId/postulaciones'),
        headers: AuthSession.headers,
      ),
    );
    if (response.statusCode != 200) throw _error(response);
    final data = _data(response);
    if (data is! List) {
      throw const ServerException('Respuesta inesperada del servidor.');
    }
    try {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Postulante.fromJson)
          .toList();
    } catch (_) {
      throw const ServerException('Respuesta inesperada del servidor.');
    }
  }

  /// `GET /api/postulaciones/{id}/formulario/evaluacion`.
  Future<EvaluacionFormulario> consultarEvaluacion(int postulacionId) async {
    final response = await _enviar(
      () => _client.get(
        _formulario(postulacionId, '/evaluacion'),
        headers: AuthSession.headers,
      ),
    );
    return _objeto(response, EvaluacionFormulario.fromJson);
  }

  /// `POST /api/postulaciones/{id}/formulario/evaluacion`.
  Future<({EvaluacionFormulario evaluacion, String? mensaje})> evaluar({
    required int postulacionId,
    required Map<int, int> puntajes,
    required bool aprobar,
    String? comentario,
  }) async {
    final response = await _enviar(
      () => _client.post(
        _formulario(postulacionId, '/evaluacion'),
        headers: _headersJson,
        body: jsonEncode({
          'calificaciones': [
            for (final e in puntajes.entries)
              {'preguntaId': e.key, 'puntaje': e.value},
          ],
          'decision': aprobar ? 'APROBAR' : 'DESCARTAR',
          'comentario': comentario?.trim(),
        }),
      ),
    );
    final evaluacion = _objeto(response, EvaluacionFormulario.fromJson);
    return (
      evaluacion: evaluacion,
      mensaje: _mensaje(_decodificar(response.bodyBytes)),
    );
  }

  // ---------------------------------------------------------------- helpers

  Future<http.Response> _enviar(
    Future<http.Response> Function() llamada,
  ) async {
    try {
      return await llamada().timeout(_timeout);
    } catch (_) {
      throw const ConnectionException();
    }
  }

  T _objeto<T>(
    http.Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (response.statusCode != 200) throw _error(response);
    final data = _data(response);
    if (data is! Map<String, dynamic>) {
      throw const ServerException('Respuesta inesperada del servidor.');
    }
    try {
      return fromJson(data);
    } catch (_) {
      throw const ServerException('Respuesta inesperada del servidor.');
    }
  }

  Object? _decodificar(List<int> bytes) {
    if (bytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(bytes));
    } catch (_) {
      return null;
    }
  }

  Object? _data(http.Response response) {
    final decoded = _decodificar(response.bodyBytes);
    return decoded is Map<String, dynamic> ? decoded['data'] : decoded;
  }

  String? _mensaje(Object? decoded) {
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message'] ?? decoded['mensaje'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
    }
    return null;
  }

  ApiException _error(http.Response response) {
    final message = _mensaje(_decodificar(response.bodyBytes));
    return switch (response.statusCode) {
      400 => ValidationException(
        message ?? 'Los datos enviados no son válidos.',
      ),
      401 => NoAutenticadoException(
        message ?? 'Tu sesión expiró. Inicia sesión para continuar.',
      ),
      403 => SinPermisosException(
        message ?? 'No tienes permisos para esta acción.',
      ),
      404 => NotFoundException(message ?? 'La postulación ya no existe.'),
      409 => ConflictoException(
        message ?? 'El estado de la postulación cambió. Actualiza e inténtalo de nuevo.',
      ),
      _ => ServerException(
        message ??
            'Ocurrió un error inesperado (código ${response.statusCode}).',
      ),
    };
  }

  void dispose() => _client.close();
}
