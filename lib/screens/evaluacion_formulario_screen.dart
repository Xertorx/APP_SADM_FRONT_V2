import 'package:flutter/material.dart';

import '../models/configuracion_seleccion.dart';
import '../models/formulario_postulacion.dart';
import '../services/api_exception.dart';
import '../services/formulario_postulacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/fecha_formato.dart';

/// Etapa 1 (dador): revisa las respuestas del adoptante, asigna un puntaje a cada una
/// (0..máximo de la pregunta) y decide si la postulación pasa a la etapa 2 o se descarta.
/// Cierra con `true` si se registró la evaluación.
class EvaluacionFormularioScreen extends StatefulWidget {
  const EvaluacionFormularioScreen({
    super.key,
    required this.postulacionId,
    this.service,
  });

  final int postulacionId;
  final FormularioPostulacionService? service;

  @override
  State<EvaluacionFormularioScreen> createState() =>
      _EvaluacionFormularioScreenState();
}

class _EvaluacionFormularioScreenState
    extends State<EvaluacionFormularioScreen> {
  late final FormularioPostulacionService _service;
  final _comentarioCtrl = TextEditingController();

  EvaluacionFormulario? _evaluacion;
  final Map<int, int> _puntajes = {};
  bool _cargando = true;
  bool _ocupado = false;
  bool _evaluada = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FormularioPostulacionService();
    _cargar();
  }

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final evaluacion = await _service.consultarEvaluacion(
        widget.postulacionId,
      );
      if (!mounted) return;
      setState(() {
        _aplicar(evaluacion);
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    }
  }

  void _aplicar(EvaluacionFormulario evaluacion) {
    _evaluacion = evaluacion;
    _puntajes.clear();
    for (final p in evaluacion.preguntas) {
      if (p.puntajeAsignado != null) {
        _puntajes[p.id] = p.puntajeAsignado!;
      } else if (evaluacion.evaluable && p.respondida) {
        // Arranca en 0: el dador sube el puntaje de cada respuesta.
        _puntajes[p.id] = 0;
      }
    }
    _comentarioCtrl.text = evaluacion.comentario ?? '';
  }

  List<PreguntaEvaluacion> get _respondidas =>
      _evaluacion?.preguntas.where((p) => p.respondida).toList() ?? const [];

  int get _total => _puntajes.values.fold(0, (a, b) => a + b);

  int get _maximoRespondidas =>
      _respondidas.fold(0, (a, p) => a + p.puntajeMaximo);

  bool get _calificacionCompleta =>
      _respondidas.every((p) => _puntajes.containsKey(p.id));

  Future<void> _decidir({required bool aprobar}) async {
    if (!_calificacionCompleta) {
      _notificar(
        'Asigna un puntaje a todas las respuestas antes de decidir.',
        error: true,
      );
      return;
    }
    final comentario = _comentarioCtrl.text.trim();
    if (!aprobar && comentario.isEmpty) {
      _notificar(
        'Escribe el motivo por el que descartas la postulación.',
        error: true,
      );
      return;
    }

    final nombre = _evaluacion!.adoptanteNombre;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(aprobar ? 'Guardar calificación' : 'Descartar postulación'),
        content: Text(
          aprobar
              ? '$nombre obtendrá $_total puntos en el formulario y seguirá en el proceso. '
                    'Esta decisión no se puede deshacer.'
              : '$nombre quedará descartado del proceso y verá tu comentario como motivo. '
                    'Esta decisión no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(aprobar ? 'Guardar' : 'Descartar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _ocupado = true);
    try {
      final resultado = await _service.evaluar(
        postulacionId: widget.postulacionId,
        puntajes: Map.of(_puntajes),
        aprobar: aprobar,
        comentario: comentario.isEmpty ? null : comentario,
      );
      if (!mounted) return;
      setState(() {
        _aplicar(resultado.evaluacion);
        _ocupado = false;
        _evaluada = true;
      });
      _notificar(resultado.mensaje ?? 'Evaluación registrada.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      _notificar(e.message, error: true);
    }
  }

  void _notificar(String mensaje, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final evaluable = _evaluacion?.evaluable ?? false;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_evaluada);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Respuestas del postulante')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _buildBody(),
            ),
          ),
        ),
        bottomNavigationBar: evaluable
            ? _BarraDecision(
                ocupado: _ocupado,
                total: _total,
                maximo: _maximoRespondidas,
                onAprobar: _ocupado ? null : () => _decidir(aprobar: true),
                onDescartar: _ocupado ? null : () => _decidir(aprobar: false),
              )
            : null,
      ),
    );
  }

  Widget _buildBody() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppPalette.mintDark,
              ),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              TextButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final e = _evaluacion!;
    final esMovil = MediaQuery.sizeOf(context).width < 600;
    final editable = e.evaluable && !_ocupado;
    return ListView(
      padding: EdgeInsets.all(esMovil ? 12 : 20),
      children: [
        _Resumen(
          evaluacion: e,
          total: e.evaluable ? _total : e.puntajeObtenido,
        ),
        const SizedBox(height: 12),
        if (e.estado == EstadoPostulacionCodigo.etapa1EnCurso)
          const _Aviso(
            icono: Icons.hourglass_empty,
            texto: 'El adoptante aún no ha enviado el formulario. Verás sus respuestas cuando lo envíe.',
          )
        else if (!e.evaluable)
          _Aviso(
            icono: Icons.verified_outlined,
            texto: e.fechaEvaluacion == null
                ? 'Estado: ${e.estadoEtiqueta}.'
                : 'Calificaste estas respuestas el ${formatearFechaHora(e.fechaEvaluacion!)}. '
                      'Estado: ${e.estadoEtiqueta}.',
          ),
        for (var i = 0; i < e.preguntas.length; i++) ...[
          _RespuestaCard(
            numero: i + 1,
            pregunta: e.preguntas[i],
            puntaje: _puntajes[e.preguntas[i].id],
            editable: editable && e.preguntas[i].respondida,
            onPuntaje: (valor) =>
                setState(() => _puntajes[e.preguntas[i].id] = valor),
          ),
          const SizedBox(height: 12),
        ],
        if (e.evaluable || (e.comentario?.isNotEmpty ?? false))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _comentarioCtrl,
                enabled: editable,
                minLines: 2,
                maxLines: 5,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Comentario para el adoptante',
                  helperText: 'Obligatorio si descartas la postulación.',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.evaluacion, required this.total});

  final EvaluacionFormulario evaluacion;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = evaluacion;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.mint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.adoptanteNombre.isEmpty ? 'Adoptante' : e.adoptanteNombre,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text('Postulación a ${e.mascotaNombre}'),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              e.estado == EstadoPostulacionCodigo.descartadaEtapa1 ||
                      e.estado.startsWith('CANCELADA')
                  ? e.estadoEtiqueta
                  : 'Etapa actual: ${e.etapaActual}${e.etapaNombre.isEmpty ? '' : ' · ${e.etapaNombre}'}',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (e.fechaEnvio != null)
            Text(
              'Formulario enviado: ${formatearFechaHora(e.fechaEnvio!)}',
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 10),
          Text(
            'Puntaje de la etapa: $total / ${e.puntajeMaximoEtapa}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RespuestaCard extends StatelessWidget {
  const _RespuestaCard({
    required this.numero,
    required this.pregunta,
    required this.puntaje,
    required this.editable,
    required this.onPuntaje,
  });

  final int numero;
  final PreguntaEvaluacion pregunta;
  final int? puntaje;
  final bool editable;
  final ValueChanged<int> onPuntaje;

  String get _textoRespuesta {
    final r = pregunta.respuesta;
    if (r.vacia) return 'Sin responder';
    return switch (pregunta.tipo) {
      TipoRespuesta.siNo => r.valor?.toUpperCase() == 'SI' ? 'Sí' : 'No',
      TipoRespuesta.seleccionMultiple => r.opciones.join(', '),
      _ => r.valor ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maximo = pregunta.puntajeMaximo;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppPalette.peach,
                  child: Text(
                    '$numero',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textDark,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    pregunta.texto,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Máx. $maximo', style: theme.textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.cream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppPalette.mintDark.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _textoRespuesta,
                style: pregunta.respondida
                    ? null
                    : const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
            if (pregunta.respondida) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('Puntaje', style: theme.textTheme.labelLarge),
                  Expanded(
                    child: Slider(
                      value: (puntaje ?? 0).toDouble().clamp(
                        0,
                        maximo.toDouble(),
                      ),
                      min: 0,
                      max: maximo <= 0 ? 1 : maximo.toDouble(),
                      divisions: maximo <= 0 ? 1 : maximo,
                      label: '${puntaje ?? 0}',
                      onChanged: editable && maximo > 0
                          ? (v) => onPuntaje(v.round())
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      puntaje == null ? '— / $maximo' : '$puntaje / $maximo',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppPalette.peach,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: AppPalette.textDark),
            const SizedBox(width: 10),
            Expanded(child: Text(texto)),
          ],
        ),
      ),
    );
  }
}

class _BarraDecision extends StatelessWidget {
  const _BarraDecision({
    required this.ocupado,
    required this.total,
    required this.maximo,
    required this.onAprobar,
    required this.onDescartar,
  });

  final bool ocupado;
  final int total;
  final int maximo;
  final VoidCallback? onAprobar;
  final VoidCallback? onDescartar;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
            ),
          ],
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDescartar,
                    icon: const Icon(Icons.close),
                    label: const Text('Descartar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAprobar,
                    icon: ocupado
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Icon(Icons.check),
                    label: Text('Guardar ($total/$maximo)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
