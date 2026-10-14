import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
const LoginScreen({super.key});

@override
State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
final _formKey = GlobalKey<FormState>();

final _emailController = TextEditingController();
final _passwordController = TextEditingController();

final AuthService _authService = AuthService();

bool _loading = false;
bool _hidePassword = true;

@override
void dispose() {
_emailController.dispose();
_passwordController.dispose();
super.dispose();
}

Future<void> _login() async {
if (!_formKey.currentState!.validate()) {
return;
}

setState(() {
_loading = true;
});

try {
await _authService.login(
email: _emailController.text,
password: _passwordController.text,
);

// AuthWrapper detectará automáticamente el inicio
// de sesión y mostrará la pantalla correspondiente.
} on FirebaseAuthException catch (e) {
if (!mounted) return;

String message;

switch (e.code) {
case 'invalid-email':
message = 'El correo electrónico no es válido.';
break;
case 'invalid-credential':
case 'wrong-password':
case 'user-not-found':
message = 'Correo o contraseña incorrectos.';
break;
case 'user-disabled':
message = 'Esta cuenta está deshabilitada.';
break;
case 'too-many-requests':
message = 'Demasiados intentos. Inténtalo más tarde.';
break;
case 'network-request-failed':
message = 'No se ha podido conectar con Firebase.';
break;
case 'operation-not-allowed':
message = 'El inicio de sesión no está habilitado.';
break;
default:
message = 'No se ha podido iniciar sesión.';
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
body: SafeArea(
child: Center(
child: SingleChildScrollView(
padding: const EdgeInsets.all(24),
child: Form(
key: _formKey,
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
const Icon(
Icons.lock_outline,
size: 80,
),
const SizedBox(height: 20),

const Text(
'Iniciar sesión',
style: TextStyle(
fontSize: 28,
fontWeight: FontWeight.bold,
),
),

const SizedBox(height: 32),

TextFormField(
controller: _emailController,
keyboardType: TextInputType.emailAddress,
autofillHints: const [
AutofillHints.email,
],
decoration: const InputDecoration(
labelText: 'Correo electrónico',
prefixIcon: Icon(Icons.email_outlined),
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
obscureText: _hidePassword,
autofillHints: const [
AutofillHints.password,
],
decoration: InputDecoration(
labelText: 'Contraseña',
prefixIcon: const Icon(Icons.lock_outline),
border: const OutlineInputBorder(),
suffixIcon: IconButton(
icon: Icon(
_hidePassword
? Icons.visibility
    : Icons.visibility_off,
),
onPressed: () {
setState(() {
_hidePassword = !_hidePassword;
});
},
),
),
validator: (value) {
if (value == null || value.isEmpty) {
return 'Introduce tu contraseña.';
}

return null;
},
),

const SizedBox(height: 24),

SizedBox(
width: double.infinity,
height: 48,
child: ElevatedButton(
onPressed: _loading ? null : _login,
child: _loading
? const CircularProgressIndicator()
    : const Text('Entrar'),
),
),

const SizedBox(height: 12),

TextButton(
onPressed: _loading
? null
    : () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
const RegisterScreen(),
),
);
},
child: const Text(
'¿No tienes cuenta? Regístrate',
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
