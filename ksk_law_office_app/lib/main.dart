import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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

  static String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
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

  static void _mergeCloud(List<Map<String, dynamic>> target, QuerySnapshot<Map<String, dynamic>> snapshot, {required bool preserveLocal}) {
    // Admin devices retain legacy local records; advocate devices receive only server-authorized records.
    final localOnly = preserveLocal ? target.where((item) => item['_id'] == null).toList() : <Map<String, dynamic>>[];
    final cloud = snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data.remove('createdAt');
      data.remove('updatedAt');
      data['_id'] = doc.id;
      return data;
    }).toList();
    target
      ..clear()
      ..addAll(localOnly)
      ..addAll(cloud);
  }

  static List<StreamSubscription<dynamic>> startRealtimeSync({
    required String userId,
    required bool isAdmin,
    required VoidCallback onChanged,
    required void Function(String message) onError,
  }) {
    final db = FirebaseFirestore.instance;
    final subscriptions = <StreamSubscription<dynamic>>[];

    // Never expose another account's locally cached office data while an advocate is signing in.
    if (!isAdmin) {
      tasks = [];
      cases = [];
      hearings = [];
      clients = [];
      entries = [];
    }

    void listenRecords(String collection, List<Map<String, dynamic>> target, {String? assignmentField}) {
      Query<Map<String, dynamic>> query = db.collection(collection);
      if (!isAdmin && assignmentField != null) {
        query = query.where(assignmentField, isEqualTo: userId);
      }
      subscriptions.add(query.snapshots().listen((snapshot) {
        _mergeCloud(target, snapshot, preserveLocal: isAdmin);
        onChanged();
      }, onError: (Object error) {
        onError('Could not sync $collection: $error');
      }));
    }

    listenRecords('tasks', tasks, assignmentField: 'assigneeUid');
    listenRecords('cases', cases, assignmentField: 'advocateUid');
    listenRecords('hearings', hearings, assignmentField: 'advocateUid');

    if (isAdmin) {
      listenRecords('clients', clients);
      listenRecords('entries', entries);
      subscriptions.add(db.collection('users').where('active', isEqualTo: true).snapshots().listen((snapshot) {
        advocates = snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          return {
            'uid': doc.id,
            'name': (data['name'] ?? data['phone'] ?? 'Advocate').toString(),
            'email': (data['email'] ?? '').toString(),
            'phone': (data['phone'] ?? '').toString(),
            'role': (data['role'] ?? 'advocate').toString(),
          };
        }).where((a) => a['role'] != 'mainAdmin').toList();
        onChanged();
      }, onError: (Object error) {
        onError('Could not sync advocate profiles: $error');
      }));
    }
    return subscriptions;
  }

  static Future<String> createCloudRecord(String collection, Map<String, dynamic> record) async {
    final data = Map<String, dynamic>.from(record)
      ..remove('_id')
      ..['createdByUid'] = FirebaseAuth.instance.currentUser!.uid
      ..['createdAt'] = FieldValue.serverTimestamp();
    final ref = FirebaseFirestore.instance.collection(collection).doc();
    record['_id'] = ref.id;
    try {
      await ref.set(data);
      return ref.id;
    } catch (_) {
      record.remove('_id');
      rethrow;
    }
  }

  static Future<void> updateCloudRecord(String collection, Map<String, dynamic> record, Map<String, dynamic> updates) async {
    final id = record['_id']?.toString();
    if (id == null || id.isEmpty) return;
    await FirebaseFirestore.instance.collection(collection).doc(id).update({
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteCloudRecord(String collection, Map<String, dynamic> record) async {
    final id = record['_id']?.toString();
    if (id == null || id.isEmpty) return;
    await FirebaseFirestore.instance.collection(collection).doc(id).delete();
  }

  static String? advocateUid(String name) {
    for (final advocate in advocates) {
      if (advocate['name'].toString().trim().toLowerCase() == name.trim().toLowerCase()) {
        final uid = advocate['uid']?.toString();
        if (uid != null && uid.isNotEmpty) return uid;
      }
    }
    return null;
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
  final advocateId = TextEditingController();
  final advocatePassword = TextEditingController();
  final adminUsername = TextEditingController();
  final adminPassword = TextEditingController();
  String? error;
  bool verifying = false;
  bool adminMode = false;
  static const String _mainAdminEmail = 'aasif882001@gmail.com';

  Future<void> _adminSignIn() async {
    if (adminUsername.text.trim() != 'ksk25' || adminPassword.text.isEmpty) {
      setState(() => error = 'Enter the Main Admin username and password.'); return;
    }
    setState(() { verifying = true; error = null; });
    try {
      final result = await FirebaseAuth.instance.signInWithEmailAndPassword(email: _mainAdminEmail, password: adminPassword.text);
      final user = result.user!;
      final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = profile.data();
      if (!profile.exists || data == null || data['active'] != true || data['role'] != 'mainAdmin') {
        await FirebaseAuth.instance.signOut();
        throw Exception('Main Admin profile is not approved.');
      }
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(role: UserRole.admin, advocateName: (data['name'] ?? 'Main Admin').toString(), isMainAdmin: true, userId: user.uid)));
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { verifying = false; error = e.message ?? e.code; });
    } catch (e) { if (mounted) setState(() { verifying = false; error = e.toString().replaceFirst('Exception: ', ''); }); }
  }

  Future<void> _advocateSignIn() async {
    final id = advocateId.text.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9._-]{3,30}$').hasMatch(id) || advocatePassword.text.isEmpty) {
      setState(() => error = 'Enter the Advocate ID and password provided by Main Admin.'); return;
    }
    setState(() { verifying = true; error = null; });
    try {
      final result = await FirebaseAuth.instance.signInWithEmailAndPassword(email: '$id@advocates.ksklaw.in', password: advocatePassword.text);
      final user = result.user!;
      final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = profile.data();
      if (!profile.exists || data == null || data['active'] != true || data['role'] == 'mainAdmin') {
        await FirebaseAuth.instance.signOut();
        throw Exception('This Advocate ID is not active. Contact Main Admin.');
      }
      final roleText = (data['role'] ?? 'advocate').toString();
      final role = ['admin', 'coAdmin'].contains(roleText) ? UserRole.admin : UserRole.advocate;
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(role: role, advocateName: (data['name'] ?? id).toString(), isMainAdmin: false, userId: user.uid)));
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { verifying = false; error = e.code == 'invalid-credential' || e.code == 'wrong-password' || e.code == 'user-not-found' ? 'Incorrect Advocate ID or password.' : (e.message ?? e.code); });
    } catch (e) { if (mounted) setState(() { verifying = false; error = e.toString().replaceFirst('Exception: ', ''); }); }
  }

  Future<void> _sendAdminPasswordReset() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _mainAdminEmail);
      if (mounted) setState(() => error = 'Password reset email sent to the registered Main Admin email.');
    } on FirebaseAuthException catch (e) { if (mounted) setState(() => error = e.message ?? e.code); }
  }

  @override
  void dispose() { advocateId.dispose(); advocatePassword.dispose(); adminUsername.dispose(); adminPassword.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 24),
        Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(22)), child: const Column(children: [
          Icon(Icons.account_balance, color: Colors.white, size: 44), SizedBox(height: 12),
          Text('KSK LAW OFFICE', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          SizedBox(height: 5), Text('SECURE ID & PASSWORD LOGIN', style: TextStyle(color: Color(0xFFD6E7FA), letterSpacing: 1.5, fontSize: 11)),
        ])),
        const SizedBox(height: 28), const Text('Welcome', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: navy)),
        const SizedBox(height: 6), Text(adminMode ? 'Main Admin sign in.' : 'Use the Advocate ID and password created by Main Admin.'),
        const SizedBox(height: 22),
        if (adminMode) ...[
          TextField(controller: adminUsername, decoration: const InputDecoration(labelText: 'Main Admin username', hintText: 'ksk25', prefixIcon: Icon(Icons.admin_panel_settings))),
          const SizedBox(height: 14),
          TextField(controller: adminPassword, obscureText: true, onSubmitted: (_) { if (!verifying) _adminSignIn(); }, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _sendAdminPasswordReset, child: const Text('Forgot password? Send reset email'))),
          FilledButton(onPressed: verifying ? null : _adminSignIn, style: FilledButton.styleFrom(backgroundColor: navy, padding: const EdgeInsets.symmetric(vertical: 16)), child: Text(verifying ? 'Signing in...' : 'Main Admin sign in')),
        ] else ...[
          TextField(controller: advocateId, autocorrect: false, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Advocate ID', hintText: 'Enter ID given by Admin', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 14),
          TextField(controller: advocatePassword, obscureText: true, onSubmitted: (_) { if (!verifying) _advocateSignIn(); }, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
          FilledButton(onPressed: verifying ? null : _advocateSignIn, style: FilledButton.styleFrom(backgroundColor: navy, padding: const EdgeInsets.symmetric(vertical: 16)), child: Text(verifying ? 'Signing in...' : 'Advocate sign in')),
        ],
        if (error != null) Padding(padding: const EdgeInsets.only(top: 8, bottom: 8), child: Text(error!, style: TextStyle(color: error!.startsWith('Password reset email sent') ? Colors.green.shade700 : Colors.red.shade700))),
        const SizedBox(height: 10),
        TextButton(onPressed: () => setState(() { adminMode = !adminMode; error = null; }), child: Text(adminMode ? 'Advocate login' : 'Main Admin login')),
        const SizedBox(height: 8),
        Text(adminMode ? 'Main Admin access is verified against the approved Firebase profile.' : 'Only Advocate IDs created and activated by Main Admin can access office records.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ]),
    ))),
  );
}

class AdvocateAccountsPage extends StatefulWidget {
  const AdvocateAccountsPage({super.key});
  @override
  State<AdvocateAccountsPage> createState() => _AdvocateAccountsPageState();
}
class _AdvocateAccountsPageState extends State<AdvocateAccountsPage> {
  final name = TextEditingController();
  final id = TextEditingController();
  final password = TextEditingController();
  bool creating = false;

  Future<void> _createAccount() async {
    final advocateName = name.text.trim();
    final loginId = id.text.trim().toLowerCase();
    final secret = password.text;
    if (advocateName.isEmpty || !RegExp(r'^[a-z0-9._-]{3,30}$').hasMatch(loginId) || secret.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter name, an ID (3–30 letters/numbers), and a password of at least 6 characters.'))); return;
    }
    setState(() => creating = true);
    try {
      FirebaseApp secondaryApp;
      try { secondaryApp = Firebase.app('advocateAccountCreator'); }
      on FirebaseException { secondaryApp = await Firebase.initializeApp(name: 'advocateAccountCreator', options: Firebase.app().options); }
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(email: '$loginId@advocates.ksklaw.in', password: secret);
      final newUser = credential.user!;
      await FirebaseFirestore.instance.collection('users').doc(newUser.uid).set({
        'name': advocateName, 'loginId': loginId, 'email': '$loginId@advocates.ksklaw.in',
        'role': 'advocate', 'active': true, 'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': FirebaseAuth.instance.currentUser!.uid,
      });
      await secondaryAuth.signOut();
      name.clear(); id.clear(); password.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Advocate account created. Login ID: $loginId')));
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == 'email-already-in-use' ? 'This Advocate ID already exists. Choose another ID.' : (e.message ?? e.code))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create account: $e')));
    } finally { if (mounted) setState(() => creating = false); }
  }

  @override
  void dispose() { name.dispose(); id.dispose(); password.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create advocate account')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Only Main Admin can create advocate login accounts.', style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 16),
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Advocate name')),
      const SizedBox(height: 12),
      TextField(controller: id, autocorrect: false, decoration: const InputDecoration(labelText: 'Advocate ID', hintText: 'Example: advocate01')),
      const SizedBox(height: 12),
      TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Temporary password (minimum 6 characters)')),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: creating ? null : _createAccount, icon: const Icon(Icons.person_add), label: Text(creating ? 'Creating account...' : 'Create advocate account')),
      const SizedBox(height: 12),
      const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Share the Advocate ID and temporary password privately. Passwords are managed by Firebase Authentication and are not stored in office records.'))),
    ]),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.role, required this.advocateName, required this.userId, this.isMainAdmin = false});
  final UserRole role;
  final String advocateName;
  final String userId;
  final bool isMainAdmin;
  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  late final List<StreamSubscription<dynamic>> _syncSubscriptions;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _syncSubscriptions = OfficeData.startRealtimeSync(
      userId: widget.userId,
      isAdmin: widget.role == UserRole.admin,
      onChanged: () { if (mounted) setState(() {}); },
      onError: (message) { if (mounted) setState(() => _syncError = message); },
    );
  }

  @override
  void dispose() {
    for (final subscription in _syncSubscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  int tab = 0;
  bool todayOnly = false;
  bool get isAdmin => widget.role == UserRole.admin;
  List<Map<String, dynamic>> get visibleTasks => isAdmin ? OfficeData.tasks : OfficeData.tasks.where((t) => t['assigneeUid'] == widget.userId).toList();
  List<Map<String, dynamic>> get visibleHearings => isAdmin ? OfficeData.hearings : OfficeData.hearings.where((h) => h['advocateUid'] == widget.userId).toList();
  List<Map<String, dynamic>> get visibleCases => isAdmin ? OfficeData.cases : OfficeData.cases.where((c) => c['advocateUid'] == widget.userId).toList();
  int countTasks(String status) => visibleTasks.where((t) => t['status'] == status).length;
  List<String> get tabs => isAdmin ? ['Home', 'Tasks', 'Cases', 'Hearings', 'Office'] : ['Home', 'Tasks', 'Cases', 'Hearings'];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[dashboard(), tasksPage(), casesPage(), hearingsPage(), if (isAdmin) officePage()];
    return Scaffold(
      appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('KSK LAW OFFICE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: .6)), Text(tabs[tab], style: const TextStyle(fontSize: 12, color: blue))]), actions: [IconButton(tooltip: 'Sign out', onPressed: () async { await FirebaseAuth.instance.signOut(); if (!context.mounted) return; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())); }, icon: const Icon(Icons.logout))]),
      body: Column(children: [if (_syncError != null) Material(color: Colors.orange.shade50, child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [const Icon(Icons.cloud_off, size: 18), const SizedBox(width: 8), Expanded(child: Text(_syncError!, style: const TextStyle(fontSize: 12)))]))), Expanded(child: pages[tab])]),
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
      Text('Hello, ${widget.advocateName}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: navy)),
      Text(DateTime.now().toString().split(' ').first, style: const TextStyle(color: Colors.black54)),
      const SizedBox(height: 18),
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.55, children: [
        stat('Total tasks', '${visibleTasks.length}', Icons.assignment, navy), stat('Pending', '${countTasks('Pending')}', Icons.pending_actions, Colors.orange.shade800), stat('Cases', '${visibleCases.length}', Icons.folder, blue), stat('Upcoming hearings', '${upcoming.length}', Icons.event, Colors.deepPurple),
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
  Widget _moneyRow(String label, double amount, Color color, {bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal))), Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.bold))]));
  double _sum(String type) => OfficeData.entries.where((e) => e['type'] == type).fold<double>(0.0, (v,e) => v + (double.tryParse(e['amount'].toString()) ?? 0));

  Widget tasksPage() => ListView(padding: const EdgeInsets.all(16), children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Task assignments', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)), Text('${visibleTasks.length} total')]),
    const SizedBox(height: 12),
    if (visibleTasks.isEmpty) const Text('No tasks to display.'),
    ...visibleTasks.map(_taskCard),
  ]);

  Widget _taskCard(Map<String, dynamic> task) => Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(task['title'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), _chip(task['status'].toString())]),
    const SizedBox(height: 8), Text('Assigned to: ${task['assignee']}', style: const TextStyle(color: Colors.black54)),
    if ((task['caseNumber'] ?? '').toString().isNotEmpty) Text('Case: ${task['caseNumber']}', style: const TextStyle(color: Colors.black54)),
    if ((task['notes'] ?? '').toString().isNotEmpty) Text(task['notes'].toString()),
    const SizedBox(height: 5), Row(children: [const Icon(Icons.event, size: 16, color: blue), const SizedBox(width: 5), Expanded(child: Text('Due: ${task['dueDate']}')), Text('${task['priority']} priority', style: TextStyle(fontWeight: FontWeight.w600, color: task['priority'] == 'High' ? Colors.red.shade700 : Colors.orange.shade800))]),
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
    if (value != null) {
      try {
        await OfficeData.updateCloudRecord('tasks', task, {'status': value});
      } on FirebaseException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cloud status update failed: ${e.message ?? e.code}')));
        return;
      }
      task['status'] = value;
      if (isAdmin) await OfficeData.save();
      setState(() {});
    }
  }

  Widget casesPage() => ListView(padding: const EdgeInsets.all(16), children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Case management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)), Text('${visibleCases.length} cases')]),
    const SizedBox(height: 12),
    if (visibleCases.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No cases added. Admin can add case details using the + button.'))),
    ...visibleCases.map((c) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
      leading: const CircleAvatar(backgroundColor: paleBlue, child: Icon(Icons.folder, color: navy)),
      title: Text('${c['caseNumber']} · ${c['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('Court: ${c['court']}\nParty: ${c['party']}\nAdvocate: ${c['advocate']}\nNext hearing: ${c['nextHearing']}'),
      isThreeLine: true,
      trailing: isAdmin ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(OfficeData.cases,c)) : null,
    ))),
  ]);

  Widget hearingsPage() {
    final list = [...visibleHearings]..sort((a,b) => a['date'].toString().compareTo(b['date'].toString()));
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Hearing date reminders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)),
      const SizedBox(height: 5), const Text('Hearing schedule for all assigned cases.'),
      Wrap(spacing: 8, children: [FilterChip(label: const Text('All dates'), selected: !todayOnly, onSelected: (_) => setState(() => todayOnly = false)), FilterChip(label: const Text('Today only'), selected: todayOnly, onSelected: (_) => setState(() => todayOnly = true))]),
      const SizedBox(height: 12),
      if (list.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No hearing dates recorded.'))),
      ...(todayOnly ? list.where((h) => h['date'].toString() == OfficeData._date(DateTime.now())) : list).map(_hearingCard),
      if (todayOnly && !list.any((h) => h['date'].toString() == OfficeData._date(DateTime.now()))) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No hearings scheduled for today.'))),
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
      title: Text('${h['caseNumber']} · ${h['purpose']}', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${h['date']} at ${h['time']}\n${h['court']} · ${h['advocate']}'),
      isThreeLine: true,
      trailing: isAdmin ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(OfficeData.hearings,h)) : (urgent ? const Icon(Icons.notifications_active, color: Colors.deepOrange) : null),
    ));
  }

  Widget officePage() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Office management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)),
    const SizedBox(height: 12),
    if (widget.isMainAdmin) Card(child: ListTile(
      leading: const CircleAvatar(backgroundColor: paleBlue, child: Icon(Icons.person_add_alt_1, color: navy)),
      title: const Text('Create advocate login', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text('Create an Advocate ID and password for office access'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvocateAccountsPage())),
    )),
    _sectionHeader('Clients', Icons.people, () => _add('client')),
    if (OfficeData.clients.isEmpty) const Text('No clients added yet.'),
    ...OfficeData.clients.map((c) => Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(c['name'].toString()), subtitle: Text('Phone: ${c['phone']}\nEmail: ${c['email']}'), isThreeLine: true, trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(OfficeData.clients,c))))),
    const Divider(height: 28),
    _sectionHeader('Office accounts', Icons.account_balance_wallet, () => _add('entry')),
    Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
      _moneyRow('Income', _sum('Income'), Colors.green.shade700),
      _moneyRow('Expenses', _sum('Expense'), Colors.red.shade700),
      const Divider(), _moneyRow('Balance', _sum('Income')-_sum('Expense'), navy, bold: true),
    ]))),
    ...OfficeData.entries.reversed.take(10).map((e) => Card(child: ListTile(
      leading: Icon(e['type'] == 'Income' ? Icons.arrow_downward : Icons.arrow_upward, color: e['type'] == 'Income' ? Colors.green : Colors.red),
      title: Text(e['description'].toString()), subtitle: Text('${e['date']} · ${e['category']}'),
      trailing: Text('₹${e['amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
    ))),
    const Divider(height: 28),
    Row(children: [const Icon(Icons.groups, color: navy), const SizedBox(width: 8), const Expanded(child: Text('Approved advocates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))]),
    Text('${OfficeData.advocates.length} active office accounts'),
    ...OfficeData.advocates.map((a) => Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person_outline)), title: Text(a['name'].toString()), subtitle: Text(a['email'].toString()), trailing: Text('${OfficeData.tasks.where((t) => t['assignee'] == a['name']).length} tasks')))),
    const SizedBox(height: 20),
    const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Tasks, cases, hearings, clients and office accounts sync through Firestore with role-based access. Export and automatic notifications require further setup.'))),
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
      if (kind == 'task') ...['','${OfficeData.advocates.isEmpty ? '' : OfficeData.advocates.first['name']}','${DateTime.now().toString().split(' ').first}','Medium','',''],
      if (kind == 'case') ...['','','','','${OfficeData.advocates.isEmpty ? '' : OfficeData.advocates.first['name']}','',''],
      if (kind == 'hearing') ...['','','${DateTime.now().toString().split(' ').first}','10:00 AM','','${OfficeData.advocates.isEmpty ? '' : OfficeData.advocates.first['name']}'],
      if (kind == 'client') ...['','','','',''],
      if (kind == 'entry') ...['Income','','General','${DateTime.now().toString().split(' ').first}',''],
      if (kind == 'advocate') ...['',''],
    ];
    final values = await showDialog<List<String>>(context: context, builder: (_) => RecordDialog(title: _kindTitle(kind), labels: labels, initial: initial));
    if (values == null) return;
    Map<String,dynamic> record;
    switch(kind) {
      case 'task':
        final assignedUid = OfficeData.advocateUid(values[1]);
        if (assignedUid == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose an approved advocate name from the active office advocate list.'))); return; }
        record = {'title':values[0], 'assignee':values[1], 'assigneeUid':assignedUid, 'dueDate':values[2], 'priority':values[3].isEmpty?'Medium':values[3], 'caseNumber':values[4], 'notes':values[5], 'status':'Pending'};
        OfficeData.tasks.insert(0,record); break;
      case 'case':
        final assignedUid = OfficeData.advocateUid(values[4]);
        if (assignedUid == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose an approved advocate name from the active office advocate list.'))); return; }
        record = {'caseNumber':values[0], 'title':values[1], 'court':values[2], 'party':values[3], 'advocate':values[4], 'advocateUid':assignedUid, 'nextHearing':values[5], 'notes':values[6]};
        OfficeData.cases.insert(0,record);
        if (values[5].trim().isNotEmpty) OfficeData.hearings.add({'caseNumber':values[0], 'court':values[2], 'date':values[5], 'time':'', 'purpose':'Next hearing', 'advocate':values[4], 'advocateUid':assignedUid});
        break;
      case 'hearing':
        final assignedUid = OfficeData.advocateUid(values[5]);
        if (assignedUid == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose an approved advocate name from the active office advocate list.'))); return; }
        record = {'caseNumber':values[0], 'court':values[1], 'date':values[2], 'time':values[3], 'purpose':values[4], 'advocate':values[5], 'advocateUid':assignedUid};
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
    try {
      if (kind == 'case') {
        await OfficeData.createCloudRecord('cases', record);
        if (values[5].trim().isNotEmpty && OfficeData.hearings.isNotEmpty) {
          await OfficeData.createCloudRecord('hearings', OfficeData.hearings.last);
        }
      } else if (kind == 'task') {
        await OfficeData.createCloudRecord('tasks', record);
      } else if (kind == 'hearing') {
        await OfficeData.createCloudRecord('hearings', record);
      } else if (kind == 'client') {
        await OfficeData.createCloudRecord('clients', record);
      } else if (kind == 'entry') {
        await OfficeData.createCloudRecord('entries', record);
      }
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cloud save failed. This record is still only on this device: ${e.message ?? e.code}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cloud save failed. This record is still only on this device: $e')));
    }
    await OfficeData.save();
    setState(() {});
  }
  String _kindTitle(String kind) => {'task':'Assign new task','case':'Add case','hearing':'Add hearing date','client':'Add client','entry':'Add account entry','advocate':'Add advocate'}[kind]!;
  Future<void> _delete(List<Map<String,dynamic>> list, Map<String,dynamic> item) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete record?'), content: const Text('This record will be removed from the office records.'), actions: [TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete'))]));
    if (ok == true) {
      final collection = identical(list, OfficeData.tasks) ? 'tasks'
        : identical(list, OfficeData.cases) ? 'cases'
        : identical(list, OfficeData.hearings) ? 'hearings'
        : identical(list, OfficeData.clients) ? 'clients'
        : identical(list, OfficeData.entries) ? 'entries' : null;
      try {
        if (collection != null) await OfficeData.deleteCloudRecord(collection, item);
      } on FirebaseException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cloud delete failed: ${e.message ?? e.code}')));
        return;
      }
      list.remove(item);
      await OfficeData.save();
      setState(() {});
    }
  }
}

class AdvocateApprovalsPage extends StatelessWidget {
  const AdvocateApprovalsPage({super.key});

  Future<void> _approve(BuildContext context, DocumentSnapshot<Map<String, dynamic>> doc, String role) async {
    try {
      await doc.reference.update({
        'active': true,
        'role': role,
        'approvedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Advocate access approved.')));
    } on FirebaseException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approval failed: ${e.message ?? e.code}')));
    }
  }

  Future<void> _reject(BuildContext context, DocumentSnapshot<Map<String, dynamic>> doc) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Reject registration?'),
      content: const Text('This will remove the pending office profile. The person can register again later.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
      ],
    ));
    if (confirm != true) return;
    try {
      await doc.reference.delete();
    } on FirebaseException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rejection failed: ${e.message ?? e.code}')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Advocate approvals')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').where('active', isEqualTo: false).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load pending registrations. Check Firestore rules.\n${snapshot.error}')));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No pending advocate registrations.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final name = (data['name'] ?? 'Advocate').toString();
            final phone = (data['phone'] ?? '').toString();
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (phone.isNotEmpty) Text(phone, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    FilledButton(onPressed: () => _approve(context, doc, 'advocate'), child: const Text('Approve advocate')),
                    OutlinedButton(onPressed: () => _approve(context, doc, 'admin'), child: const Text('Approve as admin')),
                    TextButton(onPressed: () => _reject(context, doc), child: const Text('Reject')),
                  ]),
                ]),
              ),
            );
          },
        );
      },
    ),
  );
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
