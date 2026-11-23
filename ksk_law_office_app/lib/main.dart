import 'dart:convert';
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
  final phone = TextEditingController(text: '+91');
  final otp = TextEditingController();
  final adminUsername = TextEditingController();
  final adminPassword = TextEditingController();
  String? verificationId;
  String? error;
  bool sending = false;
  bool verifying = false;
  bool adminMode = false;

  static const String _mainAdminEmail = 'aasif882001@gmail.com';

  Future<void> _adminSignIn() async {
    final username = adminUsername.text.trim();
    final password = adminPassword.text;
    if (username != 'ksk25' || password.isEmpty) {
      setState(() => error = 'Enter the Main Admin username and password.');
      return;
    }
    setState(() { verifying = true; error = null; });
    try {
      final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _mainAdminEmail,
        password: password,
      );
      final user = result.user;
      if (user == null) throw Exception('Firebase did not return a user account.');
      final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = profile.data();
      if (!profile.exists || data == null || data['active'] != true || data['role'] != 'mainAdmin') {
        await FirebaseAuth.instance.signOut();
        throw Exception('Main Admin profile is not approved. The Firebase users profile must have active=true and role=mainAdmin.');
      }
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(role: UserRole.admin, advocateName: (data['name'] ?? 'Main Admin').toString(), isMainAdmin: true)));
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { verifying = false; error = e.code == 'invalid-credential' || e.code == 'wrong-password' ? 'Incorrect username or password.' : (e.message ?? e.code); });
    } on FirebaseException catch (e) {
      if (mounted) setState(() { verifying = false; error = 'Firebase database access error: ${e.message ?? e.code}'; });
    } catch (e) {
      if (mounted) setState(() { verifying = false; error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _sendAdminPasswordReset() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _mainAdminEmail);
      if (mounted) setState(() => error = 'Password reset email sent to the registered Main Admin email.');
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = e.message ?? e.code);
    }
  }

  Future<void> _sendOtp() async {
    final number = phone.text.trim().replaceAll(' ', '');
    if (!number.startsWith('+') || number.length < 10) {
      setState(() => error = 'Enter mobile number with country code, for example +91XXXXXXXXXX.');
      return;
    }
    setState(() { sending = true; error = null; });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: number,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async { await _finishSignIn(credential); },
        verificationFailed: (e) {
          if (mounted) setState(() { sending = false; error = e.message ?? 'OTP could not be sent. Check Firebase phone authentication and app verification settings.'; });
        },
        codeSent: (id, resendToken) {
          if (mounted) setState(() { verificationId = id; sending = false; error = 'OTP sent. Enter the 6-digit code.'; });
        },
        codeAutoRetrievalTimeout: (id) { verificationId = id; },
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { sending = false; error = e.message ?? e.code; });
    } catch (e) {
      if (mounted) setState(() { sending = false; error = 'Unable to start phone verification: $e'; });
    }
  }

  Future<void> _verifyOtp() async {
    if (verificationId == null || otp.text.trim().length < 6) {
      setState(() => error = 'Enter the 6-digit OTP received by SMS.');
      return;
    }
    setState(() { verifying = true; error = null; });
    try {
      final credential = PhoneAuthProvider.credential(verificationId: verificationId!, smsCode: otp.text.trim());
      await _finishSignIn(credential);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { verifying = false; error = e.message ?? 'OTP verification failed.'; });
    } catch (e) {
      if (mounted) setState(() { verifying = false; error = 'Verification failed: $e'; });
    }
  }

  Future<void> _finishSignIn(PhoneAuthCredential credential) async {
    try {
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = result.user;
      if (user == null) throw Exception('Firebase did not return a user account.');
      final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = profile.data();
      if (!profile.exists) {
        await profile.reference.set({
          'name': user.displayName ?? user.phoneNumber ?? 'Pending advocate',
          'phone': user.phoneNumber ?? '',
          'role': 'advocate',
          'active': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (!profile.exists || data == null || data['active'] != true) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() { verifying = false; sending = false; });
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Account approval required'),
            content: SelectableText('Your mobile number is verified, but your office account is not approved yet.\n\nShare this Firebase User ID with the Main Admin to create your advocate profile:\n\n${user.uid}'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
        return;
      }
      final roleText = (data['role'] ?? 'advocate').toString();
      final role = ['mainAdmin', 'coAdmin', 'admin'].contains(roleText) ? UserRole.admin : UserRole.advocate;
      final name = (data['name'] ?? user.phoneNumber ?? 'Advocate').toString();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(role: role, advocateName: name, isMainAdmin: roleText == 'mainAdmin')));
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { verifying = false; sending = false; error = e.message ?? e.code; });
    } on FirebaseException catch (e) {
      if (mounted) setState(() { verifying = false; sending = false; error = 'Firebase database access error: ${e.message ?? e.code}. Firestore security rules may need setup.'; });
    } catch (e) {
      if (mounted) setState(() { verifying = false; sending = false; error = e.toString(); });
    }
  }

  @override
  void dispose() { phone.dispose(); otp.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(22)), child: const Column(children: [
            Icon(Icons.account_balance, color: Colors.white, size: 44),
            SizedBox(height: 12),
            Text('KSK LAW OFFICE', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
            SizedBox(height: 5),
            Text('SECURE MOBILE LOGIN', style: TextStyle(color: Color(0xFFD6E7FA), letterSpacing: 1.5, fontSize: 11)),
          ])),
          const SizedBox(height: 28),
          const Text('Welcome', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: navy)),
          const SizedBox(height: 6),
          Text(adminMode ? 'Main Admin sign in.' : 'Sign in using your registered mobile number.'),
          const SizedBox(height: 22),
          if (adminMode) ...[
            TextField(controller: adminUsername, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Main Admin username', hintText: 'ksk25', prefixIcon: Icon(Icons.admin_panel_settings))),
            const SizedBox(height: 14),
            TextField(controller: adminPassword, obscureText: true, onSubmitted: (_) { if (!verifying) _adminSignIn(); }, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _sendAdminPasswordReset, child: const Text('Forgot password? Send reset email'))),
            FilledButton(onPressed: verifying ? null : _adminSignIn, style: FilledButton.styleFrom(backgroundColor: navy, padding: const EdgeInsets.symmetric(vertical: 16)), child: Text(verifying ? 'Signing in...' : 'Main Admin sign in')),
          ] else ...[
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number with country code', hintText: '+91XXXXXXXXXX', prefixIcon: Icon(Icons.phone_android))),
            const SizedBox(height: 14),
            if (verificationId != null) TextField(controller: otp, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '6-digit OTP', prefixIcon: Icon(Icons.sms_outlined))),
            if (verificationId == null)
              FilledButton(onPressed: sending ? null : _sendOtp, style: FilledButton.styleFrom(backgroundColor: navy, padding: const EdgeInsets.symmetric(vertical: 16)), child: Text(sending ? 'Sending OTP...' : 'Send OTP'))
            else
              FilledButton(onPressed: verifying ? null : _verifyOtp, style: FilledButton.styleFrom(backgroundColor: navy, padding: const EdgeInsets.symmetric(vertical: 16)), child: Text(verifying ? 'Verifying...' : 'Verify OTP and sign in')),
            if (verificationId != null) TextButton(onPressed: sending ? null : () => setState(() { verificationId = null; otp.clear(); error = null; }), child: const Text('Change mobile number')),
          ],
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8, bottom: 8), child: Text(error!, style: TextStyle(color: error!.startsWith('OTP sent') || error!.startsWith('Password reset email sent') ? Colors.green.shade700 : Colors.red.shade700))),
          const SizedBox(height: 10),
          TextButton(onPressed: () => setState(() { adminMode = !adminMode; error = null; verificationId = null; }), child: Text(adminMode ? 'Use advocate mobile login' : 'Main Admin login')),
          const SizedBox(height: 8),
          Text(adminMode ? 'Main Admin access is verified against the approved Firebase profile.' : 'Only Main Admin-approved mobile numbers can access office records.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      )),
    )),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.role, required this.advocateName, this.isMainAdmin = false});
  final UserRole role;
  final String advocateName;
  final bool isMainAdmin;
  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  int tab = 0;
  bool todayOnly = false;
  bool get isAdmin => widget.role == UserRole.admin;
  List<Map<String, dynamic>> get visibleTasks => isAdmin ? OfficeData.tasks : OfficeData.tasks.where((t) => t['assignee'] == widget.advocateName).toList();
  List<Map<String, dynamic>> get visibleHearings => isAdmin ? OfficeData.hearings : OfficeData.hearings.where((h) => h['advocate'] == widget.advocateName).toList();
  List<Map<String, dynamic>> get visibleCases => isAdmin ? OfficeData.cases : OfficeData.cases.where((c) => c['advocate'] == widget.advocateName).toList();
  int countTasks(String status) => visibleTasks.where((t) => t['status'] == status).length;
  List<String> get tabs => isAdmin ? ['Home', 'Tasks', 'Cases', 'Hearings', 'Office'] : ['Home', 'Tasks', 'Cases', 'Hearings'];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[dashboard(), tasksPage(), casesPage(), hearingsPage(), if (isAdmin) officePage()];
    return Scaffold(
      appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('KSK LAW OFFICE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: .6)), Text(tabs[tab], style: const TextStyle(fontSize: 12, color: blue))]), actions: [IconButton(tooltip: 'Sign out', onPressed: () async { await FirebaseAuth.instance.signOut(); if (!context.mounted) return; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())); }, icon: const Icon(Icons.logout))]),
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
      Text('Hello, ${widget.advocateName}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: navy)),
      Text(DateTime.now().toString().split(' ').first, style: const TextStyle(color: Colors.black54)),
      const SizedBox(height: 18),
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.55, children: [
        stat('Total tasks', '${visibleTasks.length}', Icons.assignment, navy), stat('Pending', '${countTasks('Pending')}', Icons.pending_actions, Colors.orange.shade800), stat('Cases', '${OfficeData.cases.length}', Icons.folder, blue), stat('Upcoming hearings', '${upcoming.length}', Icons.event, Colors.deepPurple),
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
    if (value != null) { task['status'] = value; await OfficeData.save(); setState(() {}); }
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
      leading: const CircleAvatar(backgroundColor: paleBlue, child: Icon(Icons.verified_user, color: navy)),
      title: const Text('Advocate approval', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text('Review new mobile registrations and grant office access'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvocateApprovalsPage())),
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
    _sectionHeader('Advocates', Icons.groups, () => _add('advocate')),
    Text('${OfficeData.advocates.length}/10 advocates'),
    ...OfficeData.advocates.map((a) => Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person_outline)), title: Text(a['name'].toString()), subtitle: Text(a['email'].toString()), trailing: Text('${OfficeData.tasks.where((t) => t['assignee'] == a['name']).length} tasks')))),
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
