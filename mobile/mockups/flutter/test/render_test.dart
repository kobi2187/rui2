// Renders every mockup screen to a PNG, at the phone size RUI uses, with real
// fonts (Roboto and the Material icons) instead of the test font.
//
//   RUI_FLUTTER_OUT=/some/dir flutter test test/render_test.dart
//
// Run by mobile/compare/render_flutter.sh, which finds the font files.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rui_mockups/screens.dart';

const phone = Size(360, 800);

Future<void> loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  final env = Platform.environment;
  final out = env['RUI_FLUTTER_OUT'] ?? 'build/mockups';

  setUpAll(() async {
    final roboto = env['RUI_ROBOTO_DIR'];
    if (roboto != null) {
      await loadFont('Roboto', [
        for (final w in ['Regular', 'Medium', 'Bold', 'Italic']) '$roboto/Roboto-$w.ttf'
      ]);
    }
    final icons = env['RUI_MATERIAL_ICONS'];
    if (icons != null) await loadFont('MaterialIcons', [icons]);
    Directory(out).createSync(recursive: true);
  });

  for (final entry in screens.entries) {
    testWidgets('render ${entry.key}', (tester) async {
      // flutter_test draws a black outline in place of every shadow unless told
      // otherwise; RUI draws real shadows, so Flutter must too.
      debugDisableShadows = false;
      tester.view.physicalSize = phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('shot'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: mockupTheme(),
          home: entry.value(),
        ),
      ));
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('shot')));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.0);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/${entry.key}.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
      debugDisableShadows = true; // the framework checks it is back as it was
    });
  }
}
