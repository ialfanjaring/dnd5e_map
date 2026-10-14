
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
const HomeScreen({super.key});

@override
Widget build(BuildContext context) {
final AuthService authService = AuthService();

final User? user = authService.currentUser;

return Scaffold(
appBar: AppBar(
title: const Text('Página principal'),
actions: [
IconButton(
onPressed: () async {
await authService.logout();
},
icon: const Icon(Icons.logout),
tooltip: 'Cerrar sesión',
),
],
),
body: Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
const Icon(
Icons.account_circle,
size: 80,
),
const SizedBox(height: 16),
const Text(
'¡Has iniciado sesión!',
style: TextStyle(
fontSize: 24,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 12),
Text(
user?.email ?? 'Usuario autenticado',
),
const SizedBox(height: 24),
ElevatedButton.icon(
onPressed: () async {
await authService.logout();
},
icon: const Icon(Icons.logout),
label: const Text('Cerrar sesión'),
),
],
),
),
);
}
}
