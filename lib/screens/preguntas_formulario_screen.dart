import 'package:flutter/material.dart';

import '../config/preguntas_sugeridas.dart';
import '../models/configuracion_seleccion.dart';
import '../services/api_exception.dart';
import '../services/configuracion_seleccion_service.dart';
import '../theme/app_theme.dart';
import 'configuracion_elemento_dialogs.dart';

/// Dador: define las preguntas del formulario (etapa 1) de una mascota ya publicada.
/// Puede usar las preguntas sugeridas o crear las suyas, mientras ningún adoptante haya
/// enviado el formulario. Cierra con `true` si se guardaron cambios.
class PreguntasFormularioScreen extends StatefulWidget {
  const PreguntasFormularioScreen({
    super.key,
    required this.mascotaId,
    this.nombreMascota,
    this.service,
  });

  final int mascotaId;
  final String? nombreMascota;
  final ConfiguracionSeleccionService? service;

  @override
  State<PreguntasFormularioScreen> createState() =>
      _PreguntasFormularioScreenState();
}

class _PreguntasFormularioScreenState extends State<PreguntasFormularioScreen> {
  late final ConfiguracionSeleccionService _service =
      widget.service ?? ConfiguracionSeleccionService();

  PreguntasFormulario? _datos;
  List<PreguntaSeleccion> _preguntas = const [];
  bool _cargando = true;
  bool _guardando = false;
  bool _sucio = false;
  bool _guardado = false;

  /// En el estado vacío el dador primero elige: sugeridas o propias.
  bool _eligioCrear = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await _service.obtenerPreguntasFormulario(widget.mascotaId);
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _preguntas = datos.preguntas;
        _sucio = false;
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

  /// Máximo de la etapa; si no tiene, el dador reparte libremente hasta 100.
  int get _maximo {
    final m = _datos?.puntajeMaximoEtapa ?? 0;
    return m > 0 ? m : puntajeTotalSeleccion;
  }

  int get _asignado => _preguntas.fold(0, (a, p) => a + p.puntaje);

  void _usarSugeridas() {
    setState(() {
      _preguntas = preguntasSugeridas(
        puntajeMaximo: _datos?.puntajeMaximoEtapa ?? 0,
      );
      _sucio = true;
      _eligioCrear = true;
    });
  }

  Future<void> _abrirDialogo({PreguntaSeleccion? existente}) async {
    final resultado = await showDialog<ElementoSeleccion>(
      context: context,
      builder: (_) => PreguntaDialog(
        pregunta: existente,
        capacidad: CapacidadEtapa(
          maximo: _maximo,
          asignadoOtros: _asignado - (existente?.puntaje ?? 0),
        ),
      ),
    );
    if (resultado is! PreguntaSeleccion || !mounted) return;
    setState(() {
      final lista = [..._preguntas];
      final i = existente == null ? -1 : lista.indexOf(existente);
      if (i >= 0) {
        lista[i] = resultado;
      } else {
        lista.add(resultado);
      }
      _preguntas = lista;
      _sucio = true;
      _eligioCrear = true;
    });
  }

  void _eliminar(PreguntaSeleccion pregunta) {
    setState(() {
      _preguntas = [..._preguntas]..remove(pregunta);
      _sucio = true;
    });
  }

  Future<void> _guardar() async {
    if (_preguntas.isEmpty) {
      _notificar('Agrega al menos una pregunta.', error: true);
      return;
    }
    if (_asignado > _maximo) {
      _notificar(
        'Las preguntas suman $_asignado pts y el máximo es $_maximo.',
        error: true,
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      final datos = await _service.guardarPreguntasFormulario(
        widget.mascotaId,
        _datos?.puntajeMaximoEtapa ?? 0,
        _preguntas,
      );
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _preguntas = datos.preguntas;
        _sucio = false;
        _guardado = true;
        _guardando = false;
      });
      _notificar(
        'Preguntas guardadas. Los postulantes ya pueden responder el formulario.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
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

  Future<bool> _puedeSalir() async {
    if (!_sucio) return true;
    final salir = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambios sin guardar'),
        content: const Text(
          'Si sales ahora se perderán las preguntas que no guardaste.',
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
    final editable = (_datos?.editable ?? false) && !_guardando;
    final mostrarEditor = _preguntas.isNotEmpty || _eligioCrear;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _puedeSalir() && context.mounted) {
          Navigator.of(context).pop(_guardado);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Preguntas del formulario')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _cuerpo(editable, mostrarEditor),
            ),
          ),
        ),
        bottomNavigationBar: editable && mostrarEditor
            ? SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: ElevatedButton.icon(
                    onPressed: _sucio && !_guardando ? _guardar : null,
                    icon: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Guardar preguntas'),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _cuerpo(bool editable, bool mostrarEditor) {
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

    final theme = Theme.of(context);
    final datos = _datos!;
    final esMovil = MediaQuery.sizeOf(context).width < 600;
    return ListView(
      padding: EdgeInsets.all(esMovil ? 12 : 20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppPalette.mint.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.nombreMascota == null
                    ? 'Formulario de adopción'
                    : 'Formulario para adoptar a ${widget.nombreMascota}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Es la etapa 1: cada postulante responde estas preguntas y tú calificas sus '
                'respuestas.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!datos.editable)
          _Aviso(
            icono: Icons.lock_outline,
            texto: datos.motivo ?? 'Las preguntas ya no se pueden cambiar.',
          ),
        if (editable && !mostrarEditor) ...[
          Text(
            'Tu formulario aún no tiene preguntas. ¿Cómo quieres empezar?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _OpcionInicio(
            icono: Icons.auto_awesome_outlined,
            titulo: 'Usar preguntas sugeridas',
            descripcion:
                '$cantidadPreguntasSugeridas preguntas sobre vivienda, convivencia y '
                'experiencia con mascotas. Puedes editarlas o quitarlas antes de guardar.',
            destacado: true,
            onTap: _usarSugeridas,
          ),
          const SizedBox(height: 12),
          _OpcionInicio(
            icono: Icons.edit_note,
            titulo: 'Crear mis propias preguntas',
            descripcion:
                'Empieza con el formulario vacío y escribe tus preguntas.',
            onTap: () => _abrirDialogo(),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Preguntas (${_preguntas.length})',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                '$_asignado / $_maximo pts',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _asignado > _maximo ? theme.colorScheme.error : null,
                ),
              ),
            ],
          ),
          if (datos.puntajeMaximoEtapa == 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Esta mascota no tenía puntaje para la etapa 1: valdrá la suma de las preguntas.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
          if (_preguntas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Aún no hay preguntas.', textAlign: TextAlign.center),
            ),
          for (var i = 0; i < _preguntas.length; i++)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: AppPalette.peach,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(color: AppPalette.textDark),
                  ),
                ),
                title: Text(
                  _preguntas[i].texto,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  [
                    _preguntas[i].tipoRespuesta.etiqueta,
                    '${_preguntas[i].puntaje} pts',
                    if (_preguntas[i].opciones.isNotEmpty)
                      _preguntas[i].opciones.join(' / '),
                  ].join(' · '),
                ),
                trailing: editable
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Editar',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () =>
                                _abrirDialogo(existente: _preguntas[i]),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _eliminar(_preguntas[i]),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
          if (editable) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _abrirDialogo(),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar pregunta'),
                ),
                if (_preguntas.isEmpty)
                  TextButton.icon(
                    onPressed: _usarSugeridas,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Usar sugeridas'),
                  ),
              ],
            ),
          ],
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _OpcionInicio extends StatelessWidget {
  const _OpcionInicio({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.onTap,
    this.destacado = false,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: destacado ? AppPalette.peach.withValues(alpha: 0.6) : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icono, size: 32, color: AppPalette.textDark),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(descripcion),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
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
