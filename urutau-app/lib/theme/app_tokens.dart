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

  // ── Alto contraste (tema escuro, campo sob sol) — AA WCAG 2.2 ─────────
  // Estritamente preto / amarelo / branco + cinzas que ainda passam AA.
  // O par antigo (superfície #141200, outline #332B00 bege-escuro) dava
  // bordas e cinzas de baixo contraste; agora bordas = amarelo e texto
  // secundário é claro (>=4.5:1 sobre preto).
  static const Color hcPrimary = Color(0xFFFFD600); // amarelo (realce/borda)
  static const Color hcOnPrimary = Color(0xFF000000); // texto sobre amarelo
  static const Color hcBackground = Color(0xFF000000); // fundo preto
  static const Color hcSurface = Color(0xFF0B0B0B); // card/dialogo (com borda amarela)
  static const Color hcSurface2 = Color(0xFF141414); // appbar/snackbar/popup
  static const Color hcOutline = Color(0xFFFFD600); // borda de foco (alto contraste)
  static const Color hcDivider = Color(0xFF9A9A9A); // divisor (>=3:1, não-texto)
  static const Color hcText = Color(0xFFFFFFFF); // texto principal
  static const Color hcTextMuted = Color(0xFFC9C9C9); // texto secundário (>=4.5:1)
  static const Color hcDisabled = Color(0xFF6E6E6E); // controle desabilitado (>=3:1)

  // ── Kanagawa (3º tema, escuro) — paleta kanagawa.nvim (exata) ─────────
  static const Color kwFujiWhite = Color(0xFFDCD7BA);
  static const Color kwSumiInk = Color(0xFF16161D);
  static const Color kwWaveBlue1 = Color(0xFF223249);
  static const Color kwDragonBlue = Color(0xFF7E9CD8);
  static const Color kwLightBlue = Color(0xFF7FB4CA);
  static const Color kwCrystalBlue = Color(0xFF68ADCF);
  static const Color kwCarpGreen = Color(0xFF98BC6D);
  static const Color kwBoatYellow2 = Color(0xFFE6C384);
  static const Color kwSakuraPink = Color(0xFFD27E99);
  static const Color kwWaveRed = Color(0xFFE46876);
  static const Color kwSurimiOrange = Color(0xFFFFA066);
  static const Color kwSpringViolet1 = Color(0xFF938AA9);
  // Papéis do tema (pedido): surface entre sumiInk e waveBlue1.
  static const Color kwSurface = Color(0xFF1F1F28);
  static const Color kwPrimary = Color(0xFF7E9CD8);
  static const Color kwSecondary = Color(0xFF938AA9);

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
