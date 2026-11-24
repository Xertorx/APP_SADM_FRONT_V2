import 'configuracion_seleccion.dart';

/// Estados internos de la postulación que usa la etapa 1.
class EstadoPostulacionCodigo {
  EstadoPostulacionCodigo._();

  static const etapa1EnCurso = 'ETAPA_1_EN_CURSO';
  static const etapa1EnEvaluacion = 'ETAPA_1_EN_EVALUACION';
  static const etapa2EnCurso = 'ETAPA_2_EN_CURSO';
  static const descartadaEtapa1 = 'DESCARTADA_ETAPA_1';
}

/// Respuesta del adoptante a una pregunta. [valor] se usa en texto, sí/no y selección
/// única; [opciones] en selección múltiple.
class RespuestaFormulario {
  const RespuestaFormulario({this.valor, this.opciones = const []});

  final String? valor;
  final List<String> opciones;

  bool get vacia =>
      (valor == null || valor!.trim().isEmpty) && opciones.isEmpty;
}

/// Pregunta del formulario de la etapa 1 (vista del adoptante).
class PreguntaFormulario {
  const PreguntaFormulario({
    required this.id,
    required this.texto,
    required this.tipo,
    required this.opciones,
    required this.respuesta,
  });

  factory PreguntaFormulario.fromJson(Map<String, dynamic> json) =>
      PreguntaFormulario(
        id: _entero(json['id']) ?? 0,
        texto: _texto(json['texto']),
        tipo: TipoRespuesta.desdeCodigo(json['tipoRespuesta']),
        opciones: _lista(json['opciones']),
        respuesta: RespuestaFormulario(
          valor: json['respuesta'] as String?,
          opciones: _lista(json['respuestaOpciones']),
        ),
      );

  final int id;
  final String texto;
  final TipoRespuesta tipo;
  final List<String> opciones;
  final RespuestaFormulario respuesta;
}

/// `GET /api/postulaciones/{id}/formulario`.
class FormularioPostulacion {
  const FormularioPostulacion({
    required this.postulacionId,
    required this.mascotaId,
    required this.mascotaNombre,
    required this.estado,
    required this.estadoEtiqueta,
    required this.editable,
    this.etapaActual = 1,
    this.etapaNombre = '',
    required this.enviado,
    required this.preguntas,
    this.fechaEnvio,
    this.comentarioEvaluacion,
  });

  factory FormularioPostulacion.fromJson(Map<String, dynamic> json) =>
      FormularioPostulacion(
        postulacionId: _entero(json['postulacionId']) ?? 0,
        mascotaId: _entero(json['mascotaId']) ?? 0,
        mascotaNombre: _texto(json['mascotaNombre']),
        estado: _texto(json['estado']),
        estadoEtiqueta: _texto(json['estadoEtiqueta']),
        editable: json['editable'] == true,
        etapaActual: _entero(json['etapaActual']) ?? 1,
        etapaNombre: _texto(json['etapaNombre']),
        enviado: json['enviado'] == true,
        fechaEnvio: _fecha(json['fechaEnvio']),
        comentarioEvaluacion: json['comentarioEvaluacion'] as String?,
        preguntas: _mapas(json['preguntas'])
            .map(PreguntaFormulario.fromJson)
            .toList(),
      );

  final int postulacionId;
  final int mascotaId;
  final String mascotaNombre;
  final String estado;
  final String estadoEtiqueta;
  final bool editable;
  final int etapaActual;
  final String etapaNombre;
  final bool enviado;
  final DateTime? fechaEnvio;
  final String? comentarioEvaluacion;
  final List<PreguntaFormulario> preguntas;
}

/// Pregunta con la respuesta del adoptante y su calificación (vista del dador).
class PreguntaEvaluacion {
  const PreguntaEvaluacion({
    required this.id,
    required this.texto,
    required this.tipo,
    required this.opciones,
    required this.puntajeMaximo,
    required this.respuesta,
    this.puntajeAsignado,
  });

  factory PreguntaEvaluacion.fromJson(Map<String, dynamic> json) =>
      PreguntaEvaluacion(
        id: _entero(json['id']) ?? 0,
        texto: _texto(json['texto']),
        tipo: TipoRespuesta.desdeCodigo(json['tipoRespuesta']),
        opciones: _lista(json['opciones']),
        puntajeMaximo: _entero(json['puntajeMaximo']) ?? 0,
        respuesta: RespuestaFormulario(
          valor: json['respuesta'] as String?,
          opciones: _lista(json['respuestaOpciones']),
        ),
        puntajeAsignado: _entero(json['puntajeAsignado']),
      );

  final int id;
  final String texto;
  final TipoRespuesta tipo;
  final List<String> opciones;
  final int puntajeMaximo;
  final RespuestaFormulario respuesta;
  final int? puntajeAsignado;

  bool get respondida => !respuesta.vacia;
}

/// `GET /api/postulaciones/{id}/formulario/evaluacion`.
class EvaluacionFormulario {
  const EvaluacionFormulario({
    required this.postulacionId,
    required this.mascotaNombre,
    required this.adoptanteNombre,
    required this.estado,
    required this.estadoEtiqueta,
    required this.evaluable,
    required this.puntajeMaximoEtapa,
    this.etapaActual = 1,
    this.etapaNombre = '',
    required this.puntajeObtenido,
    required this.preguntas,
    this.fechaEnvio,
    this.fechaEvaluacion,
    this.comentario,
  });

  factory EvaluacionFormulario.fromJson(Map<String, dynamic> json) =>
      EvaluacionFormulario(
        postulacionId: _entero(json['postulacionId']) ?? 0,
        mascotaNombre: _texto(json['mascotaNombre']),
        adoptanteNombre: _texto(json['adoptanteNombre']),
        estado: _texto(json['estado']),
        estadoEtiqueta: _texto(json['estadoEtiqueta']),
        evaluable: json['evaluable'] == true,
        etapaActual: _entero(json['etapaActual']) ?? 1,
        etapaNombre: _texto(json['etapaNombre']),
        fechaEnvio: _fecha(json['fechaEnvio']),
        fechaEvaluacion: _fecha(json['fechaEvaluacion']),
        puntajeMaximoEtapa: _entero(json['puntajeMaximoEtapa']) ?? 0,
        puntajeObtenido: _entero(json['puntajeObtenido']) ?? 0,
        comentario: json['comentario'] as String?,
        preguntas: _mapas(json['preguntas'])
            .map(PreguntaEvaluacion.fromJson)
            .toList(),
      );

  final int postulacionId;
  final String mascotaNombre;
  final String adoptanteNombre;
  final String estado;
  final String estadoEtiqueta;
  final bool evaluable;
  final int etapaActual;
  final String etapaNombre;
  final DateTime? fechaEnvio;
  final DateTime? fechaEvaluacion;
  final int puntajeMaximoEtapa;
  final int puntajeObtenido;
  final String? comentario;
  final List<PreguntaEvaluacion> preguntas;
}

/// Fila de `GET /api/mascotas/{id}/postulaciones` (vista del dador).
class Postulante {
  const Postulante({
    required this.postulacionId,
    required this.adoptanteNombre,
    required this.estado,
    required this.estadoEtiqueta,
    required this.etapaActual,
    required this.puntaje,
    required this.formularioEnviado,
    this.etapaNombre = '',
    required this.pendienteEvaluacion,
    this.fechaPostulacion,
    this.fechaEnvioFormulario,
  });

  factory Postulante.fromJson(Map<String, dynamic> json) => Postulante(
    postulacionId: _entero(json['postulacionId']) ?? 0,
    adoptanteNombre: _texto(json['adoptanteNombre']),
    fechaPostulacion: _fecha(json['fechaPostulacion']),
    estado: _texto(json['estado']),
    estadoEtiqueta: _texto(json['estadoEtiqueta']),
    etapaActual: _entero(json['etapaActual']) ?? 1,
    etapaNombre: _texto(json['etapaNombre']),
    puntaje: _entero(json['puntaje']) ?? 0,
    formularioEnviado: json['formularioEnviado'] == true,
    fechaEnvioFormulario: _fecha(json['fechaEnvioFormulario']),
    pendienteEvaluacion: json['pendienteEvaluacion'] == true,
  );

  final int postulacionId;
  final String adoptanteNombre;
  final DateTime? fechaPostulacion;
  final String estado;
  final String estadoEtiqueta;
  final int etapaActual;
  final String etapaNombre;
  final int puntaje;
  final bool formularioEnviado;
  final DateTime? fechaEnvioFormulario;
  final bool pendienteEvaluacion;
}

int? _entero(Object? valor) =>
    valor is num ? valor.toInt() : int.tryParse('$valor');

String _texto(Object? valor) => valor is String ? valor : '';

DateTime? _fecha(Object? valor) =>
    valor is String ? DateTime.tryParse(valor) : null;

List<String> _lista(Object? valor) => valor is List
    ? valor.whereType<String>().toList(growable: false)
    : const [];

Iterable<Map<String, dynamic>> _mapas(Object? valor) =>
    valor is List ? valor.whereType<Map<String, dynamic>>() : const [];
