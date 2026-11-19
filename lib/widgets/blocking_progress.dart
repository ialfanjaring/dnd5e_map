import 'package:flutter/material.dart';

/// Ejecuta [task] mostrando una pantalla de carga que bloquea toda la
/// interacción hasta que termina.
///
/// Usa una capa del Overlay raíz (no una ruta): así no le afectan los
/// `pop` de otras pantallas mientras la operación sigue en marcha.
Future<T> runBlocking<T>(
  BuildContext context,
  String message,
  Future<T> Function() task,
) async {
  final overlay = Overlay.of(context, rootOverlay: true);

  final entry = OverlayEntry(
    builder: (_) => PopScope(
      canPop: false,
      child: Stack(
        children: [
          // Absorbe todos los toques
          const ModalBarrier(color: Colors.black54, dismissible: false),
          Center(
            child: Material(
              borderRadius: BorderRadius.circular(16),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 20,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  overlay.insert(entry);
  try {
    return await task();
  } finally {
    entry.remove();
  }
}
