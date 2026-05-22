import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color verdeInstitucional = Color(0xFF006657);
  static const Color oroInstitucional = Color(0xFFBC955C);
  static const Color guindaInstitucional = Color(0xFF691C32);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Protección Antifuga - IMSS Bienestar',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: verdeInstitucional,
          primary: verdeInstitucional,
          secondary: oroInstitucional,
          tertiary: guindaInstitucional,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();

  static const platform = MethodChannel('com.kazedev.app/security');

  @override
  void initState() {
    super.initState();
    _actualizarSeguridadPantalla(true);
  }

  @override
  void dispose() {
    _actualizarSeguridadPantalla(false);
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _actualizarSeguridadPantalla(bool activar) async {
    try {
      await platform.invokeMethod('toggleSecure', activar);
      debugPrint("✅ Bandera de seguridad FLAG_SECURE actualizada a: $activar");
    } catch (e) {
      debugPrint("⚠️ ERROR CRÍTICO: No se encontró el canal nativo. Detalle: $e");
    }
  }

  void _procesarLogin() {
    if (_formKey.currentState!.validate()) {
      if (_usuarioController.text == 'admin' && _passwordController.text == '123456') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario o contraseña incorrectos (Prueba con admin y 123456)'),
            backgroundColor: MyApp.guindaInstitucional,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: const Text(
          'IMSS Bienestar - Login Seguro',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: MyApp.verdeInstitucional,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_hospital, size: 80, color: MyApp.guindaInstitucional),
                  const SizedBox(height: 15),
                  Container(height: 4, width: 60, color: MyApp.oroInstitucional),
                  const SizedBox(height: 25),
                  const Text(
                    'Portal de Acceso Seguro',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: MyApp.verdeInstitucional),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Esta ventana cuenta con protección activa de datos nativa.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 35),
                  TextFormField(
                    controller: _usuarioController,
                    decoration: const InputDecoration(
                      labelText: 'Usuario o Matrícula',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge, color: MyApp.verdeInstitucional),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Ingresa tu usuario';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock, color: MyApp.verdeInstitucional),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Ingresa tu contraseña';
                      if (value.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 35),
                  ElevatedButton(
                    onPressed: _procesarLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyApp.verdeInstitucional,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Iniciar Sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Principal', style: TextStyle(color: Colors.white)),
        backgroundColor: MyApp.verdeInstitucional,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 100, color: Colors.green),
            const SizedBox(height: 20),
            const Text('¡Ingreso Exitoso!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                'Aquí ya se desactivó el FLAG_SECURE nativo mediante el dispose(). Ya puedes tomar capturas con normalidad.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 40),
            OutlinedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('Cerrar Sesión'),
            ),
          ],
        ),
      ),
    );
  }
}