import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/admin_mascotas_textos.dart';
import '../models/publicacion_pendiente.dart';
import '../services/admin_mascotas_service.dart';
import '../services/api_exception.dart';
import '../services/auth_session.dart';
import '../services/mascota_service.dart';
import '../theme/app_theme.dart';
import '../utils/etiquetas.dart';
import 'mascota_form_screen.dart';

/// HU26: revisión administrativa de publicaciones pendientes de moderación.
class AdminMascotasScreen extends StatefulWidget {
  const AdminMascotasScreen({super.key, this.service, this.mascotaService});

  final AdminMascotasService? service;
  final MascotaService? mascotaService;

  @override
  State<AdminMascotasScreen> createState() => _AdminMascotasScreenState();
}

class _AdminMascotasScreenState extends State<AdminMascotasScreen> {
  late final AdminMascotasService _service =
      widget.service ?? AdminMascotasService();
  late final MascotaService _mascotaService =
      widget.mascotaService ?? MascotaService();

  bool _cargando = false;
  String? _errorCarga;
  String? _errorAccion;
  bool _recargarPorConflicto = false;
  List<PublicacionPendiente> _pendientes = const [];
  int? _procesandoId;

  @override
  void initState() {
    super.initState();
    if (AuthSession.esAdministrador) _cargar();
  }

  @override
  void dispose() {
    if (widget.service == null) _service.dispose();
    if (widget.mascotaService == null) _mascotaService.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
      _errorAccion = null;
      _recargarPorConflicto = false;
    });
    try {
      final pendientes = await _service.listarPendientes();
      if (!mounted) return;
      setState(() {
        _pendientes = pendientes;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCarga = e.message;
        _cargando = false;
      });
    }
  }

  Future<void> _aprobar(PublicacionPendiente publicacion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprobar publicación'),
        content: Text(
          '¿Confirmas aprobar la publicación de ${publicacion.mascota.nombre}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirmar-aprobar'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    await _accion(publicacion.id, () async {
      final message = await _service.aprobar(publicacion.id);
      if (!mounted) return;
      setState(() {
        _pendientes = _pendientes.where((e) => e.id != publicacion.id).toList();
      });
      _notificar(message ?? AdminMascotasTextos.aprobada);
    });
  }

  Future<void> _rechazar(PublicacionPendiente publicacion) async {
    final motivo = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _DialogoMotivoRechazo(nombreMascota: publicacion.mascota.nombre),
    );
    if (motivo == null || !mounted) return;

    await _accion(publicacion.id, () async {
      final message = await _service.rechazar(publicacion.id, motivo);
      if (!mounted) return;
      setState(() {
        _pendientes = _pendientes.where((e) => e.id != publicacion.id).toList();
      });
      _notificar(message ?? AdminMascotasTextos.rechazada);
    });
  }

  Future<void> _editar(PublicacionPendiente publicacion) async {
    if (_procesandoId != null) return;
    setState(() {
      _procesandoId = publicacion.id;
      _errorAccion = null;
      _recargarPorConflicto = false;
    });
    try {
      final guardada = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => MascotaFormScreen(
            mascotaId: publicacion.id,
            service: _mascotaService,
            modoModeracion: true,
            mascotaInicial: publicacion.mascota,
            latitudInicial: publicacion.latitud,
            longitudInicial: publicacion.longitud,
          ),
        ),
      );
      if (!mounted || guardada != true) return;
      _notificar(AdminMascotasTextos.exitoEdicion);
      await _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorAccion = e.message;
        _recargarPorConflicto = e is ConflictoException;
      });
    } finally {
      if (mounted) setState(() => _procesandoId = null);
    }
  }

  Future<void> _accion(int id, Future<void> Function() accion) async {
    if (_procesandoId != null) return;
    setState(() {
      _procesandoId = id;
      _errorAccion = null;
      _recargarPorConflicto = false;
    });
    try {
      await accion();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorAccion = e.message;
        _recargarPorConflicto = e is ConflictoException;
      });
    } finally {
      if (mounted) setState(() => _procesandoId = null);
    }
  }

  void _notificar(String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _verDetalle(PublicacionPendiente publicacion) {
    showDialog<void>(
      context: context,
      builder: (_) => _DetallePublicacionDialog(publicacion: publicacion),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthSession.esAdministrador) {
      return Scaffold(
        appBar: AppBar(title: const Text(AdminMascotasTextos.titulo)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              AdminMascotasTextos.errorPermiso,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AdminMascotasTextos.titulo),
        actions: [
          IconButton(
            tooltip: 'Actualizar lista',
            onPressed: _cargando || _procesandoId != null ? null : _cargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_errorCarga != null) {
      return _MensajeEstado(
        icono: Icons.error_outline,
        texto: _errorCarga ?? AdminMascotasTextos.errorCarga,
        accion: TextButton.icon(
          onPressed: _cargar,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(
            AdminMascotasTextos.titulo,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _pendientes.isEmpty
                ? 'Las publicaciones enviadas por dadores aparecerán aquí para revisión.'
                : '${_pendientes.length} publicación${_pendientes.length == 1 ? '' : 'es'} por revisar',
          ),
          if (_errorAccion != null) ...[
            const SizedBox(height: 12),
            _AvisoModeracion(
              mensaje: _errorAccion!,
              accion: _recargarPorConflicto
                  ? TextButton.icon(
                      onPressed: _procesandoId == null ? _cargar : null,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualizar lista'),
                    )
                  : null,
            ),
          ],
          const SizedBox(height: 16),
          if (_pendientes.isEmpty)
            const _MensajeEstado(
              icono: Icons.pets_outlined,
              texto: AdminMascotasTextos.vacio,
            )
          else
            for (final publicacion in _pendientes) ...[
              _TarjetaPendiente(
                publicacion: publicacion,
                ocupado: _procesandoId == publicacion.id,
                algunaAccionEnCurso: _procesandoId != null,
                onDetalle: () => _verDetalle(publicacion),
                onAprobar: () => _aprobar(publicacion),
                onEditar: () => _editar(publicacion),
                onRechazar: () => _rechazar(publicacion),
              ),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _DialogoMotivoRechazo extends StatefulWidget {
  const _DialogoMotivoRechazo({required this.nombreMascota});

  final String nombreMascota;

  @override
  State<_DialogoMotivoRechazo> createState() => _DialogoMotivoRechazoState();
}

class _DialogoMotivoRechazoState extends State<_DialogoMotivoRechazo> {
  final _formKey = GlobalKey<FormState>();
  final _motivoCtrl = TextEditingController();

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Rechazar publicación'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Indica el motivo para rechazar a ${widget.nombreMascota}.'),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('motivo-rechazo'),
                controller: _motivoCtrl,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Motivo obligatorio',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final texto = value?.trim() ?? '';
                  if (texto.isEmpty) return 'El motivo es obligatorio.';
                  if (texto.length > 300) return 'Máximo 300 caracteres.';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirmar-rechazar'),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_motivoCtrl.text.trim());
            }
          },
          child: const Text('Rechazar'),
        ),
      ],
    );
  }
}

class _TarjetaPendiente extends StatelessWidget {
  const _TarjetaPendiente({
    required this.publicacion,
    required this.ocupado,
    required this.algunaAccionEnCurso,
    required this.onDetalle,
    required this.onAprobar,
    required this.onEditar,
    required this.onRechazar,
  });

  final PublicacionPendiente publicacion;
  final bool ocupado;
  final bool algunaAccionEnCurso;
  final VoidCallback onDetalle;
  final VoidCallback onAprobar;
  final VoidCallback onEditar;
  final VoidCallback onRechazar;

  @override
  Widget build(BuildContext context) {
    final mascota = publicacion.mascota;
    final foto = mascota.galeria.firstOrNull;
    final theme = Theme.of(context);
    final fecha = mascota.fechaPublicacion;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: foto == null
                        ? _fotoVacia()
                        : Image.network(
                            foto,
                            fit: BoxFit.cover,
                            headers: AuthSession.headers,
                            errorBuilder: (_, _, _) => _fotoVacia(),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            mascota.nombre,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          _EtiquetaEstado(estado: mascota.estado),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(mascota.datosClave),
                      if (mascota.ubicacion?.isNotEmpty == true)
                        Text('Ubicación: ${mascota.ubicacion}'),
                      Text(
                        'Dador: ${publicacion.nombreDador}'
                        '${publicacion.correoDador == null ? '' : ' · ${publicacion.correoDador}'}',
                      ),
                      if (fecha != null)
                        Text(
                          'Creada: ${DateFormat('dd/MM/yyyy HH:mm').format(fecha.toLocal())}',
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: algunaAccionEnCurso ? null : onDetalle,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Vista previa completa'),
              ),
            ),
            const Divider(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: Key('editar-${mascota.id}'),
                  onPressed: algunaAccionEnCurso ? null : onEditar,
                  icon: ocupado
                      ? const _SpinnerModeracion()
                      : const Icon(Icons.edit_outlined),
                  label: const Text(AdminMascotasTextos.editar),
                ),
                OutlinedButton.icon(
                  key: Key('rechazar-${mascota.id}'),
                  onPressed: algunaAccionEnCurso ? null : onRechazar,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text(AdminMascotasTextos.rechazar),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
                ElevatedButton.icon(
                  key: Key('aprobar-${mascota.id}'),
                  onPressed: algunaAccionEnCurso ? null : onAprobar,
                  icon: ocupado
                      ? const _SpinnerModeracion()
                      : const Icon(Icons.check_circle_outline),
                  label: const Text(AdminMascotasTextos.aprobar),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fotoVacia() => ColoredBox(
    color: AppPalette.mint.withValues(alpha: 0.3),
    child: const Center(
      child: Icon(Icons.pets_outlined, color: AppPalette.mintDark, size: 36),
    ),
  );
}

class _DetallePublicacionDialog extends StatelessWidget {
  const _DetallePublicacionDialog({required this.publicacion});

  final PublicacionPendiente publicacion;

  @override
  Widget build(BuildContext context) {
    final mascota = publicacion.mascota;
    final fotos = mascota.galeria;
    return AlertDialog(
      title: Text('Vista previa · ${mascota.nombre}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (fotos.isNotEmpty)
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: fotos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        fotos[index],
                        width: 230,
                        fit: BoxFit.cover,
                        headers: AuthSession.headers,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 230,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _DatoModeracion('Estado', humanizar(mascota.estado)),
              _DatoModeracion(
                'Especie',
                mascota.especie == null ? null : humanizar(mascota.especie!),
              ),
              _DatoModeracion('Raza', mascota.raza),
              _DatoModeracion('Edad', mascota.edadTexto),
              _DatoModeracion(
                'Tamaño',
                mascota.tamano == null ? null : humanizar(mascota.tamano!),
              ),
              _DatoModeracion(
                'Sexo',
                mascota.sexo == null ? null : humanizar(mascota.sexo!),
              ),
              _DatoModeracion(
                'Temperamento',
                mascota.temperamento.isEmpty
                    ? null
                    : mascota.temperamento.map(humanizar).join(', '),
              ),
              _DatoModeracion('Ubicación', mascota.ubicacion),
              if (publicacion.latitud != null && publicacion.longitud != null)
                _DatoModeracion(
                  'Coordenadas',
                  '${publicacion.latitud}, ${publicacion.longitud}',
                ),
              _DatoModeracion('Historial de salud', mascota.historialSalud),
              _DatoModeracion(
                'Fecha de creación',
                mascota.fechaPublicacion == null
                    ? null
                    : DateFormat('dd/MM/yyyy HH:mm')
                          .format(mascota.fechaPublicacion!.toLocal()),
              ),
              const Divider(),
              Text(
                'Datos del dador',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              _DatoModeracion('Nombre', publicacion.nombreDador),
              _DatoModeracion('Correo', publicacion.correoDador),
              _DatoModeracion('Rol', publicacion.rolDador),
              _DatoModeracion('Estado de cuenta', publicacion.estadoDador),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _DatoModeracion extends StatelessWidget {
  const _DatoModeracion(this.etiqueta, this.valor);

  final String etiqueta;
  final String? valor;

  @override
  Widget build(BuildContext context) {
    if (valor == null || valor!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text('$etiqueta: $valor'),
    );
  }
}

class _EtiquetaEstado extends StatelessWidget {
  const _EtiquetaEstado({required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(humanizar(estado)),
      backgroundColor: AppPalette.peach.withValues(alpha: 0.55),
      side: BorderSide.none,
    );
  }
}

class _MensajeEstado extends StatelessWidget {
  const _MensajeEstado({required this.icono, required this.texto, this.accion});

  final IconData icono;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 44, color: AppPalette.mintDark),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(texto, textAlign: TextAlign.center),
            ),
            if (accion != null) ...[const SizedBox(height: 8), accion!],
          ],
        ),
      ),
    );
  }
}

class _AvisoModeracion extends StatelessWidget {
  const _AvisoModeracion({required this.mensaje, this.accion});

  final String mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mensaje, style: TextStyle(color: color)),
          ?accion,
        ],
      ),
    );
  }
}

class _SpinnerModeracion extends StatelessWidget {
  const _SpinnerModeracion();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
