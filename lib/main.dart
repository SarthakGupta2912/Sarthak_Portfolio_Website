import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _preloadFonts();
  } catch (error, stackTrace) {
    debugPrint('Font preload failed: $error\n$stackTrace');
  }
  runApp(const SarthakPortfolio());
}

/// Loads bundled fonts before the first frame so the first paint uses the
/// intended typefaces instead of a fallback font.
Future<void> _preloadFonts() async {
  final FontLoader inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Inter-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf'));
  final FontLoader poppins = FontLoader('Poppins')
    ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'));

  await Future.wait([inter.load(), poppins.load()]);
}

/// Poppins is bundled with the app so the web build never waits on a font CDN.
TextStyle appPoppins({
  double? fontSize,
  Color? color,
  FontWeight? fontWeight,
  double? letterSpacing,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'Poppins',
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
  );
}

double _measureTextWidth(String text, TextStyle style, TextScaler scaler) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout();
  final double width = painter.width;
  painter.dispose();
  return width;
}

class SarthakPortfolio extends StatelessWidget {
  const SarthakPortfolio({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sarthak Gupta | Portfolio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050505),
        fontFamily: 'Inter',
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Inter'),
      ),
      home: const PortfolioHome(),
    );
  }
}

// ---------------------------------------------------------------------------
// Responsive helpers – derive everything from MediaQuery.size
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Lens animation state
// ---------------------------------------------------------------------------
class LensAnimationState extends ChangeNotifier {
  Offset _smoothedPos = const Offset(-1000, -1000);
  Offset _targetPos = const Offset(-1000, -1000);

  /// Off by default: most visitors only need the static dot grid.
  bool isActive = false;

  /// Called when the pointer moves so the background can wake its ticker.
  VoidCallback? onWake;

  Offset get smoothedPos => _smoothedPos;

  void setTarget(Offset pos) {
    if (!isActive) return;
    _targetPos = pos;
    onWake?.call();
  }

  void toggleActive() {
    isActive = !isActive;
    notifyListeners();
    if (isActive) onWake?.call();
  }

  /// Eases the glow toward the pointer. Returns true while it is still moving.
  bool advance(double dt) {
    if (!isActive) return false;

    final double factor = 1 - math.exp(-5.0 * dt);
    _smoothedPos = Offset(
      _smoothedPos.dx + (_targetPos.dx - _smoothedPos.dx) * factor,
      _smoothedPos.dy + (_targetPos.dy - _smoothedPos.dy) * factor,
    );

    final double dx = _targetPos.dx - _smoothedPos.dx;
    final double dy = _targetPos.dy - _smoothedPos.dy;
    final bool moving = dx * dx + dy * dy > 0.25;

    if (!moving) _smoothedPos = _targetPos;
    notifyListeners();
    return moving;
  }
}

// ---------------------------------------------------------------------------
// PortfolioHome
// ---------------------------------------------------------------------------
class PortfolioHome extends StatefulWidget {
  const PortfolioHome({super.key});

  @override
  State<PortfolioHome> createState() => _PortfolioHomeState();
}

class _PortfolioHomeState extends State<PortfolioHome> {
  final ValueNotifier<Offset> _mouseNotifier = ValueNotifier(
    const Offset(-1000, -1000),
  );

  final LensAnimationState _lensState = LensAnimationState();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<String> _activeTab = ValueNotifier<String>('home');

  final GlobalKey _heroKey = GlobalKey();
  final GlobalKey _skillsKey = GlobalKey();
  final GlobalKey _experienceKey = GlobalKey();
  final GlobalKey _projectsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _lensState.dispose();
    _scrollController.dispose();
    _mouseNotifier.dispose();
    _activeTab.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;

    final double scrollOffset = _scrollController.offset;
    final double triggerLine =
        _scrollController.position.viewportDimension * 0.4;

    String newTab = 'home';
    if (_hasReached(_projectsKey, scrollOffset, triggerLine)) {
      newTab = 'projects';
    } else if (_hasReached(_experienceKey, scrollOffset, triggerLine)) {
      newTab = 'experience';
    } else if (_hasReached(_skillsKey, scrollOffset, triggerLine)) {
      newTab = 'skills';
    }

    if (newTab != _activeTab.value) {
      _activeTab.value = newTab;
    }
  }

  /// Content offset of a section, independent of the current paint offset.
  ///
  /// Using [RenderAbstractViewport] avoids reading stale `localToGlobal`
  /// positions during a fast scroll, which used to leave the nav one section
  /// behind.
  double? _getSectionOffset(GlobalKey key) {
    final BuildContext? ctx = key.currentContext;
    if (ctx == null) return null;
    final RenderObject? box = ctx.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return RenderAbstractViewport.of(box).getOffsetToReveal(box, 0.0).offset;
  }

  bool _hasReached(GlobalKey key, double scrollOffset, double triggerLine) {
    final double? sectionOffset = _getSectionOffset(key);
    return sectionOffset != null && scrollOffset >= sectionOffset - triggerLine;
  }

  void _scrollTo(GlobalKey key, String tab) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeInOutCubic,
      );
      _activeTab.value = tab;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final bool showSidebar = media.width >= 1200;

    // Responsive horizontal padding: 2.4% of width, clamped 16–64 px
    final double hPad = (media.width * 0.024).clamp(16.0, 64.0);
    // Responsive vertical padding: 8% of height, clamped 40–140 px
    final double vPad = (media.height * 0.08).clamp(40.0, 140.0);
    // Responsive section gap: 10% of height, clamped 60–200 px
    final double sectionGap = (media.height * 0.10).clamp(60.0, 200.0);
    // Cursor dot size: 1.5% of shortest side, clamped 16–32 px
    final double cursorSize = (media.shortestSide * 0.015).clamp(16.0, 32.0);
    final double cursorDotSize = cursorSize * 0.28;

    return Scaffold(
      body: Listener(
        onPointerHover: (event) {
          if (event.kind != PointerDeviceKind.mouse) return;
          _mouseNotifier.value = event.position;
          _lensState.setTarget(event.position);
        },
        onPointerMove: (event) {
          if (event.kind != PointerDeviceKind.mouse) return;
          _mouseNotifier.value = event.position;
          _lensState.setTarget(event.position);
        },
        behavior: HitTestBehavior.translucent,
        child: MouseRegion(
          cursor: SystemMouseCursors.none,
          child: Stack(
            children: [
              // ── Background ──────────────────────────────────────────────
              Positioned.fill(
                child: RepaintBoundary(
                  child: KineticLensBackground(lensState: _lensState),
                ),
              ),

              // ── Main scrollable content ──────────────────────────────────
              SingleChildScrollView(
                controller: _scrollController,
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(
                      // Max content width scales gently with screen width
                      maxWidth: (media.width * 0.90).clamp(320.0, 1000.0),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: hPad,
                      vertical: vPad,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RepaintBoundary(
                          child: HeroSection(
                            key: _heroKey,
                            lensState: _lensState,
                            media: media,
                          ),
                        ),
                        SizedBox(height: sectionGap),
                        RepaintBoundary(
                          child: SkillsSection(key: _skillsKey, media: media),
                        ),
                        SizedBox(height: sectionGap),
                        RepaintBoundary(
                          child: ExperienceSection(
                            key: _experienceKey,
                            media: media,
                          ),
                        ),
                        SizedBox(height: sectionGap),
                        RepaintBoundary(
                          child: ProjectsSection(
                            key: _projectsKey,
                            media: media,
                          ),
                        ),
                        SizedBox(height: sectionGap * 0.75),
                        const RepaintBoundary(child: Footer()),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Sidebar nav ──────────────────────────────────────────────
              if (showSidebar)
                Positioned(
                  right: (media.width * 0.032).clamp(16.0, 56.0),
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: ValueListenableBuilder<String>(
                      valueListenable: _activeTab,
                      builder: (context, activeTab, _) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _NavButton(
                              label: '01. Intro',
                              isActive: activeTab == 'home',
                              onTap: () => _scrollTo(_heroKey, 'home'),
                            ),
                            SizedBox(
                              height: (media.height * 0.025).clamp(12.0, 32.0),
                            ),
                            _NavButton(
                              label: '02. Skills',
                              isActive: activeTab == 'skills',
                              onTap: () => _scrollTo(_skillsKey, 'skills'),
                            ),
                            SizedBox(
                              height: (media.height * 0.025).clamp(12.0, 32.0),
                            ),
                            _NavButton(
                              label: '03. Experience',
                              isActive: activeTab == 'experience',
                              onTap: () =>
                                  _scrollTo(_experienceKey, 'experience'),
                            ),
                            SizedBox(
                              height: (media.height * 0.025).clamp(12.0, 32.0),
                            ),
                            _NavButton(
                              label: '04. Projects',
                              isActive: activeTab == 'projects',
                              onTap: () => _scrollTo(_projectsKey, 'projects'),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

              // ── Custom cursor ────────────────────────────────────────────
              Positioned(
                left: 0,
                top: 0,
                child: ValueListenableBuilder<Offset>(
                  valueListenable: _mouseNotifier,
                  builder: (context, mousePos, child) {
                    return RepaintBoundary(
                      child: Transform.translate(
                        offset: Offset(
                          mousePos.dx - cursorSize / 2,
                          mousePos.dy - cursorSize / 2,
                        ),
                        child: IgnorePointer(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: cursorSize,
                                height: cursorSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                              Container(
                                width: cursorDotSize,
                                height: cursorDotSize,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KineticLensBackground
// ---------------------------------------------------------------------------
class KineticLensBackground extends StatefulWidget {
  final LensAnimationState lensState;
  const KineticLensBackground({super.key, required this.lensState});

  @override
  State<KineticLensBackground> createState() => _KineticLensBackgroundState();
}

class _KineticLensBackgroundState extends State<KineticLensBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final ValueNotifier<bool> _active;
  late final VoidCallback _lensListener;
  Duration _lastElapsed = Duration.zero;
  Size _lastSize = Size.zero;
  double _spacing = 0;
  List<Offset> _anchors = const [];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _active = ValueNotifier<bool>(widget.lensState.isActive);
    widget.lensState.onWake = _wake;
    _lensListener = () {
      if (_active.value != widget.lensState.isActive) {
        _active.value = widget.lensState.isActive;
      }
    };
    widget.lensState.addListener(_lensListener);
  }

  @override
  void dispose() {
    widget.lensState.removeListener(_lensListener);
    if (widget.lensState.onWake == _wake) widget.lensState.onWake = null;
    _active.dispose();
    _ticker.dispose();
    super.dispose();
  }

  void _wake() {
    if (_ticker.isActive) return;
    _lastElapsed = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    // The lens is decoration, not a game loop. 30 fps is plenty.
    if (_lastElapsed != Duration.zero &&
        elapsed - _lastElapsed < const Duration(milliseconds: 33)) {
      return;
    }

    final double dt = _lastElapsed == Duration.zero
        ? 1 / 30
        : (elapsed - _lastElapsed).inMicroseconds / 1000000;
    _lastElapsed = elapsed;

    if (!widget.lensState.advance(dt.clamp(0.001, 0.1))) {
      _ticker.stop();
      _lastElapsed = Duration.zero;
    }
  }

  List<Offset> _buildAnchors(Size size, double spacing) {
    if (size.isEmpty) return const [];
    final List<Offset> anchors = <Offset>[];
    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        anchors.add(Offset(x, y));
      }
    }
    return anchors;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final double spacing = (media.shortestSide * 0.05).clamp(38.0, 72.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size != _lastSize || spacing != _spacing) {
          _lastSize = size;
          _spacing = spacing;
          _anchors = _buildAnchors(size, spacing);
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(painter: _DotGridPainter(anchors: _anchors)),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _active,
              builder: (context, active, _) {
                if (!active) return const SizedBox.shrink();
                return RepaintBoundary(
                  child: CustomPaint(
                    painter: _LensOverlayPainter(
                      repaint: widget.lensState,
                      anchors: _anchors,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------
class _DotGridPainter extends CustomPainter {
  final List<Offset> anchors;

  const _DotGridPainter({required this.anchors});

  static final Paint _paint = Paint()
    ..color = const Color(0x14FFFFFF)
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    if (anchors.isEmpty) return;
    // One draw call for the whole grid keeps this cheap on old GPUs.
    canvas.drawPoints(ui.PointMode.points, anchors, _paint);
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) =>
      oldDelegate.anchors != anchors;
}

class _LensOverlayPainter extends CustomPainter {
  final LensAnimationState repaint;
  final List<Offset> anchors;

  _LensOverlayPainter({required this.repaint, required this.anchors})
    : super(repaint: repaint);

  static const double _radius = 230;
  static final Paint _glowPaint = Paint();
  static final Paint _coverPaint = Paint()
    ..color = const Color(0xFF050505)
    ..strokeWidth = 3.6
    ..strokeCap = StrokeCap.round;
  static final Paint _dotPaint = Paint()
    ..color = const Color(0x9900E5FF)
    ..strokeWidth = 3.2
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    if (!repaint.isActive) return;
    final Offset mouse = repaint.smoothedPos;
    if (mouse.dx < 0 || mouse.dy < 0) return;

    final List<Offset> covers = <Offset>[];
    final List<Offset> points = <Offset>[];
    for (final Offset anchor in anchors) {
      final double dx = anchor.dx - mouse.dx;
      final double dy = anchor.dy - mouse.dy;
      final double distSq = dx * dx + dy * dy;
      if (distSq >= _radius * _radius) continue;

      covers.add(anchor);
      final double dist = math.sqrt(distSq);
      final double t = 1 - dist / _radius;
      final double push = t * t * 12;
      if (dist == 0) {
        points.add(anchor);
      } else {
        points.add(
          Offset(anchor.dx - dx / dist * push, anchor.dy - dy / dist * push),
        );
      }
    }

    // Hide the inactive grey grid under the lens so only the cyan field reads.
    if (covers.isNotEmpty) {
      canvas.drawPoints(ui.PointMode.points, covers, _coverPaint);
    }

    final Rect glow = Rect.fromCircle(center: mouse, radius: _radius);
    _glowPaint.shader = const RadialGradient(
      colors: [Color(0x1F00E5FF), Color(0x0000E5FF)],
    ).createShader(glow);
    canvas.drawCircle(mouse, _radius, _glowPaint);

    if (points.isNotEmpty) {
      canvas.drawPoints(ui.PointMode.points, points, _dotPaint);
    }
  }

  @override
  bool shouldRepaint(_LensOverlayPainter oldDelegate) =>
      oldDelegate.anchors != anchors || oldDelegate.repaint != repaint;
}

// ---------------------------------------------------------------------------
// Nav button
// ---------------------------------------------------------------------------
class _NavButton extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final double fontSize = (media.shortestSide * 0.014).clamp(10.0, 14.0);
    final double dotSize = widget.isActive
        ? (media.shortestSide * 0.010).clamp(7.0, 11.0)
        : (media.shortestSide * 0.007).clamp(5.0, 8.0);
    final double gap = (media.width * 0.010).clamp(8.0, 20.0);

    final bool show = widget.isActive || _hovered;
    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.none,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: show ? 1.0 : 0.0,
                child: Text(
                  widget.label,
                  style: appPoppins(
                    fontSize: fontSize,
                    color: widget.isActive
                        ? const Color(0xFF00E5FF)
                        : Colors.grey,
                  ),
                ),
              ),
              SizedBox(width: gap),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isActive
                      ? const Color(0xFF00E5FF)
                      : (_hovered ? Colors.grey[400] : Colors.grey[800]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero section
// ---------------------------------------------------------------------------
class HeroSection extends StatelessWidget {
  static const Color accent = Color(0xFF00E5FF);

  final LensAnimationState lensState;
  final Size media;

  const HeroSection({super.key, required this.lensState, required this.media});

  @override
  Widget build(BuildContext context) {
    final bool wide = media.width >= 1060;
    final double nameFontSize = wide
        ? (media.width * 0.055).clamp(46.0, 76.0)
        : (media.width * 0.075).clamp(30.0, 84.0);
    final double subtitleFontSize = wide
        ? (media.width * 0.020).clamp(15.0, 26.0)
        : (media.width * 0.026).clamp(14.0, 28.0);
    final double pillFontSize = (media.shortestSide * 0.0135).clamp(9.0, 13.0);
    final double pillHeight = (media.shortestSide * 0.055).clamp(40.0, 50.0);
    final double pillHPad = (media.width * 0.013).clamp(12.0, 18.0);
    final String availabilityLabel = media.width < 480
        ? 'Open to work'
        : 'Available for opportunities';
    final TextScaler textScaler = MediaQuery.textScalerOf(context);
    // Match the effective style, including inherited letter spacing.
    final TextStyle pillTextStyle = DefaultTextStyle.of(
      context,
    ).style.merge(appPoppins(fontSize: pillFontSize));
    final double availabilityTextWidth = _measureTextWidth(
      availabilityLabel,
      pillTextStyle,
      textScaler,
    );
    final double lensTextWidth = _measureTextWidth(
      'Lens illusion',
      pillTextStyle,
      textScaler,
    );
    // Both pills share the widest natural size so the pair reads as a set.
    // Web fonts can arrive after the first layout, so leave headroom for the
    // final Poppins metrics instead of clipping the fallback measurement.
    const double textHeadroom = 1.25;
    final double pillWidth = math
        .max(
          availabilityTextWidth * textHeadroom + 7 * 2.3 + 8 + pillHPad * 2,
          lensTextWidth * textHeadroom + (pillFontSize + 4) + 7 + pillHPad * 2,
        )
        .ceilToDouble();
    final double gapBadge = (media.height * 0.026).clamp(16.0, 32.0);
    final double gapEyebrow = (media.height * 0.016).clamp(10.0, 20.0);
    final double gapName = (media.height * 0.020).clamp(12.0, 24.0);
    final double gapCta = (media.height * 0.040).clamp(24.0, 52.0);
    final double gapStack = (media.height * 0.026).clamp(16.0, 34.0);
    final double buttonHPad = (media.width * 0.016).clamp(14.0, 24.0);
    final double buttonVPad = (media.height * 0.016).clamp(12.0, 18.0);
    final double buttonFont = (media.shortestSide * 0.015).clamp(11.0, 15.0);
    final double socialSize = (media.shortestSide * 0.050).clamp(38.0, 46.0);
    final double eyebrowSize = (media.shortestSide * 0.0125).clamp(8.5, 11.5);
    final double stackSize = (media.shortestSide * 0.0115).clamp(8.0, 11.5);

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _HeroPill(
              key: const Key('hero-availability-pill'),
              width: pillWidth,
              height: pillHeight,
              hPad: pillHPad,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _StatusDot(size: 7),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      availabilityLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appPoppins(
                        fontSize: pillFontSize,
                        color: Colors.grey[300],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListenableBuilder(
              listenable: lensState,
              builder: (_, _) => _HeroPill(
                key: const Key('hero-lens-pill'),
                width: pillWidth,
                height: pillHeight,
                hPad: pillHPad,
                onTap: lensState.toggleActive,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      lensState.isActive
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: pillFontSize + 4,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        'Lens illusion',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appPoppins(
                          fontSize: pillFontSize,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: gapBadge),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 2,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 11),
            Text(
              'SOFTWARE ENGINEER',
              style: appPoppins(
                fontSize: eyebrowSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.6,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        SizedBox(height: gapEyebrow),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: nameFontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: nameFontSize * -0.035,
              height: 1.0,
              color: Colors.white,
            ),
            children: [
              const TextSpan(text: 'Sarthak Gupta'),
              TextSpan(
                text: '.',
                style: TextStyle(color: accent.withValues(alpha: 0.9)),
              ),
            ],
          ),
        ),
        SizedBox(height: gapName),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: subtitleFontSize,
              color: Colors.grey[400],
              fontWeight: FontWeight.w300,
              height: 1.45,
            ),
            children: [
              const TextSpan(text: 'I build '),
              const TextSpan(
                text: 'offline-first products',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const TextSpan(text: ', '),
              TextSpan(
                text: 'on-device AI',
                style: TextStyle(color: accent, fontWeight: FontWeight.w500),
              ),
              const TextSpan(text: ' and immersive experiences across '),
              const TextSpan(
                text: 'mobile, desktop and game engines.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: gapCta),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _HeroActionButton(
              label: 'Get in touch',
              icon: Icons.arrow_outward_rounded,
              primary: true,
              fontSize: buttonFont,
              hPad: buttonHPad,
              vPad: buttonVPad,
              onTap: () =>
                  launchUrl(Uri.parse('mailto:sarthakgupta2912@gmail.com')),
            ),
            _HeroActionButton(
              label: 'Resume',
              icon: Icons.file_download_outlined,
              fontSize: buttonFont,
              hPad: buttonHPad,
              vPad: buttonVPad,
              onTap: () => launchUrl(
                Uri.parse(
                  'https://drive.google.com/file/d/1oTVVP0BWlnSpawTK0GNRwbL3xR1U5-ns/view?usp=sharing',
                ),
                mode: LaunchMode.externalApplication,
              ),
            ),
            const SizedBox(width: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SocialIconButton(
                  icon: Icons.code_rounded,
                  size: socialSize,
                  tooltip: 'GitHub',
                  onTap: () => launchUrl(
                    Uri.parse('https://github.com/SarthakGupta2912'),
                  ),
                ),
                const SizedBox(width: 10),
                _SocialIconButton(
                  icon: Icons.work_outline_rounded,
                  size: socialSize,
                  tooltip: 'LinkedIn',
                  onTap: () => launchUrl(
                    Uri.parse('https://www.linkedin.com/in/sarthakgupta2912/'),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: gapStack),
        Row(
          children: [
            Container(
              width: 22,
              height: 1,
              color: Colors.white.withValues(alpha: 0.16),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'FLUTTER   ·   DART   ·   AI   ·   UNITY',
                style: appPoppins(
                  fontSize: stackSize,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.3,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ],
    );

    if (!wide) return content;

    final double portraitWidth = (media.width * 0.245).clamp(250.0, 330.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: content),
        SizedBox(width: (media.width * 0.040).clamp(32.0, 56.0)),
        _HeroPortrait(width: portraitWidth, captionSize: pillFontSize),
      ],
    );
  }
}

class _HeroPortrait extends StatelessWidget {
  final double width;
  final double captionSize;

  const _HeroPortrait({required this.width, required this.captionSize});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 12,
          top: 12,
          right: -12,
          bottom: -12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: HeroSection.accent.withValues(alpha: 0.32),
              ),
            ),
          ),
        ),
        Container(
          width: width,
          height: width * 1.25,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/hero_portrait.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.medium,
                  cacheWidth: (width * 2).round(),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xE6050505), Color(0x00050505)],
                      stops: [0.0, 0.55],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Row(
                    children: [
                      const _StatusDot(size: 6),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'BASED IN INDIA',
                          style: appPoppins(
                            fontSize: captionSize * 0.82,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroPill extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final double hPad;

  const _HeroPill({
    super.key,
    required this.child,
    required this.width,
    required this.height,
    required this.hPad,
    this.onTap,
  });

  @override
  State<_HeroPill> createState() => _HeroPillState();
}

class _HeroPillState extends State<_HeroPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: widget.width,
          height: widget.height,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: widget.hPad),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _hovered ? 0.07 : 0.035),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: Colors.white.withValues(alpha: _hovered ? 0.25 : 0.10),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _HeroActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final double fontSize;
  final double hPad;
  final double vPad;
  final VoidCallback onTap;

  const _HeroActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.fontSize,
    required this.hPad,
    required this.vPad,
    this.primary = false,
  });

  @override
  State<_HeroActionButton> createState() => _HeroActionButtonState();
}

class _HeroActionButtonState extends State<_HeroActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color border;
    final Color foreground;

    if (widget.primary) {
      background = _hovered ? HeroSection.accent : Colors.white;
      border = Colors.transparent;
      foreground = Colors.black;
    } else {
      background = Colors.white.withValues(alpha: _hovered ? 0.07 : 0.02);
      border = Colors.white.withValues(alpha: _hovered ? 0.35 : 0.16);
      foreground = Colors.white;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
          padding: EdgeInsets.symmetric(
            horizontal: widget.hPad,
            vertical: widget.vPad,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
            boxShadow: widget.primary && _hovered
                ? [
                    BoxShadow(
                      color: HeroSection.accent.withValues(alpha: 0.25),
                      blurRadius: 26,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: appPoppins(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                widget.icon,
                size: widget.fontSize + 4,
                color: widget.primary || !_hovered
                    ? foreground
                    : HeroSection.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final double size;

  const _StatusDot({required this.size});

  static const Color _green = Color(0xFF4ADE80);

  @override
  Widget build(BuildContext context) {
    final double box = size * 2.3;

    return SizedBox(
      width: box,
      height: box,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _green.withValues(alpha: 0.18), width: 1.2),
        ),
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: _green,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialIconButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final String tooltip;
  final VoidCallback onTap;

  const _SocialIconButton({
    required this.icon,
    required this.size,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_SocialIconButton> createState() => _SocialIconButtonState();
}

class _SocialIconButtonState extends State<_SocialIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HeroSection.accent.withValues(
                alpha: _hovered ? 0.10 : 0.02,
              ),
              border: Border.all(
                color: _hovered
                    ? HeroSection.accent.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Icon(
              widget.icon,
              size: widget.size * 0.42,
              color: _hovered ? HeroSection.accent : Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------
class SectionHeader extends StatelessWidget {
  final String number;
  final String title;
  final Size media;

  const SectionHeader({
    super.key,
    required this.number,
    required this.title,
    required this.media,
  });

  @override
  Widget build(BuildContext context) {
    final double fontSize = (media.width * 0.034).clamp(18.0, 38.0);
    final double barWidth = (media.width * 0.040).clamp(28.0, 60.0);
    final double barHeight = (media.height * 0.005).clamp(3.0, 6.0);
    final double gap = (media.height * 0.008).clamp(4.0, 12.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number. $title',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: gap),
        Container(
          width: barWidth,
          height: barHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Skills section
// ---------------------------------------------------------------------------
class SkillsSection extends StatelessWidget {
  final Size media;
  const SkillsSection({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    final double headerGap = (media.height * 0.045).clamp(24.0, 60.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(number: '02', title: 'Arsenal', media: media),
        SizedBox(height: headerGap),
        LayoutBuilder(
          builder: (context, constraints) {
            final double availableWidth = constraints.maxWidth;
            final bool isMobile = availableWidth < 760;
            final double cardSpacing = (availableWidth * 0.020).clamp(
              12.0,
              30.0,
            );

            // Card builder — no cardWidth needed
            TiltCard buildCard({
              required IconData icon,
              required Color iconColor,
              required String title,
              required List<String> skills,
            }) => TiltCard(
              icon: icon,
              iconColor: iconColor,
              title: title,
              skills: skills,
              media: media,
            );

            final c0 = buildCard(
              icon: Icons.phone_android_rounded,
              iconColor: const Color(0xFF00E5FF),
              title: 'Mobile & Desktop',
              skills: const [
                'Flutter & Dart',
                'Android • iOS • Windows',
                'Offline-First Architecture',
                'Stripe & Payment Flows',
              ],
            );
            final c1 = buildCard(
              icon: Icons.memory_rounded,
              iconColor: const Color(0xFF4ADE80),
              title: 'On-Device AI',
              skills: const [
                'On-Device LLMs (LiteRT)',
                'YOLO & MediaPipe',
                'ML Kit / OCR Pipelines',
                'RAG & MCP Systems',
              ],
            );
            final c2 = buildCard(
              icon: Icons.sports_esports_rounded,
              iconColor: Colors.purpleAccent,
              title: 'Game Dev',
              skills: const [
                'Unity Engine',
                'C# Scripting',
                'Gameplay Mechanics & Physics',
                'Object Pooling',
              ],
            );
            final c3 = buildCard(
              icon: Icons.terminal_rounded,
              iconColor: const Color(0xFFFFB347),
              title: 'Core Languages',
              skills: const [
                'Java & C/C++',
                'Data Structures',
                'SQLite & MySQL',
                'Problem Solving',
              ],
            );

            // Mobile: single column
            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [c0, c1, c2, c3]
                    .map(
                      (c) => Padding(
                        padding: EdgeInsets.only(bottom: cardSpacing),
                        child: c,
                      ),
                    )
                    .toList(),
              );
            }

            // Desktop / tablet: balanced 2 × 2 grid with equal-height rows
            final double cardWidth = (availableWidth - cardSpacing) / 2;
            return Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: cardWidth, child: c0),
                      SizedBox(width: cardSpacing),
                      SizedBox(width: cardWidth, child: c1),
                    ],
                  ),
                ),
                SizedBox(height: cardSpacing),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: cardWidth, child: c2),
                      SizedBox(width: cardSpacing),
                      SizedBox(width: cardWidth, child: c3),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TiltCard
// ---------------------------------------------------------------------------
class TiltCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> skills;
  final Size media;
  // ← cardWidth removed

  const TiltCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.skills,
    required this.media,
  });

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Size media = widget.media;
    final double pad = (media.shortestSide * 0.035).clamp(16.0, 40.0);
    final double iconSize = (media.shortestSide * 0.038).clamp(20.0, 40.0);
    final double titleSize = (media.width * 0.020).clamp(14.0, 24.0);
    final double skillSize = (media.width * 0.013).clamp(10.0, 16.0);
    final double skillArrowSize = (media.width * 0.016).clamp(12.0, 20.0);
    final double innerGap1 = (media.height * 0.022).clamp(12.0, 30.0);
    final double innerGap2 = (media.height * 0.022).clamp(12.0, 30.0);
    final double skillBottomPad = (media.height * 0.012).clamp(6.0, 16.0);
    final double skillIconGap = (media.width * 0.010).clamp(6.0, 14.0);
    final double borderRadius = (media.shortestSide * 0.018).clamp(8.0, 20.0);

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.none,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          // ← No width set here. Parent (Expanded) controls it.
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0C),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: _hovered
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: widget.iconColor, size: iconSize),
              SizedBox(height: innerGap1),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: innerGap2),
              ...widget.skills.map(
                (s) => Padding(
                  padding: EdgeInsets.only(bottom: skillBottomPad),
                  child: Row(
                    children: [
                      Text(
                        '▹',
                        style: TextStyle(
                          color: widget.iconColor,
                          fontSize: skillArrowSize,
                        ),
                      ),
                      SizedBox(width: skillIconGap),
                      Expanded(
                        child: Text(
                          s,
                          style: appPoppins(
                            fontSize: skillSize,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Experience section
// ---------------------------------------------------------------------------
class ExperienceSection extends StatelessWidget {
  final Size media;
  const ExperienceSection({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    final double headerGap = (media.height * 0.060).clamp(32.0, 80.0);
    final double itemGap = (media.height * 0.060).clamp(32.0, 80.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(number: '03', title: 'Experience', media: media),
        SizedBox(height: headerGap),
        Container(
          margin: EdgeInsets.only(left: (media.width * 0.008).clamp(4.0, 12.0)),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: Column(
            children: [
              ExperienceItem(
                media: media,
                title: 'Software Developer',
                company: 'BigVision Software Services',
                companyColor: const Color(0xFF00E5FF),
                period: 'Feb 2024 – Present',
                points: const [
                  'Led Flutter front-end dev, accelerating feature rollouts by 25%.',
                  'Integrated OpenAI ChatGPT APIs, driving 15% increase in engagement.',
                  'Optimized API latency by 30% and implemented robust Stripe payment flows.',
                  'Slashed crash incidents by 90% via lazy loading and intelligent caching.',
                ],
              ),
              SizedBox(height: itemGap),
              ExperienceItem(
                media: media,
                title: 'Game Developer Intern',
                company: 'Immersivevision Technology',
                companyColor: Colors.purpleAccent,
                period: 'Feb 2022 – Jul 2022',
                points: const [
                  'Developed immersive virtual environments and mechanics in Unity.',
                  'Integrated Cinemachine for dynamic camera control and cutscenes.',
                  'Implemented Object Pooling, minimizing runtime allocations and GC overhead.',
                ],
              ),
              SizedBox(height: itemGap),
              ExperienceItem(
                media: media,
                title: 'Game Developer Intern',
                company: 'K12 Techno Services',
                companyColor: Colors.grey,
                period: 'Aug 2021 – Oct 2021',
                points: const [
                  'Coded game logic for educational games using Unity and C#.',
                  'Collaborated closely with design teams to ensure engaging UX.',
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ExperienceItem extends StatelessWidget {
  final String title;
  final String company;
  final Color companyColor;
  final String period;
  final List<String> points;
  final Size media;

  const ExperienceItem({
    super.key,
    required this.title,
    required this.company,
    required this.companyColor,
    required this.period,
    required this.points,
    required this.media,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobile = media.width < 800;

    final double titleSize = (media.width * 0.020).clamp(14.0, 24.0);
    final double periodSize = (media.shortestSide * 0.014).clamp(10.0, 15.0);
    final double bodySize = (media.width * 0.016).clamp(12.0, 18.0);
    final double arrowSize = (media.width * 0.018).clamp(13.0, 20.0);
    final double leftPad = (media.width * 0.028).clamp(16.0, 40.0);
    final double arrowGap = (media.width * 0.010).clamp(6.0, 14.0);
    final double pointBottomPad = (media.height * 0.012).clamp(6.0, 16.0);
    final double titlePeriodGap = (media.height * 0.010).clamp(4.0, 14.0);
    final double titlePointsGap = (media.height * 0.016).clamp(8.0, 22.0);

    // Timeline dot
    final double dotSize = (media.shortestSide * 0.014).clamp(8.0, 16.0);
    final double dotLeft = -(dotSize / 2);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: dotLeft,
          top: 4,
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: const Color(0xFF050505),
              shape: BoxShape.circle,
              border: Border.all(color: companyColor, width: 2),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: leftPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            children: [
                              TextSpan(text: title),
                              TextSpan(
                                text: ' @ $company',
                                style: TextStyle(color: companyColor),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: titlePeriodGap),
                        Text(
                          period,
                          style: appPoppins(
                            fontSize: periodSize,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              children: [
                                TextSpan(text: title),
                                TextSpan(
                                  text: ' @ $company',
                                  style: TextStyle(color: companyColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: (media.width * 0.012).clamp(8.0, 20.0)),
                        Text(
                          period,
                          style: appPoppins(
                            fontSize: periodSize,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
              SizedBox(height: titlePointsGap),
              ...points.map(
                (p) => Padding(
                  padding: EdgeInsets.only(bottom: pointBottomPad),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '▹',
                        style: TextStyle(
                          color: companyColor,
                          fontSize: arrowSize,
                        ),
                      ),
                      SizedBox(width: arrowGap),
                      Expanded(
                        child: Text(
                          p,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: bodySize,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Projects section
// ---------------------------------------------------------------------------
class ProjectsSection extends StatelessWidget {
  final Size media;
  const ProjectsSection({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    final double headerGap = (media.height * 0.045).clamp(24.0, 60.0);
    final double cardSpacing = (media.width * 0.020).clamp(12.0, 30.0);

    final projects = <_ProjectData>[
      _ProjectData(
        title: 'Fridge Roulette',
        tagline: 'On-device AI cooking game for kids',
        description:
            'Snap one photo of your fridge and Fridge Roulette turns it into a cooking challenge. Two YOLO models and ML Kit label reading find the food, then a Qwen2.5 0.5B model writes a kid-safe recipe word by word — entirely on the phone, with no account, ads, or analytics.',
        highlights: const [
          '100% on-device inference — photos never leave the phone',
          'Qwen2.5 0.5B streamed token-by-token via MediaPipe',
          'COCO + FoodSeg103 detectors and a 96-food catalog',
        ],
        tags: const ['Flutter', 'On-Device LLM', 'YOLO', 'ML Kit OCR'],
        status: 'Android • Offline',
        accentColor: const Color(0xFF4ADE80),
        icon: Icons.auto_awesome_rounded,
        link: 'https://github.com/SarthakGupta2912/Fridge-Roulette',
      ),
      _ProjectData(
        title: 'LIMS',
        tagline: 'Offline-first billing & local shop ordering',
        description:
            'LIMS gives small shops a complete billing and order desk without a cloud backend. It runs on Android and Windows, keeps products, invoices, and orders in local SQLite, and lets customers join a shop hotspot by QR to browse the menu, place orders, and track pickup over the local network.',
        highlights: const [
          'SQLite is the source of truth, with delta sync between devices',
          'QR-paired hotspot ordering over local Wi-Fi discovery',
          'PDF invoices, templates, and role-based local profiles',
        ],
        tags: const ['Flutter', 'SQLite', 'Wi-Fi Direct', 'Windows'],
        status: 'Android • Windows',
        accentColor: const Color(0xFF00E5FF),
        icon: Icons.receipt_long_rounded,
        link: 'https://github.com/SarthakGupta2912/LIMS',
      ),
      _ProjectData(
        title: 'PathKosh',
        tagline: 'AI skill trees for any learning goal',
        description:
            'PathKosh turns a big goal into a clear skill tree. Tell Forge AI what you want to learn, your level and timeline, and it builds a step-by-step roadmap with prerequisites, difficulty, time estimates and XP. Chat for guidance, track progress, and pick up where you left off — in English or Hindi.',
        highlights: const [
          'AI roadmaps and coaching through user-chosen OpenRouter models',
          'Prerequisite-locked steps with difficulty, time and XP',
          'Live on Google Play with saved progress and no data collected',
        ],
        tags: const [
          'Flutter',
          'OpenRouter AI',
          'Google Play',
          'English + Hindi',
        ],
        status: 'Google Play • Live',
        accentColor: const Color(0xFFE6BE8A),
        icon: Icons.account_tree_rounded,
        link:
            'https://play.google.com/store/apps/details?id=com.Sarthak.pathkosh',
        ctaLabel: 'View on Google Play',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(number: '04', title: 'Selected Builds', media: media),
        SizedBox(height: headerGap),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool twoUp = constraints.maxWidth >= 760;

            if (!twoUp) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...projects.map(
                    (p) => Padding(
                      padding: EdgeInsets.only(bottom: cardSpacing),
                      child: _ProjectCard(project: p, media: media),
                    ),
                  ),
                  _MoreOnGitHubCard(media: media),
                ],
              );
            }

            final double cardWidth = (constraints.maxWidth - cardSpacing) / 2;

            return Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _ProjectCard(
                          project: projects[0],
                          media: media,
                          fillHeight: true,
                        ),
                      ),
                      SizedBox(width: cardSpacing),
                      SizedBox(
                        width: cardWidth,
                        child: _ProjectCard(
                          project: projects[1],
                          media: media,
                          fillHeight: true,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: cardSpacing),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _ProjectCard(
                          project: projects[2],
                          media: media,
                          fillHeight: true,
                        ),
                      ),
                      SizedBox(width: cardSpacing),
                      SizedBox(
                        width: cardWidth,
                        child: _MoreOnGitHubCard(
                          media: media,
                          fillHeight: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProjectData {
  final String title;
  final String tagline;
  final String description;
  final List<String> highlights;
  final List<String> tags;
  final String status;
  final Color accentColor;
  final IconData icon;
  final String link;
  final String ctaLabel;

  const _ProjectData({
    required this.title,
    required this.tagline,
    required this.description,
    required this.highlights,
    required this.tags,
    required this.status,
    required this.accentColor,
    required this.icon,
    required this.link,
    this.ctaLabel = 'View source',
  });
}

class _ProjectCard extends StatefulWidget {
  final _ProjectData project;
  final Size media;
  final bool fillHeight;

  const _ProjectCard({
    required this.project,
    required this.media,
    this.fillHeight = false,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final _ProjectData project = widget.project;
    final Size media = widget.media;
    final double pad = (media.shortestSide * 0.035).clamp(16.0, 36.0);
    final double iconSize = (media.shortestSide * 0.042).clamp(22.0, 40.0);
    final double openIconSize = (media.shortestSide * 0.022).clamp(14.0, 22.0);
    final double titleSize = (media.width * 0.022).clamp(15.0, 26.0);
    final double taglineSize = (media.width * 0.0135).clamp(10.0, 15.0);
    final double descSize = (media.width * 0.014).clamp(11.0, 15.0);
    final double bulletSize = (media.width * 0.0135).clamp(10.0, 14.0);
    final double tagSize = (media.shortestSide * 0.012).clamp(9.0, 12.0);
    final double statusSize = (media.shortestSide * 0.0105).clamp(8.0, 10.0);
    final double innerGap1 = (media.height * 0.018).clamp(10.0, 22.0);
    final double innerGap2 = (media.height * 0.012).clamp(6.0, 14.0);
    final double innerGap3 = (media.height * 0.018).clamp(10.0, 22.0);
    final double bulletGap = (media.height * 0.010).clamp(6.0, 12.0);
    final double tagSpacing = (media.width * 0.008).clamp(5.0, 12.0);
    final double borderRadius = (media.shortestSide * 0.018).clamp(8.0, 20.0);

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.none,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => launchUrl(
            Uri.parse(project.link),
            mode: LaunchMode.externalApplication,
          ),
          child: AnimatedContainer(
            key: Key('project-card-${project.title}'),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            padding: EdgeInsets.all(pad),
            transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0C),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: _hovered
                    ? project.accentColor.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: widget.fillHeight
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      project.icon,
                      color: project.accentColor,
                      size: iconSize,
                    ),
                    SizedBox(width: tagSpacing),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: _StatusPill(
                          label: project.status,
                          accentColor: project.accentColor,
                          fontSize: statusSize,
                          hPad: tagSpacing,
                          vPad: tagSpacing * 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: innerGap1),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: _hovered ? project.accentColor : Colors.white,
                  ),
                  child: Text(project.title),
                ),
                SizedBox(height: innerGap2),
                Text(
                  project.tagline,
                  style: appPoppins(
                    fontSize: taglineSize,
                    color: project.accentColor.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: innerGap3),
                Text(
                  project.description,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: descSize,
                    height: 1.6,
                  ),
                ),
                SizedBox(height: innerGap3),
                ...project.highlights.map(
                  (h) => Padding(
                    padding: EdgeInsets.only(bottom: bulletGap),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '▸',
                          style: TextStyle(
                            color: project.accentColor,
                            fontSize: bulletSize,
                          ),
                        ),
                        SizedBox(width: tagSpacing),
                        Expanded(
                          child: Text(
                            h,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: bulletSize,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.fillHeight)
                  const Spacer()
                else
                  SizedBox(height: innerGap2),
                Wrap(
                  spacing: tagSpacing,
                  runSpacing: tagSpacing * 0.6,
                  children: project.tags
                      .map(
                        (t) => Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: tagSpacing,
                            vertical: tagSpacing * 0.4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Text(
                            t,
                            style: appPoppins(
                              fontSize: tagSize,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                SizedBox(height: innerGap1),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        project.ctaLabel,
                        key: Key('project-cta-${project.title}'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: appPoppins(
                          fontSize: taglineSize,
                          color: _hovered ? Colors.white : Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(width: tagSpacing),
                    Icon(
                      Icons.arrow_outward_rounded,
                      color: _hovered ? project.accentColor : Colors.grey[600],
                      size: openIconSize,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color accentColor;
  final double fontSize;
  final double hPad;
  final double vPad;

  const _StatusPill({
    required this.label,
    required this.accentColor,
    required this.fontSize,
    required this.hPad,
    required this.vPad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: appPoppins(
          fontSize: fontSize,
          color: accentColor,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MoreOnGitHubCard extends StatefulWidget {
  final Size media;
  final bool fillHeight;

  const _MoreOnGitHubCard({required this.media, this.fillHeight = false});

  @override
  State<_MoreOnGitHubCard> createState() => _MoreOnGitHubCardState();
}

class _MoreOnGitHubCardState extends State<_MoreOnGitHubCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Size media = widget.media;
    final double pad = (media.shortestSide * 0.035).clamp(16.0, 36.0);
    final double iconSize = (media.shortestSide * 0.042).clamp(22.0, 40.0);
    final double titleSize = (media.width * 0.022).clamp(15.0, 26.0);
    final double bodySize = (media.width * 0.014).clamp(11.0, 15.0);
    final double linkSize = (media.width * 0.0135).clamp(10.0, 14.0);
    final double gap1 = (media.height * 0.018).clamp(10.0, 22.0);
    final double gap2 = (media.height * 0.012).clamp(6.0, 14.0);

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.none,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => launchUrl(
            Uri.parse('https://github.com/SarthakGupta2912'),
            mode: LaunchMode.externalApplication,
          ),
          child: AnimatedContainer(
            key: const Key('project-card-github'),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            padding: EdgeInsets.all(pad),
            transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.015),
              borderRadius: BorderRadius.circular(
                (media.shortestSide * 0.018).clamp(8.0, 20.0),
              ),
              border: Border.all(
                color: _hovered
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: widget.fillHeight
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.center,
              mainAxisSize: widget.fillHeight
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.code_rounded,
                      color: _hovered ? Colors.white : Colors.grey[500],
                      size: iconSize,
                    ),
                    SizedBox(height: gap1),
                    Text(
                      'More on GitHub',
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: gap2),
                    Text(
                      'Game prototypes, AI experiments, and the rest of my builds live on my GitHub profile.',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: bodySize,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(top: gap1),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'github.com/SarthakGupta2912',
                          maxLines: 2,
                          style: appPoppins(
                            fontSize: linkSize,
                            color: _hovered ? Colors.white : Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(width: gap2),
                      Icon(
                        Icons.arrow_outward_rounded,
                        color: _hovered ? Colors.white : Colors.grey[600],
                        size: (media.shortestSide * 0.022).clamp(14.0, 22.0),
                      ),
                    ],
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

// ---------------------------------------------------------------------------
// Footer
// ---------------------------------------------------------------------------
class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final double fontSize = (media.shortestSide * 0.014).clamp(9.0, 14.0);
    final double gap1 = (media.height * 0.030).clamp(16.0, 40.0);
    final double gap2 = (media.height * 0.008).clamp(4.0, 12.0);
    final double gap3 = (media.height * 0.045).clamp(24.0, 60.0);

    return Column(
      children: [
        const Divider(color: Colors.white10),
        SizedBox(height: gap1),
        Text(
          'Designed and Engineered by Sarthak Gupta',
          style: appPoppins(fontSize: fontSize, color: Colors.grey[700]),
        ),
        SizedBox(height: gap2),
        Text(
          'MCA • Panjab University',
          style: appPoppins(fontSize: fontSize, color: Colors.grey[700]),
        ),
        SizedBox(height: gap1),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: (media.width * 0.014).clamp(10.0, 22.0),
          runSpacing: gap2,
          children: [
            _FooterLink(
              label: 'GitHub',
              url: 'https://github.com/SarthakGupta2912',
              fontSize: fontSize,
            ),
            _FooterLink(
              label: 'LinkedIn',
              url: 'https://www.linkedin.com/in/sarthakgupta2912/',
              fontSize: fontSize,
            ),
            _FooterLink(
              label: 'Email',
              url: 'mailto:sarthakgupta2912@gmail.com',
              fontSize: fontSize,
            ),
          ],
        ),
        SizedBox(height: gap3),
      ],
    );
  }
}

class _FooterLink extends StatefulWidget {
  final String label;
  final String url;
  final double fontSize;

  const _FooterLink({
    required this.label,
    required this.url,
    required this.fontSize,
  });

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse(widget.url),
          mode: LaunchMode.externalApplication,
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: appPoppins(
            fontSize: widget.fontSize,
            color: _hovered ? Colors.white : Colors.grey[600],
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}
