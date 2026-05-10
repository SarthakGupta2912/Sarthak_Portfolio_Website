import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const SarthakPortfolio());
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
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const PortfolioHome(),
    );
  }
}

// ---------------------------------------------------------------------------
// Responsive helpers – derive everything from MediaQuery.size
// ---------------------------------------------------------------------------

/// Returns a value clamped between [min] and [max], scaled by [factor] of
/// the screen's shorter dimension (width on portrait, height on landscape).
double _scaled(
  BuildContext context,
  double factor, {
  double min = 0,
  double max = double.infinity,
}) {
  final size = MediaQuery.of(context).size;
  return (size.shortestSide * factor).clamp(min, max);
}

/// True when the screen width is below 800 logical pixels.
bool _isMobile(BuildContext context) => MediaQuery.of(context).size.width < 800;

/// True when the sidebar (≥ 1200 px) should be shown.
bool _showSidebar(BuildContext context) =>
    MediaQuery.of(context).size.width >= 1200;

// ---------------------------------------------------------------------------
// Lens animation state
// ---------------------------------------------------------------------------
class LensAnimationState extends ChangeNotifier {
  Offset _smoothedPos = const Offset(-1000, -1000);
  Offset _targetPos = const Offset(-1000, -1000);
  bool isActive = true;

  List<_Dot> dots = [];
  bool _initialized = false;

  Offset get smoothedPos => _smoothedPos;

  void setTarget(Offset pos) {
    _targetPos = pos;
  }

  void resetGrid() {
    _initialized = false;
    dots.clear();
  }

  void initGrid(Size size, double spacing) {
    if (_initialized) return;
    _initialized = true;
    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        dots.add(_Dot(baseX: x, baseY: y, x: x, y: y));
      }
    }
  }

  bool tick() {
    final dx = _targetPos.dx - _smoothedPos.dx;
    final dy = _targetPos.dy - _smoothedPos.dy;

    const double kMovementThreshold = 0.3;
    final bool moving =
        dx.abs() > kMovementThreshold || dy.abs() > kMovementThreshold;

    _smoothedPos = Offset(
      _smoothedPos.dx + dx * 0.08,
      _smoothedPos.dy + dy * 0.08,
    );

    if (!isActive && !moving) return false;

    _updateDots();
    notifyListeners();
    return true;
  }

  void _updateDots() {
    const double radius = 220;
    const double radiusSq = radius * radius;

    for (final dot in dots) {
      final double dx = _smoothedPos.dx - dot.baseX;
      final double dy = _smoothedPos.dy - dot.baseY;
      final double distSq = dx * dx + dy * dy;

      double targetX = dot.baseX;
      double targetY = dot.baseY;
      double targetIntensity;

      if (isActive && distSq < radiusSq && distSq > 0) {
        final double dist = math.sqrt(distSq);
        final double t = (radius - dist) / radius;
        final double force = t * t * t;
        targetX -= (dx / dist) * force * 55;
        targetY -= (dy / dist) * force * 55;
        targetIntensity = 0.12 + force * 0.88;
      } else {
        targetIntensity = isActive ? 0.07 : 0.03;
      }

      dot.x += (targetX - dot.x) * 0.12;
      dot.y += (targetY - dot.y) * 0.12;
      dot.intensity += (targetIntensity - dot.intensity) * 0.18;
    }
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

  final GlobalKey _heroKey = GlobalKey();
  final GlobalKey _skillsKey = GlobalKey();
  final GlobalKey _experienceKey = GlobalKey();
  final GlobalKey _projectsKey = GlobalKey();

  String _activeTab = 'home';

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
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double triggerLine = screenHeight * 0.4;

    final heroY = _getY(_heroKey);
    final skillsY = _getY(_skillsKey);
    final expY = _getY(_experienceKey);
    final projY = _getY(_projectsKey);

    String newTab = _activeTab;

    if (projY != null && projY < triggerLine) {
      newTab = 'projects';
    } else if (expY != null && expY < triggerLine) {
      newTab = 'experience';
    } else if (skillsY != null && skillsY < triggerLine) {
      newTab = 'skills';
    } else if (heroY != null && heroY < triggerLine) {
      newTab = 'home';
    }

    if (newTab != _activeTab) {
      setState(() => _activeTab = newTab);
    }
  }

  double? _getY(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final RenderBox? box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  void _scrollTo(GlobalKey key, String tab) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _activeTab = tab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final bool isMobile = media.width < 800;
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
          _mouseNotifier.value = event.position;
          _lensState.setTarget(event.position);
        },
        onPointerMove: (event) {
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
                        HeroSection(
                          key: _heroKey,
                          lensState: _lensState,
                          media: media,
                        ),
                        SizedBox(height: sectionGap),
                        SkillsSection(key: _skillsKey, media: media),
                        SizedBox(height: sectionGap),
                        ExperienceSection(key: _experienceKey, media: media),
                        SizedBox(height: sectionGap),
                        ProjectsSection(key: _projectsKey, media: media),
                        SizedBox(height: sectionGap * 0.75),
                        const Footer(),
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _NavButton(
                          label: '01. Intro',
                          isActive: _activeTab == 'home',
                          onTap: () => _scrollTo(_heroKey, 'home'),
                        ),
                        SizedBox(
                          height: (media.height * 0.025).clamp(12.0, 32.0),
                        ),
                        _NavButton(
                          label: '02. Skills',
                          isActive: _activeTab == 'skills',
                          onTap: () => _scrollTo(_skillsKey, 'skills'),
                        ),
                        SizedBox(
                          height: (media.height * 0.025).clamp(12.0, 32.0),
                        ),
                        _NavButton(
                          label: '03. Experience',
                          isActive: _activeTab == 'experience',
                          onTap: () => _scrollTo(_experienceKey, 'experience'),
                        ),
                        SizedBox(
                          height: (media.height * 0.025).clamp(12.0, 32.0),
                        ),
                        _NavButton(
                          label: '04. Projects',
                          isActive: _activeTab == 'projects',
                          onTap: () => _scrollTo(_projectsKey, 'projects'),
                        ),
                      ],
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
                    return Transform.translate(
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
                                  color: Colors.white.withOpacity(0.3),
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
  late Ticker _ticker;
  Size _lastSize = Size.zero; // ← track previous layout size

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => widget.lensState.tick());
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final double spacing = (media.shortestSide * 0.04).clamp(28.0, 70.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final Size currentSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        // Reset grid whenever the available size changes (zoom, resize, etc.)
        if (currentSize != _lastSize) {
          _lastSize = currentSize;
          // Schedule after layout to avoid mutating state mid-build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.lensState.resetGrid();
            widget.lensState.initGrid(currentSize, spacing);
          });
        }

        return SizedBox(
          width: currentSize.width,
          height: currentSize.height,
          child: CustomPaint(painter: LensPainter(repaint: widget.lensState)),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------
class _Dot {
  final double baseX;
  final double baseY;
  double x;
  double y;
  double intensity = 0.03;

  _Dot({
    required this.baseX,
    required this.baseY,
    required this.x,
    required this.y,
  });
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------
class LensPainter extends CustomPainter {
  final LensAnimationState repaint;

  LensPainter({required this.repaint}) : super(repaint: repaint);

  static final Paint _paint = Paint()..style = PaintingStyle.fill;
  static const double _dotRadius = 1.5;
  static const double _radiusThreshold = 220;
  static const double _radiusThresholdSq = _radiusThreshold * _radiusThreshold;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset mouse = repaint.smoothedPos;
    final bool active = repaint.isActive;

    for (final dot in repaint.dots) {
      final double dx = mouse.dx - dot.baseX;
      final double dy = mouse.dy - dot.baseY;
      final bool inRadius = active && (dx * dx + dy * dy) < _radiusThresholdSq;

      _paint.color = (inRadius ? const Color(0xFF00E5FF) : Colors.white)
          .withOpacity(dot.intensity.clamp(0.0, 1.0));

      canvas.drawCircle(Offset(dot.x, dot.y), _dotRadius, _paint);
    }
  }

  @override
  bool shouldRepaint(LensPainter old) => !identical(old.repaint, repaint);
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
                  style: GoogleFonts.poppins(
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
  final LensAnimationState lensState;
  final Size media;

  const HeroSection({super.key, required this.lensState, required this.media});

  @override
  Widget build(BuildContext context) {
    final bool isMobile = media.width < 800;

    // Responsive font sizes – clamp ensures nothing breaks at extremes
    final double nameFontSize = (media.width * 0.075).clamp(28.0, 90.0);
    final double subtitleFontSize = (media.width * 0.026).clamp(14.0, 32.0);
    final double badgeFontSize = (media.shortestSide * 0.014).clamp(9.0, 14.0);
    final double badgeIconSize = (media.shortestSide * 0.014).clamp(9.0, 16.0);
    final double badgeHPad = (media.width * 0.010).clamp(8.0, 16.0);
    final double badgeVPad = (media.height * 0.006).clamp(4.0, 10.0);
    final double badgeSpacing = (media.width * 0.012).clamp(6.0, 16.0);
    final double gap1 = (media.height * 0.030).clamp(16.0, 40.0);
    final double gap2 = (media.height * 0.025).clamp(14.0, 32.0);
    final double gap3 = (media.height * 0.045).clamp(24.0, 60.0);
    final double btnHPad = (media.width * 0.020).clamp(12.0, 28.0);
    final double btnVPad = (media.height * 0.018).clamp(10.0, 22.0);
    final double socialIconSize = (media.shortestSide * 0.028).clamp(
      18.0,
      30.0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: badgeSpacing,
          runSpacing: badgeSpacing * 0.6,
          children: [
            _Badge(
              hPad: badgeHPad,
              vPad: badgeVPad,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: badgeIconSize * 0.55,
                    height: badgeIconSize * 0.55,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E5FF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: badgeHPad * 0.65),
                  Text(
                    'Available for Opportunities',
                    style: GoogleFonts.poppins(
                      fontSize: badgeFontSize,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            ListenableBuilder(
              listenable: lensState,
              builder: (_, __) => GestureDetector(
                onTap: () {
                  lensState.isActive = !lensState.isActive;
                  lensState.notifyListeners();
                },
                child: _Badge(
                  hPad: badgeHPad,
                  vPad: badgeVPad,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        lensState.isActive
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: badgeIconSize,
                        color: Colors.grey[400],
                      ),
                      SizedBox(width: badgeHPad * 0.65),
                      Text(
                        'Toggle Lens Illusion',
                        style: GoogleFonts.poppins(
                          fontSize: badgeFontSize,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: gap1),
        Text(
          'Sarthak Gupta.',
          style: TextStyle(
            fontSize: nameFontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: nameFontSize * -0.025,
            height: 1.0,
            color: Colors.white,
          ),
        ),
        SizedBox(height: gap2),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: subtitleFontSize,
              color: Colors.grey[400],
              fontWeight: FontWeight.w300,
              height: 1.4,
            ),
            children: const [
              TextSpan(
                text:
                    'I engineer scalable applications and immersive experiences across ',
              ),
              TextSpan(
                text: 'Mobile, Web, and Game engines.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: gap3),
        Wrap(
          spacing: (media.width * 0.020).clamp(12.0, 28.0),
          runSpacing: (media.height * 0.016).clamp(10.0, 20.0),
          children: [
            // ── Get in Touch ────────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: () =>
                  launchUrl(Uri.parse('mailto:sarthakgupta2912@gmail.com')),
              icon: Icon(
                Icons.mail_outline_rounded,
                size: (media.shortestSide * 0.022).clamp(14.0, 22.0),
              ),
              label: Text(
                'Get in Touch',
                style: TextStyle(
                  fontSize: (media.shortestSide * 0.016).clamp(11.0, 16.0),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(
                  horizontal: btnHPad,
                  vertical: btnVPad,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // ── Resume Download ─────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(
                  'https://drive.google.com/file/d/1oTVVP0BWlnSpawTK0GNRwbL3xR1U5-ns/view?usp=sharing',
                ),
                mode: LaunchMode.externalApplication,
              ),
              icon: Icon(
                Icons.file_download_outlined,
                size: (media.shortestSide * 0.022).clamp(14.0, 22.0),
              ),
              label: Text(
                'Resume',
                style: TextStyle(
                  fontSize: (media.shortestSide * 0.016).clamp(11.0, 16.0),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(
                  horizontal: btnHPad,
                  vertical: btnVPad,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // ── Social icons ────────────────────────────────────────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SocialIconButton(
                  icon: Icons.code_rounded,
                  iconSize: socialIconSize,
                  tooltip: 'GitHub',
                  onTap: () => launchUrl(
                    Uri.parse('https://github.com/SarthakGupta2912'),
                  ),
                ),
                SizedBox(width: (media.width * 0.006).clamp(4.0, 10.0)),
                _SocialIconButton(
                  icon: Icons.work_outline_rounded,
                  iconSize: socialIconSize,
                  tooltip: 'LinkedIn',
                  onTap: () => launchUrl(
                    Uri.parse('https://www.linkedin.com/in/sarthakgupta2912/'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final Widget child;
  final double hPad;
  final double vPad;

  const _Badge({required this.child, required this.hPad, required this.vPad});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String tooltip;
  final VoidCallback onTap;

  const _SocialIconButton({
    required this.icon,
    required this.iconSize,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.grey[400], size: iconSize),
        hoverColor: Colors.white.withOpacity(0.05),
        splashRadius: iconSize,
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
            final bool isMobile = availableWidth <= 800;
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
              title: 'Mobile & Web',
              skills: const [
                'Flutter & Dart',
                'Android & iOS',
                'Firebase & REST APIs',
                'Payment Integration',
              ],
            );
            final c1 = buildCard(
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
            final c2 = buildCard(
              icon: Icons.terminal_rounded,
              iconColor: Colors.grey,
              title: 'Core Languages',
              skills: const [
                'Java & C/C++',
                'Data Structures',
                'Problem Solving',
                'SQL / MySQL',
              ],
            );
            final c3 = buildCard(
              icon: Icons.psychology_rounded,
              iconColor: const Color(0xFFFFB347),
              title: 'AI & ML',
              skills: const [
                'LLM Integration',
                'RAG Systems',
                'Model Fine-tuning',
                'Model Context Protocol (MCP)',
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

            // Desktop — Expanded handles all width math, overflow is impossible
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: all three cards, equal width via Expanded
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: c0),
                      SizedBox(width: cardSpacing),
                      Expanded(child: c1),
                      SizedBox(width: cardSpacing),
                      Expanded(child: c2),
                    ],
                  ),
                ),

                SizedBox(height: cardSpacing),

                // Row 2: invisible Expanded spacer + card[3] + invisible Expanded spacer
                // This keeps card[3] centred under card[1] at exactly 1/3 width
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(child: SizedBox.shrink()), // col 0 ghost
                      SizedBox(width: cardSpacing),
                      Expanded(child: c3), // col 1 = under c1
                      SizedBox(width: cardSpacing),
                      const Expanded(child: SizedBox.shrink()), // col 2 ghost
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
                  ? Colors.white.withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
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
                          style: GoogleFonts.poppins(
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
              left: BorderSide(color: Colors.white.withOpacity(0.1)),
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
                          style: GoogleFonts.poppins(
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
                          style: GoogleFonts.poppins(
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

    // Card width: roughly half the content area on wide screens, nearly full on narrow
    final double cardWidth = media.width > 800
        ? (media.width * 0.38).clamp(280.0, 460.0)
        : (media.width * 0.82).clamp(260.0, 500.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(number: '04', title: 'Selected Builds', media: media),
        SizedBox(height: headerGap),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProjectCard(
                title: 'LIMS Application',
                description:
                    'Localized Invoice Management System. A highly responsive desktop application built with Flutter featuring offline data storage and automated PDF invoice generation.',
                tags: const ['Flutter', 'Dart', 'Desktop Dev'],
                accentColor: const Color(0xFF00E5FF),
                icon: Icons.code_rounded,
                link: 'https://github.com/SarthakGupta2912/LIMS',
                media: media,
                cardWidth: cardWidth,
              ),
              SizedBox(width: cardSpacing),
              ProjectCard(
                title: 'Hardware-Integrated Cart',
                description:
                    'A software ordering application showcasing unique hardware integration, capable of validating customer transactions securely via OTP using a physical GSM modem.',
                tags: const ['Java', 'MySQL', 'GSM Hardware API'],
                accentColor: Colors.purpleAccent,
                icon: Icons.layers_rounded,
                link: 'https://github.com/SarthakGupta2912/ShoppingCart',
                media: media,
                cardWidth: cardWidth,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ProjectCard extends StatefulWidget {
  final String title;
  final String description;
  final List<String> tags;
  final Color accentColor;
  final IconData icon;
  final String link;
  final Size media;
  final double cardWidth; // ← new

  const ProjectCard({
    super.key,
    required this.title,
    required this.description,
    required this.tags,
    required this.accentColor,
    required this.icon,
    required this.link,
    required this.media,
    required this.cardWidth, // ← new
  });

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Size media = widget.media;
    final double pad = (media.shortestSide * 0.035).clamp(16.0, 40.0);
    final double iconSize = (media.shortestSide * 0.042).clamp(22.0, 44.0);
    final double openIconSize = (media.shortestSide * 0.022).clamp(14.0, 24.0);
    final double titleSize = (media.width * 0.022).clamp(15.0, 28.0);
    final double descSize = (media.width * 0.014).clamp(11.0, 16.0);
    final double tagSize = (media.shortestSide * 0.012).clamp(9.0, 13.0);
    final double innerGap1 = (media.height * 0.022).clamp(12.0, 28.0);
    final double innerGap2 = (media.height * 0.016).clamp(8.0, 20.0);
    final double innerGap3 = (media.height * 0.022).clamp(12.0, 28.0);
    final double tagSpacing = (media.width * 0.010).clamp(6.0, 14.0);
    final double borderRadius = (media.shortestSide * 0.018).clamp(8.0, 20.0);

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.none,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => launchUrl(Uri.parse(widget.link)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: widget.cardWidth, // ← explicit width, no aspect ratio needed
            padding: EdgeInsets.all(pad),
            transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0C),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: _hovered
                    ? Colors.white.withOpacity(0.15)
                    : Colors.white.withOpacity(0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // ← shrink-wraps height naturally
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      widget.icon,
                      color: widget.accentColor,
                      size: iconSize,
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      color: _hovered ? widget.accentColor : Colors.grey[600],
                      size: openIconSize,
                    ),
                  ],
                ),
                SizedBox(height: innerGap1),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: _hovered ? widget.accentColor : Colors.white,
                  ),
                  child: Text(widget.title),
                ),
                SizedBox(height: innerGap2),
                Text(
                  widget.description,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: descSize,
                    height: 1.6,
                  ),
                ),
                SizedBox(height: innerGap3),
                Wrap(
                  spacing: tagSpacing,
                  runSpacing: tagSpacing * 0.6,
                  children: widget.tags
                      .map(
                        (t) => Text(
                          t,
                          style: GoogleFonts.poppins(
                            fontSize: tagSize,
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                      .toList(),
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
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: gap2),
        Text(
          'MCA • Panjab University',
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: gap3),
      ],
    );
  }
}
