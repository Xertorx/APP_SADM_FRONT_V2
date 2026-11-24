import '../models/configuracion_seleccion.dart';

/// Preguntas estándar para la etapa 1 (formulario). El dador puede usarlas tal cual,
/// editarlas, quitarlas o agregar las suyas.
const _sugeridas = <(String, TipoRespuesta, List<String>)>[
  ('¿Por qué quieres adoptar a esta mascota?', TipoRespuesta.texto, []),
  (
    '¿En qué tipo de vivienda vives?',
    TipoRespuesta.seleccionUnica,
    ['Casa', 'Apartamento', 'Finca', 'Otro'],
  ),
  (
    '¿La vivienda es propia o arrendada?',
    TipoRespuesta.seleccionUnica,
    [
      'Propia',
      'Arrendada con permiso para mascotas',
      'Arrendada sin confirmar permiso',
      'Familiar',
    ],
  ),
  (
    '¿Quiénes viven contigo?',
    TipoRespuesta.seleccionMultiple,
    ['Vivo solo/a', 'Pareja', 'Niños', 'Adultos mayores', 'Otros adultos'],
  ),
  ('¿Tienes otras mascotas actualmente?', TipoRespuesta.siNo, []),
  ('¿Has tenido mascotas antes?', TipoRespuesta.siNo, []),
  (
    '¿Cuántas horas al día estaría sola la mascota?',
    TipoRespuesta.seleccionUnica,
    [
      'Menos de 2 horas',
      'Entre 2 y 4 horas',
      'Entre 4 y 8 horas',
      'Más de 8 horas',
    ],
  ),
  (
    '¿Todas las personas de tu hogar están de acuerdo con la adopción?',
    TipoRespuesta.siNo,
    [],
  ),
];

/// Puntaje por pregunta cuando la etapa todavía no tiene máximo.
const puntajeSugeridoPorPregunta = 5;

int get cantidadPreguntasSugeridas => _sugeridas.length;

/// Las preguntas sugeridas con el puntaje repartido en [puntajeMaximo] (el sobrante va a las
/// primeras). Si [puntajeMaximo] es 0, cada una vale [puntajeSugeridoPorPregunta].
List<PreguntaSeleccion> preguntasSugeridas({required int puntajeMaximo}) {
  final n = _sugeridas.length;
  final base = puntajeMaximo <= 0
      ? puntajeSugeridoPorPregunta
      : puntajeMaximo ~/ n;
  final sobrante = puntajeMaximo <= 0 ? 0 : puntajeMaximo - base * n;
  return [
    for (var i = 0; i < n; i++)
      PreguntaSeleccion(
        texto: _sugeridas[i].$1,
        tipoRespuesta: _sugeridas[i].$2,
        opciones: _sugeridas[i].$3,
        puntaje: base + (i < sobrante ? 1 : 0),
      ),
  ];
}
