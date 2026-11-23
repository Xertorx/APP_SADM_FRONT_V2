import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/publicacion_pendiente.dart';
import 'api_exception.dart';
import 'auth_session.dart';

/// HTTP client for the administrator's pending pet publication moderation flow (HU26).
class AdminMascotasService {
  AdminMascotasService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 15);

  Uri _uri([String suffix = '']) =>
      Uri.parse('${AppConfig.baseUrl}/admin/mascotas$suffix');

  /// `GET /api/admin/mascotas/pendientes`.
  Future<List<PublicacionPendiente>> listarPendientes() async {
    final response = await _enviar(
      () => _client.get(_uri('/pendientes'), headers: AuthSession.headers),
    );
    if (response.statusCode != 200) throw _error(response);
    final data = _data(response);
    if (data is! List) {
      throw const ServerException('Respuesta inesperada del servidor.');
    }
    try {
      return data
          .whereType<Map<String, dynamic>>()
          .map(PublicacionPendiente.fromJson)
          .toList(growable: true);
    } catch (_) {
      throw const ServerException('Respuesta inesperada del servidor.');
    }
  }

  /// `POST /api/admin/mascotas/{id}/aprobar`.
  Future<String?> aprobar(int id) async {
    final response = await _enviar(
      () => _client.post(_uri('/$id/aprobar'), headers: AuthSession.headers),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _error(response);
    }
    return _mensaje(_decodificar(response.bodyBytes));
  }

  /// `DELETE /api/admin/mascotas/{id}` with the mandatory reason in JSON.
  Future<String?> rechazar(int id, String motivo) async {
    final response = await _enviar(
      () => _client.delete(
        _uri('/$id'),
        headers: {
          ...AuthSession.headers,
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({'motivo': motivo.trim()}),
      ),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _error(response);
    }
    return _mensaje(_decodificar(response.bodyBytes));
  }

  Future<http.Response> _enviar(
    Future<http.Response> Function() llamada,
  ) async {
    try {
      return await llamada().timeout(_timeout);
    } catch (_) {
      throw const ConnectionException();
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
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        for (final value in data.values) {
          if (value is String && value.trim().isNotEmpty) return value.trim();
        }
      }
    }
    return null;
  }

  ApiException _error(http.Response response) {
    final decoded = _decodificar(response.bodyBytes);
    final message = _mensaje(decoded);
    switch (response.statusCode) {
      case 400:
        return ValidationException(
          message ?? 'Los datos enviados no son válidos.',
        );
      case 401:
        return NoAutenticadoException(
          message ?? 'Tu sesión expiró. Inicia sesión para continuar.',
        );
      case 403:
        return SinPermisosException(
          message ?? 'Solo un administrador puede moderar publicaciones.',
        );
      case 404:
        return NotFoundException(message ?? 'La publicación ya no existe.');
      case 409:
        return ConflictoException(
          message ?? 'El estado de la publicación cambió. Actualiza la lista e inténtalo de nuevo.',
        );
      default:
        return ServerException(
          message ??
              'Ocurrió un error inesperado (código ${response.statusCode}).',
        );
    }
  }

  void dispose() => _client.close();
}
