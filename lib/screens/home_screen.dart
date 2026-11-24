import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'panel_screen.dart';
import 'registro_screen.dart';

const _imagenPrincipal = 'assets/images/principal.jpg';

/// Ancho por debajo del cual el home usa el diseño móvil.
const _anchoMovil = 600.0;

/// Public landing page: explains what SADM is and offers login / sign-up.
/// Every other feature requires an authenticated session.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _abrir(BuildContext context, Widget pantalla) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    final esMovil = MediaQuery.sizeOf(context).width < _anchoMovil;
    return Scaffold(
      appBar: AppBar(title: const Text('SADM')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: EdgeInsets.all(esMovil ? 16 : 20),
              children: [
                const _Hero(),
                const SizedBox(height: 20),
                _AccesoButtons(
                  onLogin: () => _abrir(context, const LoginScreen()),
                  onRegistro: () => _abrir(context, const RegistroScreen()),
                  onPanel: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const PanelScreen()),
                    (route) => false,
                  ),
                ),
                const SizedBox(height: 32),
                const _SectionHeading('¿Qué es SADM?'),
                const SizedBox(height: 8),
                Text(
                  'SADM es una plataforma que conecta a personas que quieren dar '
                  'una mascota en adopción con personas dispuestas a darle un '
                  'hogar. Con una sola cuenta puedes publicar mascotas, '
                  'postularte para adoptar y seguir el proceso paso a paso.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                const _Beneficios(),
                const SizedBox(height: 32),
                const _SectionHeading('Nuestra comunidad'),
                const SizedBox(height: 12),
                const _Galeria(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esMovil = MediaQuery.sizeOf(context).width < _anchoMovil;
    return Container(
      padding: EdgeInsets.all(esMovil ? 16 : 24),
      decoration: BoxDecoration(
        color: AppPalette.mint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: const _ImagenAsset(
              ruta: _imagenPrincipal,
              icon: Icons.pets,
              label: 'Imagen principal',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Dale un hogar a quien más lo necesita',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adopta o da en adopción de forma segura y responsable.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _AccesoButtons extends StatelessWidget {
  const _AccesoButtons({
    required this.onLogin,
    required this.onRegistro,
    required this.onPanel,
  });

  final VoidCallback onLogin;
  final VoidCallback onRegistro;
  final VoidCallback onPanel;

  @override
  Widget build(BuildContext context) {
    if (AuthSession.autenticado) {
      return ElevatedButton.icon(
        onPressed: onPanel,
        icon: const Icon(Icons.dashboard_outlined),
        label: const Text('Ir a mi panel'),
      );
    }

    final ancho = MediaQuery.sizeOf(context).width < _anchoMovil
        ? double.infinity
        : 240.0;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        SizedBox(
          width: ancho,
          child: ElevatedButton.icon(
            onPressed: onLogin,
            icon: const Icon(Icons.login),
            label: const Text('Iniciar sesión'),
          ),
        ),
        SizedBox(
          width: ancho,
          child: OutlinedButton.icon(
            onPressed: onRegistro,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Registrarse'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: AppPalette.textDark,
              side: const BorderSide(color: AppPalette.mintDark, width: 1.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Beneficios extends StatelessWidget {
  const _Beneficios();

  static const _items = [
    (
      Icons.favorite_border,
      'Adopta',
      'Encuentra a tu compañero ideal y postúlate en pocos pasos.',
    ),
    (
      Icons.volunteer_activism_outlined,
      'Da en adopción',
      'Publica a tu mascota con fotos y datos para que halle un buen hogar.',
    ),
    (
      Icons.verified_user_outlined,
      'Proceso seguro',
      'Cada adopción pasa por etapas de evaluación y seguimiento.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const espacio = 16.0;
        final ancho = constraints.maxWidth < _anchoMovil
            ? constraints.maxWidth
            : (constraints.maxWidth - espacio * 2) / 3;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final (icono, titulo, descripcion) in _items)
              SizedBox(
                width: ancho,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: AppPalette.peach,
                          child: Icon(icono, color: AppPalette.textDark),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          titulo,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(descripcion),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Galería "Nuestra comunidad".
///
/// - Escritorio / tablet: mosaico (una foto destacada a la izquierda que ocupa dos
///   filas, una foto ancha arriba a la derecha y dos más pequeñas debajo).
/// - Móvil: foto destacada a todo el ancho y las otras tres en una fila de cuadrados.
///
/// Al tocar una foto se abre un visor a pantalla completa con deslizamiento y zoom.
class _Galeria extends StatelessWidget {
  const _Galeria();

  static const _imagenes = [
    'assets/images/comunidad1.jpg',
    'assets/images/comunidad2.jpg',
    'assets/images/comunidad3.jpg',
    'assets/images/comunidad4.jpg',
  ];

  static const _espacio = 10.0;

  void _abrirVisor(BuildContext context, int inicial) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, _, _) =>
            _VisorGaleria(imagenes: _imagenes, inicial: inicial),
        transitionsBuilder: (_, animacion, _, hijo) =>
            FadeTransition(opacity: animacion, child: hijo),
      ),
    );
  }

  Widget _tile(BuildContext context, int i) => _GaleriaTile(
    ruta: _imagenes[i],
    heroTag: _imagenes[i],
    indice: i,
    total: _imagenes.length,
    onTap: () => _abrirVisor(context, i),
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        return ancho < _anchoMovil
            ? _movil(context, ancho)
            : _mosaico(context, ancho);
      },
    );
  }

  Widget _movil(BuildContext context, double ancho) {
    final lado = (ancho - _espacio * 2) / 3;
    return Column(
      children: [
        AspectRatio(aspectRatio: 4 / 3, child: _tile(context, 0)),
        const SizedBox(height: _espacio),
        SizedBox(
          height: lado,
          child: Row(
            children: [
              Expanded(child: _tile(context, 1)),
              const SizedBox(width: _espacio),
              Expanded(child: _tile(context, 2)),
              const SizedBox(width: _espacio),
              Expanded(child: _tile(context, 3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mosaico(BuildContext context, double ancho) {
    final alto = (ancho * 0.5).clamp(320.0, 460.0);
    return SizedBox(
      height: alto,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: _tile(context, 0)),
          const SizedBox(width: _espacio),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _tile(context, 1)),
                const SizedBox(height: _espacio),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _tile(context, 2)),
                      const SizedBox(width: _espacio),
                      Expanded(child: _tile(context, 3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto de la galería con efecto al pasar el cursor / tocar.
class _GaleriaTile extends StatefulWidget {
  const _GaleriaTile({
    required this.ruta,
    required this.heroTag,
    required this.indice,
    required this.total,
    required this.onTap,
  });

  final String ruta;
  final Object heroTag;
  final int indice;
  final int total;
  final VoidCallback onTap;

  @override
  State<_GaleriaTile> createState() => _GaleriaTileState();
}

class _GaleriaTileState extends State<_GaleriaTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      image: true,
      label:
          'Foto ${widget.indice + 1} de ${widget.total} de nuestra comunidad. Toca para ampliar',
      child: MouseRegion(
        cursor: SystemMouseCursors.zoomIn,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _hover ? 0.18 : 0.08),
                  blurRadius: _hover ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Hero(
                tag: widget.heroTag,
                child: AnimatedScale(
                  scale: _hover ? 1.05 : 1,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: _ImagenAsset(
                    ruta: widget.ruta,
                    icon: Icons.photo_outlined,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Visor a pantalla completa: deslizar entre fotos, pellizcar para hacer zoom.
class _VisorGaleria extends StatefulWidget {
  const _VisorGaleria({required this.imagenes, required this.inicial});

  final List<String> imagenes;
  final int inicial;

  @override
  State<_VisorGaleria> createState() => _VisorGaleriaState();
}

class _VisorGaleriaState extends State<_VisorGaleria> {
  late final PageController _controller = PageController(
    initialPage: widget.inicial,
  );
  late int _actual = widget.inicial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ir(int delta) {
    final destino = (_actual + delta).clamp(0, widget.imagenes.length - 1);
    _controller.animateToPage(
      destino,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final esMovil = MediaQuery.sizeOf(context).width < _anchoMovil;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.imagenes.length,
              onPageChanged: (i) => setState(() => _actual = i),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: esMovil ? 8 : 72,
                    vertical: 56,
                  ),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: Hero(
                        tag: widget.imagenes[i],
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            widget.imagenes[i],
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox(
                              width: 240,
                              height: 180,
                              child: _ImagePlaceholder(
                                icon: Icons.photo_outlined,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
            if (!esMovil) ...[
              if (_actual > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: _BotonVisor(
                    icon: Icons.chevron_left,
                    tooltip: 'Anterior',
                    onTap: () => _ir(-1),
                  ),
                ),
              if (_actual < widget.imagenes.length - 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: _BotonVisor(
                    icon: Icons.chevron_right,
                    tooltip: 'Siguiente',
                    onTap: () => _ir(1),
                  ),
                ),
            ],
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.imagenes.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _actual ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _actual ? AppPalette.peach : Colors.white54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonVisor extends StatelessWidget {
  const _BotonVisor({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: IconButton.filled(
        tooltip: tooltip,
        onPressed: onTap,
        style: IconButton.styleFrom(backgroundColor: Colors.white24),
        icon: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}

/// Imagen del home tomada de `assets/images/`; llena el espacio que le da su padre.
/// Si el archivo no existe se muestra el [_ImagePlaceholder].
class _ImagenAsset extends StatelessWidget {
  const _ImagenAsset({required this.ruta, required this.icon, this.label});

  final String ruta;
  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.asset(
        ruta,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _ImagePlaceholder(icon: icon, label: label),
      ),
    );
  }
}

/// Space reserved for an image while its asset file is missing.
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.icon, this.label});

  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.mintDark.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: AppPalette.mintDark),
          if (label != null) ...[const SizedBox(height: 6), Text(label!)],
        ],
      ),
    );
  }
}
