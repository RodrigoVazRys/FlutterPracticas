import 'package:flutter/foundation.dart';
import '../models/user.dart';

class AuthService extends ChangeNotifier {
  User? _currentUser;
  
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Simula el inicio de sesión. Falla si las credenciales no son admin/admin.
  Future<bool> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1)); // Simula red
    
    if (email == 'admin@test.com' && password == 'admin') {
      _currentUser = const User(
        id: 'admin_mock_id',
        email: 'admin@test.com',
        name: 'Administrador',
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Cierra la sesión
  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
