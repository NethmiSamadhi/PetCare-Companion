import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'storage.dart';

const ink = Color(0xFF24372F);
const green = Color(0xFF32644D);
const cream = Color(0xFFF7F6F0);
const peach = Color(0xFFF4D8C6);

// Wait for the closing animation before disposing form controllers.
Future<void> safeDialog(
    {required BuildContext context, required WidgetBuilder builder}) async {
  final route = DialogRoute<void>(context: context, builder: builder);
  await Navigator.of(context).push(route);
  await route.completed;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PetCareApp());
}

class PetCareApp extends StatelessWidget {
  const PetCareApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'PetCare Companion',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'PetCare',
          colorScheme: ColorScheme.fromSeed(seedColor: green, surface: cream),
          scaffoldBackgroundColor: cream,
          appBarTheme: const AppBarTheme(
            backgroundColor: cream,
            foregroundColor: ink,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.all(16),
          ),
          cardTheme: const CardThemeData(color: Colors.white, elevation: 0),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(color: ink, fontWeight: FontWeight.w800),
            headlineMedium: TextStyle(color: ink, fontWeight: FontWeight.w700),
            titleLarge: TextStyle(color: ink, fontWeight: FontWeight.w700),
          ),
        ),
        home: const HomeShell(),
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  LocalStore? store;
  PetData data = PetData();
  bool loading = true, saving = false;
  String? loadError, saveError, selectedPet;
  int page = 0, revision = 0;
  DateTime careDay = DateTime.now();
  String query = '';
  Future<void> saveQueue = Future.value();
  Timer? midnight;
  String lastDay = dayKey(DateTime.now());
  static const labels = [
    'Overview',
    'My pets',
    'Daily care',
    'Health records',
    'Appointments',
    'Settings',
  ];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.pets_outlined,
    Icons.checklist_rounded,
    Icons.favorite_border,
    Icons.calendar_month_outlined,
    Icons.settings_outlined,
  ];
  @override
  void initState() {
    super.initState();
    load();
    midnight = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {
          final today = dayKey(DateTime.now());
          if (today != lastDay && dayKey(careDay) == lastDay) {
            careDay = DateTime.now();
          }
          lastDay = today;
        });
      }
    });
  }

  @override
  void dispose() {
    midnight?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      store = await LocalStore.open();
      data = store!.load();
    } catch (_) {
      loadError =
          'Your saved data could not be opened. It has not been overwritten. Open Settings to copy the raw backup or restore a valid backup.';
    }
    if (mounted) setState(() => loading = false);
  }

  String id() => DateTime.now().microsecondsSinceEpoch.toString();
  Pet? get active => data.pets.isEmpty
      ? null
      : data.pets.firstWhere(
          (p) => p.id == selectedPet,
          orElse: () => data.pets.first,
        );
  Pet? petFor(String id) {
    for (final pet in data.pets) {
      if (pet.id == id) return pet;
    }
    return null;
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void change(VoidCallback action) {
    if (store == null) {
      message('Local storage is unavailable. Reload the app to try again.');
      return;
    }
    if (loadError != null) {
      message('Restore your saved data in Settings before making changes.');
      return;
    }
    setState(() {
      action();
      saving = true;
      saveError = null;
    });
    final snapshot = PetData.decode(data.encode());
    final current = ++revision;
    saveQueue = saveQueue.then((_) async {
      try {
        await store!.save(snapshot);
        if (mounted && revision == current) {
          setState(() {
            saving = false;
            saveError = null;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            saving = false;
            saveError =
                'Changes are not saved. Retry or copy a backup in Settings.';
          });
          message(saveError!);
        }
      }
    });
  }

  Future<bool> confirm(String title, String detail) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;
  Widget panel(Widget child, {Color color = Colors.white}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: ink.withValues(alpha: .06)),
        ),
        child: child,
      );
  Widget heading(String title, String subtitle, {Widget? action}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Color(0xFF6B7971))),
          if (action != null)
            Padding(padding: const EdgeInsets.only(top: 16), child: action),
        ],
      );
  Widget empty(
    String title,
    String subtitle,
    VoidCallback onTap,
    String button,
  ) =>
      panel(
        Column(
          children: [
            const Icon(Icons.pets, size: 52, color: green),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: onTap, child: Text(button)),
          ],
        ),
      );
  Widget petArt(Pet pet, {double size = 80}) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/${pet.species.toLowerCase() == 'cat' ? 'cat' : pet.species == 'Dog' ? 'dog' : 'other'}.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
  Widget pill(String text, {Color color = green}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.pets, color: green),
            SizedBox(width: 12),
            Text(
              'PetCare',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
          ],
        ),
        actions: [
          if (MediaQuery.sizeOf(context).width > 600)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Center(
                child: pill(
                  saving
                      ? 'Saving…'
                      : saveError != null || loadError != null
                          ? 'Storage needs attention'
                          : 'Saved on this device',
                ),
              ),
            ),
          if (MediaQuery.sizeOf(context).width <= 600)
            IconButton(
              tooltip: saving
                  ? 'Saving'
                  : saveError != null || loadError != null
                      ? 'Storage needs attention'
                      : 'Saved on this device',
              onPressed: () => setState(() => page = 5),
              icon: Icon(
                saveError != null || loadError != null
                    ? Icons.warning_amber
                    : Icons.cloud_off,
                color: green,
              ),
            ),
        ],
      ),
      drawer: wide ? null : Drawer(child: SafeArea(child: navigation())),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                if (wide) SizedBox(width: 242, child: navigation()),
                Expanded(
                  child: Column(
                    children: [
                      if (loadError != null || saveError != null)
                        MaterialBanner(
                          content: Text(loadError ?? saveError!),
                          actions: [
                            TextButton(
                              onPressed: () => setState(() => page = 5),
                              child: const Text('Open Settings'),
                            ),
                          ],
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(wide ? 36 : 20),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1120),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: KeyedSubtree(
                                  key: ValueKey(page),
                                  child: content(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget navigation() => Container(
        color: const Color(0xFFEEF1E9),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'A LITTLE CARE, EVERY DAY',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 18),
            ...List.generate(
              labels.length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: page == i ? green : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    selected: page == i,
                    selectedTileColor: green,
                    selectedColor: Colors.white,
                    leading: Icon(icons[i]),
                    title: Text(labels[i]),
                    onTap: () {
                      setState(() => page = i);
                      if (scaffoldKey.currentState?.isDrawerOpen ?? false) {
                        scaffoldKey.currentState?.closeDrawer();
                      }
                    },
                  ),
                ),
              ),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Little routines.\nHappier companions.',
                style: TextStyle(
                  color: green,
                  fontWeight: FontWeight.w700,
                  height: 1.7,
                ),
              ),
            ),
          ],
        ),
      );
  Widget content() {
    switch (page) {
      case 1:
        return petsPage();
      case 2:
        return carePage();
      case 3:
        return recordsPage(false);
      case 4:
        return recordsPage(true);
      case 5:
        return settingsPage();
      default:
        return overview();
    }
  }

  int completed(Pet p, DateTime day) =>
      p.tasks.where((t) => data.done(p, day).contains(t)).length;
  Widget overview() {
    final now = DateTime.now();
    final total = data.pets.fold<int>(0, (sum, p) => sum + p.tasks.length);
    final done = data.pets.fold<int>(0, (sum, p) => sum + completed(p, now));
    final upcoming = data.appointments
        .where((r) => !r.completed && !DateTime.parse(r.date).isBefore(now))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final due = data.health
        .where(
          (r) =>
              r.nextDate.isNotEmpty &&
              !DateTime.parse(
                r.nextDate,
              ).isAfter(now.add(const Duration(days: 30))),
        )
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          'Good days start with good care.',
          '${dayKey(now)}  •  Your companions, all in one place.',
        ),
        const SizedBox(height: 26),
        panel(
          LayoutBuilder(
            builder: (ctx, box) => Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      pill('MADE FOR YOUR LITTLE FAMILY'),
                      const SizedBox(height: 20),
                      const Text(
                        'Little routines.\nHappier companions.',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: ink,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Make room for the moments that matter.\nKeep everyday care beautifully organised.',
                        style: TextStyle(height: 1.6, color: ink),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: data.pets.isEmpty
                            ? () => editPet()
                            : () => setState(() => page = 2),
                        icon: const Icon(Icons.add),
                        label: Text(
                          data.pets.isEmpty
                              ? 'Meet your first companion'
                              : 'Open today’s care',
                        ),
                      ),
                    ],
                  ),
                ),
                if (box.maxWidth > 600)
                  Image.asset('assets/hero.png', width: 265, height: 250),
              ],
            ),
          ),
          color: peach,
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (ctx, box) {
            final width =
                box.maxWidth < 600 ? box.maxWidth : (box.maxWidth - 32) / 3;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                stat(
                  'Your companions',
                  '${data.pets.length}',
                  Icons.pets,
                  width,
                ),
                stat(
                  'Care completed today',
                  '$done / $total',
                  Icons.check_circle_outline,
                  width,
                ),
                stat(
                  'Health reminders ≤30 days',
                  '$due',
                  Icons.favorite_border,
                  width,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 30),
        heading(
          'Your companions',
          'A little attention goes a long way.',
          action: TextButton.icon(
            onPressed: () => editPet(),
            icon: const Icon(Icons.add),
            label: const Text('Add a pet'),
          ),
        ),
        const SizedBox(height: 16),
        if (data.pets.isEmpty)
          empty(
            'Your care story starts here',
            'Add your first pet to create their profile and daily checklist.',
            () => editPet(),
            'Add my first pet',
          )
        else
          petGrid(data.pets.take(3).toList()),
        const SizedBox(height: 30),
        heading('Next on the calendar', 'Appointments you have planned.'),
        const SizedBox(height: 16),
        if (upcoming.isEmpty)
          panel(
            const Text(
              'No upcoming appointments. Plan a visit from Appointments.',
            ),
          )
        else
          ...upcoming.take(3).map((r) => recordTile(r, true)),
      ],
    );
  }

  Widget stat(String label, String value, IconData icon, double width) =>
      SizedBox(
        width: width,
        child: panel(
          Row(
            children: [
              Icon(icon, size: 30, color: green),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7971),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  Widget petGrid(List<Pet> pets) => LayoutBuilder(
        builder: (ctx, box) {
          final columns = box.maxWidth > 850
              ? 3
              : box.maxWidth > 550
                  ? 2
                  : 1;
          final width = (box.maxWidth - 16 * (columns - 1)) / columns;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: pets
                .map(
                  (p) => SizedBox(
                    width: width,
                    child: panel(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              petArt(p),
                              const Spacer(),
                              PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'edit') {
                                    editPet(p);
                                  } else if (await confirm(
                                    'Delete ${p.name}?',
                                    'Their profile, care history, appointments and health records will also be deleted.',
                                  )) {
                                    change(() => data.deletePet(p.id));
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit profile'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete pet'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            p.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${p.species}${p.breed.isEmpty ? '' : ' • ${p.breed}'}',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (p.weight != null) pill('${p.weight} kg'),
                              if (p.birthday.isNotEmpty)
                                pill('Born ${p.birthday}'),
                            ],
                          ),
                          if (p.notes.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                p.notes,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          const SizedBox(height: 20),
                          Text(
                            '${completed(p, DateTime.now())} of ${p.tasks.length} care tasks today',
                            style: const TextStyle(fontSize: 12, color: green),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: p.tasks.isEmpty
                                ? 0
                                : completed(p, DateTime.now()) / p.tasks.length,
                            borderRadius: BorderRadius.circular(20),
                            minHeight: 6,
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => setState(() {
                              selectedPet = p.id;
                              page = 2;
                              careDay = DateTime.now();
                            }),
                            child: const Text('View daily care →'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      );
  Widget petsPage() {
    final filtered = data.pets
        .where(
          (p) => '${p.name} ${p.species} ${p.breed}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          'My pets',
          'Their personalities. Their routines. Their place.',
          action: FilledButton.icon(
            onPressed: () => editPet(),
            icon: const Icon(Icons.add),
            label: const Text('Add pet'),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search by name, species or breed',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 24),
        if (data.pets.isEmpty)
          empty(
            'Meet your first companion',
            'Start with a name. You can add more details later.',
            () => editPet(),
            'Add pet',
          )
        else if (filtered.isEmpty)
          panel(const Text('No pets match your search.'))
        else
          petGrid(filtered),
      ],
    );
  }

  Widget selector() => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: data.pets
            .map(
              (p) => ChoiceChip(
                avatar: const Icon(Icons.pets, size: 18),
                label: Text(p.name),
                selected: active?.id == p.id,
                onSelected: (_) => setState(() => selectedPet = p.id),
              ),
            )
            .toList(),
      );
  Widget carePage() {
    final p = active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          'Daily care',
          'Small habits, a happier companion.',
          action: OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: careDay,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => careDay = picked);
            },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(dayKey(careDay)),
          ),
        ),
        const SizedBox(height: 24),
        if (p == null)
          empty(
            'Add a pet to begin',
            'Each companion gets their own checklist.',
            () => editPet(),
            'Add pet',
          )
        else ...[
          selector(),
          const SizedBox(height: 24),
          panel(
            Row(
              children: [
                petArt(p),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p.name}’s daily rhythm',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${completed(p, careDay)} of ${p.tasks.length} tasks complete',
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: p.tasks.isEmpty
                            ? 0
                            : completed(p, careDay) / p.tasks.length,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            color: const Color(0xFFE6EFE7),
          ),
          const SizedBox(height: 20),
          panel(
            Column(
              children: [
                for (final task in p.tasks)
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(task),
                          controlAffinity: ListTileControlAffinity.leading,
                          value: data.done(p, careDay).contains(task),
                          onChanged: (_) =>
                              change(() => data.toggle(p, careDay, task)),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove task',
                        onPressed: () async {
                          if (await confirm('Remove this task?',
                              'Remove “$task” from ${p.name}’s daily checklist?')) {
                            change(() {
                              p.tasks.remove(task);
                              for (final entry in data.checks.entries
                                  .where((e) => e.key.endsWith('|${p.id}'))) {
                                entry.value.remove(task);
                              }
                            });
                          }
                        },
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                if (p.tasks.isEmpty)
                  const Text('No tasks yet. Add your first daily routine.'),
                const Divider(),
                TextButton.icon(
                  onPressed: () => addTask(p),
                  icon: const Icon(Icons.add),
                  label: const Text('Add custom task'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'A fresh checklist starts each day. Use the date button to view earlier days.',
            style: TextStyle(color: Color(0xFF6B7971)),
          ),
        ],
      ],
    );
  }

  Future<void> addTask(Pet p) async {
    final controller = TextEditingController();
    String? error;
    await safeDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Add a daily task'),
          content: TextField(
            controller: controller,
            maxLength: 60,
            decoration: InputDecoration(
              labelText: 'Task name',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty ||
                    p.tasks.any(
                      (t) => t.toLowerCase() == value.toLowerCase(),
                    )) {
                  update(() => error = 'Enter a unique task name.');
                  return;
                }
                change(() => p.tasks.add(value));
                Navigator.pop(ctx);
              },
              child: const Text('Add task'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Widget recordsPage(bool appointment) {
    final source = appointment ? data.appointments : data.health;
    final records = source.where((r) => r.petId == active?.id).toList()
      ..sort(
        (a, b) =>
            appointment ? a.date.compareTo(b.date) : b.date.compareTo(a.date),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          appointment ? 'Appointments' : 'Health records',
          appointment
              ? 'Make time for their next visit.'
              : 'Keep their care history close.',
          action: FilledButton.icon(
            onPressed: data.pets.isEmpty ? null : () => editRecord(appointment),
            icon: const Icon(Icons.add),
            label: Text(appointment ? 'Plan a visit' : 'Add record'),
          ),
        ),
        const SizedBox(height: 24),
        if (data.pets.isEmpty)
          empty(
            'Add a pet first',
            'Records and appointments belong to a companion.',
            () => editPet(),
            'Add pet',
          )
        else ...[
          selector(),
          const SizedBox(height: 24),
          if (records.isEmpty)
            panel(
              Text(
                appointment
                    ? 'No appointments for this companion yet.'
                    : 'No health records yet. Add vaccinations, checkups or treatment notes.',
              ),
            )
          else
            ...records.map((r) => recordTile(r, appointment)),
        ],
      ],
    );
  }

  Widget recordTile(CareRecord r, bool appointment) {
    final overdue = appointment
        ? !r.completed && DateTime.parse(r.date).isBefore(DateTime.now())
        : r.nextDate.isNotEmpty &&
            DateTime.parse(r.nextDate).isBefore(
              DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
              ),
            );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: peach,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    appointment ? Icons.calendar_month : Icons.favorite_border,
                    color: green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${petFor(r.petId)?.name ?? 'Pet'} • ${appointment ? r.date.replaceFirst('T', ' ').substring(0, 16) : r.date}',
                        style: const TextStyle(color: Color(0xFF6B7971)),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      editRecord(appointment, r);
                    } else if (await confirm(
                      'Delete this record?',
                      'This action removes “${r.title}”.',
                    )) {
                      change(
                        () => (appointment ? data.appointments : data.health)
                            .remove(r),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                pill(
                  appointment
                      ? r.completed
                          ? 'Completed'
                          : overdue
                              ? 'Past due'
                              : 'Scheduled'
                      : r.type,
                  color: overdue ? Colors.deepOrange : green,
                ),
                if (!appointment && r.nextDate.isNotEmpty)
                  pill(
                    '${overdue ? 'Overdue' : 'Next due'}: ${r.nextDate}',
                    color: overdue ? Colors.deepOrange : green,
                  ),
                if (r.provider.isNotEmpty) pill(r.provider),
              ],
            ),
            if (r.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(r.notes),
              ),
            if (appointment)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: () => change(() => r.completed = !r.completed),
                  icon: Icon(r.completed ? Icons.undo : Icons.check),
                  label: Text(
                    r.completed ? 'Mark as scheduled' : 'Mark completed',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> editPet([Pet? existing]) async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController(text: existing?.name ?? '');
    final breed = TextEditingController(text: existing?.breed ?? '');
    final weight = TextEditingController(
      text: existing?.weight?.toString() ?? '',
    );
    final notes = TextEditingController(text: existing?.notes ?? '');
    String species = existing?.species ?? 'Dog',
        birthday = existing?.birthday ?? '';
    await safeDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(
            existing == null ? 'Meet your companion' : 'Edit pet profile',
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    field(name, 'Pet name', required: true, max: 50),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: [
                        'Dog',
                        'Cat',
                        'Bird',
                        'Rabbit',
                        'Other',
                      ].contains(species)
                          ? species
                          : 'Other',
                      decoration: const InputDecoration(labelText: 'Species'),
                      items: ['Dog', 'Cat', 'Bird', 'Rabbit', 'Other']
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) => update(() => species = v!),
                    ),
                    const SizedBox(height: 16),
                    field(breed, 'Breed (optional)', max: 80),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: weight,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Weight in kg (optional)',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = double.tryParse(v);
                        return n == null || !n.isFinite || n <= 0 || n > 1000
                            ? 'Enter a weight between 0 and 1000 kg.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: ctx,
                                initialDate: birthday.isEmpty
                                    ? DateTime.now()
                                    : DateTime.parse(birthday),
                                firstDate: DateTime(1970),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                update(() => birthday = dayKey(date));
                              }
                            },
                            icon: const Icon(Icons.cake_outlined),
                            label: Text(
                              birthday.isEmpty
                                  ? 'Birthday (optional)'
                                  : birthday,
                            ),
                          ),
                        ),
                        if (birthday.isNotEmpty)
                          IconButton(
                            onPressed: () => update(() => birthday = ''),
                            icon: const Icon(Icons.clear),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    field(notes, 'Notes (optional)', lines: 3, max: 1000),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                final p = Pet(
                  id: existing?.id ?? id(),
                  name: name.text.trim(),
                  species: species,
                  breed: breed.text.trim(),
                  birthday: birthday,
                  weight: double.tryParse(weight.text.trim()),
                  notes: notes.text.trim(),
                  tasks: existing == null ? null : List.of(existing.tasks),
                );
                change(() {
                  if (existing == null) {
                    data.pets.add(p);
                  } else {
                    data.pets[data.pets.indexOf(existing)] = p;
                  }
                  selectedPet = p.id;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save pet'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    breed.dispose();
    weight.dispose();
    notes.dispose();
  }

  Widget field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int lines = 1,
    int max = 100,
  }) =>
      TextFormField(
        controller: controller,
        maxLines: lines,
        maxLength: max,
        decoration: InputDecoration(labelText: label, counterText: ''),
        validator: required
            ? (v) =>
                v == null || v.trim().isEmpty ? 'Please enter $label.' : null
            : null,
      );
  Future<void> editRecord(bool appointment, [CareRecord? existing]) async {
    if (active == null) return;
    final form = GlobalKey<FormState>();
    final title = TextEditingController(text: existing?.title ?? '');
    final provider = TextEditingController(text: existing?.provider ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    String petId = existing?.petId ?? active!.id,
        type = existing?.type ?? 'Checkup',
        next = existing?.nextDate ?? '';
    DateTime date = existing == null
        ? DateTime.now().add(const Duration(hours: 1))
        : DateTime.parse(existing.date);
    await safeDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(
            '${existing == null ? 'Add' : 'Edit'} ${appointment ? 'appointment' : 'health record'}',
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: petId,
                      decoration: const InputDecoration(labelText: 'Companion'),
                      items: data.pets
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => update(() => petId = v!),
                    ),
                    const SizedBox(height: 16),
                    field(
                      title,
                      appointment ? 'Visit title' : 'Record title',
                      required: true,
                    ),
                    const SizedBox(height: 16),
                    if (!appointment) ...[
                      DropdownButtonFormField<String>(
                        value: [
                          'Vaccination',
                          'Checkup',
                          'Treatment',
                          'Other',
                        ].contains(type)
                            ? type
                            : 'Other',
                        decoration: const InputDecoration(
                          labelText: 'Record type',
                        ),
                        items: ['Vaccination', 'Checkup', 'Treatment', 'Other']
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                        onChanged: (v) => update(() => type = v!),
                      ),
                      const SizedBox(height: 16),
                    ],
                    OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) {
                          update(() => date = DateTime(
                              d.year, d.month, d.day, date.hour, date.minute));
                        }
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: Text('Date: ${dayKey(date)}'),
                    ),
                    if (appointment)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.fromDateTime(date),
                          );
                          if (t != null) {
                            update(() => date = DateTime(date.year, date.month,
                                date.day, t.hour, t.minute));
                          }
                        },
                        icon: const Icon(Icons.schedule),
                        label: Text(
                          'Time: ${TimeOfDay.fromDateTime(date).format(ctx)}',
                        ),
                      ),
                    if (!appointment)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: ctx,
                                  initialDate: next.isEmpty
                                      ? date
                                      : DateTime.parse(next),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (d != null) update(() => next = dayKey(d));
                              },
                              child: Text(
                                next.isEmpty
                                    ? 'Next due date (optional)'
                                    : 'Next due: $next',
                              ),
                            ),
                          ),
                          if (next.isNotEmpty)
                            IconButton(
                              onPressed: () => update(() => next = ''),
                              icon: const Icon(Icons.clear),
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    field(provider, 'Clinic / veterinarian (optional)'),
                    const SizedBox(height: 16),
                    field(notes, 'Notes (optional)', lines: 3, max: 2000),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                if (!appointment &&
                    next.isNotEmpty &&
                    DateTime.parse(
                      next,
                    ).isBefore(DateTime(date.year, date.month, date.day))) {
                  message('Next due date must be on or after the record date.');
                  return;
                }
                final record = CareRecord(
                  id: existing?.id ?? id(),
                  petId: petId,
                  title: title.text.trim(),
                  date: appointment ? date.toIso8601String() : dayKey(date),
                  nextDate: next,
                  provider: provider.text.trim(),
                  notes: notes.text.trim(),
                  type: type,
                  completed: existing?.completed ?? false,
                );
                change(() {
                  final list = appointment ? data.appointments : data.health;
                  if (existing == null) {
                    list.add(record);
                  } else {
                    list[list.indexOf(existing)] = record;
                  }
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    provider.dispose();
    notes.dispose();
  }

  Widget settingsPage() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading(
              'Your data, your companion', 'Manage local storage and backups.'),
          const SizedBox(height: 24),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, size: 32, color: green),
                const SizedBox(height: 14),
                const Text(
                  'Saved on this device',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Profiles, checklists and records are saved locally. There is no account, cloud sync or MySQL server. Browser data can be cleared, so keep a backup. For Chrome, always use the same port and browser profile to keep the same storage.',
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () => backup(),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy / view backup'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => restore(),
                      icon: const Icon(Icons.restore),
                      label: const Text('Restore backup'),
                    ),
                    if (saveError != null)
                      OutlinedButton(
                        onPressed: () => change(() {}),
                        child: const Text('Retry save'),
                      ),
                    if (loadError != null)
                      OutlinedButton(
                        onPressed: () => backup(raw: true),
                        child: const Text('Copy unreadable saved data'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          panel(
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Care reminders',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 12),
                Text(
                  'Health due dates and appointment status appear inside the app. This version does not send phone notifications, emails or SMS.',
                ),
                SizedBox(height: 18),
                Text(
                  'About PetCare Companion',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 12),
                Text(
                  'Version 1.0.0 • Flutter + Dart\nA personal care planner. Keep vet instructions in your health notes. All dates and appointment times use your device’s local time.',
                ),
              ],
            ),
          ),
        ],
      );
  Future<void> backup({bool raw = false}) async {
    final text = raw
        ? store?.preferences.getString(LocalStore.key) ?? ''
        : data.encode();
    await safeDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your JSON backup'),
        content: SizedBox(
          width: 600,
          height: 350,
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: text));
                message(
                  'Backup copied. Paste it into a .json file and save it.',
                );
              } catch (_) {
                message(
                  'Clipboard unavailable. Select and copy the backup text manually.',
                );
              }
            },
            child: const Text('Copy backup'),
          ),
        ],
      ),
    );
  }

  Future<void> restore() async {
    if (store == null) {
      message('Storage is unavailable. Reload the app first.');
      return;
    }
    final controller = TextEditingController();
    String? error;
    await safeDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Restore a backup'),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This replaces all current pets and records. Copy a backup of your current data first.',
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  maxLines: 9,
                  decoration: InputDecoration(
                    labelText: 'Paste PetCare JSON backup',
                    errorText: error,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                PetData incoming;
                try {
                  incoming = PetData.decode(controller.text);
                } catch (_) {
                  update(
                    () => error =
                        'Invalid backup. Paste a complete PetCare v1 backup.',
                  );
                  return;
                }
                if (!await confirm('Replace all current data?',
                    'Restore ${incoming.pets.length} pets and their records from this backup?')) {
                  return;
                }
                await saveQueue;
                try {
                  await store!.save(incoming);
                } catch (_) {
                  update(() => error =
                      'Restore failed. Your current data is unchanged.');
                  return;
                }
                if (!mounted || !ctx.mounted) return;
                setState(() {
                  data = incoming;
                  selectedPet = null;
                  loadError = null;
                  saveError = null;
                  saving = false;
                });
                Navigator.pop(ctx);
                message('Backup restored.');
              },
              child: const Text('Restore'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }
}
