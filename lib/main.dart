import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 1. Your Supabase details (from Project Settings > API in the dashboard)
const supabaseUrl = 'https://nhuzmoiciktvavfasico.supabase.co';
const supabaseAnonKey = 'sb_publishable_6Krt4djAO-bGO3sECO_OXw_34KNYS9X';

// A shortcut so any screen can write "supabase" to talk to your project.
SupabaseClient get supabase => Supabase.instance.client;

// Turns an error into a message a person can read.
String cleanError(Object e) {
  if (e is AuthException) return e.message;
  if (e is PostgrestException) return e.message;
  return 'Something went wrong. Please try again.';
}

// 2. Where the app starts
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // wake up Flutter's engine
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  ); // connect to Supabase and wait until ready
  runApp(const MyApp()); // show the first widget
}

// 3. The outer shell: colors and first screen. It never changes, so Stateless.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Tasks',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D47A1)),
      ),
      // If someone is already logged in, go straight to the items screen.
      home: supabase.auth.currentSession != null
          ? const ItemsScreen()
          : const LoginScreen(),
    );
  }
}

// 4. Login screen: it changes (typing, busy, status), so Stateful.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String status = ''; // message the app writes to the person
  bool busy = false; // true = working, buttons locked

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit({required bool isSignUp}) async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.length < 6) {
      setState(
          () => status = 'Enter an email and a password of 6+ characters.');
      return;
    }

    setState(() {
      busy = true;
      status = isSignUp ? 'Signing up...' : 'Logging in...';
    });

    try {
      if (isSignUp) {
        await supabase.auth.signUp(email: email, password: password);
      } else {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }

      // Only runs if the line above did not fail
      if (mounted && supabase.auth.currentSession != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ItemsScreen()),
        );
      } else if (mounted) {
        // Happens when email confirmation is turned on in Supabase
        setState(() => status = 'Check your email to confirm your account.');
      }
    } catch (e) {
      if (mounted) setState(() => status = cleanError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  onSubmitted: (_) => submit(isSignUp: false),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: busy ? null : () => submit(isSignUp: false),
                    child: const Text('Log in'),
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : () => submit(isSignUp: true),
                  child: const Text('Create account'),
                ),
                const SizedBox(height: 8),
                Text(status, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 5. Items screen: loads a list from your database.
class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error; // the ? means it can be empty (null)
  final titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadAll(); // runs once when the screen opens
  }

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  Future<void> loadAll() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data =
          await supabase.from('items').select().order('id', ascending: false);
      if (!mounted) return;
      setState(() => items = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      if (mounted) setState(() => error = cleanError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addItem() async {
    final title = titleController.text.trim();
    if (title.isEmpty) return;
    try {
      await supabase.from('items').insert({'title': title});
      titleController.clear();
      await loadAll();
    } catch (e) {
      if (mounted) setState(() => error = cleanError(e));
    }
  }

  Future<void> logOut() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Items'),
        actions: [
          IconButton(
            onPressed: logOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Row: text box and Add button side by side
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: titleController,
                    onSubmitted: (_) => addItem(),
                    decoration: const InputDecoration(
                      labelText: 'New item',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(onPressed: addItem, child: const Text('Add')),
              ],
            ),
            const SizedBox(height: 16),
            // The list takes all the space that is left
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                      ? Center(child: Text(error!))
                      : items.isEmpty
                          ? const Center(child: Text('No items yet.'))
                          : ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return ListTile(
                                  title: Text('${item['title']}'),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}