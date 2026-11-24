/// Estado que ve el adoptante (HU21). El backend lo manda como texto.
enum EstadoMiPostulacion {
  activa,
  ganadora,
  descartada;

  /// Convierte el texto del backend; un valor desconocido se trata como activa.
  static EstadoMiPostulacion desdeTexto(String? valor) {
    switch (valor?.toUpperCase()) {
      case 'GANADORA':
        return EstadoMiPostulacion.ganadora;
      case 'DESCARTADA':
        return EstadoMiPostulacion.descartada;
      default:
        return EstadoMiPostulacion.activa;
    }
  }

  String get texto => switch (this) {
        EstadoMiPostulacion.activa => 'ACTIVA',
        EstadoMiPostulacion.ganadora => 'GANADORA',
        EstadoMiPostulacion.descartada => 'DESCARTADA',
      };
}

/// Una fila de `GET /api/postulaciones/mias`.
class MiPostulacion {
  const MiPostulacion({
    required this.id,
    required this.mascotaId,
    required this.mascotaNombre,
    required this.dadorNombre,
    required this.nombreProceso,
    required this.etapaActual,
    required this.totalEtapas,
    required this.puntaje,
    required this.estado,
    required this.estadoEtiqueta,
    this.fechaPostulacion,
    this.primeraFotoId,
    this.estadoDetalle,
    this.fechaActualizacion,
    this.estadoCodigo,
  });

  final int id;
  final DateTime? fechaPostulacion;
  final int mascotaId;
  final String mascotaNombre;
  final int? primeraFotoId;
  final String dadorNombre;
  final String nombreProceso;
  final int etapaActual;
  final int totalEtapas;
  final int puntaje;
  final EstadoMiPostulacion estado;
  final String estadoEtiqueta;
  final String? estadoDetalle;
  final DateTime? fechaActualizacion;

  /// Estado interno del backend (p. ej. ETAPA_1_EN_CURSO).
  final String? estadoCodigo;

  /// Etapa 1 pendiente: el adoptante debe responder el formulario.
  bool get formularioPendiente => estadoCodigo == 'ETAPA_1_EN_CURSO';

  /// El adoptante ya envió el formulario (en evaluación o evaluado).
  bool get formularioEnviado =>
      estadoCodigo != null &&
      estadoCodigo != 'ETAPA_1_EN_CURSO' &&
      !estadoCodigo!.startsWith('CANCELADA');

  bool get esActiva => estado == EstadoMiPostulacion.activa;
  bool get esGanadora => estado == EstadoMiPostulacion.ganadora;
  bool get esDescartada => estado == EstadoMiPostulacion.descartada;

  /// Ruta de la imagen de la primera foto (HU11), o null si no tiene fotos.
  /// Se resuelve a URL absoluta con `resolverUrlFoto`.
  String? get fotoPath =>
      primeraFotoId == null ? null : '/SADM/api/mascotas/fotos/$primeraFotoId/imagen';

  factory MiPostulacion.fromJson(Map<String, dynamic> json) {
    final total = _entero(json['totalEtapas']) ?? 4;
    final etapa = (_entero(json['etapaActual']) ?? 1).clamp(1, total);
    return MiPostulacion(
      id: _entero(json['id']) ?? 0,
      fechaPostulacion: _fecha(json['fechaPostulacion']),
      mascotaId: _entero(json['mascotaId']) ?? 0,
      mascotaNombre: (json['mascotaNombre'] as String?) ?? '',
      primeraFotoId: _entero(json['primeraFotoId']),
      dadorNombre: (json['dadorNombre'] as String?) ?? '',
      nombreProceso: (json['nombreProceso'] as String?) ?? '',
      etapaActual: etapa,
      totalEtapas: total,
      puntaje: _entero(json['puntaje']) ?? 0,
      estado: EstadoMiPostulacion.desdeTexto(json['estado'] as String?),
      estadoEtiqueta: (json['estadoEtiqueta'] as String?) ?? '',
      estadoDetalle: json['estadoDetalle'] as String?,
      fechaActualizacion: _fecha(json['fechaActualizacion']),
      estadoCodigo: json['estadoCodigo'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fechaPostulacion': fechaPostulacion?.toUtc().toIso8601String(),
        'mascotaId': mascotaId,
        'mascotaNombre': mascotaNombre,
        'primeraFotoId': primeraFotoId,
        'dadorNombre': dadorNombre,
        'nombreProceso': nombreProceso,
        'etapaActual': etapaActual,
        'totalEtapas': totalEtapas,
        'puntaje': puntaje,
        'estado': estado.texto,
        'estadoEtiqueta': estadoEtiqueta,
        'estadoDetalle': estadoDetalle,
        'fechaActualizacion': fechaActualizacion?.toUtc().toIso8601String(),
        'estadoCodigo': estadoCodigo,
      };

  static int? _entero(Object? valor) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    if (valor is String) return int.tryParse(valor);
    return null;
  }

  static DateTime? _fecha(Object? valor) =>
      valor is String ? DateTime.tryParse(valor) : null;
}
