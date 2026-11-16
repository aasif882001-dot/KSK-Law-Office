import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OfficeData.load();
  runApp(const KskLawOfficeApp());
}

const navy = Color(0xFF173F73);
const blue = Color(0xFF2468B2);
const paleBlue = Color(0xFFEAF2FB);

class OfficeData {
  static late SharedPreferences _prefs;
  static List<Map<String, dynamic>> advocates = [];
  static List<Map<String, dynamic>> tasks = [];
  static List<Map<String, dynamic>> cases = [];
  static List<Map<String, dynamic>> hearings = [];
  static List<Map<String, dynamic>> clients = [];
  static List<Map<String, dynamic>> entries = [];

  static Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    advocates = _read('advocates', [
      {'name': 'Advocate 01', 'email': 'advocate01@ksklaw.in'},
      {'name': 'Advocate 02', 'email': 'advocate02@ksklaw.in'},
      {'name': 'Advocate 03', 'email': 'advocate03@ksklaw.in'},
    ]);
    tasks = _read('tasks', [
      {'title': 'Prepare written statement', 'assignee': 'Advocate 01', 'dueDate': _date(DateTime.now().add(const Duration(days: 1))), 'priority': 'High', 'caseNumber': 'OS 124/2026', 'notes': '', 'status': 'Pending'},
      {'title': 'Attend Munsif Court', 'assignee': 'Advocate 02', 'dueDate': _date(DateTime.now()), 'priority': 'High', 'caseNumber': 'OS 88/2025', 'notes': '', 'status': 'In progress'},
      {'title': 'Research case laws for counter', 'assignee': 'Advocate 03', 'dueDate': _date(DateTime.now().add(const Duration(days: 2))), 'priority': 'Medium', 'caseNumber': '', 'notes': '', 'status': 'Pending'},
    ]);
    cases = _read('cases', []);
    hearings = _read('hearings', []);
    clients = _read('clients', []);
    entries = _read('entries', []);
  }

  static String _date(DateTime d) => '\${d.year.toString().padLeft(4, '0')}-\${d.month.toString().padLeft(2, '0')}-\${d.day.toString().padLeft(2, '0')}';
  static List<Map<String, dynamic>> _read(String key, List<Map<String, dynamic>> fallback) {
    final raw = _prefs.getString(key);
    if (raw == null) return fallback.map((e) => Map<String, dynamic>.from(e)).toList();
    try {
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return fallback.map((e) => Map<String, dynamic>.from(e)).toList();
    }
  }
  static Future<void> save() async {
    await _prefs.setString('advocates', jsonEncode(advocates));
    await _prefs.setString('tasks', jsonEncode(tasks));
    await _prefs.setString('cases', jsonEncode(cases));
    await _prefs.setString('hearings', jsonEncode(hearings));
    await _prefs.setString('clients', jsonEncode(clients));
    await _prefs.setString('entries', jsonEncode(entries));
  }
}

class KskLawOfficeApp extends StatelessWidget {
  const KskLawOfficeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
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

enum UserRole { admin, advocate }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  UserRole role = UserRole.admin;
  String selectedAdvocate = OfficeData.advocates.isEmpty ? '' : OfficeData.advocates.first['name'].toString();
  final email = TextEditingController(text: 'admin@ksklaw.in');
  final password = TextEditingController(text: 'demo123');
  String? error;

  void login() {
    final entered = email.text.trim().toLowerCase();
    final valid = role == UserRole.admin
      ? entered == 'admin@ksklaw.in' && password.text == 'demo123'
      : OfficeData.advocates.any((a) => a['email'].toString().toLowerCase() == entered) && password.text == 'demo123';
    if (!valid) { setState(() => error = 'Demo login details do not match.'); return; }
    final advocate = OfficeData.advocates.firstWhere((a) => a['email'].toString().toLowerCase() == entered, orElse: () => {'name': selectedAdvocate});
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(role: role, advocateName: role == UserRole.admin ? 'Office Admin' : advocate['name'].toString())));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 24),
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(22)), child: const Column(children: [Icon(Icons.account_balance, color: Colors.white, size: 44), SizedBox(height: 12), Text('KSK LAW OFFICE', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold, letterSpacing: 1.1)), SizedBox(height: 5), Text('ADVOCATE OFFICE MANAGER', style: TextStyle(color: Color(0xFFD6E7FA), letterSpacing: 1.5, fontSize: 11))])),
      const SizedBox(height: 28), const Text('Welcome back', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: navy)), const SizedBox(height: 6), const Text('Sign in to manage your office work.'), const SizedBox(height: 22),
      SegmentedButton<UserRole>(segments: const [ButtonSegment(value: UserRole.admin, label: Text('Admin'), icon: Icon(Icons.admin_panel_settings)), ButtonSegment(value: UserRole.advocate, label: Text('Advocate'), icon: Icon(Icons.person))], selected: {role}, onSelectionChanged: (v) => setState(() { role = v.first; error = null; email.text = role == UserRole.admin ? 'admin@ksklaw.in' : (OfficeData.advocates.isEmpty ? '' : OfficeData.advocates.first['email'].toString()); })),
      const SizedBox(height: 18),
      if (role == UserRole.advocate) ...[
        DropdownButtonFormField<String>(value: OfficeData.advocates.any((a) => a['name'] == selectedAdvocate) ? selectedAdvocate : null, decoration: const InputDecoration(labelText: 'Select advocate'), items: OfficeData.advocates.map((a) => DropdownMenuItem(value: a['name'].toString(), child: Text(a['name'].toString()))).toList(), onChanged: (v) => setState(() { selectedAdvocate = v ?? ''; final a = OfficeData.advocates.firstWhere((x) => x['name'] == v); email.text = a['email'].toString(); })),
        const SizedBox(height: 14),
      ],
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline))), const SizedBox(height: 14),
      TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20), FilledButton(onPressed: login, style: FilledButton.styleFrom(backgroundColor: navy, padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Sign in')),
      const SizedBox(height: 18), const Text('Prototype demo password: demo123\nAdmin: admin@ksklaw.in\nAdvocates: use the email shown in the advocate list', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
    ])))),
  );
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
  List<Map<String, dynamic>> get visibleTasks => isAdmin ? OfficeData.tasks : OfficeData.tasks.where((t) => t['assignee'] == widget.advocateName).toList();
  List<Map<String, dynamic>> get visibleHearings => isAdmin ? OfficeData.hearings : OfficeData.hearings.where((h) => h['advocate'] == widget.advocateName).toList();
  int countTasks(String status) => visibleTasks.where((t) => t['status'] == status).length;
  List<String> get tabs => isAdmin ? ['Home', 'Tasks', 'Cases', 'Hearings', 'Office'] : ['Home', 'Tasks', 'Cases', 'Hearings'];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[dashboard(), tasksPage(), casesPage(), hearingsPage(), if (isAdmin) officePage()];
    return Scaffold(
      appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('KSK LAW OFFICE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: .6)), Text(tabs[tab], style: const TextStyle(fontSize: 12, color: blue))]), actions: [IconButton(tooltip: 'Sign out', onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())), icon: const Icon(Icons.logout))]),
      body: pages[tab],
      floatingActionButton: _fab(),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: [
        const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
        const NavigationDestination(icon: Icon(Icons.checklist), label: 'Tasks'),
        const NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Cases'),
        const NavigationDestination(icon: Icon(Icons.event), label: 'Hearings'),
        if (isAdmin) const NavigationDestination(icon: Icon(Icons.business_center_outlined), label: 'Office'),
      ]),
    );
  }

  Widget? _fab() {
    if (!isAdmin) return null;
    if (tab == 1) return FloatingActionButton.extended(onPressed: () => _add('task'), backgroundColor: navy, foregroundColor: Colors.white, icon: const Icon(Icons.add), label: const Text('Assign task'));
    if (tab == 2) return FloatingActionButton.extended(onPressed: () => _add('case'), backgroundColor: navy, foregroundColor: Colors.white, icon: const Icon(Icons.add), label: const Text('Add case'));
    if (tab == 3) return FloatingActionButton.extended(onPressed: () => _add('hearing'), backgroundColor: navy, foregroundColor: Colors.white, icon: const Icon(Icons.add), label: const Text('Add hearing'));
    return null;
  }

  Widget dashboard() {
    final upcoming = visibleHearings.where((h) => _isUpcoming(h['date'])).toList()..sort((a,b) => a['date'].toString().compareTo(b['date'].toString()));
    final income = _sum('Income'), expense = _sum('Expense');
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Hello, \${widget.advocateName}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: navy)),
      Text(DateTime.now().toString().split(' ').first, style: const TextStyle(color: Colors.black54)),
      const SizedBox(height: 18),
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.55, children: [
        stat('Total tasks', '\${visibleTasks.length}', Icons.assignment, navy), stat('Pending', '\${countTasks('Pending')}', Icons.pending_actions, Colors.orange.shade800), stat('Cases', '\${OfficeData.cases.length}', Icons.folder, blue), stat('Upcoming hearings', '\${upcoming.length}', Icons.event, Colors.deepPurple),
      ]),
      const SizedBox(height: 20),
      const Text('Upcoming hearing dates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (upcoming.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No upcoming hearings added.'))),
      ...upcoming.take(3).map((h) => _hearingCard(h)),
      if (isAdmin) ...[
        const SizedBox(height: 18), const Text('Office accounts overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          _moneyRow('Total income', income, Colors.green.shade700), _moneyRow('Total expenses', expense, Colors.red.shade700), const Divider(), _moneyRow('Balance', income-expense, navy, bold: true),
        ]))),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () => setState(() => tab = 4), icon: const Icon(Icons.business_center), label: const Text('Open office management')),
      ],
      const SizedBox(height: 18),
      const Text('Recent tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ...visibleTasks.take(3).map(_taskCard),
    ]);
  }

  Widget stat(String label, String value, IconData icon, Color color) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: color), Text(value, style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: color)), Text(label, style: const TextStyle(color: Colors.black54))])));
  Widget _moneyRow(String label, double amount, Color color, {bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal))), Text('₹\${amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.bold))]));
  double _sum(String type) => OfficeData.entries.where((e) => e['type'] == type).fold<double>(0.0, (v,e) => v + (double.tryParse(e['amount'].toString()) ?? 0));

  Widget tasksPage() => ListView(padding: const EdgeInsets.all(16), children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Task assignments', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)), Text('\${visibleTasks.length} total')]),
    const SizedBox(height: 12),
    if (visibleTasks.isEmpty) const Text('No tasks to display.'),
    ...visibleTasks.map(_taskCard),
  ]);

  Widget _taskCard(Map<String, dynamic> task) => Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(task['title'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), _chip(task['status'].toString())]),
    const SizedBox(height: 8), Text('Assigned to: \${task['assignee']}', style: const TextStyle(color: Colors.black54)),
    if ((task['caseNumber'] ?? '').toString().isNotEmpty) Text('Case: \${task['caseNumber']}', style: const TextStyle(color: Colors.black54)),
    if ((task['notes'] ?? '').toString().isNotEmpty) Text(task['notes'].toString()),
    const SizedBox(height: 5), Row(children: [const Icon(Icons.event, size: 16, color: blue), const SizedBox(width: 5), Expanded(child: Text('Due: \${task['dueDate']}')), Text('\${task['priority']} priority', style: TextStyle(fontWeight: FontWeight.w600, color: task['priority'] == 'High' ? Colors.red.shade700 : Colors.orange.shade800))]),
    const Divider(height: 20), Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      if (isAdmin) TextButton(onPressed: () => _delete(OfficeData.tasks, task), child: const Text('Delete')),
      OutlinedButton.icon(onPressed: () => _updateTask(task), icon: const Icon(Icons.update, size: 17), label: const Text('Update status')),
    ]),
  ])));

  Widget _chip(String status) {
    final color = status == 'Completed' ? Colors.green : status == 'In progress' ? blue : Colors.orange.shade800;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(30)), child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)));
  }
  Future<void> _updateTask(Map<String, dynamic> task) async {
    final value = await showModalBottomSheet<String>(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Padding(padding: EdgeInsets.all(16), child: Text('Update task status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
      for (final s in ['Pending','In progress','Completed']) ListTile(title: Text(s), trailing: task['status'] == s ? const Icon(Icons.check, color: blue) : null, onTap: () => Navigator.pop(ctx,s)),
    ])));
    if (value != null) { task['status'] = value; await OfficeData.save(); setState(() {}); }
  }

  Widget casesPage() => ListView(padding: const EdgeInsets.all(16), children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Case management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)), Text('\${OfficeData.cases.length} cases')]),
    const SizedBox(height: 12),
    if (OfficeData.cases.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No cases added. Admin can add case details using the + button.'))),
    ...OfficeData.cases.map((c) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
      leading: const CircleAvatar(backgroundColor: paleBlue, child: Icon(Icons.folder, color: navy)),
      title: Text('\${c['caseNumber']} · \${c['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('Court: \${c['court']}\nParty: \${c['party']}\nAdvocate: \${c['advocate']}\nNext hearing: \${c['nextHearing']}'),
      isThreeLine: true,
      trailing: isAdmin ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(OfficeData.cases,c)) : null,
    ))),
  ]);

  Widget hearingsPage() {
    final list = [...visibleHearings]..sort((a,b) => a['date'].toString().compareTo(b['date'].toString()));
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Hearing date reminders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)),
      const SizedBox(height: 5), const Text('Upcoming dates are highlighted when you open the app. Keep notifications enabled on your device for app alerts.'),
      const SizedBox(height: 12),
      if (list.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No hearing dates recorded.'))),
      ...list.map(_hearingCard),
    ]);
  }
  bool _isUpcoming(dynamic date) {
    final d = DateTime.tryParse(date.toString());
    if (d == null) return false;
    final today = DateTime.now();
    return !d.isBefore(DateTime(today.year,today.month,today.day));
  }
  Widget _hearingCard(Map<String,dynamic> h) {
    final d = DateTime.tryParse(h['date'].toString());
    final days = d == null ? null : d.difference(DateTime(DateTime.now().year,DateTime.now().month,DateTime.now().day)).inDays;
    final urgent = days != null && days <= 3 && days >= 0;
    return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
      leading: CircleAvatar(backgroundColor: urgent ? const Color(0xFFFFF0E4) : paleBlue, child: Icon(Icons.event, color: urgent ? Colors.deepOrange : navy)),
      title: Text('\${h['caseNumber']} · \${h['purpose']}', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('\${h['date']} at \${h['time']}\n\${h['court']} · \${h['advocate']}'),
      isThreeLine: true,
      trailing: isAdmin ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(OfficeData.hearings,h)) : (urgent ? const Icon(Icons.notifications_active, color: Colors.deepOrange) : null),
    ));
  }

  Widget officePage() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Office management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)),
    const SizedBox(height: 12),
    _sectionHeader('Clients', Icons.people, () => _add('client')),
    if (OfficeData.clients.isEmpty) const Text('No clients added yet.'),
    ...OfficeData.clients.map((c) => Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(c['name'].toString()), subtitle: Text('Phone: \${c['phone']}\nEmail: \${c['email']}'), isThreeLine: true, trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(OfficeData.clients,c))))),
    const Divider(height: 28),
    _sectionHeader('Office accounts', Icons.account_balance_wallet, () => _add('entry')),
    Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
      _moneyRow('Income', _sum('Income'), Colors.green.shade700),
      _moneyRow('Expenses', _sum('Expense'), Colors.red.shade700),
      const Divider(), _moneyRow('Balance', _sum('Income')-_sum('Expense'), navy, bold: true),
    ]))),
    ...OfficeData.entries.reversed.take(10).map((e) => Card(child: ListTile(
      leading: Icon(e['type'] == 'Income' ? Icons.arrow_downward : Icons.arrow_upward, color: e['type'] == 'Income' ? Colors.green : Colors.red),
      title: Text(e['description'].toString()), subtitle: Text('\${e['date']} · \${e['category']}'),
      trailing: Text('₹\${e['amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
    ))),
    const Divider(height: 28),
    _sectionHeader('Advocates', Icons.groups, () => _add('advocate')),
    Text('\${OfficeData.advocates.length}/10 advocates'),
    ...OfficeData.advocates.map((a) => Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person_outline)), title: Text(a['name'].toString()), subtitle: Text(a['email'].toString()), trailing: Text('\${OfficeData.tasks.where((t) => t['assignee'] == a['name']).length} tasks')))),
    const SizedBox(height: 20),
    const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Reports are calculated from the records stored on this device. Export, cloud sync, user permissions and automatic notifications require further production setup.'))),
  ]);
  Widget _sectionHeader(String title, IconData icon, VoidCallback add) => Row(children: [Icon(icon,color:navy), const SizedBox(width:8), Expanded(child: Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold))), TextButton.icon(onPressed:add,icon:const Icon(Icons.add),label:const Text('Add'))]);

  Future<void> _add(String kind) async {
    if (kind == 'advocate' && OfficeData.advocates.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 10 advocates allowed.')));
      return;
    }
    final specs = <String, List<String>>{
      'task': ['Task title','Assigned advocate','Due date (YYYY-MM-DD)','Priority (High/Medium/Low)','Case number','Instructions / notes'],
      'case': ['Case number','Case title','Court name','Parties / client','Assigned advocate','Next hearing date (YYYY-MM-DD)','Notes'],
      'hearing': ['Case number','Court name','Hearing date (YYYY-MM-DD)','Hearing time','Purpose / stage','Advocate'],
      'client': ['Client name','Phone number','Email address','Address','Notes'],
      'entry': ['Type (Income/Expense)','Amount (₹)','Category','Date (YYYY-MM-DD)','Description'],
      'advocate': ['Advocate name','Email address'],
    };
    final labels = specs[kind]!;
    final initial = <String>[
      if (kind == 'task') ...['','\${OfficeData.advocates.isEmpty ? '' : OfficeData.advocates.first['name']}','\${DateTime.now().toString().split(' ').first}','Medium','',''],
      if (kind == 'case') ...['','','','','\${OfficeData.advocates.isEmpty ? '' : OfficeData.advocates.first['name']}','',''],
      if (kind == 'hearing') ...['','','\${DateTime.now().toString().split(' ').first}','10:00 AM','','\${OfficeData.advocates.isEmpty ? '' : OfficeData.advocates.first['name']}'],
      if (kind == 'client') ...['','','','',''],
      if (kind == 'entry') ...['Income','','General','\${DateTime.now().toString().split(' ').first}',''],
      if (kind == 'advocate') ...['',''],
    ];
    final values = await showDialog<List<String>>(context: context, builder: (_) => RecordDialog(title: _kindTitle(kind), labels: labels, initial: initial));
    if (values == null) return;
    Map<String,dynamic> record;
    switch(kind) {
      case 'task':
        record = {'title':values[0], 'assignee':values[1], 'dueDate':values[2], 'priority':values[3].isEmpty?'Medium':values[3], 'caseNumber':values[4], 'notes':values[5], 'status':'Pending'};
        OfficeData.tasks.insert(0,record); break;
      case 'case':
        record = {'caseNumber':values[0], 'title':values[1], 'court':values[2], 'party':values[3], 'advocate':values[4], 'nextHearing':values[5], 'notes':values[6]};
        OfficeData.cases.insert(0,record);
        if (values[5].trim().isNotEmpty) OfficeData.hearings.add({'caseNumber':values[0], 'court':values[2], 'date':values[5], 'time':'', 'purpose':'Next hearing', 'advocate':values[4]});
        break;
      case 'hearing':
        record = {'caseNumber':values[0], 'court':values[1], 'date':values[2], 'time':values[3], 'purpose':values[4], 'advocate':values[5]};
        OfficeData.hearings.add(record); break;
      case 'client':
        record = {'name':values[0], 'phone':values[1], 'email':values[2], 'address':values[3], 'notes':values[4]};
        OfficeData.clients.add(record); break;
      case 'entry':
        record = {'type':values[0].toLowerCase().startsWith('i')?'Income':'Expense', 'amount':values[1], 'category':values[2], 'date':values[3], 'description':values[4]};
        OfficeData.entries.add(record); break;
      default:
        record = {'name':values[0], 'email':values[1]};
        OfficeData.advocates.add(record);
    }
    await OfficeData.save();
    setState(() {});
  }
  String _kindTitle(String kind) => {'task':'Assign new task','case':'Add case','hearing':'Add hearing date','client':'Add client','entry':'Add account entry','advocate':'Add advocate'}[kind]!;
  Future<void> _delete(List<Map<String,dynamic>> list, Map<String,dynamic> item) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete record?'), content: const Text('This record will be removed from this device.'), actions: [TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete'))]));
    if (ok == true) { list.remove(item); await OfficeData.save(); setState(() {}); }
  }
}

class RecordDialog extends StatefulWidget {
  const RecordDialog({super.key, required this.title, required this.labels, required this.initial});
  final String title;
  final List<String> labels;
  final List<String> initial;
  @override State<RecordDialog> createState() => _RecordDialogState();
}
class _RecordDialogState extends State<RecordDialog> {
  late final List<TextEditingController> controllers = List.generate(widget.labels.length, (i) => TextEditingController(text: widget.initial[i]));
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      for (int i=0;i<widget.labels.length;i++) Padding(padding: const EdgeInsets.only(bottom:10), child: TextField(controller: controllers[i], keyboardType: widget.labels[i].contains('Amount') || widget.labels[i].contains('Phone') ? TextInputType.number : TextInputType.text, maxLines: widget.labels[i].contains('Notes') || widget.labels[i].contains('Address') || widget.labels[i].contains('Instructions') ? 3 : 1, decoration: InputDecoration(labelText: widget.labels[i]))),
    ]))),
    actions: [TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,controllers.map((c)=>c.text.trim()).toList()),child:const Text('Save'))],
  );
}
