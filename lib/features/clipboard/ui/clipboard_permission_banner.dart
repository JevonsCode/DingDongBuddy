part of 'clipboard_screen.dart';

class _ClipboardPermissionBanner extends StatefulWidget {
  const _ClipboardPermissionBanner({required this.viewModel});

  final ClipboardSettingsController viewModel;

  @override
  State<_ClipboardPermissionBanner> createState() =>
      _ClipboardPermissionBannerState();
}

class _ClipboardPermissionBannerState extends State<_ClipboardPermissionBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burstController;
  bool? _previousGranted;
  late bool _visible;
  bool _bursting = false;

  @override
  void initState() {
    super.initState();
    _previousGranted = widget.viewModel.quickPastePermissionGranted;
    _visible = _previousGranted == false;
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    )..addStatusListener(_handleBurstStatus);
    widget.viewModel.addListener(_handlePermissionChanged);
  }

  @override
  void didUpdateWidget(covariant _ClipboardPermissionBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel == widget.viewModel) {
      return;
    }
    oldWidget.viewModel.removeListener(_handlePermissionChanged);
    widget.viewModel.addListener(_handlePermissionChanged);
    _previousGranted = widget.viewModel.quickPastePermissionGranted;
    _visible = _previousGranted == false;
    _bursting = false;
    _burstController.reset();
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_handlePermissionChanged);
    _burstController
      ..removeStatusListener(_handleBurstStatus)
      ..dispose();
    super.dispose();
  }

  void _handlePermissionChanged() {
    final bool? granted = widget.viewModel.quickPastePermissionGranted;
    final bool becameGranted = _previousGranted == false && granted == true;
    _previousGranted = granted;

    if (becameGranted && _visible && !_bursting) {
      _startBurst();
      return;
    }
    if (granted == false && !_visible) {
      _burstController.reset();
      setState(() {
        _visible = true;
        _bursting = false;
      });
      return;
    }
    if (granted != false && _visible && !_bursting) {
      setState(() => _visible = false);
    }
  }

  void _startBurst() {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      setState(() => _visible = false);
      return;
    }
    setState(() => _bursting = true);
    _burstController.forward(from: 0);
  }

  void _handleBurstStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) {
      return;
    }
    setState(() {
      _visible = false;
      _bursting = false;
    });
    _burstController.reset();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: !_visible
          ? const SizedBox.shrink()
          : KeyedSubtree(
              key: const Key('clipboard-permission-banner'),
              child: _bursting
                  ? Semantics(
                      liveRegion: true,
                      label: context.localized(
                        'Quick paste permission granted',
                        '快捷粘贴权限已开启',
                      ),
                      child: ExcludeSemantics(
                        child: _PermissionBannerBurst(
                          animation: _burstController,
                          surfaceBuilder: () => _ClipboardPermissionSurface(
                            viewModel: widget.viewModel,
                            interactive: false,
                          ),
                        ),
                      ),
                    )
                  : _ClipboardPermissionSurface(
                      viewModel: widget.viewModel,
                      interactive: true,
                    ),
            ),
    );
  }
}

class _ClipboardPermissionSurface extends StatelessWidget {
  const _ClipboardPermissionSurface({
    required this.viewModel,
    required this.interactive,
  });

  final ClipboardSettingsController viewModel;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5DF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE7C77E)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: Color(0xFF8A6420),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.localized(
                'Quick paste needs Accessibility permission.',
                '快捷粘贴需要辅助功能权限。',
              ),
              style: const TextStyle(
                color: Color(0xFF76571F),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DesktopActionButton(
            key: interactive
                ? const Key('clipboard-open-permission-settings')
                : null,
            onPressed: interactive
                ? viewModel.openQuickPastePermissionSettings
                : null,
            label: context.localized('Open settings', '前往开启'),
            compact: true,
            tone: DesktopActionTone.soft,
          ),
        ],
      ),
    );
  }
}

class _PermissionBannerBurst extends StatelessWidget {
  const _PermissionBannerBurst({
    required this.animation,
    required this.surfaceBuilder,
  });

  final Animation<double> animation;
  final Widget Function() surfaceBuilder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double progress = animation.value;
        final double flight = Curves.easeOutCubic.transform(progress);
        final double fadeProgress = ((progress - 0.24) / 0.76).clamp(0, 1);
        final double opacity = 1 - Curves.easeInCubic.transform(fadeProgress);
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            IgnorePointer(child: Opacity(opacity: 0, child: surfaceBuilder())),
            Positioned.fill(
              child: IgnorePointer(
                child: Transform.translate(
                  offset: Offset(-22 * flight, -4 * flight),
                  child: Transform.rotate(
                    angle: -0.035 * flight,
                    child: Opacity(
                      opacity: opacity,
                      child: ClipPath(
                        key: const Key('clipboard-permission-left-fragment'),
                        clipper: const _PermissionFragmentClipper(
                          _PermissionFragmentSide.left,
                        ),
                        child: surfaceBuilder(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Transform.translate(
                  offset: Offset(22 * flight, 4 * flight),
                  child: Transform.rotate(
                    angle: 0.035 * flight,
                    child: Opacity(
                      opacity: opacity,
                      child: ClipPath(
                        key: const Key('clipboard-permission-right-fragment'),
                        clipper: const _PermissionFragmentClipper(
                          _PermissionFragmentSide.right,
                        ),
                        child: surfaceBuilder(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const Key('clipboard-permission-burst-particles'),
                  painter: _PermissionBurstPainter(progress),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _PermissionFragmentSide { left, right }

class _PermissionFragmentClipper extends CustomClipper<Path> {
  const _PermissionFragmentClipper(this.side);

  final _PermissionFragmentSide side;

  List<Offset> _seam(Size size) {
    final double center = size.width / 2;
    return <Offset>[
      Offset(center - 2, 0),
      Offset(center + 2, size.height * 0.18),
      Offset(center - 3, size.height * 0.36),
      Offset(center + 3, size.height * 0.55),
      Offset(center - 1, size.height * 0.73),
      Offset(center + 2, size.height),
    ];
  }

  @override
  Path getClip(Size size) {
    final List<Offset> seam = _seam(size);
    final Path path = Path();
    if (side == _PermissionFragmentSide.left) {
      path
        ..moveTo(0, 0)
        ..lineTo(seam.first.dx, seam.first.dy);
      for (final Offset point in seam.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path
        ..lineTo(0, size.height)
        ..close();
      return path;
    }
    path
      ..moveTo(seam.first.dx, seam.first.dy)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(seam.last.dx, seam.last.dy);
    for (final Offset point in seam.reversed.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _PermissionFragmentClipper oldClipper) =>
      oldClipper.side != side;
}

class _PermissionBurstPainter extends CustomPainter {
  const _PermissionBurstPainter(this.progress);

  final double progress;

  static const List<_PermissionBurstParticle> _particles =
      <_PermissionBurstParticle>[
        _PermissionBurstParticle(-2.75, 34, 7, 2, Color(0xFFD49A25)),
        _PermissionBurstParticle(-2.25, 26, 5, 2, Color(0xFFF1C663)),
        _PermissionBurstParticle(-1.78, 31, 7, 2, Color(0xFFB77B11)),
        _PermissionBurstParticle(-1.25, 27, 5, 2, Color(0xFFE7B447)),
        _PermissionBurstParticle(-0.72, 35, 8, 2, Color(0xFFCA8B17)),
        _PermissionBurstParticle(-0.18, 25, 5, 2, Color(0xFFF1C663)),
        _PermissionBurstParticle(0.35, 32, 7, 2, Color(0xFFD49A25)),
        _PermissionBurstParticle(0.92, 28, 5, 2, Color(0xFFE7B447)),
        _PermissionBurstParticle(1.42, 34, 7, 2, Color(0xFFB77B11)),
        _PermissionBurstParticle(1.95, 26, 5, 2, Color(0xFFF1C663)),
        _PermissionBurstParticle(2.48, 32, 7, 2, Color(0xFFCA8B17)),
        _PermissionBurstParticle(3.02, 25, 5, 2, Color(0xFFE7B447)),
      ];

  @override
  void paint(Canvas canvas, Size size) {
    final double flight = Curves.easeOutCubic.transform(progress);
    final double opacity = progress < 0.14
        ? (progress / 0.14).clamp(0, 1)
        : ((1 - progress) / 0.86).clamp(0, 1);
    final Offset origin = Offset(size.width / 2, size.height / 2 + 5);
    final Paint paint = Paint();

    for (final _PermissionBurstParticle particle in _particles) {
      final Offset position =
          origin +
          Offset.fromDirection(particle.angle, particle.distance * flight);
      paint.color = particle.color.withValues(alpha: opacity * 0.9);
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(particle.angle + flight * 0.8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.length,
            height: particle.width,
          ),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }

    if (progress < 0.3) {
      final double seamOpacity = (1 - progress / 0.3).clamp(0, 1);
      paint
        ..color = const Color(0xFFFFD979).withValues(alpha: seamOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final List<Offset> seam = const _PermissionFragmentClipper(
        _PermissionFragmentSide.left,
      )._seam(size);
      final Path seamPath = Path()..moveTo(seam.first.dx, seam.first.dy);
      for (final Offset point in seam.skip(1)) {
        seamPath.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(seamPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PermissionBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _PermissionBurstParticle {
  const _PermissionBurstParticle(
    this.angle,
    this.distance,
    this.length,
    this.width,
    this.color,
  );

  final double angle;
  final double distance;
  final double length;
  final double width;
  final Color color;
}
