
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
const RegisterScreen({super.key});

@override
State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
final _formKey = GlobalKey<FormState>();

final _emailController = TextEditingController();
final _passwordController = TextEditingController();
final _confirmPasswordController = TextEditingController();

final AuthService _authService = AuthService();

bool _loading = false;

@override
void dispose() {
_emailController.dispose();
_passwordController.dispose();
_confirmPasswordController.dispose();
super.dispose();
}

Future<void> _register() async {
if (!_formKey.currentState!.validate()) {
return;
}

setState(() {
_loading = true;
});

try {
await _authService.register(
email: _emailController.text,
password: _passwordController.text,
);

if (!mounted) return;

// Firebase inicia sesión automáticamente después del registro.
// AuthWrapper mostrará la pantalla principal.
Navigator.pop(context);
} on FirebaseAuthException catch (e) {
if (!mounted) return;

String message;

switch (e.code) {
case 'email-already-in-use':
message = 'Ya existe una cuenta con ese correo.';
break;
case 'invalid-email':
message = 'El correo electrónico no es válido.';
break;
case 'weak-password':
message = 'La contraseña es demasiado débil.';
break;
case 'operation-not-allowed':
message = 'El registro por correo no está habilitado.';
break;
case 'network-request-failed':
message = 'No se ha podido conectar con Firebase.';
break;
default:
message = 'No se ha podido crear la cuenta.';
}

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text(message)),
);
} catch (_) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Se ha producido un error inesperado.'),
),
);
} finally {
if (mounted) {
setState(() {
_loading = false;
});
}
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text('Crear cuenta'),
),
body: SafeArea(
child: Center(
child: SingleChildScrollView(
padding: const EdgeInsets.all(24),
child: Form(
key: _formKey,
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
TextFormField(
controller: _emailController,
keyboardType: TextInputType.emailAddress,
decoration: const InputDecoration(
labelText: 'Correo electrónico',
border: OutlineInputBorder(),
),
validator: (value) {
if (value == null || value.trim().isEmpty) {
return 'Introduce tu correo electrónico.';
}

if (!RegExp(
r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
).hasMatch(value.trim())) {
return 'Introduce un correo válido.';
}

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
),
validator: (value) {
if (value == null || value.isEmpty) {
return 'Introduce una contraseña.';
}

if (value.length < 6) {
return 'Usa al menos 6 caracteres.';
}

return null;
},
),

const SizedBox(height: 16),

TextFormField(
controller: _confirmPasswordController,
obscureText: true,
decoration: const InputDecoration(
labelText: 'Confirmar contraseña',
border: OutlineInputBorder(),
),
validator: (value) {
if (value == null || value.isEmpty) {
return 'Confirma tu contraseña.';
}

if (value != _passwordController.text) {
return 'Las contraseñas no coinciden.';
}

return null;
},
),

const SizedBox(height: 24),

SizedBox(
width: double.infinity,
height: 48,
child: ElevatedButton(
onPressed: _loading ? null : _register,
child: _loading
? const CircularProgressIndicator()
    : const Text('Registrarse'),
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
