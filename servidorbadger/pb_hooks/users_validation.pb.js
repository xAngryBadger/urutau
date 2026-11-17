// Hook: restringe updates de users — so admin muda outro utilizador, e so o
// campo isAdmin. PocketBase 0.36.4: onRecordUpdateRequest + throw BadRequestError.
//
// t21 — o hook estava MORTO (extensao .js + nome onRecordBeforeUpdateRequestEvent
// inexistente + arranque sem --hooksDir). Neste build, handlers nao podem chamar
// funcoes de nivel de ficheiro — tudo inline.
// Prova de vida: admin PATCH campo qualquer de outro user -> 400 do hook
// (docs/t21-probes-ao-vivo.md).

onRecordUpdateRequest((e) => {
    let col = '';
    try {
        col = e.record && e.record.collection ? e.record.collection().name : (e.collection ? e.collection.name : '');
    } catch (err) {
        col = e.collection ? e.collection.name : '';
    }
    if (col !== 'users' || !e.record) return e.next();
    if (e.hasSuperuserAuth && e.hasSuperuserAuth()) return e.next(); // painel admin bypassa

    const auth = e.auth;
    if (!auth) throw new BadRequestError('Autenticação necessária.');

    // Self-update (o próprio utilizador) e sempre permitido.
    if (auth.id === e.record.id) return e.next();

    // Outro utilizador: so admin.
    if (auth.get('isAdmin') !== true) {
        throw new BadRequestError('Apenas administradores podem modificar outros utilizadores.');
    }

    // Admin -> outro utilizador: so o campo isAdmin pode mudar.
    const ri = typeof e.requestInfo === 'function' ? e.requestInfo() : e.requestInfo;
    const body = (ri && ri.body) || {};
    const allowed = ['isAdmin'];
    const modified = [];
    for (const k in body) {
        if (k.charAt(0) !== '@' && allowed.indexOf(k) === -1) modified.push(k);
    }
    if (modified.length > 0) {
        throw new BadRequestError('Administradores só podem alterar o campo isAdmin de outros utilizadores. Campos rejeitados: ' + modified.join(', '));
    }
    return e.next();
});
