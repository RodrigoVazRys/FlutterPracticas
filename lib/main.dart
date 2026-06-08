import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safe_device/safe_device.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─── Constantes de almacén encriptado ────────────────────────────────────────
const _kTokenKey = 'session_token';
const _kTimeoutKey = 'inactivity_timeout_seconds';
const int _kDefaultTimeout = 15;

void main() {
  runApp(const MyApp());
}

// ─── App principal ────────────────────────────────────────────────────────────
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
      builder: (context, child) => SecurityWrapper(child: child!),
      home: const SplashRouter(),
    );
  }
}

// ─── SplashRouter: decide si retomar sesión o ir a Login ─────────────────────
class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});
  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final storage = SecureSessionStorage.instance;
    final token = await storage.getToken();

    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      // Token guardado → sesión activa anterior, ir directo a Home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen(timeoutSeconds: 15)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: MyApp.verdeInstitucional,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

// ─── Servicio de almacenamiento encriptado (Singleton) ───────────────────────
class SecureSessionStorage {
  SecureSessionStorage._();
  static final SecureSessionStorage instance = SecureSessionStorage._();

  final FlutterSecureStorage _store = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Guarda el token de sesión encriptado
  Future<void> saveToken(String token) =>
      _store.write(key: _kTokenKey, value: token);

  /// Lee el token de sesión
  Future<String?> getToken() => _store.read(key: _kTokenKey);

  /// Elimina el token (logout)
  Future<void> clearToken() => _store.delete(key: _kTokenKey);

  /// Guarda el tiempo de inactividad en segundos
  Future<void> saveTimeout(int seconds) =>
      _store.write(key: _kTimeoutKey, value: seconds.toString());

  /// Lee el tiempo de inactividad (devuelve default si no existe)
  Future<int> getTimeout() async {
    final val = await _store.read(key: _kTimeoutKey);
    return int.tryParse(val ?? '') ?? _kDefaultTimeout;
  }
}

// ─── InactivityManager: detecta gestos y dispara logout ─────────────────────
class InactivityManager extends StatefulWidget {
  final Widget child;
  final VoidCallback onTimeout;
  final int timeoutSeconds;

  const InactivityManager({
    super.key,
    required this.child,
    required this.onTimeout,
    required this.timeoutSeconds,
  });

  @override
  State<InactivityManager> createState() => _InactivityManagerState();
}

class _InactivityManagerState extends State<InactivityManager>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetTimer();
  }

  @override
  void didUpdateWidget(InactivityManager old) {
    super.didUpdateWidget(old);
    if (old.timeoutSeconds != widget.timeoutSeconds) _resetTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Cuando la app va a background, registramos el momento
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_backgroundedAt != null) {
        final elapsed = DateTime.now().difference(_backgroundedAt!);
        if (elapsed.inSeconds >= widget.timeoutSeconds) {
          _timer?.cancel();
          widget.onTimeout();
          return;
        }
      }
      _resetTimer();
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(Duration(seconds: widget.timeoutSeconds), widget.onTimeout);
  }

  void _onUserInteraction(PointerEvent _) => _resetTimer();

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onUserInteraction,
      onPointerMove: _onUserInteraction,
      onPointerSignal: _onUserInteraction,
      child: widget.child,
    );
  }
}

// ─── SecurityWrapper: fake GPS / permiso de ubicación ────────────────────────
class SecurityWrapper extends StatefulWidget {
  final Widget child;
  const SecurityWrapper({super.key, required this.child});

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper>
    with WidgetsBindingObserver {
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
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _verificarFakeGps(),
    );
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
      setState(() => _isChecking = true);
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
      } catch (_) {
        debugPrint('Método nativo de ubicación no encontrado');
      }

      setState(() {
        _sinPermisoUbicacion = false;
        _isFakeGps = pluginMock || nativeMock;
        _isChecking = false;
      });
    } catch (e) {
      debugPrint('Error verificando Fake GPS: $e');
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: MyApp.verdeInstitucional,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    if (_sinPermisoUbicacion) {
      return _blocker(
        Icons.location_disabled,
        'Permiso Requerido',
        'Para garantizar tu seguridad necesitamos el permiso de ubicación. '
            'Esto nos permite verificar que no se usen ubicaciones falsas.',
      );
    }

    if (_isFakeGps) {
      return _blocker(
        Icons.location_off,
        '¡Acceso Denegado!',
        'Se ha detectado el uso de un Fake GPS o ubicación simulada. '
            'Por seguridad, la aplicación no puede ejecutarse.',
      );
    }

    return widget.child;
  }

  Widget _blocker(IconData icon, String title, String msg) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: MyApp.guindaInstitucional,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 100, color: Colors.white),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── LoginScreen ──────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

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
      debugPrint('⚠️ FLAG_SECURE error: $e');
    }
  }

  Future<void> _procesarLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    // Simula llamada a API — reemplaza con tu endpoint real
    await Future.delayed(const Duration(milliseconds: 600));

    if (_usuarioController.text == 'admin' &&
        _passwordController.text == '123456') {
      // Genera token ficticio — en producción usa el JWT del backend
      final token = base64Encode(
        utf8.encode('admin:${DateTime.now().toIso8601String()}'),
      );

      final storage = SecureSessionStorage.instance;
      await storage.saveToken(token);

      // Leer timeout configurado (o usar default)
      final timeout = await storage.getTimeout();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(timeoutSeconds: timeout)),
      );
    } else {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Usuario o contraseña incorrectos (Prueba con admin / 123456)',
          ),
          backgroundColor: MyApp.guindaInstitucional,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: const Text(
          'IMSS Bienestar - Login Seguro',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
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
                  const Icon(
                    Icons.local_hospital,
                    size: 80,
                    color: MyApp.guindaInstitucional,
                  ),
                  const SizedBox(height: 15),
                  Container(
                    height: 4,
                    width: 60,
                    color: MyApp.oroInstitucional,
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Portal de Acceso Seguro',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: MyApp.verdeInstitucional,
                    ),
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
                      prefixIcon: Icon(
                        Icons.badge,
                        color: MyApp.verdeInstitucional,
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa tu usuario'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(
                        Icons.lock,
                        color: MyApp.verdeInstitucional,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Ingresa tu contraseña';
                      }
                      if (v.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 35),
                  _loading
                      ? const CircularProgressIndicator(
                          color: MyApp.verdeInstitucional,
                        )
                      : ElevatedButton(
                          onPressed: _procesarLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MyApp.verdeInstitucional,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Iniciar Sesión',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

// ─── HomeScreen: protegida por InactivityManager ─────────────────────────────
class HomeScreen extends StatefulWidget {
  final int timeoutSeconds;
  const HomeScreen({super.key, required this.timeoutSeconds});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _timeoutSeconds;
  int _remainingSeconds = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _timeoutSeconds = widget.timeoutSeconds;
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _remainingSeconds = _timeoutSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _resetCountdown() => _startCountdown();

  Future<void> _logout({bool byTimeout = false}) async {
    _countdownTimer?.cancel();
    final storage = SecureSessionStorage.instance;
    await storage.clearToken();

    if (!mounted) return;

    if (byTimeout) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesión cerrada por inactividad'),
          backgroundColor: MyApp.guindaInstitucional,
          duration: Duration(seconds: 3),
        ),
      );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _cambiarTimeout(int nuevosSegundos) async {
    await SecureSessionStorage.instance.saveTimeout(nuevosSegundos);
    if (!mounted) return;

    setState(() => _timeoutSeconds = nuevosSegundos);
    _startCountdown();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tiempo de inactividad actualizado a $nuevosSegundos segundos',
        ),
        backgroundColor: MyApp.verdeInstitucional,
      ),
    );
  }

  void _mostrarDialogoTimeout() {
    int seleccion = _timeoutSeconds;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tiempo de inactividad'),
        content: StatefulBuilder(
          builder: (ctx2, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [5, 10, 15, 30, 60, 120]
                .map(
                  (seconds) => ListTile(
                    title: Text('$seconds segundos'),
                    trailing: seleccion == seconds
                        ? const Icon(
                            Icons.check,
                            color: MyApp.verdeInstitucional,
                          )
                        : null,
                    onTap: () => setS(() => seleccion = seconds),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MyApp.verdeInstitucional,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _cambiarTimeout(seleccion);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color get _timerColor {
    if (_remainingSeconds <= 30) return MyApp.guindaInstitucional;
    if (_remainingSeconds <= 60) return Colors.orange;
    return MyApp.verdeInstitucional;
  }

  @override
  Widget build(BuildContext context) {
    return InactivityManager(
      timeoutSeconds: _timeoutSeconds,
      onTimeout: () => _logout(byTimeout: true),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Panel Principal',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: MyApp.verdeInstitucional,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.timer, color: Colors.white),
              tooltip: 'Configurar inactividad',
              onPressed: _mostrarDialogoTimeout,
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Cerrar sesión',
              onPressed: () => _logout(),
            ),
          ],
        ),
        body: GestureDetector(
          // Cualquier toque en el body también resetea el countdown visual
          onTap: _resetCountdown,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 100,
                  color: Colors.green,
                ),
                const SizedBox(height: 20),
                const Text(
                  '¡Ingreso Exitoso!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),

                // ── Contador de inactividad ──────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: _timerColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _timerColor, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            color: _timerColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Cierre por inactividad en:',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTime(_remainingSeconds),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: _timerColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Timeout: $_timeoutSeconds segundos  •  Toca para reiniciar',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    'Aquí el FLAG_SECURE se desactivó vía dispose().\nToca la pantalla para reiniciar el timer de inactividad.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 40),
                OutlinedButton.icon(
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('Cambiar tiempo de inactividad'),
                  onPressed: _mostrarDialogoTimeout,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar Sesión'),
                  onPressed: () => _logout(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
