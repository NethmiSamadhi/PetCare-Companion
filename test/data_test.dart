import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petcare_companion/models.dart';
import 'package:petcare_companion/storage.dart';

void main() {
  test(
    'Care completion is separate for each pet and day and survives reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      final first = Pet(id: '1', name: 'Nurmo', species: 'Cat');
      final second = Pet(id: '2', name: 'Buddy');
      final data = PetData(pets: [first, second]);
      final day = DateTime(2026, 10, 11);
      data.toggle(first, day, 'Feeding');
      await store.save(data);
      final loaded = store.load();
      expect(loaded.done(loaded.pets[0], day), ['Feeding']);
      expect(loaded.done(loaded.pets[1], day), isEmpty);
      expect(
        loaded.done(loaded.pets[0], day.add(const Duration(days: 1))),
        isEmpty,
      );
      loaded.toggle(loaded.pets[0], day, 'Feeding');
      expect(loaded.done(loaded.pets[0], day), isEmpty);
    },
  );
  test(
    'Deleting a pet removes only their associated records and care history',
    () {
      final data = PetData(
        pets: [
          Pet(id: '1', name: 'Nurmo'),
          Pet(id: '2', name: 'Buddy'),
        ],
        health: [
          CareRecord(id: 'h', petId: '1', title: 'Rabies', date: '2026-10-11'),
        ],
        appointments: [
          CareRecord(
            id: 'a',
            petId: '2',
            title: 'Checkup',
            date: '2026-10-20T10:00:00',
          ),
        ],
      );
      data.toggle(data.pets[0], DateTime(2026, 10, 11), 'Feeding');
      data.deletePet('1');
      expect(data.pets.single.id, '2');
      expect(data.health, isEmpty);
      expect(data.checks, isEmpty);
      expect(data.appointments.single.petId, '2');
    },
  );
  test('Backups round trip all record fields and reject damaged data', () {
    final p = Pet(
      id: '1',
      name: 'Nurmo',
      weight: 4.5,
      birthday: '2022-06-01',
      notes: 'Shy cat',
    );
    final data = PetData(
      pets: [p],
      health: [
        CareRecord(
          id: 'h',
          petId: '1',
          title: 'Vaccination',
          date: '2026-10-11',
          nextDate: '2027-10-11',
          provider: 'Vet',
          type: 'Vaccination',
        ),
      ],
    );
    expect(PetData.decode(data.encode()).encode(), data.encode());
    expect(() => PetData.decode('{"version": 2}'), throwsFormatException);
    expect(
      () => PetData.decode(
        data.encode().replaceFirst('"petId": "1"', '"petId": "missing"'),
      ),
      throwsFormatException,
    );
  });
}
