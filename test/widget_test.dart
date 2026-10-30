import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sarthak_portfolio/main.dart';

void _useSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _useTextScale(WidgetTester tester, double scale) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void _expectCardsContained(WidgetTester tester) {
  for (final String title in const ['Fridge Roulette', 'LIMS', 'PathKosh']) {
    final Finder card = find.byKey(Key('project-card-$title'));
    final Finder cta = find.byKey(Key('project-cta-$title'));

    expect(card, findsOneWidget, reason: '$title card should exist');
    expect(cta, findsOneWidget, reason: '$title CTA should exist');

    final Rect cardRect = tester.getRect(card);
    final Rect ctaRect = tester.getRect(cta);

    expect(
      ctaRect.bottom,
      lessThanOrEqualTo(cardRect.bottom),
      reason: '$title CTA must stay inside the card vertically',
    );
    expect(
      ctaRect.right,
      lessThanOrEqualTo(cardRect.right),
      reason: '$title CTA must stay inside the card horizontally',
    );
    expect(
      ctaRect.left,
      greaterThanOrEqualTo(cardRect.left),
      reason: '$title CTA must not spill left of the card',
    );
  }
}

void main() {
  testWidgets('renders the hero and every featured build', (
    WidgetTester tester,
  ) async {
    _useSize(tester, const Size(1440, 900));

    await tester.pumpWidget(const SarthakPortfolio());
    await tester.pumpAndSettle();

    expect(find.text('Sarthak Gupta.', findRichText: true), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Fridge Roulette'), findsOneWidget);
    expect(find.text('LIMS'), findsOneWidget);
    expect(find.text('PathKosh'), findsOneWidget);
    expect(find.text('More on GitHub'), findsOneWidget);
    expect(find.text('Unity algorithm visualizers'), findsOneWidget);
    expect(find.text('DSA & core coding'), findsOneWidget);
  });

  testWidgets('has no idle animations after the page settles', (
    WidgetTester tester,
  ) async {
    _useSize(tester, const Size(1440, 900));

    await tester.pumpWidget(const SarthakPortfolio());
    await tester.pumpAndSettle();

    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('keeps both hero pills at the same height', (
    WidgetTester tester,
  ) async {
    _useSize(tester, const Size(1440, 900));

    await tester.pumpWidget(const SarthakPortfolio());
    await tester.pumpAndSettle();

    final Rect availability = tester.getRect(
      find.byKey(const Key('hero-availability-pill')),
    );
    final Rect lens = tester.getRect(find.byKey(const Key('hero-lens-pill')));

    expect(availability.height, lens.height);
    expect(availability.width, moreOrLessEquals(lens.width));
    expect(
      availability.top,
      lens.top,
      reason: 'both pills should stay on one row on desktop',
    );
  });

  test('lens illusion starts enabled', () {
    final LensAnimationState lens = LensAnimationState();
    addTearDown(lens.dispose);

    expect(lens.isActive, isTrue);
  });

  testWidgets('lens toggle settles without leaving a running animation', (
    WidgetTester tester,
  ) async {
    _useSize(tester, const Size(1440, 900));

    await tester.pumpWidget(const SarthakPortfolio());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('hero-lens-pill')));
    await tester.pump();

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: const Offset(700, 450));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(const Offset(720, 470));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('highlights the active section after a long scroll', (
    WidgetTester tester,
  ) async {
    _useSize(tester, const Size(1440, 900));

    await tester.pumpWidget(const SarthakPortfolio());
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -4200),
    );
    await tester.pumpAndSettle();

    final Text projectsNav = tester.widget<Text>(find.text('04. Projects'));
    expect(projectsNav.style?.color, const Color(0xFF00E5FF));
  });

  testWidgets('does not flicker the nav around a section boundary', (
    WidgetTester tester,
  ) async {
    _useSize(tester, const Size(1440, 900));

    await tester.pumpWidget(const SarthakPortfolio());
    await tester.pumpAndSettle();

    final RenderBox skillsHeader = tester.renderObject<RenderBox>(
      find.text('02. Arsenal'),
    );
    final double skillsOffset = RenderAbstractViewport.of(
      skillsHeader,
    ).getOffsetToReveal(skillsHeader, 0.0).offset;
    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable),
    );
    final double threshold =
        skillsOffset - scrollable.position.viewportDimension * 0.4;

    Color navColor(String label) =>
        tester.widget<Text>(find.text(label)).style!.color!;

    scrollable.position.jumpTo(threshold - 10);
    await tester.pump();
    expect(navColor('01. Intro'), const Color(0xFF00E5FF));

    scrollable.position.jumpTo(threshold + 10);
    await tester.pump();
    expect(navColor('01. Intro'), const Color(0xFF00E5FF));

    scrollable.position.jumpTo(threshold + 40);
    await tester.pump();
    expect(navColor('02. Skills'), const Color(0xFF00E5FF));

    scrollable.position.jumpTo(threshold + 10);
    await tester.pump();
    expect(navColor('02. Skills'), const Color(0xFF00E5FF));

    scrollable.position.jumpTo(threshold - 40);
    await tester.pump();
    expect(navColor('01. Intro'), const Color(0xFF00E5FF));
  });

  testWidgets('keeps a tapped nav target active during its scroll', (
    WidgetTester tester,
  ) async {
    _useSize(tester, const Size(1440, 900));

    await tester.pumpWidget(const SarthakPortfolio());
    await tester.pumpAndSettle();

    await tester.tap(find.text('04. Projects'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final Text projectsNav = tester.widget<Text>(find.text('04. Projects'));
    expect(projectsNav.style?.color, const Color(0xFF00E5FF));

    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('04. Projects')).style?.color,
      const Color(0xFF00E5FF),
    );
  });

  testWidgets('pins the project CTAs to the bottom of their cards', (
    WidgetTester tester,
  ) async {
    _useSize(tester, const Size(1440, 900));

    await tester.pumpWidget(const SarthakPortfolio());
    await tester.pumpAndSettle();

    final Rect first = tester.getRect(
      find.byKey(const Key('project-cta-Fridge Roulette')),
    );
    final Rect second = tester.getRect(
      find.byKey(const Key('project-cta-LIMS')),
    );

    expect((first.bottom - second.bottom).abs(), lessThan(1.0));
    _expectCardsContained(tester);
  });

  for (final Size size in const [
    Size(360, 800),
    Size(768, 1024),
    Size(1440, 900),
  ]) {
    testWidgets(
      'lays out without overflow at ${size.width.toInt()}x${size.height.toInt()}',
      (WidgetTester tester) async {
        _useSize(tester, size);

        await tester.pumpWidget(const SarthakPortfolio());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Fridge Roulette'), findsOneWidget);
        expect(find.text('LIMS'), findsOneWidget);
        _expectCardsContained(tester);
      },
    );
  }

  for (final Size size in const [Size(900, 1200), Size(1100, 900)]) {
    testWidgets(
      'keeps card content inside at ${size.width.toInt()}px and 160% text',
      (WidgetTester tester) async {
        _useSize(tester, size);
        _useTextScale(tester, 1.6);

        await tester.pumpWidget(const SarthakPortfolio());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        _expectCardsContained(tester);
      },
    );
  }

  testWidgets('eases wheel scrolling instead of jumping', (
    WidgetTester tester,
  ) async {
    _useSize(tester, const Size(1440, 900));

    await tester.pumpWidget(const SarthakPortfolio());
    await tester.pumpAndSettle();

    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable),
    );

    final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(const Offset(720, 450)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 300)));
    await tester.pump(const Duration(milliseconds: 16));

    final double partial = scrollable.position.pixels;
    expect(partial, greaterThan(0.0));
    expect(partial, lessThan(300.0));

    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, closeTo(300.0, 0.5));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reveals project cards as they enter the viewport', (
    WidgetTester tester,
  ) async {
    _useSize(tester, const Size(1440, 900));

    await tester.pumpWidget(const SarthakPortfolio());
    await tester.pumpAndSettle();

    final Finder card = find.byKey(const Key('project-card-Fridge Roulette'));
    final Finder opacity = find.ancestor(
      of: card,
      matching: find.byType(Opacity),
    );

    expect(opacity, findsOneWidget);
    expect(tester.widget<Opacity>(opacity).opacity, 0.0);

    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable),
    );
    scrollable.position.jumpTo(2500);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final double partial = tester.widget<Opacity>(opacity).opacity;
    expect(partial, greaterThan(0.0));
    expect(partial, lessThan(1.0));

    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(opacity).opacity, 1.0);
  });

  testWidgets('reveals the footer at the bottom of the page', (
    WidgetTester tester,
  ) async {
    _useSize(tester, const Size(1440, 900));

    await tester.pumpWidget(const SarthakPortfolio());
    await tester.pumpAndSettle();

    final Finder footer = find.text('Designed and Engineered by Sarthak Gupta');
    final Finder opacity = find.ancestor(
      of: footer,
      matching: find.byType(Opacity),
    );

    expect(opacity, findsOneWidget);
    expect(tester.widget<Opacity>(opacity).opacity, 0.0);

    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable),
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(tester.widget<Opacity>(opacity).opacity, 1.0);
  });

  testWidgets('reveals content as it scrolls into view', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 1600),
                ScrollReveal(
                  child: SizedBox(
                    key: Key('reveal-target'),
                    width: 120,
                    height: 120,
                    child: ColoredBox(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Finder target = find.byKey(const Key('reveal-target'));
    final Finder opacity = find.ancestor(
      of: target,
      matching: find.byType(Opacity),
    );

    expect(opacity, findsOneWidget);
    expect(tester.widget<Opacity>(opacity).opacity, 0.0);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -1400),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<Opacity>(opacity).opacity, 1.0);
  });
}
