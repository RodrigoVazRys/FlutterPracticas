import 'package:flutter/foundation.dart';
import '../models/record.dart';
import 'fcm_service.dart';

class MemoryDbService extends ChangeNotifier {
  final List<MedicalRecord> _records = [
    const MedicalRecord(id: '1', patientName: 'Juan Perez', diagnosis: 'Gripe'),
    const MedicalRecord(id: '2', patientName: 'Maria Lopez', diagnosis: 'Migraña'),
    const MedicalRecord(id: '3', patientName: 'Carlos Diaz', diagnosis: 'Fractura'),
  ];

  MemoryDbService() {
    // Escucha globalmente los comandos FCM, sin importar en qué pantalla esté el usuario
    FcmService.instance.onCodeReceived.listen((code) {
      final safeCode = code.trim().toLowerCase();
      if (safeCode == 'ejecutando la orden 66' || safeCode.contains('orden 66')) {
        deleteAll();
      }
    });
  }

  List<MedicalRecord> get records => List.unmodifiable(_records);

  void deleteRecord(String id) {
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  void deleteAll() {
    _records.clear();
    notifyListeners();
  }
}

