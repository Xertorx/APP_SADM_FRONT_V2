import 'mascota_detalle.dart';
import 'dador_publico.dart';

/// Publicación pendiente de moderación, devuelta por
/// `GET /api/admin/mascotas/pendientes`.
class PublicacionPendiente {
  const PublicacionPendiente({
    required this.mascota,
    required this.dador,
    this.latitud,
    this.longitud,
    this.correoDador,
    this.rolDador,
    this.estadoDador,
  });

  factory PublicacionPendiente.fromJson(Map<String, dynamic> json) {
    final dadorJson = json['dador'];
    final dador = dadorJson is Map<String, dynamic>
        ? dadorJson
        : const <String, dynamic>{};
    return PublicacionPendiente(
      mascota: MascotaDetalle.fromJson(json),
      dador: DadorPublico(
        id: _entero(dador['id']) ?? -1,
        nombre: dador['nombre'] as String? ?? '',
        apellido: dador['apellido'] as String? ?? '',
        tieneFoto: false,
      ),
      latitud: _decimal(json['latitud']),
      longitud: _decimal(json['longitud']),
      correoDador: dador['correo'] as String?,
      rolDador: dador['rol'] as String?,
      estadoDador: dador['estado'] as String?,
    );
  }

  final MascotaDetalle mascota;
  final DadorPublico dador;
  final double? latitud;
  final double? longitud;
  final String? correoDador;
  final String? rolDador;
  final String? estadoDador;

  int get id => mascota.id;
  String get nombreDador => dador.nombreCompleto;
}

int? _entero(Object? valor) =>
    valor is num ? valor.toInt() : int.tryParse('$valor');

double? _decimal(Object? valor) =>
    valor is num ? valor.toDouble() : double.tryParse('$valor');
