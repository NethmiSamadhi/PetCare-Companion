import 'dart:convert';

String dayKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
const defaultTasks = [
  'Fresh water',
  'Feeding',
  'Activity and play',
  'Care observation',
];

class Pet {
  final String id;
  String name, species, breed, birthday, notes;
  double? weight;
  List<String> tasks;
  Pet({
    required this.id,
    required this.name,
    this.species = 'Dog',
    this.breed = '',
    this.birthday = '',
    this.weight,
    this.notes = '',
    List<String>? tasks,
  }) : tasks = tasks ?? List.of(defaultTasks);
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'species': species,
        'breed': breed,
        'birthday': birthday,
        'weight': weight,
        'notes': notes,
        'tasks': tasks,
      };
  factory Pet.fromJson(Map<String, dynamic> j) => Pet(
        id: j['id'] as String,
        name: j['name'] as String,
        species: j['species'] as String,
        breed: j['breed'] as String,
        birthday: j['birthday'] as String,
        weight: (j['weight'] as num?)?.toDouble(),
        notes: j['notes'] as String,
        tasks: List<String>.from(j['tasks'] as List),
      );
}

class CareRecord {
  final String id, petId;
  String title, date, nextDate, provider, notes, type;
  bool completed;
  CareRecord({
    required this.id,
    required this.petId,
    required this.title,
    required this.date,
    this.nextDate = '',
    this.provider = '',
    this.notes = '',
    this.type = 'Checkup',
    this.completed = false,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'petId': petId,
        'title': title,
        'date': date,
        'nextDate': nextDate,
        'provider': provider,
        'notes': notes,
        'type': type,
        'completed': completed,
      };
  factory CareRecord.fromJson(Map<String, dynamic> j) => CareRecord(
        id: j['id'] as String,
        petId: j['petId'] as String,
        title: j['title'] as String,
        date: j['date'] as String,
        nextDate: j['nextDate'] as String,
        provider: j['provider'] as String,
        notes: j['notes'] as String,
        type: j['type'] as String,
        completed: j['completed'] as bool,
      );
}

class PetData {
  List<Pet> pets;
  List<CareRecord> health, appointments;
  Map<String, List<String>> checks;
  PetData({
    List<Pet>? pets,
    List<CareRecord>? health,
    List<CareRecord>? appointments,
    Map<String, List<String>>? checks,
  })  : pets = pets ?? [],
        health = health ?? [],
        appointments = appointments ?? [],
        checks = checks ?? {};
  String encode() => const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'pets': pets.map((p) => p.toJson()).toList(),
        'health': health.map((r) => r.toJson()).toList(),
        'appointments': appointments.map((r) => r.toJson()).toList(),
        'checks': checks,
      });
  factory PetData.decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['version'] != 1) {
      throw const FormatException('Unsupported backup version.');
    }
    final data = PetData(
      pets: (j['pets'] as List)
          .map((p) => Pet.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      health: (j['health'] as List)
          .map((r) => CareRecord.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList(),
      appointments: (j['appointments'] as List)
          .map((r) => CareRecord.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList(),
      checks: (j['checks'] as Map).map(
        (k, v) => MapEntry(k as String, List<String>.from(v as List)),
      ),
    );
    final ids = data.pets.map((p) => p.id).toSet();
    if (ids.length != data.pets.length ||
        data.pets.any(
          (p) =>
              p.id.isEmpty ||
              p.id.contains('|') ||
              p.name.trim().isEmpty ||
              p.tasks.toSet().length != p.tasks.length ||
              p.tasks.any((t) => t.trim().isEmpty) ||
              (p.weight != null &&
                  (!p.weight!.isFinite || p.weight! <= 0 || p.weight! > 1000)),
        )) {
      throw const FormatException('Invalid pet data.');
    }
    for (final r in [...data.health, ...data.appointments]) {
      if (!ids.contains(r.petId) ||
          r.title.trim().isEmpty ||
          DateTime.tryParse(r.date) == null ||
          (r.nextDate.isNotEmpty && DateTime.tryParse(r.nextDate) == null)) {
        throw const FormatException('Invalid record data.');
      }
    }
    for (final p in data.pets) {
      if (p.birthday.isNotEmpty && DateTime.tryParse(p.birthday) == null) {
        throw const FormatException('Invalid birthday.');
      }
    }
    for (final r in data.appointments) {
      final date = DateTime.parse(r.date);
      if (date.year < 2000 || date.year > 2100) {
        throw const FormatException(
          'Appointment outside supported date range.',
        );
      }
      r.date = date.toIso8601String();
    }
    for (final r in data.health) {
      final date = DateTime.parse(r.date);
      if (date.year < 2000 || date.year > 2100) {
        throw const FormatException('Record outside supported date range.');
      }
      r.date = dayKey(date);
      if (r.nextDate.isNotEmpty) {
        final next = DateTime.parse(r.nextDate);
        if (next.year < 2000 ||
            next.year > 2100 ||
            next.isBefore(DateTime(date.year, date.month, date.day))) {
          throw const FormatException('Invalid next due date.');
        }
        r.nextDate = dayKey(next);
      }
    }
    for (final p in data.pets) {
      if (p.birthday.isNotEmpty) {
        final date = DateTime.parse(p.birthday);
        if (date.year < 1970 || date.isAfter(DateTime.now())) {
          throw const FormatException('Invalid birthday range.');
        }
        p.birthday = dayKey(date);
      }
    }
    return data;
  }
  List<String> done(Pet pet, DateTime date) =>
      checks['${dayKey(date)}|${pet.id}'] ?? [];
  void toggle(Pet pet, DateTime date, String task) {
    final key = '${dayKey(date)}|${pet.id}';
    final values = checks.putIfAbsent(key, () => []);
    if (values.contains(task)) {
      values.remove(task);
    } else {
      values.add(task);
    }
  }

  void deletePet(String id) {
    pets.removeWhere((p) => p.id == id);
    health.removeWhere((r) => r.petId == id);
    appointments.removeWhere((r) => r.petId == id);
    checks.removeWhere((key, _) => key.endsWith('|$id'));
  }
}
