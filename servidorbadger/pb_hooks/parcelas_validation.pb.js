// Hooks server-side do Urutau — PocketBase 0.36.4 (API de hooks NOVA).
//
// t21 — estes hooks estavam MORTOS em producao por TRES raisons:
//  1. extensao .js (so .pb.js carrega — provado: erro de sintaxe num .pb.js
//     faz o serve reclamar; num .js nem le);
//  2. nomes onRecordBefore*RequestEvent nao existem no binario 0.36.4
//     (so ha onRecordCreateRequest/onRecordUpdateRequest — ver types.d.ts);
//  3. sem --hooksDir explicito no arranque, o PB nao carrega pb_hooks
//     (falha em silencio — ver iniciar_servidor.ps1/serveron.ps1/start.sh).
// Alem disso: neste build, um handler NAO pode chamar funcoes declaradas ao
// nivel do ficheiro (lanca erro silencioso → 400 generico). Tudo inline.
// E na API nova nao existe e.error — rejeitar e `throw new BadRequestError`.
//
// Prova de vida por COMPORTAMENTO: docs/t21-probes-ao-vivo.md

// Hook 1: conflito de (prop_ut, id_parcela) entre utilizadores diferentes.
onRecordCreateRequest((e) => {
    // inline: e.record.collection().name e o caminho fiavel; e.collection tambem serve
    let col = '';
    try {
        col = e.record && e.record.collection ? e.record.collection().name : (e.collection ? e.collection.name : '');
    } catch (err) {
        col = e.collection ? e.collection.name : '';
    }
    if (col !== 'parcelas' || !e.record) return e.next();

    const propUt = e.record.get('prop_ut');
    const idParcela = e.record.get('id_parcela');
    const user = e.record.get('user');
    if (!propUt || idParcela === undefined || idParcela === null || !user) return e.next();

    const idNum = Number(idParcela);
    if (!Number.isFinite(idNum)) throw new BadRequestError('id_parcela inválido.');

    // Mesmo escape do app (escapePbFilter, sync_service.dart, commit 2ee0315):
    // barra invertida vira dupla e aspa vira backslash+aspa dentro de literais.
    const escProp = String(propUt).replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    const escUser = String(user).replace(/\\/g, '\\\\').replace(/"/g, '\\"');

    const existing = $app.findRecordsByFilter(
        'parcelas',
        'prop_ut = "' + escProp + '" && id_parcela = ' + idNum + ' && user != "' + escUser + '"',
        '', 1, 0
    );

    if (existing.length > 0) {
        throw new BadRequestError('CONFLITO: esta parcela já existe para outro utilizador. Verifique os dados.');
    }
    return e.next();
});

// Hooks 2 e 3 (H-2): plantas. O campo texto `parcela` guarda o server id da
// parcela; `parcela_rel` e a relation. App antigo manda so o texto — derivamos
// a relation aqui. Depois exigimos dono da parcela ou admin (fecha o escape
// parcela_rel.user = "" do createRule/updateRule para pedidos sem relation).
onRecordCreateRequest((e) => {
    let col = '';
    try {
        col = e.record && e.record.collection ? e.record.collection().name : (e.collection ? e.collection.name : '');
    } catch (err) {
        col = e.collection ? e.collection.name : '';
    }
    if (col !== 'plantas' || !e.record) return e.next();

    const rec = e.record;
    let rel = rec.get('parcela_rel');
    if (rel === undefined || rel === null || rel === '') {
        const texto = rec.get('parcela');
        if (texto) {
            const p = $app.findRecordById('parcelas', String(texto));
            if (p) {
                rec.set('parcela_rel', p.id);
                rel = p.id;
            }
        }
    }
    if (!rel) throw new BadRequestError('Planta precisa de referência para parcela.');
    const parcela = $app.findRecordById('parcelas', String(rel));
    if (!parcela) throw new BadRequestError('Parcela de referência não existe.');

    if (e.hasSuperuserAuth && e.hasSuperuserAuth()) return e.next(); // painel admin bypassa
    const auth = e.auth;
    if (!auth) throw new BadRequestError('Autenticação necessária.');
    if (parcela.get('user') !== auth.id && auth.get('isAdmin') !== true) {
        throw new BadRequestError('Sem permissão para criar/alterar plantas nesta parcela.');
    }
    return e.next();
});

onRecordUpdateRequest((e) => {
    let col = '';
    try {
        col = e.record && e.record.collection ? e.record.collection().name : (e.collection ? e.collection.name : '');
    } catch (err) {
        col = e.collection ? e.collection.name : '';
    }
    if (col !== 'plantas' || !e.record) return e.next();

    const rec = e.record;
    let rel = rec.get('parcela_rel');
    if (rel === undefined || rel === null || rel === '') {
        const texto = rec.get('parcela');
        if (texto) {
            const p = $app.findRecordById('parcelas', String(texto));
            if (p) {
                rec.set('parcela_rel', p.id);
                rel = p.id;
            }
        }
    }
    if (!rel) throw new BadRequestError('Planta precisa de referência para parcela.');
    const parcela = $app.findRecordById('parcelas', String(rel));
    if (!parcela) throw new BadRequestError('Parcela de referência não existe.');

    if (e.hasSuperuserAuth && e.hasSuperuserAuth()) return e.next();
    const auth = e.auth;
    if (!auth) throw new BadRequestError('Autenticação necessária.');
    if (parcela.get('user') !== auth.id && auth.get('isAdmin') !== true) {
        throw new BadRequestError('Sem permissão para criar/alterar plantas nesta parcela.');
    }
    return e.next();
});
