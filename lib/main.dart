import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safe_device/safe_device.dart';
import 'package:permission_handler/permission_handler.dart';

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
      builder: (context, child) {
        return SecurityWrapper(child: child!);
      },
      home: const LoginScreen(),
    );
  }
}

class SecurityWrapper extends StatefulWidget {
  final Widget child;
  const SecurityWrapper({super.key, required this.child});

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper> with WidgetsBindingObserver {
  bool _isChecking = true;
  bool _isFakeGps = false;
  bool _sinPermisoUbicacion = false;
  Timer? _timer;

  static const platform = MethodChannel('com.kazedev.app/security');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verificarFakeGps();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _verificarFakeGps());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isChecking = true;
      _verificarFakeGps();
    }
  }

  Future<void> _verificarFakeGps() async {
    try {
      var status = await Permission.location.request();
      if (!status.isGranted) {
        setState(() {
          _sinPermisoUbicacion = true;
          _isFakeGps = false;
          _isChecking = false;
        });
        return;
      }

      bool pluginMock = await SafeDevice.isMockLocation;

      bool nativeMock = false;
      try {
        nativeMock = await platform.invokeMethod('isMockLocation');
      } catch (e) {
        debugPrint("Método nativo de ubicación no encontrado");
      }

      setState(() {
        _sinPermisoUbicacion = false;
        _isFakeGps = pluginMock || nativeMock;
        _isChecking = false;
      });
    } catch (e) {
      debugPrint("Error verificando Fake GPS: $e");
      setState(() {
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: MyApp.verdeInstitucional,
          child: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    if (_sinPermisoUbicacion) {
      return const Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: MyApp.guindaInstitucional,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_disabled, size: 100, color: Colors.white),
                SizedBox(height: 20),
                Text(
                  'Permiso Requerido',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    'Para garantizar tu seguridad, necesitamos el permiso de ubicación.\nEsto nos permite verificar que no se usen ubicaciones falsas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isFakeGps) {
      return const Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: MyApp.guindaInstitucional,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, size: 100, color: Colors.white),
                SizedBox(height: 20),
                Text(
                  '¡Acceso Denegado!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    'Se ha detectado el uso de un Fake GPS o ubicación simulada.\nPor seguridad, la aplicación no puede ejecutarse.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
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