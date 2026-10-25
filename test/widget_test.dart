import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sarthak_portfolio/main.dart';

void main() {
  testWidgets('renders the hero and every featured build', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const SarthakPortfolio());
    await tester.pump();

    expect(find.text('Sarthak Gupta.'), findsOneWidget);
    expect(find.text('Fridge Roulette'), findsOneWidget);
    expect(find.text('LIMS'), findsOneWidget);
    expect(find.text('PathKosh'), findsOneWidget);
    expect(find.text('More on GitHub'), findsOneWidget);
  });

  testWidgets('keeps the source link inside every project card', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(const SarthakPortfolio());
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Fridge Roulette'), findsOneWidget);
        expect(find.text('LIMS'), findsOneWidget);
      },
    );
  }
}
