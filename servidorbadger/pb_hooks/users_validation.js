// Hook: Restrict user updates — only admins can modify isAdmin, and only isAdmin can be changed by non-self users.

onRecordBeforeUpdateRequestEvent((e) => {
  if (e.record.collection().name !== 'users') {
    return;
  }

  const authRecord = e.requestInfo?.auth;
  if (!authRecord) {
    e.error = new Error('Autenticação necessária.');
    return;
  }

  // Self-updates (user editing their own record) are always allowed
  if (authRecord.id === e.record.id) {
    return;
  }

  // Non-self updates: only admins can do it
  if (!authRecord.get('isAdmin')) {
    e.error = new Error('Apenas administradores podem modificar outros usuários.');
    return;
  }

  // Non-self updates: only the isAdmin field can be changed
  const body = e.requestInfo?.body || {};
  const allowedFields = ['isAdmin'];
  const modifiedFields = Object.keys(body).filter(k => !k.startsWith('@') && allowedFields.indexOf(k) === -1);
  if (modifiedFields.length > 0) {
    e.error = new Error('Administradores só podem alterar o campo isAdmin de outros usuários. Campos rejeitados: ' + modifiedFields.join(', '));
    return;
  }
});
