import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // FIX 1: Import added
import 'dart:convert';

void main() => runApp(const TaskApp());

enum Priority { low, medium, high }
enum UserRole { admin, staff }

// --- MODELS ---

class AppUser {
  final String email;
  final String password;
  final UserRole role;

  AppUser({required this.email, required this.password, required this.role});

  Map<String, dynamic> toJson() => {'email': email, 'password': password, 'role': role.index};
  factory AppUser.fromJson(Map<String, dynamic> json) => 
    AppUser(email: json['email'], password: json['password'], role: UserRole.values[json['role']]);
}

class TaskUpdate {
  final String text;
  final DateTime timestamp;
  TaskUpdate(this.text, this.timestamp);

  Map<String, dynamic> toJson() => {'text': text, 'timestamp': timestamp.toIso8601String()};
  factory TaskUpdate.fromJson(Map<String, dynamic> json) => 
    TaskUpdate(json['text'], DateTime.parse(json['timestamp']));
}

class Task {
  String title;
  String description;
  List<TaskUpdate> updates;
  DateTime date;
  bool isDone;
  Priority priority;

  Task({
    required this.title,
    this.description = "",
    List<TaskUpdate>? updates,
    required this.date,
    this.isDone = false,
    this.priority = Priority.low,
  }) : updates = updates ?? [];

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'updates': updates.map((u) => u.toJson()).toList(),
    'date': date.toIso8601String(),
    'isDone': isDone,
    'priority': priority.index,
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    title: json['title'],
    description: json['description'],
    updates: (json['updates'] as List).map((u) => TaskUpdate.fromJson(u)).toList(),
    date: DateTime.parse(json['date']),
    isDone: json['isDone'],
    priority: Priority.values[json['priority']],
  );
}

// --- MAIN APP ---

class TaskApp extends StatelessWidget {
  const TaskApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LegacyFlow CSCAA',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
      ),
      home: const AuthCheck(),
    );
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});
  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  bool? _isLoggedIn;
  UserRole _role = UserRole.staff;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      _role = UserRole.values[prefs.getInt('currentUserRole') ?? 1];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return _isLoggedIn! ? MainNavigationScreen(initialRole: _role) : const LoginScreen();
  }
}

// --- LOGIN SCREEN ---

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String _error = "";

  Future<void> _login() async {
    final prefs = await SharedPreferences.getInstance();
    List<AppUser> users = [AppUser(email: "admin@cscaa.com", password: "admin123", role: UserRole.admin)];
    
    final savedUsers = prefs.getString('registered_users');
    if (savedUsers != null) {
      users.addAll((jsonDecode(savedUsers) as List).map((u) => AppUser.fromJson(u)));
    }

    try {
      final user = users.firstWhere((u) => u.email == _email.text && u.password == _pass.text);
      await prefs.setBool('isLoggedIn', true);
      await prefs.setInt('currentUserRole', user.role.index);
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => MainNavigationScreen(initialRole: user.role)));
    } catch (e) {
      setState(() => _error = "Invalid credentials");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.account_balance, size: 80, color: Color(0xFF6C63FF)),
              const SizedBox(height: 20),
              const Text("LegacyFlow CSCAA", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              TextField(controller: _email, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder())),
              if (_error.isNotEmpty) Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error, style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _login, child: const Text("Sign In")),
            ],
          ),
        ),
      ),
    );
  }
}

// --- MAIN NAVIGATION ---

class MainNavigationScreen extends StatefulWidget {
  final UserRole initialRole;
  const MainNavigationScreen({super.key, required this.initialRole});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  List<Task> _tasks = [];
  late UserRole _currentRole;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.initialRole;
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getString('cscaa_tasks');
    if (tasksJson != null) {
      setState(() => _tasks = (jsonDecode(tasksJson) as List).map((t) => Task.fromJson(t)).toList());
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cscaa_tasks', jsonEncode(_tasks.map((t) => t.toJson()).toList()));
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginScreen()));
  }

  void _showStaffRegistration() {
    final emailController = TextEditingController();
    final passController = TextEditingController();
    
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text("Register Staff"),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              TextField(controller: emailController, decoration: const InputDecoration(labelText: "Staff Email", border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: passController, obscureText: true, decoration: const InputDecoration(labelText: "Temporary Password", border: OutlineInputBorder())),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () async {
                    if (emailController.text.isNotEmpty && passController.text.isNotEmpty) {
                      final prefs = await SharedPreferences.getInstance();
                      List<dynamic> users = jsonDecode(prefs.getString('registered_users') ?? "[]");
                      users.add(AppUser(email: emailController.text, password: passController.text, role: UserRole.staff).toJson());
                      await prefs.setString('registered_users', jsonEncode(users));
                      if (mounted) Navigator.pop(context);
                    }
                  }, 
                  child: const Text("Create Staff Account")
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  void _showTaskPage({int? index}) {
    final isEdit = index != null;
    final titleC = TextEditingController(text: isEdit ? _tasks[index].title : "");
    final descC = TextEditingController(text: isEdit ? _tasks[index].description : "");
    DateTime selectedDate = isEdit ? _tasks[index].date : DateTime.now();

    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setM) => Scaffold(
          appBar: AppBar(
            title: Text(isEdit ? "Edit Task" : "New Task"),
            leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            actions: [
              TextButton(
                onPressed: () {
                  if (titleC.text.isNotEmpty) {
                    setState(() {
                      if (isEdit) {
                        _tasks[index].title = titleC.text;
                        _tasks[index].description = descC.text;
                        _tasks[index].date = selectedDate;
                      } else {
                        _tasks.add(Task(title: titleC.text, description: descC.text, date: selectedDate));
                      }
                      _tasks.sort((a,b) => a.date.compareTo(b.date));
                    });
                    _saveData();
                    Navigator.pop(context);
                  }
                }, 
                child: const Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold))
              )
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(controller: titleC, decoration: const InputDecoration(labelText: "Task Title", border: OutlineInputBorder())),
              const SizedBox(height: 20),
              TextField(controller: descC, maxLines: 5, decoration: const InputDecoration(labelText: "Instructions", border: OutlineInputBorder())),
              const SizedBox(height: 20),
              const Text("Schedule", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(DateFormat('EEEE, MMM dd, yyyy').format(selectedDate)),
                subtitle: Text(DateFormat('hh:mm a').format(selectedDate)),
                trailing: const Icon(Icons.calendar_today, color: Color(0xFF6C63FF)),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                  if (d != null) {
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDate));
                    if (t != null) setM(() => selectedDate = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                  }
                },
              ),
              if (isEdit) ...[
                const Divider(height: 40),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _tasks.removeAt(index));
                    _saveData();
                    Navigator.pop(context);
                  }, 
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text("Delete Task", style: TextStyle(color: Colors.red))
                )
              ]
            ],
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeScreen(
        tasks: _tasks, role: _currentRole, 
        onChanged: () { setState(() {}); _saveData(); },
        onEdit: (i) => _showTaskPage(index: i),
        onAddUpdate: (i) => _showUpdateSheet(i),
      ),
      CalendarViewScreen(tasks: _tasks, role: _currentRole, onRefresh: () { setState(() {}); _saveData(); }),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("CSCAA", style: TextStyle(fontWeight: FontWeight.w900)),
        leading: IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        actions: [
          if (_currentRole == UserRole.admin) 
            IconButton(icon: const Icon(Icons.person_add_alt_1), onPressed: _showStaffRegistration),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text(_currentRole.name.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
          )
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.assignment), label: "Tasks"),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: "Calendar"),
        ],
      ),
      floatingActionButton: _currentRole == UserRole.admin
          ? FloatingActionButton.extended(
              onPressed: () => _showTaskPage(), 
              label: const Text("New Task"),
              icon: const Icon(Icons.add)
            )
          : null,
    );
  }

  void _showUpdateSheet(int index) {
    String text = "";
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Post Progress Update", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(autofocus: true, onChanged: (v) => text = v, decoration: const InputDecoration(hintText: "What happened?", border: OutlineInputBorder())),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () {
            if (text.isNotEmpty) {
              setState(() => _tasks[index].updates.insert(0, TaskUpdate(text, DateTime.now())));
              _saveData(); Navigator.pop(c);
            }
          }, child: const Text("Post"))),
          const SizedBox(height: 24),
        ]),
      )
    );
  }
}

class HomeScreen extends StatelessWidget {
  final List<Task> tasks;
  final UserRole role;
  final VoidCallback onChanged;
  final Function(int) onEdit;
  final Function(int) onAddUpdate;

  const HomeScreen({super.key, required this.tasks, required this.role, required this.onChanged, required this.onEdit, required this.onAddUpdate});

  @override
  Widget build(BuildContext context) {
    return tasks.isEmpty ? const Center(child: Text("No Tasks Found")) : ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: tasks.length,
      itemBuilder: (c, i) => _TaskTile(task: tasks[i], role: role, onCheck: onChanged, onEdit: () => onEdit(i), onUpdate: () => onAddUpdate(i)),
    );
  }
}

class CalendarViewScreen extends StatefulWidget {
  final List<Task> tasks;
  final UserRole role;
  final VoidCallback onRefresh;
  const CalendarViewScreen({super.key, required this.tasks, required this.role, required this.onRefresh});
  @override
  State<CalendarViewScreen> createState() => _CalendarViewScreenState();
}

class _CalendarViewScreenState extends State<CalendarViewScreen> {
  DateTime _selected = DateTime.now();
  @override
  Widget build(BuildContext context) {
    final daily = widget.tasks.where((t) => t.date.day == _selected.day && t.date.month == _selected.month && t.date.year == _selected.year).toList();
    return Column(children: [
      CalendarDatePicker(initialDate: _selected, firstDate: DateTime(2020), lastDate: DateTime(2030), onDateChanged: (d) => setState(() => _selected = d)),
      const Divider(),
      Expanded(child: ListView.builder(itemCount: daily.length, itemBuilder: (c, i) => _TaskTile(task: daily[i], role: widget.role, onCheck: widget.onRefresh, onEdit: null, onUpdate: null)))
    ]);
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;
  final UserRole role;
  final VoidCallback onCheck;
  final VoidCallback? onEdit;
  final VoidCallback? onUpdate;

  const _TaskTile({required this.task, required this.role, required this.onCheck, this.onEdit, this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), 
        side: BorderSide(color: Colors.grey[200]!), // FIX 2: changed 'border' to 'side'
      ),
      child: ExpansionTile(
        leading: Checkbox(value: task.isDone, onChanged: (v) { task.isDone = v!; onCheck(); }),
        title: Text(task.title, style: TextStyle(fontWeight: FontWeight.bold, decoration: task.isDone ? TextDecoration.lineThrough : null)),
        subtitle: Text(DateFormat('hh:mm a').format(task.date)),
        trailing: (role == UserRole.admin && onEdit != null) ? IconButton(icon: const Icon(Icons.edit_note), onPressed: onEdit) : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("DETAILS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(task.description.isEmpty ? "No detailed instructions." : task.description),
              const Divider(height: 30),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("ACTIVITY LOG", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                if (role == UserRole.staff && onUpdate != null) 
                  TextButton.icon(onPressed: onUpdate, icon: const Icon(Icons.add, size: 14), label: const Text("Post Update", style: TextStyle(fontSize: 12)))
              ]),
              if (task.updates.isEmpty) const Text("Pending first update...", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
              ...task.updates.map((u) => Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.circle, size: 6, color: Color(0xFF6C63FF)),
                    const SizedBox(width: 8),
                    Expanded(child: Text("${u.text} (${DateFormat('HH:mm').format(u.timestamp)})", style: const TextStyle(fontSize: 12))),
                  ],
                ),
              )),
            ]),
          )
        ],
      ),
    );
  }
}