import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petcare_companion/main.dart';
import 'package:petcare_companion/models.dart';
import 'package:petcare_companion/storage.dart';

void main() {
  for (final size in [const Size(1440, 1100), const Size(390, 844)]) {
    testWidgets('Visual layout ${size.width.toInt()}px', (tester) async {
      final pet = Pet(
        id: 'demo',
        name: 'Nurmo',
        species: 'Cat',
        breed: 'Domestic shorthair',
        weight: 4.5,
      );
      final data = PetData(pets: [pet]);
      data.toggle(pet, DateTime.now(), 'Feeding');
      SharedPreferences.setMockInitialValues({LocalStore.key: data.encode()});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final regular = FontLoader('PetCare')
        ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
      final iconFont = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await regular.load();
      await iconFont.load();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: key, child: const PetCareApp()),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final ctx = tester.element(find.byType(Scaffold));
        for (final asset in ['assets/hero.png', 'assets/cat.png']) {
          await precacheImage(AssetImage(asset), ctx);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/qa/overview_${size.width.toInt()}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    });
  }
}
