import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petcare_companion/main.dart';
import 'package:petcare_companion/models.dart';
import 'package:petcare_companion/storage.dart';

void main() {
  testWidgets('Add a pet, open checklist, complete a task on mobile', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const PetCareApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meet your first companion'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Nurmo');
    await tester.tap(find.text('Save pet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open today’s care'));
    await tester.pumpAndSettle();
    expect(find.text('Nurmo’s daily rhythm'), findsOneWidget);
    await tester.ensureVisible(find.text('Feeding'));
    await tester.tap(find.text('Feeding'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 4 tasks complete'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Desktop overview renders without overflow and navigation works',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const PetCareApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('My pets'));
      await tester.pumpAndSettle();
      expect(find.text('Search by name, species or breed'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Health and appointment forms save and close safely',
      (tester) async {
    final initial = PetData(pets: [Pet(id: 'pet', name: 'Nurmo')]);
    SharedPreferences.setMockInitialValues({LocalStore.key: initial.encode()});
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const PetCareApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Health records'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add record'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'Annual vaccination');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Annual vaccination'), findsOneWidget);
    await tester.tap(find.text('Appointments'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan a visit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Vet checkup');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Vet checkup'), findsOneWidget);
    await tester.tap(find.text('Mark completed'));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
    final stored = (await LocalStore.open()).load();
    expect(stored.health.single.title, 'Annual vaccination');
    expect(stored.appointments.single.completed, true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
