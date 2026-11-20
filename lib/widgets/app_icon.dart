import 'package:flutter/material.dart';

/// Icono propio de la app (assets/icons/<nombre>.png): insignias doradas y
/// dados. Sustituye a un `Icon(...)` con el mismo tamaño.
class AppIcon extends StatelessWidget {
  final String name;
  final double size;

  const AppIcon(this.name, {super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/$name.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported, size: size),
    );
  }
}
