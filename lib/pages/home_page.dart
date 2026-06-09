import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/memory_db_service.dart';
import '../services/fcm_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  void _logout() {
    context.read<AuthService>().logout();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final records = context.watch<MemoryDbService>().records;

    return Scaffold(
      appBar: AppBar(
        title: Text('Panel SUMS - ${user?.name ?? ""}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: records.isEmpty
          ? const Center(child: Text('No hay registros o han sido borrados.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final r = records[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.medical_services),
                    title: Text(r.patientName),
                    subtitle: Text(r.diagnosis),
                    // Ahora se borra vía push (Kill Switch).
                  ),
                );
              },
            ),
    );
  }
}

