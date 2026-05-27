/// Stub para plataformas não-web.
/// No mobile/desktop, o download é feito via share_plus.
void downloadFileBytes(List<int> bytes, String fileName) {
  // Não faz nada no mobile — o chamador usa share_plus.
  throw UnsupportedError('downloadFileBytes só é suportado na web.');
}
