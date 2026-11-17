/**
 * Gera o PDF de telas do Urutau — A4 paisagem, 1 tela por página, Helvetica,
 * mesmo formato de C:\Users\Badger\orca-rework\_telas_pdf\Orca_Painel_Telas.pdf.
 * Entrada: JPEGs em docs/_pdf-img (gerados por tools/prepare-imgs.ps1).
 * Uso: node tools/make-telas-pdf.mjs
 */
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = join(ROOT, 'docs', 'Urutau_Telas.pdf');
const IMG = (name) => join(ROOT, 'docs', '_pdf-img', name);

/** Dimensões reais lidas do header JPEG (SOF0), sem dependência externa. */
function jpegSize(buf) {
  let i = 2;
  while (i < buf.length - 9) {
    if (buf[i] !== 0xff) { i++; continue; }
    const marker = buf[i + 1];
    if (marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc) {
      return { h: buf.readUInt16BE(i + 5), w: buf.readUInt16BE(i + 7) };
    }
    i += 2 + buf.readUInt16BE(i + 2);
  }
  throw new Error('SOF0 nao encontrado');
}

const PAGES = [
  { grupo: 'App de campo (celular)', titulo: 'Home — parcelas do usuário', legenda: 'Lista com status de sync, plantas e fotos por parcela.', img: 'wz0-home.jpg' },
  { grupo: 'App de campo (celular)', titulo: 'Wizard — etapa 1 de 4: Local', legenda: 'GPS enxuto (sem "obrigatório" no título), propriedade, UT e número. Stepper com swipe.', img: 'wz1-local.jpg' },
  { grupo: 'App de campo (celular)', titulo: 'Wizard — etapa 2 de 4: Fotos', legenda: 'Fotos da parcela antes das plantas (protocolo de campo); seleção múltipla.', img: 'wz3-fotos.jpg' },
  { grupo: 'App de campo (celular)', titulo: 'Wizard — etapa 3 de 4: Plantas em cascata', legenda: '50 plantas em 5 grupos por espécie + chips de filtro com o que já foi digitado na parcela.', img: 'wz3-cascata-50.jpg' },
  { grupo: 'App de campo (celular)', titulo: 'Cascata — grupo aberto', legenda: 'Plantas do grupo com nome científico, nome popular, DAP/altura e categoria discreta.', img: 'wz3-cascata-aberto.jpg' },
  { grupo: 'App de campo (celular)', titulo: 'Cascata — filtro por espécie', legenda: 'Um toque no chip e a lista mostra só as plantas daquela espécie.', img: 'wz3-cascata-filtro.jpg' },
  { grupo: 'App de campo (celular)', titulo: 'Form da planta', legenda: 'Tipo de nome, espécie, altura, DAP e só então a categoria (linha discreta + opção manual).', img: 'wz2-planta-form.jpg' },
  { grupo: 'App de campo (celular)', titulo: 'Wizard — etapa 4 de 4: Revisar', legenda: 'Resumo, estimativa de carbono (MRV) só aqui e aviso de sync no fim — antes do Concluir.', img: 'wz4-revisar-mrv.jpg' },
  { grupo: 'App de campo (celular)', titulo: 'Wizard — botões do Revisar', legenda: 'Guardar rascunho e Concluir alterações no fim da etapa.', img: 'wz4-concluir.jpg' },
  { grupo: 'App de campo (celular)', titulo: 'Configurações', legenda: 'Menu do app > Configuracoes - servidor, sync, backup local (zip; guarde fora do celular), tema e wizard.', img: 'wz5-configuracoes.jpg' },
  { grupo: 'App de campo (celular)', titulo: 'Alto contraste (app)', legenda: 'Preto/amarelo/branco com contraste AA (WCAG 2.2) para leitura sob sol direto.', img: 'wz5-alto-contraste.jpg' },
  { grupo: 'Painel do verificador (web)', titulo: 'Dashboard (modo demonstração)', legenda: 'Selo "DADOS DE DEMONSTRAÇÃO" — servidor PocketBase ainda não publicado.', img: 'painel-01-dashboard.jpg' },
  { grupo: 'Painel do verificador (web)', titulo: 'Auditoria da parcela', legenda: 'Status, crédito bloqueado, cálculo MRV com IC 95% e hash dos insumos; "Refazer a conta" no navegador.', img: 'painel-02-auditoria.jpg' },
  { grupo: 'Painel do verificador (web)', titulo: 'Verificação da cadeia', legenda: 'Cadeia recalculada elo por elo: payload adulterado detectado (dados de demonstração).', img: 'painel-03-cadeia-quebrada.jpg' },
  { grupo: 'Painel do verificador (web)', titulo: 'Incidentes', legenda: 'Incidente bloqueador aberto impede crédito; resolver exige justificativa (vai pra trilha).', img: 'painel-04-incidentes.jpg' },
  { grupo: 'Painel do verificador (web)', titulo: 'Projeto MRV', legenda: 'Baseline, adicionalidade, desenho amostral com meta de incerteza vs realizada.', img: 'painel-05-projeto-mrv.jpg' },
  { grupo: 'Painel do verificador (web)', titulo: 'Alto contraste', legenda: 'Mesmo par de cores do app (preto/amarelo) para uso em campo sob sol.', img: 'painel-06-alto-contraste.jpg' },
];

const W = 841.89, H = 595.28; // A4 paisagem (mesmo do Orca)
const objects = [];
const add = (body) => { objects.push(body); return objects.length; };
const catalogId = add(null);
const pagesId = add(null);
const fontId = add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
const esc = (s) => s.replace(/([()\\])/g, '\\$1');

/**
 * Fonte padrão do PDF (Helvetica) é WinAnsi: normaliza o texto pra ASCII
 * (ç->c, ã->a, ₂->2, —->-, ±->+-, …->...) pra não sair '?' no leitor.
 */
const winansi = (s) =>
  s
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/₂/g, '2')
    .replace(/—|–/g, '-')
    .replace(/…/g, '...')
    .replace(/·/g, '-')
    .replace(/±/g, '+/-')
    .replace(/[“”„]/g, '"')
    .replace(/[‘’]/g, "'")
    .replace(/≥/g, '>=')
    .replace(/≤/g, '<=')
    .replace(/→/g, '->')
    .replace(/×/g, 'x');

const T = (s) => winansi(s);
const pageIds = [];

for (const p of PAGES) {
  const path = IMG(p.img);
  if (!existsSync(path)) throw new Error(`imagem faltando: ${path}`);
  const buf = readFileSync(path);
  const { w, h } = jpegSize(buf);

  const imgId = add({
    bin: buf,
    header: `<< /Type /XObject /Subtype /Image /Width ${w} /Height ${h} `
      + `/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${buf.length} >>`,
  });

  const margin = 40;
  const topText = 76;
  const availW = W - margin * 2;
  const availH = H - margin - topText - 26;
  const scale = Math.min(availW / w, availH / h);
  const dw = w * scale, dh = h * scale;
  const x = (W - dw) / 2;
  const y = margin + 22 + (availH - dh) / 2;

  const content =
    `BT /F1 9 Tf 0.45 0.5 0.42 rg ${margin} ${H - 32} Td (${esc(T(p.grupo))}) Tj ET\n` +
    `BT /F1 17 Tf 0.1 0.15 0.1 rg ${margin} ${H - 52} Td (${esc(T(p.titulo))}) Tj ET\n` +
    `BT /F1 10 Tf 0.35 0.4 0.35 rg ${margin} ${H - 68} Td (${esc(T(p.legenda))}) Tj ET\n` +
    `q ${dw} 0 0 ${dh} ${x} ${y} cm /Im${imgId} Do Q\n` +
    `BT /F1 8 Tf 0.55 0.6 0.55 rg ${margin} ${margin - 16} Td `
    + `(Urutau — telas · app emulado (perfil) + painel web · dados de demonstração) Tj ET\n`;

  const contentId = add({ text: Buffer.from(content, 'utf8') });
  pageIds.push(add(
    `<< /Type /Page /Parent ${pagesId} 0 R /MediaBox [0 0 ${W} ${H}] `
    + `/Resources << /XObject << /Im${imgId} ${imgId} 0 R >> /Font << /F1 ${fontId} 0 R >> >> `
    + `/Contents ${contentId} 0 R >>`,
  ));
}

objects[catalogId - 1] = `<< /Type /Catalog /Pages ${pagesId} 0 R >>`;
objects[pagesId - 1] = `<< /Type /Pages /Count ${pageIds.length} /Kids [${pageIds.map((i) => `${i} 0 R`).join(' ')}] >>`;

let pdf = Buffer.from('%PDF-1.4\n', 'binary');
const offsets = [];
for (let i = 0; i < objects.length; i++) {
  offsets.push(pdf.length);
  const o = objects[i];
  pdf = Buffer.concat([pdf, Buffer.from(`${i + 1} 0 obj\n`, 'binary')]);
  if (typeof o === 'string') {
    pdf = Buffer.concat([pdf, Buffer.from(o + '\nendobj\n', 'binary')]);
  } else if (o.bin) {
    pdf = Buffer.concat([
      pdf,
      Buffer.from(o.header + '\nstream\n', 'binary'),
      o.bin,
      Buffer.from('\nendstream\nendobj\n', 'binary'),
    ]);
  } else if (o.text) {
    pdf = Buffer.concat([
      pdf,
      Buffer.from(`<< /Length ${o.text.length} >>\nstream\n`, 'binary'),
      o.text,
      Buffer.from('\nendstream\nendobj\n', 'binary'),
    ]);
  }
}
const xrefPos = pdf.length;
let xref = `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
for (const off of offsets) xref += `${String(off).padStart(10, '0')} 00000 n \n`;
xref += `trailer\n<< /Size ${objects.length + 1} /Root ${catalogId} 0 R `
  + `/Title (Urutau - telas (app de campo e painel)) /Author (Urutau) >>\nstartxref\n${xrefPos}\n%%EOF`;
pdf = Buffer.concat([pdf, Buffer.from(xref, 'binary')]);

writeFileSync(OUT, pdf);
console.log(`PDF: ${OUT} · ${PAGES.length} páginas · ${(pdf.length / 1024).toFixed(0)} KB`);
