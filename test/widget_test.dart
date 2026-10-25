import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sarthak_portfolio/main.dart';

void _useSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('renders the hero and every featured build', (
    WidgetTester tester,
  ) async {
    _useSize(tester, const Size(1440, 900));

    await tester.pumpWidget(const SarthakPortfolio());
    await tester.pump();

    expect(find.text('Sarthak Gupta.', findRichText: true), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/hero_portrait.jpg')),
      findsOneWidget,
    );
    expect(find.text('Fridge Roulette'), findsOneWidget);
    expect(find.text('LIMS'), findsOneWidget);
    expect(find.text('PathKosh'), findsOneWidget);
    expect(find.text('More on GitHub'), findsOneWidget);
  });

  testWidgets('keeps the source link inside every project card', (
    WidgetTester tester,
  ) async {
    _useSize(tester, const Size(900, 1200));

    await tester.pumpWidget(const SarthakPortfolio());
    await tester.pump();

    final Finder footers = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.data == 'View source' ||
              widget.data == 'View on Google Play'),
    );
    expect(footers, findsNWidgets(3));

    for (int i = 0; i < 3; i++) {
      final Rect footerRect = tester.getRect(footers.at(i));
      final Rect cardRect = tester.getRect(
        find
            .ancestor(
              of: footers.at(i),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );

      expect(footerRect.bottom, lessThan(cardRect.bottom));
      expect(footerRect.right, lessThanOrEqualTo(cardRect.right));
    }
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
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Fridge Roulette'), findsOneWidget);
        expect(find.text('LIMS'), findsOneWidget);
      },
    );
  }
}
