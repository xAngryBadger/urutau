import 'package:flutter/material.dart';

/// Tokens de design do Urutau — FONTE ÚNICA.
/// Os dois temas (claro e alto contraste) derivam daqui; telas não devem
/// inventar cores soltas (antes cada form usava Colors.teal à vontade).
///
/// Paleta da marca: verde-sálvia (floresta) + bege-dourado (terra/luz),
/// fundo off-white quente. Alto contraste: preto + amarelo para sol direto.
abstract final class AppTokens {
  // ── Marca (tema claro) ──────────────────────────────────────────────
  static const Color brandPrimary = Color(0xFF5A6B5C); // verde-sálvia
  static const Color brandSecondary = Color(0xFFC4A47C); // bege-dourado
  static const Color brandBackground = Color(0xFFF9F6F0); // off-white quente
  static const Color brandSurface = Color(0xFFFFFFFF);

  // ── Alto contraste (tema escuro, campo sob sol) ─────────────────────
  static const Color hcPrimary = Color(0xFFFFD600); // amarelo
  static const Color hcOnPrimary = Color(0xFF000000);
  static const Color hcBackground = Color(0xFF000000);
  static const Color hcSurface = Color(0xFF141200);
  static const Color hcSurface2 = Color(0xFF1A1500);
  static const Color hcOutline = Color(0xFF332B00);
  static const Color hcText = Color(0xFFFFFFFF);

  // ── Status de verificação (RG-02) — um lugar só pra cor+ícone ───────
  static const Color statusPendente = Color(0xFFE8A13A); // âmbar
  static const Color statusRevisado = Color(0xFF3A7BD5); // azul
  static const Color statusAprovado = Color(0xFF3E8E4F); // verde

  static Color statusColor(String status) => switch (status) {
        'aprovado' => statusAprovado,
        'revisado' => statusRevisado,
        _ => statusPendente,
      };

  static IconData statusIcon(String status) => switch (status) {
        'aprovado' => Icons.verified,
        'revisado' => Icons.fact_check_outlined,
        _ => Icons.hourglass_top,
      };

  static String statusLabel(String status) => switch (status) {
        'aprovado' => 'Aprovado',
        'revisado' => 'Revisado',
        _ => 'Pendente',
      };

  // ── MRV / carbono ───────────────────────────────────────────────────
  static const Color mrvGreen = Color(0xFF2E7D32);
  static const Color mrvGreenBg = Color(0xFFE8F5E9);
  static const Color danger = Color(0xFFC62828);

  // ── Semânticas usadas nos forms (mesmos valores de antes, só nomeadas) ──
  static const Color accentTeal = Color(0xFF009688); // == Colors.teal
  static const Color success = Color(0xFF4CAF50); // == Colors.green
  static const Color successBg = Color(0xFFE8F5E9); // == Colors.green.shade50
  static const Color successDark = Color(0xFF1B5E20); // == Colors.green.shade900
  static const Color warning = Color(0xFFFF9800); // == Colors.orange
  static const Color neutralBg = Color(0xFFF5F5F5); // == Colors.grey.shade100

  // ── Escala de espaçamento e formas ───────────────────────────────────
  static const double spaceXs = 4;
  static const double spaceS = 8;
  static const double spaceM = 12;
  static const double spaceL = 16;
  static const double spaceXl = 24;
  static const double spaceXxl = 32;

  static const double radiusS = 8;
  static const double radiusM = 12;
  static const double radiusL = 16;

  static const double buttonHeight = 52;
  static const double cardPadding = 12;

  static const BorderRadius radiusCard = BorderRadius.all(Radius.circular(radiusM));

  // ── Tipografia ──────────────────────────────────────────────────────
  static const double fontTitle = 20;
  static const double fontBody = 16;
  static const double fontSmall = 13;
  static const double fontCaption = 11;
}
