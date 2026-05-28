/// Calcula a categoria da planta com base em altura e DAP.
///
/// Regras:
/// - Altura < 50cm → Categoria 1 (DAP ignorado)
/// - Altura >= 50cm e DAP < 5cm → Categoria 2
/// - Altura >= 50cm e DAP >= 5cm → Categoria 3
int calcularCategoria(double alturaCm, double? dapCm) {
  if (alturaCm < 50) {
    return 1;
  } else {
    if (dapCm == null || dapCm < 5) {
      return 2;
    } else {
      return 3;
    }
  }
}

/// Retorna se o campo DAP é obrigatório.
bool dapObrigatorio(double alturaCm) => alturaCm >= 50;

/// Retorna se a foto da espécie é obrigatória.
bool fotoEspecieObrigatoria(String especie) =>
    especie.trim().toUpperCase() == 'NI';

/// Descrição textual da categoria.
String descricaoCategoria(int categoria) {
  switch (categoria) {
    case 1:
      return 'Cat. 1 — Altura < 50cm';
    case 2:
      return 'Cat. 2 — Altura ≥ 50cm, DAP < 5cm';
    case 3:
      return 'Cat. 3 — Altura ≥ 50cm, DAP ≥ 5cm';
    default:
      return 'Categoria desconhecida';
  }
}

/// Lista de espécies comuns para autocomplete.
/// "NI" = Não Identificada.
const List<String> especiesComuns = [
  'NI',
  'Acrocomia aculeata (Jacq.) Lodd. ex Mart.',
  'Aegiphila integrifolia (Jacq.) Moldenke',
  'Alchornea triplinervia (Spreng.) Müll.Arg.',
  'Lafoensia pacari A. St.-Hil',
  'Anadenanthera colubrina (Vell.) Brenan',
  'Anadenanthera macrocarpa',
  'Andira fraxinifolia Benth.',
  'Apeiba tibourbou Aubl.',
  'Apuleia leiocarpa (Vogel) J.F.Macbr.',
  'Astronium fraxinifolium Schott',
  'Attalea dubia (Mart.) Burret',
  'Bixa orellana L.',
  'Byrsonima crassifolia (L.) Kunth',
  'Byrsonima sericea DC.',
  'Cariniana estrellensis',
  'Carpotroche brasiliensis (Raddi) A Gray',
  'Casearia sylvestris Sw.',
  'Cassia ferruginea (Schrad.) Schrad. ex DC.',
  'Cassia grandis L.f.',
  'Cecropia glaziovii Snethl.',
  'Cecropia hololeuca Miq.',
  'Cecropia pachystachya',
  'Cedrela fissilis Vell.',
  'Ceiba speciosa (A.St.-Hil.) Ravenna',
  'Centrolobium microchaete (Mart. ex Benth.) H.C.Lima',
  'Citharexylum myrianthum',
  'Colubrina glandulosa Perkins',
  'Copaifera langsdorffii Desf.',
  'Cordia trichotoma (Vell.) Arráb. ex Steud.',
  'Croton floribundus Spreng.',
  'Croton urucurana',
  'Dalbergia nigra (Vell.) Allemão ex Benth.',
  'Dictyoloma vandellianum A.Juss.',
  'Diospyros inconstans Jacq.',
  'Diospyros lasiocalyx (Mart.) B.Walln.',
  'Enterolobium contortisiliquum (Vell.) Morong',
  'Enterolobium monjollo (Vell.) Mart.',
  'Enterolobium timbouva Mart.',
  'Eriotheca candolleana (K.Schum.) A.Robyns',
  'Eriotheca macrophylla (K.Schum.) A.Robyns',
  'Erythrina mulungu',
  'Erythrina velutina',
  'Erythrina verna Vell.',
  'Erythroxylum pelleterianum A.St.-Hil.',
  'Eugenia uniflora L.',
  'Ficus gomelleira Kunth',
  'Gallesia integrifolia (Spreng.) Harms',
  'Genipa americana',
  'Guazuma ulmifolia Lam.',
  'Handroanthus chrysotrichus (Mart. ex DC.) Mattos',
  'Handroanthus heptaphyllus',
  'Handroanthus ochraceus (Cham.) Mattos',
  'Handroanthus serratifolius (Vahl) S.Grose',
  'Heteropterys byrsonimifolia A.Juss.',
  'Himatanthus obovatus (Müll. Arg.) Woodson',
  'Hymenaea courbaril L.',
  'Jacaranda cuspidifolia',
  'Joannesia princeps Vell.',
  'Lecythis pisonis Cambess.',
  'Luehea divericata',
  'Machaerium brasiliense Vogel',
  'Machaerium hirtum (Vell.) Stellfeld',
  'Machaerium nyctitans (Vell.) Benth.',
  'Maclura tinctoria (L.) D.Don ex Steud.',
  'Melanoxylon brauna Schott',
  'Mezilaurus crassiramea (Meisn.) Taub. ex Mez',
  'Miconia affinis DC.',
  'Miconia ligustroides (DC.) Naudin',
  'Miconia sp.',
  'Myrcia guianensis (Aubl.) DC.',
  'Myrcia splendens (Sw.) DC.',
  'Myrsine guianensis (Aubl.) Kuntze',
  'Ormosia arborea (Vell.) Harms',
  'Peltophorum dubium (Spreng.) Taub.',
  'Piptadenia gonoacantha (Mart.) J.F.Macbr.',
  'Piptadenia paniculata Benth.',
  'Plathymenia reticulata Benth.',
  'Platypodium elegans Vogel',
  'Pouteria venosa (Mart.) Baehni',
  'Pseudobombax grandiflorum (Cav.) A.Robyns',
  'Pseudobombax longiflorum',
  'Psidium guieense',
  'Psidium rufum Mart. ex DC.',
  'Psychotria carthagenensis Jacq.',
  'Pterocarpus violaceus Vogel',
  'Pterogyne nitens Tul.',
  'Randia armata (Sw.) DC.',
  'Sapindus saponaria L.',
  'Schinus terebinthifolius',
  'Schizolobium parahyba (Vell.) Blake',
  'Senegalia polyphylla (DC.) Britton & Rose',
  'Senna alata',
  'Senna macranthera (DC. ex Collad.) H.S.Irwin & Barneby',
  'Senna multijuga',
  'Sesbania virgata (Cav.) Poir.',
  'Solanum granulosoleprosum Dunal',
  'Spondias macrocarpa Engl.',
  'Spondias mombin L.',
  'Spondias venulosa (Mart. ex Engl.) Engl.',
  'Stryphnodendron polyphyllum Mart.',
  'Styrax camporum Pohl',
  'Syagrus botryophora (Mart.) Mart.',
  'Syagrus macrocarpa Barb.Rodr.',
  'Syagrus romanzoffiana (Cham.) Glassman',
  'Tabernaemontana hystrix',
  'Tabernaemontana laeta Mart.',
  'Talisia esculenta (Cambess.) Radlk.',
  'Terminalia argentea Mart. & Zucc.',
  'Vitex polygama Cham.',
  'Xylopia aromatica (Lam.) Mart.',
  'Zanthoxylum rhoifolium Lam.',
  'Zanthoxylum riedelianum Engl.',
  'Zeyheria tuberculosa (Vell.) Bureau ex Verl.',
];
