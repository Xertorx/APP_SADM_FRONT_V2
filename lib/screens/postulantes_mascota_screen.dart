import 'package:flutter/material.dart';

import '../models/formulario_postulacion.dart';
import '../services/api_exception.dart';
import '../services/formulario_postulacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/fecha_formato.dart';
import 'evaluacion_formulario_screen.dart';

/// Vista del dador: postulantes de una de sus mascotas, con acceso a evaluar el
/// formulario de la etapa 1.
class PostulantesMascotaScreen extends StatefulWidget {
  const PostulantesMascotaScreen({
    super.key,
    required this.mascotaId,
    required this.mascotaNombre,
    this.service,
  });

  final int mascotaId;
  final String mascotaNombre;
  final FormularioPostulacionService? service;

  @override
  State<PostulantesMascotaScreen> createState() =>
      _PostulantesMascotaScreenState();
}

class _PostulantesMascotaScreenState extends State<PostulantesMascotaScreen> {
  late final FormularioPostulacionService _service;

  bool _cargando = true;
  String? _error;
  List<Postulante> _postulantes = const [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FormularioPostulacionService();
    _cargar();
  }

  @override
  void dispose() {
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool mostrarSpinner = true}) async {
    if (mostrarSpinner) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final lista = await _service.listarPostulantes(widget.mascotaId);
      if (!mounted) return;
      setState(() {
        _postulantes = lista;
        _error = null;
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

  Future<void> _abrir(Postulante postulante) async {
    final evaluada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EvaluacionFormularioScreen(
          postulacionId: postulante.postulacionId,
          service: _service,
        ),
      ),
    );
    if (!mounted) return;
    if (evaluada == true) await _cargar(mostrarSpinner: false);
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = _postulantes.where((p) => p.pendienteEvaluacion).length;
    return Scaffold(
      appBar: AppBar(title: Text('Postulantes de ${widget.mascotaNombre}')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _cargar(mostrarSpinner: false),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (_error != null)
                          _Mensaje(
                            icono: Icons.error_outline,
                            texto: _error!,
                            accion: TextButton.icon(
                              onPressed: _cargar,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          )
                        else if (_postulantes.isEmpty)
                          const _Mensaje(
                            icono: Icons.people_outline,
                            texto: 'Aún no hay postulantes para esta mascota.',
                          )
                        else ...[
                          if (pendientes > 0)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppPalette.peach,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.rate_review_outlined),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      pendientes == 1
                                          ? 'Tienes 1 formulario pendiente por evaluar.'
                                          : 'Tienes $pendientes formularios pendientes por evaluar.',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          for (final p in _postulantes) ...[
                            _PostulanteTile(
                              postulante: p,
                              onTap: () => _abrir(p),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _PostulanteTile extends StatelessWidget {
  const _PostulanteTile({required this.postulante, required this.onTap});

  final Postulante postulante;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = postulante;
    final descartada =
        p.estado == EstadoPostulacionCodigo.descartadaEtapa1 ||
        p.estado.startsWith('CANCELADA');
    final String accion;
    if (p.pendienteEvaluacion) {
      accion = 'Evaluar';
    } else if (p.formularioEnviado) {
      accion = 'Ver respuestas';
    } else {
      accion = 'Ver';
    }

    final tile = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppPalette.mint,
                child: Text(
                  p.adoptanteNombre.isEmpty
                      ? '?'
                      : p.adoptanteNombre[0].toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppPalette.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.adoptanteNombre.isEmpty
                          ? 'Adoptante'
                          : p.adoptanteNombre,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(p.estadoEtiqueta, style: theme.textTheme.bodySmall),
                    Text(
                      [
                        if (p.fechaPostulacion != null)
                          'Postulado: ${formatearFechaHora(p.fechaPostulacion!)}',
                        'Puntaje: ${p.puntaje}',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              p.pendienteEvaluacion
                  ? FilledButton.tonal(onPressed: onTap, child: Text(accion))
                  : TextButton(onPressed: onTap, child: Text(accion)),
            ],
          ),
        ),
      ),
    );
    return descartada ? Opacity(opacity: 0.7, child: tile) : tile;
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.icono, required this.texto, this.accion});

  final IconData icono;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
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
