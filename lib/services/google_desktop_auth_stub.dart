/// Versión vacía para la web (no existe dart:io). El inicio de sesión con
/// Google en la web usa la ventana emergente de Firebase (ver auth_service).
class GoogleDesktopAuth {
  static Future<({String idToken, String accessToken})> signIn({
    required String clientId,
    required String tokenUrl,
    int port = 61797,
  }) async {
    throw UnsupportedError('El acceso de escritorio no está disponible en la web.');
  }
}
