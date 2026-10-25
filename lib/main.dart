import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ====== EDIT ONLY THESE 4 LINES ======
const supabaseUrl = 'https://fhajsobxeyadsxhloefo.supabase.co';
const supabaseKey = 'sb_publishable_1VqdPp4liC_zZhAnCJGzqQ_TEUXdDoN';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

String cleanError(Object e) {
  if (e is AuthException) return e.message;
  if (e is PostgrestException) return e.message;
  return e.toString();
}

// Shows the login screen if nobody is logged in,
// otherwise shows the add-point screen.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mteja Points',
      home: StreamBuilder<AuthState>(
        stream: supabase.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = supabase.auth.currentSession;
          return session == null ? const LoginScreen() : const AddPointScreen();
        },
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String status = '';
  bool busy = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => status = 'Type your email and password.');
      return;
    }
    setState(() {
      busy = true;
      status = 'Logging in...';
    });
    try {
      await supabase.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      if (mounted) setState(() => status = 'Login failed: ${cleanError(e)}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mteja Points - Shop login')),
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
                  onSubmitted: (_) => login(),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: busy ? null : login,
                    child: const Text('Log in'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(status, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AddPointScreen extends StatefulWidget {
  const AddPointScreen({super.key});

  @override
  State<AddPointScreen> createState() => _AddPointScreenState();
}

class _AddPointScreenState extends State<AddPointScreen> {
  final phoneController = TextEditingController();
  String? shopId;
  String shopName = 'Mteja Points';
  String status = 'Loading shop...';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    loadShop();
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  Future<void> loadShop() async {
    try {
      final shop =
          await supabase.from('shops').select('id, name').limit(1).maybeSingle();
      if (!mounted) return;
      if (shop == null) {
        setState(() => status = 'No shop found for this login.');
        return;
      }
      setState(() {
        shopId = shop['id'] as String;
        shopName = shop['name'] as String;
        status = 'Ready. Type a phone number.';
      });
    } catch (e) {
      if (mounted) setState(() => status = 'Error: ${cleanError(e)}');
    }
  }

  // Turns 0712345678 or +254712345678 into 254712345678
  String? normalizePhone(String input) {
    var p = input.replaceAll(RegExp(r'[\s\-+]'), '');
    if (p.startsWith('0')) p = '254${p.substring(1)}';
    if (!RegExp(r'^254[17][0-9]{8}$').hasMatch(p)) return null;
    return p;
  }

  Future<void> addPoint() async {
    if (shopId == null) return;
    final phone = normalizePhone(phoneController.text);
    if (phone == null) {
      setState(() => status = 'That phone number looks wrong. Try 0712345678.');
      return;
    }
    setState(() {
      busy = true;
      status = 'Saving...';
    });
    try {
      final total = await supabase.rpc(
        'add_point',
        params: {'p_shop_id': shopId, 'p_phone': phone},
      );
      if (!mounted) return;
      setState(() {
        status = 'Point added! This customer now has $total visit(s) here.';
      });
      phoneController.clear();
    } catch (e) {
      if (mounted) setState(() => status = 'Error: ${cleanError(e)}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(shopName),
        actions: [
          TextButton(
            onPressed: () => supabase.auth.signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Customer phone number',
                    hintText: '0712345678',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (busy || shopId == null) ? null : addPoint,
                    child: const Text('Add point'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(status, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}