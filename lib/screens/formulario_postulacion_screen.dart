import 'package:flutter/material.dart';

import '../models/configuracion_seleccion.dart';
import '../models/formulario_postulacion.dart';
import '../services/api_exception.dart';
import '../services/formulario_postulacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/fecha_formato.dart';

/// Etapa 1 (adoptante): responder el formulario de preguntas que configuró el dador.
/// Se puede guardar como borrador y enviarlo cuando todas las preguntas estén respondidas.
/// Cierra con `true` si el formulario se envió.
class FormularioPostulacionScreen extends StatefulWidget {
  const FormularioPostulacionScreen({
    super.key,
    required this.postulacionId,
    this.mascotaNombre,
    this.service,
  });

  final int postulacionId;
  final String? mascotaNombre;
  final FormularioPostulacionService? service;

  @override
  State<FormularioPostulacionScreen> createState() =>
      _FormularioPostulacionScreenState();
}

class _FormularioPostulacionScreenState
    extends State<FormularioPostulacionScreen> {
  late final FormularioPostulacionService _service;

  FormularioPostulacion? _formulario;
  final Map<int, RespuestaFormulario> _respuestas = {};
  final Map<int, TextEditingController> _textos = {};

  bool _cargando = true;
  bool _ocupado = false;
  bool _sucio = false;
  bool _intentoEnviar = false;
  bool _enviado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FormularioPostulacionService();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in _textos.values) {
      c.dispose();
    }
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final formulario = await _service.consultar(widget.postulacionId);
      if (!mounted) return;
      _aplicar(formulario);
      setState(() => _cargando = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    }
  }

  void _aplicar(FormularioPostulacion formulario) {
    _formulario = formulario;
    _respuestas.clear();
    for (final p in formulario.preguntas) {
      _respuestas[p.id] = p.respuesta;
      if (p.tipo == TipoRespuesta.texto) {
        final controller = _textos.putIfAbsent(p.id, TextEditingController.new);
        controller.text = p.respuesta.valor ?? '';
      }
    }
    _sucio = false;
  }

  bool get _editable => (_formulario?.editable ?? false) && !_ocupado;

  int get _respondidas => _formulario == null
      ? 0
      : _formulario!.preguntas
            .where((p) => !(_respuestas[p.id]?.vacia ?? true))
            .length;

  void _responder(int preguntaId, RespuestaFormulario respuesta) {
    setState(() {
      _respuestas[preguntaId] = respuesta;
      _sucio = true;
    });
  }

  Future<void> _guardar() async {
    setState(() => _ocupado = true);
    try {
      final formulario = await _service.guardarBorrador(
        widget.postulacionId,
        Map.of(_respuestas),
      );
      if (!mounted) return;
      setState(() {
        _aplicar(formulario);
        _ocupado = false;
      });
      _notificar('Respuestas guardadas. Puedes continuar más tarde.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      _notificar(e.message, error: true);
    }
  }

  Future<void> _enviar() async {
    final formulario = _formulario!;
    final faltantes = formulario.preguntas.length - _respondidas;
    if (faltantes > 0) {
      setState(() => _intentoEnviar = true);
      _notificar(
        faltantes == 1
            ? 'Falta responder 1 pregunta.'
            : 'Faltan $faltantes preguntas por responder.',
        error: true,
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enviar formulario'),
        content: const Text(
          'Una vez enviado no podrás cambiar tus respuestas. El dador las revisará y te '
          'avisaremos el resultado en "Mis postulaciones". ¿Deseas enviarlo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Revisar de nuevo'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _ocupado = true);
    try {
      final resultado = await _service.enviar(
        widget.postulacionId,
        Map.of(_respuestas),
      );
      if (!mounted) return;
      setState(() {
        _aplicar(resultado.formulario);
        _ocupado = false;
        _enviado = true;
      });
      _notificar(resultado.mensaje ?? 'Formulario enviado.');
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

  Future<bool> _confirmarSalida() async {
    if (!_sucio || !(_formulario?.editable ?? false)) return true;
    final salir = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambios sin guardar'),
        content: const Text(
          'Tienes respuestas sin guardar. ¿Quieres salir de todas formas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Quedarme'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salir sin guardar'),
          ),
        ],
      ),
    );
    return salir == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmarSalida() && context.mounted) {
          Navigator.of(context).pop(_enviado);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Etapa 1 · Formulario')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _buildBody(),
            ),
          ),
        ),
        bottomNavigationBar:
            (_formulario?.editable ?? false) &&
                _formulario!.preguntas.isNotEmpty
            ? _BarraAcciones(
                ocupado: _ocupado,
                onGuardar: _editable ? _guardar : null,
                onEnviar: _editable ? _enviar : null,
              )
            : null,
      ),
    );
  }

  Widget _buildBody() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _Centro(
        icono: Icons.error_outline,
        texto: _error!,
        accion: TextButton.icon(
          onPressed: _cargar,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
    }

    final formulario = _formulario!;
    final esMovil = MediaQuery.sizeOf(context).width < 600;
    return ListView(
      padding: EdgeInsets.all(esMovil ? 12 : 20),
      children: [
        _Encabezado(
          mascotaNombre: formulario.mascotaNombre.isNotEmpty
              ? formulario.mascotaNombre
              : (widget.mascotaNombre ?? ''),
          respondidas: _respondidas,
          total: formulario.preguntas.length,
        ),
        const SizedBox(height: 12),
        _AvisoEstado(formulario: formulario),
        if (formulario.preguntas.isEmpty)
          const _Centro(
            icono: Icons.quiz_outlined,
            texto: 'El dador no configuró preguntas para esta mascota.',
          ),
        for (var i = 0; i < formulario.preguntas.length; i++) ...[
          _PreguntaCard(
            numero: i + 1,
            pregunta: formulario.preguntas[i],
            respuesta:
                _respuestas[formulario.preguntas[i].id] ??
                const RespuestaFormulario(),
            controller: _textos[formulario.preguntas[i].id],
            editable: _editable,
            mostrarError: _intentoEnviar,
            onCambio: (r) => _responder(formulario.preguntas[i].id, r),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.mascotaNombre,
    required this.respondidas,
    required this.total,
  });

  final String mascotaNombre;
  final int respondidas;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            mascotaNombre.isEmpty
                ? 'Formulario de adopción'
                : 'Adopción de $mascotaNombre',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Responde con sinceridad: el dador usará tus respuestas para conocerte y '
            'calificar esta primera etapa.',
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : respondidas / total,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.7),
                      color: AppPalette.mintDark,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$respondidas de $total',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AvisoEstado extends StatelessWidget {
  const _AvisoEstado({required this.formulario});

  final FormularioPostulacion formulario;

  @override
  Widget build(BuildContext context) {
    final (
      IconData icono,
      Color color,
      String texto,
    ) = switch (formulario.estado) {
      EstadoPostulacionCodigo.etapa1EnCurso when !formulario.editable => (
        Icons.info_outline,
        AppPalette.peach,
        'Esta mascota ya no está disponible, por lo que no puedes modificar el formulario.',
      ),
      EstadoPostulacionCodigo.etapa1EnCurso => (
        Icons.edit_note,
        Colors.transparent,
        '',
      ),
      EstadoPostulacionCodigo.etapa1EnEvaluacion => (
        Icons.hourglass_top,
        AppPalette.peach,
        'Enviaste el formulario${formulario.fechaEnvio == null ? '' : ' el ${formatearFechaHora(formulario.fechaEnvio!)}'}. '
            'El dador está revisando tus respuestas.',
      ),
      EstadoPostulacionCodigo.descartadaEtapa1 => (
        Icons.cancel_outlined,
        Colors.red.shade100,
        'Tu postulación no continuó en esta etapa.'
            '${(formulario.comentarioEvaluacion?.isNotEmpty ?? false) ? '\nMotivo: ${formulario.comentarioEvaluacion}' : ''}',
      ),
      _ => (
        Icons.check_circle_outline,
        AppPalette.mint,
        'Superaste la etapa 1. Estado actual: ${formulario.estadoEtiqueta}.',
      ),
    };
    if (texto.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
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

class _PreguntaCard extends StatelessWidget {
  const _PreguntaCard({
    required this.numero,
    required this.pregunta,
    required this.respuesta,
    required this.controller,
    required this.editable,
    required this.mostrarError,
    required this.onCambio,
  });

  final int numero;
  final PreguntaFormulario pregunta;
  final RespuestaFormulario respuesta;
  final TextEditingController? controller;
  final bool editable;
  final bool mostrarError;
  final ValueChanged<RespuestaFormulario> onCambio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final falta = mostrarError && respuesta.vacia;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: falta
            ? BorderSide(color: theme.colorScheme.error, width: 1.5)
            : BorderSide.none,
      ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pregunta.texto,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        pregunta.tipo == TipoRespuesta.seleccionMultiple
                            ? 'Puedes elegir varias opciones'
                            : pregunta.tipo.etiqueta,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _campo(context),
            if (falta) ...[
              const SizedBox(height: 6),
              Text(
                'Responde esta pregunta.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _campo(BuildContext context) {
    switch (pregunta.tipo) {
      case TipoRespuesta.texto:
        return TextField(
          controller: controller,
          enabled: editable,
          minLines: 2,
          maxLines: 6,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Escribe tu respuesta',
            border: OutlineInputBorder(),
          ),
          onChanged: (texto) => onCambio(RespuestaFormulario(valor: texto)),
        );
      case TipoRespuesta.siNo:
        return _Opciones(
          opciones: const ['SI', 'NO'],
          etiqueta: (o) => o == 'SI' ? 'Sí' : 'No',
          seleccionadas: {
            if (respuesta.valor != null) respuesta.valor!.toUpperCase(),
          },
          editable: editable,
          onTap: (o) => onCambio(RespuestaFormulario(valor: o)),
        );
      case TipoRespuesta.seleccionUnica:
        return _Opciones(
          opciones: pregunta.opciones,
          seleccionadas: {if (respuesta.valor != null) respuesta.valor!},
          editable: editable,
          onTap: (o) => onCambio(RespuestaFormulario(valor: o)),
        );
      case TipoRespuesta.seleccionMultiple:
        final actuales = respuesta.opciones.toSet();
        return _Opciones(
          opciones: pregunta.opciones,
          seleccionadas: actuales,
          multiple: true,
          editable: editable,
          onTap: (o) {
            final nuevas = {...actuales};
            if (!nuevas.remove(o)) nuevas.add(o);
            // Conserva el orden en que el dador definió las opciones.
            onCambio(
              RespuestaFormulario(
                opciones: pregunta.opciones.where(nuevas.contains).toList(),
              ),
            );
          },
        );
    }
  }
}

class _Opciones extends StatelessWidget {
  const _Opciones({
    required this.opciones,
    required this.seleccionadas,
    required this.editable,
    required this.onTap,
    this.multiple = false,
    this.etiqueta,
  });

  final List<String> opciones;
  final Set<String> seleccionadas;
  final bool editable;
  final bool multiple;
  final ValueChanged<String> onTap;
  final String Function(String)? etiqueta;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final opcion in opciones)
          multiple
              ? FilterChip(
                  label: Text(etiqueta?.call(opcion) ?? opcion),
                  selected: seleccionadas.contains(opcion),
                  selectedColor: AppPalette.mint,
                  onSelected: editable ? (_) => onTap(opcion) : null,
                )
              : ChoiceChip(
                  label: Text(etiqueta?.call(opcion) ?? opcion),
                  selected: seleccionadas.contains(opcion),
                  selectedColor: AppPalette.mint,
                  onSelected: editable ? (_) => onTap(opcion) : null,
                ),
      ],
    );
  }
}

class _BarraAcciones extends StatelessWidget {
  const _BarraAcciones({
    required this.ocupado,
    required this.onGuardar,
    required this.onEnviar,
  });

  final bool ocupado;
  final VoidCallback? onGuardar;
  final VoidCallback? onEnviar;

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
                    onPressed: onGuardar,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onEnviar,
                    icon: ocupado
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Icon(Icons.send),
                    label: const Text('Enviar'),
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

class _Centro extends StatelessWidget {
  const _Centro({required this.icono, required this.texto, this.accion});

  final IconData icono;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 48, color: AppPalette.mintDark),
          const SizedBox(height: 12),
          Text(texto, textAlign: TextAlign.center),
          if (accion != null) ...[const SizedBox(height: 8), accion!],
        ],
      ),
    );
  }
}
