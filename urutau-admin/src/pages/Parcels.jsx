import React, { useEffect, useState, useCallback, useRef, startTransition } from 'react';
import {
  fetchParcels,
  fetchAllParcels,
  fetchParcelsByIds,
  fetchProperties,
  fetchUTs,
  fetchUsers,
  fetchPlantsByParcel,
  exportToExcel,
  exportToCSV,
  getPhotoUrl,
} from '../services/pocketbase';
import { useAuth } from '../context/AuthContext';
import safeError from '../services/logger';
import {
  Search,
  Filter,
  FileSpreadsheet,
  FileText,
  Image,
  ChevronLeft,
  ChevronRight,
  Eye,
  X,
  Loader2,
  CheckCircle,
  Clock,
  MapPin,
  User,
  TreePine,
  Camera,
} from 'lucide-react';

const ParcelDetailModal = ({ parcel, onClose }) => {
const [plants, setPlants] = useState([]);
const [loadingPlants, setLoadingPlants] = useState(!parcel);

useEffect(() => {
if (!parcel) return;
let cancelled = false;
fetchPlantsByParcel(parcel.id)
.then((data) => {
if (!cancelled) setPlants(data);
})
.catch((err) => {
    if (!err?.isAbort && !cancelled) safeError('fetchPlantsByParcel', err);
})
.finally(() => {
if (!cancelled) setLoadingPlants(false);
});
return () => {
cancelled = true;
};
}, [parcel]);

  if (!parcel) return null;

  const photoUrls = (parcel.fotos_parcela || [])
    .filter(Boolean)
    .map((_, i) => getPhotoUrl(parcel, i))
    .filter(Boolean);

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      onClick={onClose}
    >
      <div
        className="bg-white rounded-2xl shadow-2xl w-full max-w-3xl max-h-[90vh] overflow-y-auto m-4"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between rounded-t-2xl z-10">
          <h2 className="text-xl font-bold text-gray-900">
            Parcela {String(parcel.id_parcela).padStart(3, '0')}
          </h2>
          <button
            onClick={onClose}
            className="p-2 rounded-lg hover:bg-gray-100 text-gray-500"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="px-6 py-5 space-y-5">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wider">
                Propriedade
              </p>
              <p className="font-medium text-forest-700 mt-1">
                {parcel.propertyCode || '-'}
              </p>
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wider">
                UT
              </p>
              <p className="font-medium text-gray-900 mt-1">
                {parcel.utCode || '-'}
              </p>
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wider">
                Status
              </p>
              <p className="mt-1">
        {parcel.prontaParaSync ? (
          <span className="inline-flex items-center gap-1 px-2 py-1 bg-emerald-100 text-emerald-700 rounded-full text-xs font-medium">
            <CheckCircle className="h-3 w-3" /> Pronto para sync
          </span>
        ) : (
          <span className="inline-flex items-center gap-1 px-2 py-1 bg-amber-100 text-amber-700 rounded-full text-xs font-medium">
            <Clock className="h-3 w-3" /> Rascunho
          </span>
        )}
              </p>
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wider">
                Usuário
              </p>
              <p className="font-medium text-gray-900 mt-1 flex items-center gap-2">
                <User className="h-4 w-4 text-gray-400" />
                {parcel.displayUser || '-'}
              </p>
            </div>
            <div className="col-span-2">
              <p className="text-xs text-gray-500 uppercase tracking-wider">
                Observações
              </p>
              <p className="font-medium text-gray-900 mt-1">
                {parcel.observacoes || '-'}
              </p>
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wider">
                Data de Criação
              </p>
              <p className="font-medium text-gray-900 mt-1">
                {parcel.createdAt
                  ? new Date(parcel.createdAt).toLocaleString('pt-BR')
                  : '-'}
              </p>
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wider">
                ID
              </p>
              <p className="font-mono text-sm text-gray-600 mt-1">
                {parcel.id}
              </p>
            </div>
          </div>

          {photoUrls.length > 0 && (
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wider mb-2 flex items-center gap-1">
                <Camera className="h-3 w-3" /> Fotos ({photoUrls.length})
              </p>
              <div className="flex gap-3 overflow-x-auto pb-2">
                {photoUrls.map((url, i) => (
                  <img
                    key={i}
                    src={url}
                    alt={`Foto ${i + 1}`}
                    className="h-32 w-32 object-cover rounded-lg border border-gray-200 flex-shrink-0"
                  />
                ))}
              </div>
            </div>
          )}

          <div>
            <p className="text-xs text-gray-500 uppercase tracking-wider mb-2 flex items-center gap-1">
              <TreePine className="h-3 w-3" /> Plantas registradas
            </p>
            {loadingPlants ? (
              <div className="flex items-center justify-center py-8">
                <Loader2 className="h-6 w-6 animate-spin text-forest-600" />
              </div>
            ) : plants.length === 0 ? (
              <p className="text-sm text-gray-400 py-4 text-center">
                Nenhuma planta registrada nesta parcela.
              </p>
            ) : (
              <div className="overflow-x-auto border border-gray-200 rounded-lg">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">
                        Espécie
                      </th>
                      <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">
                        DAP (cm)
                      </th>
                      <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">
                        Altura (cm)
                      </th>
                      <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">
                        Categoria
                      </th>
                      <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">
                        Foto
                      </th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {plants.map((plant) => (
                      <tr key={plant.id} className="hover:bg-gray-50">
                        <td className="px-4 py-3 text-sm font-medium text-gray-900">
                          {plant.especie || '-'}
                        </td>
                        <td className="px-4 py-3 text-sm text-gray-600">
                          {plant.dap_cm ?? '-'}
                        </td>
                        <td className="px-4 py-3 text-sm text-gray-600">
                          {plant.altura_cm ?? '-'}
                        </td>
                        <td className="px-4 py-3 text-sm text-gray-600">
                          {plant.categoria ?? '-'}
                        </td>
                        <td className="px-4 py-3 text-sm text-gray-600">
                          {plant.foto_especie ? (
                            <Image className="h-4 w-4 text-blue-600" />
                          ) : (
                            <span className="text-gray-400">-</span>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

const Parcels = () => {
  const { hasPermission } = useAuth();
  const [parcels, setParcels] = useState([]);
  const [properties, setProperties] = useState([]);
  const [uts, setUTs] = useState([]);
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [totalItems, setTotalItems] = useState(0);
  const [currentPage, setCurrentPage] = useState(1);
  const [selectedParcels, setSelectedParcels] = useState([]);
  const [showFilters, setShowFilters] = useState(true);
  const [detailParcel, setDetailParcel] = useState(null);
  const [actionError, setActionError] = useState(null);

  const [filters, setFilters] = useState({
    property: '',
    ut: '',
    parcelNumber: '',
    user: '',
    syncStatus: '',
    hasPhotos: false,
  });

  const perPage = 25;

  const getUsersById = useCallback(() => {
    const map = new Map();
    for (const u of users) {
      map.set(u.id, u.name || u.email);
    }
    return map;
  }, [users]);

  const loadFiltersData = useCallback(async () => {
    const safe = async (fn) => {
      try {
        return await fn();
      } catch (e) {
        safeError('loadFiltersData', e);
        return [];
      }
    };

    const [props, utList, userList] = await Promise.all([
      safe(fetchProperties),
      safe(fetchUTs),
      safe(fetchUsers),
    ]);
    startTransition(() => {
      setProperties(props);
      setUTs(utList);
      setUsers(userList);
    });
  }, []);

  const loadParcels = useCallback(async () => {
    try {
      startTransition(() => { setLoading(true); setError(null); });
      const result = await fetchParcels(filters, currentPage, perPage, getUsersById());
      startTransition(() => {
        setParcels(result.items);
        setTotalItems(result.totalItems);
      });
    } catch (err) {
      if (err?.isAbort) return;
      startTransition(() => setError('Erro ao carregar parcelas'));
      safeError('loadParcels', err);
    } finally {
      startTransition(() => setLoading(false));
    }
  }, [filters, currentPage, getUsersById]);

  useEffect(() => {
    startTransition(() => { loadFiltersData(); });
  }, [loadFiltersData]);

  useEffect(() => {
    startTransition(() => { loadParcels(); });
  }, [loadParcels]);

  const prevPropertyRef = useRef(filters.property);

  useEffect(() => {
    if (!actionError) return;
    const id = setTimeout(() => setActionError(null), 5000);
    return () => clearTimeout(id);
  }, [actionError]);

  useEffect(() => {
    if (filters.property === prevPropertyRef.current) return;
    prevPropertyRef.current = filters.property;
    startTransition(() => {
      setFilters((prev) => ({ ...prev, ut: '' }));
      setCurrentPage(1);
    });
    fetchUTs(filters.property || null)
      .then((list) => { startTransition(() => setUTs(list)); })
      .catch(() => { startTransition(() => setUTs([])); });
  }, [filters.property]);

  const handleFilterChange = (key, value) => {
    setFilters((prev) => ({ ...prev, [key]: value }));
    setCurrentPage(1);
    setSelectedParcels([]);
  };

  const clearFilters = () => {
    setFilters({
      property: '',
      ut: '',
      parcelNumber: '',
      user: '',
      syncStatus: '',
      hasPhotos: false,
    });
    setCurrentPage(1);
  };

  const toggleParcelSelection = (parcelId) => {
    setSelectedParcels((prev) =>
      prev.includes(parcelId)
        ? prev.filter((id) => id !== parcelId)
        : [...prev, parcelId]
    );
  };

  const selectAllParcels = () => {
    if (selectedParcels.length === parcels.length) {
      setSelectedParcels([]);
    } else {
      setSelectedParcels(parcels.map((p) => p.id));
    }
  };

  const handleExport = async (format) => {
    try {
      const usersMap = getUsersById();
      let dataToExport;
      if (selectedParcels.length > 0) {
        dataToExport = await fetchParcelsByIds(selectedParcels, usersMap);
      } else {
        dataToExport = await fetchAllParcels(filters, usersMap);
      }

      if (format === 'excel') {
        await exportToExcel(dataToExport, 'urutau.xlsx', usersMap);
      } else if (format === 'csv') {
        await exportToCSV(dataToExport, usersMap);
      }
    } catch (err) {
      if (err?.isAbort) return;
      safeError('Export error:', err);
      setActionError('Erro ao exportar dados');
    }
  };

  const totalPages = Math.ceil(totalItems / perPage);

  return (
    <div className="space-y-6">
      {detailParcel && (
        <ParcelDetailModal
          parcel={detailParcel}
          onClose={() => setDetailParcel(null)}
        />
      )}

      {actionError && (
        <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg flex items-center justify-between">
          <p className="text-red-700 text-sm">{actionError}</p>
          <button onClick={() => setActionError(null)} className="text-red-500 hover:text-red-700">
            <X className="h-4 w-4" />
          </button>
        </div>
      )}

      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Parcelas</h1>
          <p className="text-gray-600 mt-1">
            {totalItems} parcelas encontradas
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={() => setShowFilters(!showFilters)}
            className="btn-secondary"
          >
            <Filter className="h-4 w-4" />
            {showFilters ? 'Ocultar filtros' : 'Mostrar filtros'}
          </button>
          <button
            onClick={loadParcels}
            className="btn-secondary"
            disabled={loading}
          >
            {loading ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Search className="h-4 w-4" />
            )}
            Atualizar
          </button>
        </div>
      </div>

      <div className="flex gap-6">
        {showFilters && (
          <div className="w-64 flex-shrink-0 space-y-4">
            <div className="card">
              <div className="flex items-center justify-between mb-4">
                <h3 className="font-semibold text-gray-900">Filtros</h3>
                <button
                  onClick={clearFilters}
                  className="text-sm text-forest-600 hover:text-forest-700"
                >
                  Limpar
                </button>
              </div>

              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Propriedade
                  </label>
                  <select
                    value={filters.property}
                    onChange={(e) =>
                      handleFilterChange('property', e.target.value)
                    }
                    className="input-field text-sm"
                  >
                        <option value="">Todas</option>
                        {properties.map((prop) => (
                          <option key={prop.id} value={prop.id}>
                            {prop.codigo}
                          </option>
                        ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    UT
                  </label>
                  <select
                    value={filters.ut}
                    onChange={(e) =>
                      handleFilterChange('ut', e.target.value)
                    }
                    className="input-field text-sm"
                  >
                    <option value="">Todas</option>
                    {uts.map((ut) => {
                      const propCodigo = ut.expand?.propriedade?.codigo || ut.propriedade || '?';
                      return (
                        <option key={ut.id} value={ut.id}>
                          {propCodigo} - {ut.codigo}
                        </option>
                      );
                    })}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Nº Parcela
                  </label>
                  <input
                    type="text"
                    value={filters.parcelNumber}
                    onChange={(e) =>
                      handleFilterChange('parcelNumber', e.target.value)
                    }
                    placeholder="Ex: 001"
                    className="input-field text-sm"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Usuário
                  </label>
                  <select
                    value={filters.user}
                    onChange={(e) =>
                      handleFilterChange('user', e.target.value)
                    }
                    className="input-field text-sm"
                  >
                    <option value="">Todos</option>
                    {users.map((u) => (
                      <option key={u.id} value={u.id}>
                        {u.name || u.email}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Status
                  </label>
                  <select
                    value={filters.syncStatus}
                    onChange={(e) =>
                      handleFilterChange('syncStatus', e.target.value)
                    }
                    className="input-field text-sm"
                  >
                    <option value="">Todos</option>
<option value="synced">Pronto para sync</option>
<option value="pending">Rascunho</option>
                  </select>
                </div>

                <div className="flex items-center">
                  <input
                    type="checkbox"
                    id="hasPhotos"
                    checked={filters.hasPhotos}
                    onChange={(e) =>
                      handleFilterChange('hasPhotos', e.target.checked)
                    }
                    className="h-4 w-4 text-forest-600 focus:ring-forest-500 border-gray-300 rounded"
                  />
                  <label
                    htmlFor="hasPhotos"
                    className="ml-2 text-sm text-gray-700"
                  >
                    Com fotos
                  </label>
                </div>
              </div>
            </div>
          </div>
        )}

        <div className="flex-1 space-y-4">
          <div className="card">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-4">
                <label className="flex items-center">
                  <input
                    type="checkbox"
                    checked={
                      selectedParcels.length === parcels.length &&
                      parcels.length > 0
                    }
                    onChange={selectAllParcels}
                    className="h-4 w-4 text-forest-600 focus:ring-forest-500 border-gray-300 rounded"
                  />
                  <span className="ml-2 text-sm text-gray-700">
                    {selectedParcels.length > 0
                  ? `${selectedParcels.length} selecionadas`
                    : 'Selecionar todas da página'}
                  </span>
                </label>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => handleExport('excel')}
                  className="btn-secondary text-sm"
                  disabled={!hasPermission('export')}
                >
                  <FileSpreadsheet className="h-4 w-4" />
                  Excel
                </button>
                <button
                  onClick={() => handleExport('csv')}
                  className="btn-secondary text-sm"
                  disabled={!hasPermission('export')}
                >
                  <FileText className="h-4 w-4" />
                  CSV
                </button>
              </div>
            </div>
          </div>

          <div className="card overflow-hidden p-0">
            {loading ? (
              <div className="flex items-center justify-center h-64">
                <Loader2 className="h-8 w-8 animate-spin text-forest-600" />
              </div>
            ) : error ? (
              <div className="p-8 text-center text-red-600">{error}</div>
            ) : parcels.length === 0 ? (
              <div className="p-8 text-center text-gray-500">
                <MapPin className="h-12 w-12 mx-auto mb-4 text-gray-300" />
                <p>Nenhuma parcela encontrada</p>
                <button onClick={clearFilters} className="mt-4 btn-secondary">
                  Limpar filtros
                </button>
              </div>
            ) : (
              <>
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                      <tr>
                        <th className="px-6 py-3 w-10">
                          <span className="sr-only">Select</span>
                        </th>
<th className="table-header">Propriedade</th>
                    <th className="table-header">UT</th>
                    <th className="table-header">Parcela</th>
                    <th className="table-header">Área (ha)</th>
                    <th className="table-header">Observações</th>
                        <th className="table-header">Usuário</th>
                        <th className="table-header">Status</th>
                        <th className="table-header">Fotos</th>
                        <th className="table-header">Data</th>
                        <th className="table-header">Ações</th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                      {parcels.map((parcel) => (
                        <tr key={parcel.id} className="hover:bg-gray-50">
                          <td className="px-6 py-4">
                            <input
                              type="checkbox"
                              checked={selectedParcels.includes(parcel.id)}
                              onChange={() =>
                                toggleParcelSelection(parcel.id)
                              }
                              className="h-4 w-4 text-forest-600 focus:ring-forest-500 border-gray-300 rounded"
                            />
                          </td>
                          <td className="table-cell">
                            <span className="font-medium text-forest-700">
                              {parcel.propertyCode || '-'}
                            </span>
                          </td>
                          <td className="table-cell">
                            {parcel.utCode || '-'}
                          </td>
<td className="table-cell">
              <span className="font-mono bg-gray-100 px-2 py-1 rounded">
                {String(parcel.id_parcela).padStart(3, '0')}
              </span>
            </td>
            <td className="table-cell">
              {parcel.area_ha != null
                ? <span className="font-mono text-sm">{parcel.area_ha.toFixed(4)}</span>
                : <span className="text-gray-400">-</span>
              }
            </td>
            <td className="table-cell max-w-xs truncate">
                            {parcel.observacoes || '-'}
                          </td>
                          <td className="table-cell">
                            <div className="flex items-center gap-2">
                              <User className="h-4 w-4 text-gray-400" />
                              {parcel.displayUser || '-'}
                            </div>
                          </td>
                          <td className="table-cell">
        {parcel.prontaParaSync ? (
          <span className="inline-flex items-center gap-1 px-2 py-1 bg-emerald-100 text-emerald-700 rounded-full text-xs font-medium">
            <CheckCircle className="h-3 w-3" /> Sync
          </span>
        ) : (
          <span className="inline-flex items-center gap-1 px-2 py-1 bg-amber-100 text-amber-700 rounded-full text-xs font-medium">
            <Clock className="h-3 w-3" /> Rascunho
          </span>
        )}
                          </td>
                          <td className="table-cell">
                            {parcel.photoCount > 0 ? (
                              <span className="inline-flex items-center gap-1 text-blue-600">
                                <Image className="h-4 w-4" />{' '}
                                {parcel.photoCount}
                              </span>
                            ) : (
                              <span className="text-gray-400">-</span>
                            )}
                          </td>
                          <td className="table-cell text-gray-500">
                            {parcel.createdAt
                              ? new Date(
                                  parcel.createdAt
                                ).toLocaleDateString('pt-BR')
                              : '-'}
                          </td>
                          <td className="table-cell">
                            <button
                              className="text-forest-600 hover:text-forest-800"
                              title="Ver detalhes"
                              onClick={() => setDetailParcel(parcel)}
                            >
                              <Eye className="h-4 w-4" />
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                <div className="px-6 py-4 border-t border-gray-200 flex items-center justify-between">
                  <div className="text-sm text-gray-500">
                    Mostrando {((currentPage - 1) * perPage) + 1} -{' '}
                    {Math.min(currentPage * perPage, totalItems)} de{' '}
                    {totalItems}
                  </div>
                  <div className="flex items-center gap-2">
                    <button
                      onClick={() =>
                        setCurrentPage((p) => Math.max(1, p - 1))
                      }
                      disabled={currentPage === 1}
                      className="p-2 rounded-lg border border-gray-300 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      <ChevronLeft className="h-4 w-4" />
                    </button>
                    <span className="text-sm text-gray-700">
                      Página {currentPage} de {totalPages}
                    </span>
                    <button
                      onClick={() =>
                        setCurrentPage((p) => Math.min(totalPages, p + 1))
                      }
                      disabled={currentPage === totalPages}
                      className="p-2 rounded-lg border border-gray-300 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      <ChevronRight className="h-4 w-4" />
                    </button>
                  </div>
                </div>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default Parcels;
