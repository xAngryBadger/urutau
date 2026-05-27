// Hook: Validate parcela uniqueness (propriedade + UT + id_parcela)
// Previne duplicatas ao nível do banco de dados

onRecordBeforeCreateRequestEvent((e) => {
    // Only for parcelas collection
    if (e.record.collection().name !== 'parcelas') {
        return;
    }

    const propUt = e.record.get('prop_ut');
    const idParcela = e.record.get('id_parcela');
    const user = e.record.get('user');

    if (!propUt || !idParcela) {
        return; // Sem validação se campos obrigatórios faltando
    }

    // Check if another user already has this parcela
    const existing = $app.dao().findRecordsByFilter('parcelas', `prop_ut = "${propUt}" && id_parcela = ${idParcela} && user != "${user}"`, '', 1, 0);

    if (existing.length > 0) {
        // Conflito detectado!
        e.error = new Error('CONFLITO: Esta parcela já existe para outro usuário. Por favor, verifique os dados.');
        return;
    }
});

// Hook: Ensure plantas have valid parcela reference
onRecordBeforeCreateRequestEvent((e) => {
    if (e.record.collection().name !== 'plantas') {
        return;
    }

    const parcelaId = e.record.get('parcela');
    if (!parcelaId) {
        e.error = new Error('Planta precisa de referência para parcela.');
        return;
    }

    // Verify parcela exists
    const parcela = $app.dao().findRecordById('parcelas', parcelaId);
    if (!parcela) {
        e.error = new Error('Parcela de referência não existe.');
        return;
    }
});

// Hook: Auto-set prontaParaSync=true when parcela is created/updated
// REMOVED — prontaParaSync is intentionally controlled by the mobile app.
// Server-side auto-set contradicts the draft workflow where
// prontaParaSync=false means "draft, don't sync yet".
