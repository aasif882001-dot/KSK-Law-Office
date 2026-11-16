import 'package:flutter/material.dart';

void main() => runApp(const KskLawOfficeApp());

const navy = Color(0xFF173F73);
const blue = Color(0xFF2468B2);
const paleBlue = Color(0xFFEAF2FB);

class KskLawOfficeApp extends StatelessWidget {
  const KskLawOfficeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KSK Law Office',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: blue, primary: navy),
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: navy),
        cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE3EAF2)))),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD8E2EF))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD8E2EF))),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

enum UserRole { admin, advocate }
enum TaskStatus { pending, inProgress, completed }

class Advocate {
  Advocate(this.name, this.email);
  final String name;
  final String email;
}

class OfficeTask {
  OfficeTask({required this.title, required this.assignee, required this.dueDate, required this.priority, this.caseNumber = '', this.notes = '', this.status = TaskStatus.pending});
  final String title;
  final String assignee;
  final DateTime dueDate;
  final String priority;
  final String caseNumber;
  final String notes;
  TaskStatus status;
}

class OfficeData {
  static final advocates = <Advocate>[
    Advocate('Advocate 01', 'advocate01@ksklaw.in'),
    Advocate('Advocate 02', 'advocate02@ksklaw.in'),
    Advocate('Advocate 03', 'advocate03@ksklaw.in'),
  ];
  static final tasks = <OfficeTask>[
    OfficeTask(title: 'Prepare written statement', assignee: 'Advocate 01', dueDate: DateTime.now().add(const Duration(hours: 3)), priority: 'High', caseNumber: 'OS 124/2026'),
    OfficeTask(title: 'Attend Munsif Court', assignee: 'Advocate 02', dueDate: DateTime.now().add(const Duration(hours: 1)), priority: 'High', caseNumber: 'OS 88/2025', status: TaskStatus.inProgress),
    OfficeTask(title: 'Research case laws for counter', assignee: 'Advocate 03', dueDate: DateTime.now().add(const Duration(days: 1)), priority: 'Medium'),
  ];
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  UserRole role = UserRole.admin;
  String selectedAdvocate = OfficeData.advocates.first.name;
  final email = TextEditingController(text: 'admin@ksklaw.in');
  final password = TextEditingController(text: 'demo123');
  String? error;

  void login() {
    final valid = role == UserRole.admin
        ? email.text.trim() == 'admin@ksklaw.in' && password.text == 'demo123'
        : email.text.trim().toLowerCase() == '${selectedAdvocate.toLowerCase().replaceAll(' ', '')}@ksklaw.in' && password.text == 'demo123';
    if (!valid) { setState(() => error = 'Demo login details do not match.'); return; }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(role: role, advocateName: selectedAdvocate)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 24),
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(22)), child: const Column(children: [Icon(Icons.account_balance, color: Colors.white, size: 44), SizedBox(height: 12), Text('KSK LAW OFFICE', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold, letterSpacing: 1.1)), SizedBox(height: 5), Text('ADVOCATE TASK MANAGER', style: TextStyle(color: Color(0xFFD6E7FA), letterSpacing: 1.5, fontSize: 11))])),
      const SizedBox(height: 28), const Text('Welcome back', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: navy)), const SizedBox(height: 6), const Text('Sign in to manage your office work.'), const SizedBox(height: 22),
      SegmentedButton<UserRole>(segments: const [ButtonSegment(value: UserRole.admin, label: Text('Admin'), icon: Icon(Icons.admin_panel_settings)), ButtonSegment(value: UserRole.advocate, label: Text('Advocate'), icon: Icon(Icons.person))], selected: {role}, onSelectionChanged: (v) => setState(() { role = v.first; error = null; email.text = role == UserRole.admin ? 'admin@ksklaw.in' : '${selectedAdvocate.toLowerCase().replaceAll(' ', '')}@ksklaw.in'; })),
      const SizedBox(height: 18),
      if (role == UserRole.advocate) ...[
        const Text('Select advocate', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 7),
        DropdownButtonFormField<String>(value: selectedAdvocate, items: OfficeData.advocates.map((a) => DropdownMenuItem(value: a.name, child: Text(a.name))).toList(), onChanged: (v) => setState(() { selectedAdvocate = v!; email.text = '${selectedAdvocate.toLowerCase().replaceAll(' ', '')}@ksklaw.in'; })), const SizedBox(height: 14),
      ],
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline))), const SizedBox(height: 14),
      TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20), FilledButton(onPressed: login, style: FilledButton.styleFrom(backgroundColor: navy, padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Sign in')),
      const SizedBox(height: 18), const Text('Prototype demo password: demo123\nAdmin: admin@ksklaw.in\nAdvocate 01: advocate01@ksklaw.in (and similarly 02, 03)', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
    ])))));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.role, required this.advocateName});
  final UserRole role;
  final String advocateName;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  bool get isAdmin => widget.role == UserRole.admin;
  List<OfficeTask> get visibleTasks => isAdmin ? OfficeData.tasks : OfficeData.tasks.where((t) => t.assignee == widget.advocateName).toList();
  int count(TaskStatus s) => visibleTasks.where((t) => t.status == s).length;

  @override
  Widget build(BuildContext context) {
    final pages = [dashboard(), tasksPage(), if (isAdmin) advocatesPage(), reportsPage()];
    final titles = ['Dashboard', 'Tasks', if (isAdmin) 'Advocates', 'Reports'];
    return Scaffold(
      appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('KSK LAW OFFICE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: .6)), Text(titles[tab], style: const TextStyle(fontSize: 12, color: blue))]), actions: [IconButton(tooltip: 'Sign out', onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())), icon: const Icon(Icons.logout))]),
      body: pages[tab],
      floatingActionButton: isAdmin && tab == 1 ? FloatingActionButton.extended(onPressed: addTask, backgroundColor: navy, foregroundColor: Colors.white, icon: const Icon(Icons.add), label: const Text('Assign task')) : null,
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: [const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'), const NavigationDestination(icon: Icon(Icons.checklist), label: 'Tasks'), if (isAdmin) const NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Advocates'), const NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Reports')]),
    );
  }

  Widget dashboard() => ListView(padding: const EdgeInsets.all(16), children: [
    Text('Hello, ${isAdmin ? 'Office Admin' : widget.advocateName}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: navy)), const SizedBox(height: 4), Text(DateTime.now().toLocal().toString().split(' ').first, style: const TextStyle(color: Colors.black54)), const SizedBox(height: 18),
    GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.55, children: [stat('Total tasks', '${visibleTasks.length}', Icons.assignment, navy), stat('Pending', '${count(TaskStatus.pending)}', Icons.pending_actions, Colors.orange.shade800), stat('In progress', '${count(TaskStatus.inProgress)}', Icons.timelapse, blue), stat('Completed', '${count(TaskStatus.completed)}', Icons.task_alt, Colors.green.shade700)]),
    const SizedBox(height: 22), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Today's work", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), TextButton(onPressed: () => setState(() => tab = 1), child: const Text('View all'))]),
    if (visibleTasks.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No tasks assigned yet.'))),
    ...visibleTasks.take(4).map(taskCard),
    if (isAdmin) ...[const SizedBox(height: 18), const Text('Quick actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8), FilledButton.icon(onPressed: addTask, icon: const Icon(Icons.add_task), label: const Text('Assign a new task'))],
  ]);

  Widget stat(String label, String value, IconData icon, Color color) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: color), Text(value, style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: color)), Text(label, style: const TextStyle(color: Colors.black54))])));

  Widget tasksPage() => ListView(padding: const EdgeInsets.all(16), children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Task assignments', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)), if (isAdmin) Text('${OfficeData.tasks.length} total')]), const SizedBox(height: 12), if (visibleTasks.isEmpty) const Text('No tasks to display.'), ...visibleTasks.map(taskCard)]);

  Widget taskCard(OfficeTask task) => Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), statusChip(task.status)]), const SizedBox(height: 8), Text('Assigned to: ${task.assignee}', style: const TextStyle(color: Colors.black54)), if (task.caseNumber.isNotEmpty) Text('Case: ${task.caseNumber}', style: const TextStyle(color: Colors.black54)), const SizedBox(height: 5), Row(children: [const Icon(Icons.event, size: 16, color: blue), const SizedBox(width: 5), Text('Due: ${task.dueDate.toLocal().toString().substring(0, 16)}'), const Spacer(), Text('${task.priority} priority', style: TextStyle(fontWeight: FontWeight.w600, color: task.priority == 'High' ? Colors.red.shade700 : Colors.orange.shade800))]), const Divider(height: 20), Row(mainAxisAlignment: MainAxisAlignment.end, children: [if (isAdmin) TextButton(onPressed: () => setState(() => OfficeData.tasks.remove(task)), child: const Text('Delete')), const SizedBox(width: 8), OutlinedButton.icon(onPressed: () => updateStatus(task), icon: const Icon(Icons.update, size: 17), label: const Text('Update status'))])])));

  Widget statusChip(TaskStatus status) { final color = status == TaskStatus.completed ? Colors.green : status == TaskStatus.inProgress ? blue : Colors.orange.shade800; final label = status == TaskStatus.completed ? 'Completed' : status == TaskStatus.inProgress ? 'In progress' : 'Pending'; return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(30)), child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600))); }

  Future<void> updateStatus(OfficeTask task) async { final selected = await showModalBottomSheet<TaskStatus>(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [const Padding(padding: EdgeInsets.all(16), child: Text('Update task status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))), for (final s in TaskStatus.values) ListTile(title: Text(s == TaskStatus.pending ? 'Pending' : s == TaskStatus.inProgress ? 'In progress' : 'Completed'), trailing: task.status == s ? const Icon(Icons.check, color: blue) : null, onTap: () => Navigator.pop(ctx, s))]))); if (selected != null) setState(() => task.status = selected); }

  Future<void> addTask() async { final result = await showDialog<OfficeTask>(context: context, builder: (_) => const AddTaskDialog()); if (result != null) setState(() => OfficeData.tasks.insert(0, result)); }

  Widget advocatesPage() => ListView(padding: const EdgeInsets.all(16), children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Office advocates', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)), Text('${OfficeData.advocates.length}/10')]), const SizedBox(height: 12), ...OfficeData.advocates.map((a) => Card(child: ListTile(leading: CircleAvatar(backgroundColor: paleBlue, child: Text(a.name.split(' ').last)), title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(a.email), trailing: Text('${OfficeData.tasks.where((t) => t.assignee == a.name).length} tasks')))), const SizedBox(height: 10), FilledButton.icon(onPressed: addAdvocate, icon: const Icon(Icons.person_add), label: const Text('Add advocate'))]);

  Future<void> addAdvocate() async { final name = TextEditingController(); final email = TextEditingController(); final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Add advocate'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Advocate name')), const SizedBox(height: 10), TextField(controller: email, decoration: const InputDecoration(labelText: 'Email address'))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add'))])); if (ok == true && name.text.trim().isNotEmpty && OfficeData.advocates.length < 10) setState(() => OfficeData.advocates.add(Advocate(name.text.trim(), email.text.trim()))); }

  Widget reportsPage() => ListView(padding: const EdgeInsets.all(16), children: [const Text('Work summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)), const SizedBox(height: 12), Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [for (final s in TaskStatus.values) Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(children: [Expanded(child: Text(s == TaskStatus.pending ? 'Pending' : s == TaskStatus.inProgress ? 'In progress' : 'Completed')), Text('${count(s)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy))]))]))), const SizedBox(height: 12), const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Prototype report: task counts are calculated from the tasks currently stored in this app session. Cloud reports and scheduled daily summaries will be enabled after Firebase setup.')))]);
}

class AddTaskDialog extends StatefulWidget { const AddTaskDialog({super.key}); @override State<AddTaskDialog> createState() => _AddTaskDialogState(); }
class _AddTaskDialogState extends State<AddTaskDialog> {
  final title = TextEditingController(); final caseNo = TextEditingController(); final notes = TextEditingController();
  String assignee = OfficeData.advocates.first.name; String priority = 'Medium'; DateTime due = DateTime.now().add(const Duration(days: 1));
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('Assign new task'), content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: title, decoration: const InputDecoration(labelText: 'Task title *')), const SizedBox(height: 10), DropdownButtonFormField<String>(value: assignee, decoration: const InputDecoration(labelText: 'Assign to'), items: OfficeData.advocates.map((a) => DropdownMenuItem(value: a.name, child: Text(a.name))).toList(), onChanged: (v) => setState(() => assignee = v!),), const SizedBox(height: 10), TextField(controller: caseNo, decoration: const InputDecoration(labelText: 'Case number (optional)')), const SizedBox(height: 10), DropdownButtonFormField<String>(value: priority, decoration: const InputDecoration(labelText: 'Priority'), items: ['High', 'Medium', 'Low'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(), onChanged: (v) => setState(() => priority = v!)), const SizedBox(height: 10), ListTile(contentPadding: EdgeInsets.zero, title: const Text('Deadline'), subtitle: Text('${due.day}/${due.month}/${due.year}'), trailing: const Icon(Icons.calendar_month), onTap: () async { final d = await showDatePicker(context: context, initialDate: due, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 3650))); if (d != null) setState(() => due = d); }), TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Instructions / notes'))]))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { if (title.text.trim().isEmpty) return; Navigator.pop(context, OfficeTask(title: title.text.trim(), assignee: assignee, dueDate: due, priority: priority, caseNumber: caseNo.text.trim(), notes: notes.text.trim())); }, child: const Text('Assign task'))]);
}
