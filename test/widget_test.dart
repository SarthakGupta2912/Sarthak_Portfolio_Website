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
    expect(find.text('Hardware-Integrated Cart'), findsOneWidget);
    expect(find.text('More on GitHub'), findsOneWidget);
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
