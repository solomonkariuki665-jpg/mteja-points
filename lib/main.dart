import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ====== EDIT ONLY THESE 4 LINES ======
const supabaseUrl = 'https://fhajsobxeyadsxhloefo.supabase.co';
const supabaseKey = 'sb_publishable_1VqdPp4liC_zZhAnCJGzqQ_TEUXdDoN';
const testEmail = 'solomonkariuki665@gmail.com';
const testPassword = 'Solo0717415921@';
// =====================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: AddPointScreen());
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

  // TEMPORARY: logs in automatically with the test user.
  // A real login screen comes later.
  Future<void> loadShop() async {
    try {
      if (supabase.auth.currentUser == null) {
        await supabase.auth.signInWithPassword(
          email: testEmail,
          password: testPassword,
        );
      }
      final shop =
          await supabase.from('shops').select('id, name').limit(1).maybeSingle();
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
      setState(() => status = 'Error: ${_clean(e)}');
    }
  }

  String _clean(Object e) => e is PostgrestException ? e.message : e.toString();

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
      setState(() {
        status = 'Point added! This customer now has $total visit(s) here.';
      });
      phoneController.clear();
    } catch (e) {
      setState(() => status = 'Error: ${_clean(e)}');
    } finally {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(shopName)),
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