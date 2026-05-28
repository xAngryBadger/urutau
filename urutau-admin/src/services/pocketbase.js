import PocketBase from 'pocketbase';
import safeError from './logger';

const sanitizeUrl = (url) => (url || '').trim().replace(/\/+$/, '');

const DEFAULT_POCKETBASE_URL = window.location.origin;
const POCKETBASE_URL = sanitizeUrl(import.meta.env.VITE_POCKETBASE_URL) || DEFAULT_POCKETBASE_URL;

if (/github\.io$/.test(window.location.hostname) && !import.meta.env.VITE_POCKETBASE_URL) {
  console.error(
    '[urutau-admin] VITE_POCKETBASE_URL is not set and the app is running on GitHub Pages.' +
    ' The admin panel will fail to connect to PocketBase.' +
    ' Set VITE_POCKETBASE_URL in .env.production before building.',
  );
}

export const pb = new PocketBase(POCKETBASE_URL);
pb.autoCancellation(false);

let _onAuthExpired = null;
export const onAuthExpired = (callback) => { _onAuthExpired = callback; };

const originalSend = pb.send.bind(pb);
pb.send = async function (...args) {
  try {
    return await originalSend(...args);
  } catch (err) {
    if (err?.status === 401 && _onAuthExpired) {
      _onAuthExpired();
    }
    throw err;
  }
};

const escapeFilterValue = (value) => String(value ?? '')
  .replace(/\\/g, '\\\\')
  .replace(/"/g, '\\"');

const normalizePhotoFiles = (value) => {
  if (Array.isArray(value)) {
    return value.filter(Boolean);
  }

  if (typeof value === 'string') {
    return value
      .split(',')
      .map((part) => part.trim())
      .filter(Boolean);
  }

  return [];
};

const EXPAND_RELATIONS = 'ut.propriedade,userId';

const normalizeParcelRecord = (parcel, usersById = null) => {
  const photos = normalizePhotoFiles(parcel.fotos_parcela);

  let propertyCode = '';
  let utCode = '';
  try {
    const utExpand = parcel.expand?.ut;
    if (utExpand) {
      utCode = utExpand.codigo || '';
      const propExpand = utExpand.expand?.propriedade;
      if (propExpand) {
        propertyCode = propExpand.codigo || propExpand.nome || '';
      }
    }
  } catch { /* expand data may be missing */ }

  if (!propertyCode && parcel.prop_ut) {
    const parts = parcel.prop_ut.split(' - ');
    propertyCode = parts[0] || parcel.prop_ut;
  }
  if (!utCode && parcel.prop_ut) {
    const parts = parcel.prop_ut.split(' - ');
    utCode = parts[1] || '-';
  }

  let displayUser = '-';
  try {
    const userExpand = parcel.expand?.userId;
    if (userExpand) {
      displayUser = userExpand.name || userExpand.email || '-';
    } else if (parcel.user && usersById && usersById.has(parcel.user)) {
      displayUser = usersById.get(parcel.user);
    } else if (parcel.user) {
      displayUser = parcel.user;
    }
} catch { /* fallback to raw user id */
  displayUser = parcel.user || '-';
}

return {
    ...parcel,
    fotos_parcela: photos,
    photoCount: photos.length,
    propertyCode,
    utCode: utCode || '-',
    displayUser,
    synced: parcel.synced === true,
    prontaParaSync: parcel.prontaParaSync === true,
      syncLabel: parcel.prontaParaSync ? 'Pronto para sync' : 'Rascunho',
    createdAt: parcel.created || parcel.updated || null,
  };
};

const buildUserSession = (model, authCollection = '') => {
  if (!model) {
    return null;
  }

  const collectionName = authCollection || model.collectionName || '';
  const isSuperuser = collectionName === '_superusers';
  const isAdmin = isSuperuser || model.isAdmin === true;

  return {
    ...model,
    authCollection: collectionName,
    role: isAdmin ? 'admin' : 'user',
    canEdit: isAdmin,
    canDelete: isAdmin,
    canExport: true,
    canView: true,
  };
};

const toAuthErrorMessage = (error) => {
  const message = error?.response?.message || error?.message || '';

  if (!message) {
    return 'Nao foi possivel autenticar agora. Tente novamente.';
  }

  if (/failed to authenticate|invalid|password/i.test(message)) {
    return 'Credenciais invalidas. Confira usuario/email e senha.';
  }

  if (/failed to fetch|network|connect/i.test(message)) {
    return `Nao foi possivel conectar ao PocketBase em ${POCKETBASE_URL}.`;
  }

  if (/not found|404|resource/i.test(message)) {
    return 'Colecao de autenticacao nao encontrada no PocketBase.';
  }

  return message;
};

export const loginUser = async (identity, password, { remember = true } = {}) => {
  const normalizedIdentity = (identity || '').trim();

  if (!normalizedIdentity || !password) {
    return {
      success: false,
      error: 'Informe usuario/email e senha.',
    };
  }

  const authCollections = ['users', '_superusers'];
  let lastError = null;

  for (const collectionName of authCollections) {
    try {
      const authData = await pb.collection(collectionName).authWithPassword(normalizedIdentity, password);
      const model = authData?.record || authData?.admin || pb.authStore.record || pb.authStore.model;
      const user = buildUserSession(model, collectionName);

      if (!user) {
        throw new Error('Resposta de autenticacao invalida.');
      }

      if (!remember) {
        const raw = localStorage.getItem('pb_auth');
        if (raw) {
          localStorage.removeItem('pb_auth');
          sessionStorage.setItem('pb_auth', raw);
        }
      }

      return {
        success: true,
        user,
      };
    } catch (error) {
      lastError = error;
      pb.authStore.clear();
    }
  }

  return {
    success: false,
    error: toAuthErrorMessage(lastError),
  };
};

export const logoutUser = () => {
  pb.authStore.clear();
};

export const isAuthenticated = () => {
  const model = pb.authStore.record || pb.authStore.model;
  const token = pb.authStore.token;
  if (!token || !model) return false;
  if (pb.authStore.isValid) return true;
  try {
    const payload = JSON.parse(atob(token.split('.')[1]));
    const exp = payload.exp;
    if (exp && Date.now() >= exp * 1000) return false;
    return true;
  } catch {
    return false;
  }
};

export const getCurrentUser = () => {
  const model = pb.authStore.record || pb.authStore.model;
  return buildUserSession(model);
};

export const fetchParcels = async (filters = {}, page = 1, perPage = 25, usersById = null) => {
  const filterString = buildFilterString(filters);

  try {
    const result = await pb.collection('parcelas').getList(page, perPage, {
      filter: filterString,
      sort: '-id_parcela',
      expand: EXPAND_RELATIONS,
    });

    return {
      ...result,
      items: result.items.map((p) => normalizeParcelRecord(p, usersById)),
    };
  } catch (error) {
    if (error?.isAbort) return { items: [], totalItems: 0 };
    safeError('Error fetching parcels:', error);
    throw error;
  }
};

export const fetchAllParcels = async (filters = {}, usersById = null) => {
  const filterString = buildFilterString(filters);

  try {
    const result = await pb.collection('parcelas').getFullList({
      filter: filterString,
      sort: '-id_parcela',
      expand: EXPAND_RELATIONS,
    });

    return result.map((p) => normalizeParcelRecord(p, usersById));
  } catch (error) {
    if (error?.isAbort) return [];
    safeError('Error fetching all parcels:', error);
    throw error;
  }
};

export const fetchParcelsByIds = async (ids, usersById = null) => {
  if (!ids || ids.length === 0) return [];

  const filterParts = ids.map((id) => `id = "${escapeFilterValue(id)}"`);
  const filterString = filterParts.join(' || ');

  try {
    const result = await pb.collection('parcelas').getFullList({
      filter: filterString,
      sort: '-id_parcela',
      expand: EXPAND_RELATIONS,
    });

    return result.map((p) => normalizeParcelRecord(p, usersById));
  } catch (error) {
    if (error?.isAbort) return [];
    safeError('Error fetching parcels by IDs:', error);
    throw error;
  }
};

export const fetchParcelById = async (id, usersById = null) => {
  try {
    const result = await pb.collection('parcelas').getOne(id, {
      expand: EXPAND_RELATIONS,
    });
    return normalizeParcelRecord(result, usersById);
  } catch (error) {
    if (error?.isAbort) return null;
    safeError('Error fetching parcel:', error);
    throw error;
  }
};

export const fetchPlantsByParcel = async (parcelId) => {
  try {
    const result = await pb.collection('plantas').getFullList({
      filter: `parcela = "${parcelId}"`,
      sort: '-created_at',
    });
    return result;
  } catch (error) {
    if (error?.isAbort) return [];
    safeError('Error fetching plants:', error);
    throw error;
  }
};

export const fetchAllPlants = async () => {
  try {
    const result = await pb.collection('plantas').getFullList({
      sort: '-created_at',
    });
    return result;
  } catch (error) {
    if (error?.isAbort) return [];
    safeError('Error fetching all plants:', error);
    throw error;
  }
};

export const fetchProperties = async () => {
  try {
    const result = await pb.collection('propriedades').getFullList({
      sort: 'codigo',
    });
    return result;
  } catch (error) {
    if (error?.isAbort) return [];
    safeError('Error fetching properties:', error);
    throw error;
  }
};

export const fetchUTs = async (propertyId = null) => {
  const conditions = [];
  if (propertyId) conditions.push(`propriedade = "${propertyId}"`);

  try {
    const result = await pb.collection('uts').getFullList({
      filter: conditions.length > 0 ? conditions.join(' && ') : '',
      sort: 'codigo',
      expand: 'propriedade',
    });
    return result;
  } catch (error) {
    if (error?.isAbort) return [];
    safeError('Error fetching UTs:', error);
    return [];
  }
};

export const fetchUsers = async () => {
  try {
    const result = await pb.collection('users').getFullList({
      sort: 'name',
    });
    return result;
  } catch (error) {
    if (error?.isAbort) return [];
    safeError('Error fetching users:', error);
    throw error;
  }
};

export const getStats = async () => {
  const safeCount = async (collectionName, filter = '') => {
    try {
      const opts = filter ? { filter } : {};
      const result = await pb.collection(collectionName).getList(1, 1, opts);
      return result.totalItems;
    } catch (error) {
      if (error?.isAbort) return 0;
      safeError(`Error counting ${collectionName}:`, error);
      return 0;
    }
  };

  const [
    totalProperties,
    totalUTs,
    totalParcels,
    totalPlants,
    totalUsers,
    syncedParcels,
  ] = await Promise.all([
    safeCount('propriedades'),
    safeCount('uts'),
    safeCount('parcelas'),
    safeCount('plantas'),
    safeCount('users'),
    safeCount('parcelas', 'prontaParaSync = true'),
  ]);

  return {
    totalProperties,
    totalUTs,
    totalParcels,
    totalPlants,
    totalUsers,
    syncedParcels,
    pendingParcels: totalParcels - syncedParcels,
  };
};

export const getTopSpecies = async (limit = 8) => {
  try {
    const counts = new Map();
    let page = 1;
    const perPage = 500;
    let hasMore = true;

    while (hasMore) {
      const result = await pb.collection('plantas').getList(page, perPage, {
        fields: 'especie',
      });
      for (const plant of result.items) {
        const name = (plant.especie || 'Nao informada').trim() || 'Nao informada';
        counts.set(name, (counts.get(name) || 0) + 1);
      }
      hasMore = result.items.length === perPage;
      page++;
    }

    return [...counts.entries()]
      .map(([name, count]) => ({ name, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, limit);
  } catch (error) {
    if (error?.isAbort) return [];
    safeError('Error fetching top species:', error);
    throw error;
  }
};

export const getPhotoUrl = (parcel, photoIndex = 0) => {
  const photos = normalizePhotoFiles(parcel.fotos_parcela);

  if (photos.length === 0) {
    return null;
  }

  const photoFile = photos[photoIndex];
  if (!photoFile) {
    return null;
  }

  return pb.files.getUrl(parcel, photoFile);
};

const buildFilterString = (filters) => {
  const conditions = [];

  if (filters.property) {
    const safeProp = escapeFilterValue(filters.property);
    conditions.push(`ut.propriedade = "${safeProp}"`);
  }

  if (filters.ut) {
    const safeUt = escapeFilterValue(filters.ut);
    conditions.push(`ut = "${safeUt}"`);
  }

  if (filters.parcelNumber) {
    const parcelNumber = Number(filters.parcelNumber);
    if (!Number.isNaN(parcelNumber)) {
      conditions.push(`id_parcela = ${parcelNumber}`);
    }
  }

  if (filters.user) {
    const safeUser = escapeFilterValue(filters.user);
    conditions.push(`userId = "${safeUser}" || user = "${safeUser}"`);
  }

  if (filters.syncStatus === 'synced') {
    conditions.push('prontaParaSync = true');
  } else if (filters.syncStatus === 'pending') {
    conditions.push('prontaParaSync = false');
  }

  if (filters.hasPhotos === true) {
    conditions.push('fotos_parcela != "" && fotos_parcela != null && fotos_parcela != "[]"');
  }

  return conditions.join(' && ');
};

export const exportToExcel = async (parcels, filename = 'urutau.xlsx', usersById = null, onProgress = null) => {
  const XLSX = await import('xlsx');

  const totalSteps = parcels.length + 1; // +1 for plants fetch
  let currentStep = 0;

  const normalizedParcels = parcels.map((p) => normalizeParcelRecord(p, usersById));
  currentStep++;
  if (onProgress) onProgress(currentStep / totalSteps, 'Normalizando parcelas...');

  const parcelRows = normalizedParcels.map((p) => ({
    Propriedade: p.propertyCode || '',
    UT: p.utCode || '',
    Parcela: p.id_parcela,
    Area_ha: p.area_ha != null ? p.area_ha : '',
    Observacoes: p.observacoes || '',
    Usuario: p.displayUser || '',
      Status: p.prontaParaSync ? 'Pronto para sync' : 'Rascunho',
    Data: p.createdAt ? new Date(p.createdAt).toLocaleDateString('pt-BR') : '-',
    Fotos: p.photoCount || 0,
  }));

  const parcelMap = new Map(normalizedParcels.map((p) => [p.id, p]));

  let plantRows = [];
  try {
    if (onProgress) onProgress(0.5, 'Buscando plantas...');
    const allPlants = await fetchAllPlants();
    currentStep++;
    if (onProgress) onProgress(currentStep / totalSteps, 'Processando plantas...');
    plantRows = allPlants
      .filter((plant) => parcelMap.has(plant.parcela))
      .map((plant) => {
        const parentParcel = parcelMap.get(plant.parcela);
        return {
          Propriedade: parentParcel?.propertyCode || '',
          UT: parentParcel?.utCode || '',
          Parcela_ID: parentParcel?.id_parcela ?? '',
          Especie: plant.especie || '',
          DAP_cm: plant.dap_cm ?? '',
          Altura_cm: plant.altura_cm ?? '',
          Categoria: plant.categoria ?? '',
          Com_Foto: plant.foto_especie ? 'Sim' : 'Nao',
        };
      });
  } catch (err) {
    if (!err?.isAbort) safeError('Error fetching plants for export:', err);
  }

  if (onProgress) onProgress(0.9, 'Gerando arquivo Excel...');
  const wsParcels = XLSX.utils.json_to_sheet(parcelRows);
  const wsPlants = XLSX.utils.json_to_sheet(plantRows);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, wsParcels, 'Parcelas');
  XLSX.utils.book_append_sheet(wb, wsPlants, 'Plantas');

  if (onProgress) onProgress(1.0, 'Baixando arquivo...');
  XLSX.writeFile(wb, filename);
};

export const exportToCSV = async (parcels, usersById = null) => {
  const csvEscape = (val) => {
    const str = String(val ?? '');
    if (str.includes(',') || str.includes('"') || str.includes('\n')) {
      return `"${str.replace(/"/g, '""')}"`;
    }
    return str;
  };

  const normalizedParcels = parcels.map((p) => normalizeParcelRecord(p, usersById));
  const parcelMap = new Map(normalizedParcels.map((p) => [p.id, p]));

  let allPlants = [];
  try {
    allPlants = await fetchAllPlants();
  } catch (err) {
    if (!err?.isAbort) safeError('Error fetching plants for CSV export:', err);
  }

  const headers = ['Propriedade', 'UT', 'Parcela', 'Area_ha', 'Observacoes', 'Usuario', 'Status', 'Data', 'Fotos'];
  const rows = normalizedParcels.map((p) => [
    csvEscape(p.propertyCode || ''),
    csvEscape(p.utCode || ''),
    p.id_parcela,
    p.area_ha != null ? p.area_ha : '',
    csvEscape(p.observacoes || ''),
    csvEscape(p.displayUser || ''),
    p.prontaParaSync ? 'Pronto para sync' : 'Rascunho',
    p.createdAt ? new Date(p.createdAt).toLocaleDateString('pt-BR') : '-',
    p.photoCount || 0,
  ]);

  const csvContent = [headers.join(','), ...rows.map((row) => row.join(','))].join('\n');

  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const link = document.createElement('a');
  const objectUrl = URL.createObjectURL(blob);
  link.href = objectUrl;
  link.download = 'urutau_parcelas.csv';
  link.click();
  setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);

  if (allPlants.length > 0) {
    const plantHeaders = ['Propriedade', 'UT', 'Parcela', 'Especie', 'DAP_cm', 'Altura_cm', 'Categoria', 'Com_Foto'];
    const plantRows = allPlants
      .filter((plant) => parcelMap.has(plant.parcela))
      .map((plant) => {
        const parentParcel = parcelMap.get(plant.parcela);
        return [
          csvEscape(parentParcel?.propertyCode || ''),
          csvEscape(parentParcel?.utCode || ''),
          parentParcel?.id_parcela ?? '',
          csvEscape(plant.especie || ''),
          plant.dap_cm ?? '',
          plant.altura_cm ?? '',
          csvEscape(plant.categoria ?? ''),
          plant.foto_especie ? 'Sim' : 'Nao',
        ];
      });

    const plantsCsv = [plantHeaders.join(','), ...plantRows.map((row) => row.join(','))].join('\n');
    const plantsBlob = new Blob([plantsCsv], { type: 'text/csv;charset=utf-8;' });
    const plantsLink = document.createElement('a');
    const plantsObjectUrl = URL.createObjectURL(plantsBlob);
    plantsLink.href = plantsObjectUrl;
    plantsLink.download = 'urutau_plantas.csv';
    plantsLink.click();
    setTimeout(() => URL.revokeObjectURL(plantsObjectUrl), 1000);
  }
}

// ============================================================
// ADMIN USER MANAGEMENT FUNCTIONS
// ============================================================

/**
 * Update user's isAdmin flag
 */
export const updateUserAdmin = async (userId, isAdmin) => {
  try {
    const record = await pb.collection('users').update(userId, {
      isAdmin: isAdmin,
    });
    return { success: true, record };
  } catch (error) {
    safeError('Error updating user admin:', error);
    return { success: false, error: error.message };
  }
};

/**
 * Delete a user (and optionally their data)
 */
export const deleteUser = async (userId, deleteUserData = false) => {
  const errors = [];
  try {
    if (deleteUserData) {
      const userParcelas = await pb.collection('parcelas').getFullList({
        filter: `user = "${userId}"`,
      });

      const allPlantaIds = [];
      for (const parcela of userParcelas) {
        try {
          const plantas = await pb.collection('plantas').getFullList({
            filter: `parcela = "${parcela.id}"`,
          });
          allPlantaIds.push(...plantas.map((p) => p.id));
        } catch (e) {
          errors.push(`Failed to fetch plants for parcela ${parcela.id}: ${e.message}`);
        }
      }

      for (const plantaId of allPlantaIds) {
        try {
          await pb.collection('plantas').delete(plantaId);
        } catch (e) {
          errors.push(`Failed to delete plant ${plantaId}: ${e.message}`);
        }
      }

      for (const parcela of userParcelas) {
        try {
          await pb.collection('parcelas').delete(parcela.id);
        } catch (e) {
          errors.push(`Failed to delete parcela ${parcela.id}: ${e.message}`);
        }
      }
    }

    try {
      await pb.collection('users').delete(userId);
    } catch (e) {
      errors.push(`Failed to delete user: ${e.message}`);
      return { success: false, error: errors.join('; ') };
    }

    if (errors.length > 0) {
      return { success: true, warning: `User deleted but some data could not be removed: ${errors.join('; ')}` };
    }

    return { success: true };
  } catch (error) {
    safeError('Error deleting user:', error);
    return { success: false, error: error.message };
  }
};

/**
 * Get user's parcelas count
 */
export const getUserParcelasCount = async (userId) => {
  try {
    const result = await pb.collection('parcelas').getList(1, 1, {
      filter: `user = "${userId}"`,
    });
    return result.totalItems;
  } catch (error) {
    safeError('Error counting user parcelas:', error);
    return 0;
  }
};

export const getAllUsersParcelasCount = async () => {
  try {
    const counts = {};
    let page = 1;
    const perPage = 500;
    let hasMore = true;

    while (hasMore) {
      const result = await pb.collection('parcelas').getList(page, perPage, {
        fields: 'user',
      });
      for (const parcela of result.items) {
        const uid = parcela.user || '_none_';
        counts[uid] = (counts[uid] || 0) + 1;
      }
      hasMore = result.items.length === perPage;
      page++;
    }

    return counts;
  } catch (error) {
    if (error?.isAbort) return {};
    safeError('Error counting all user parcelas:', error);
    return {};
  }
};

/**
 * Reset user password (requires current password or superuser auth)
 */
export const resetUserPassword = async (userId, newPassword) => {
  try {
    const record = await pb.collection('users').update(userId, {
      password: newPassword,
      passwordConfirm: newPassword,
    });
    return { success: true, record };
  } catch (error) {
    safeError('Error resetting password:', error);
    return { success: false, error: error.message };
  }
};

