import React, { useEffect, useMemo, useState, useCallback, useRef, startTransition } from 'react';
import { useAuth } from '../context/AuthContext';
import { fetchAllParcels, fetchAllPlants, fetchUsers } from '../services/pocketbase';
import safeError from '../services/logger';
import { FileSpreadsheet, FileText, Image, Download, Users, TreePine, MapPin, Loader2, AlertTriangle, X } from 'lucide-react';

const EXPORT_HISTORY_KEY = 'urutau_export_history';
let _reportIdCounter = 0;

const Reports = () => {
  const { hasPermission, user } = useAuth();
  const [parcels, setParcels] = useState([]);
  const [plants, setPlants] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [generatingReportId, setGeneratingReportId] = useState(null);
  const [exportHistory, setExportHistory] = useState([]);
  const [actionError, setActionError] = useState(null);
  const idCounterRef = useRef(++_reportIdCounter);

  const loadData = useCallback(async () => {
    try {
      startTransition(() => { setLoading(true); setError(null); });

      const [parcelsData, plantsData, userList] = await Promise.all([
        fetchAllParcels(),
        fetchAllPlants(),
        fetchUsers().catch(() => []),
      ]);

      const ubMap = new Map();
      for (const u of userList) {
        ubMap.set(u.id, u.name || u.email);
      }

      const resolvedParcels = parcelsData.map((p) => {
        if (p.displayUser && p.displayUser !== '-' && !p.displayUser.includes('@')) return p;
        if (p.user && ubMap.has(p.user)) {
          return { ...p, displayUser: ubMap.get(p.user) };
        }
        return p;
      });

      startTransition(() => {
        setParcels(resolvedParcels);
        setPlants(plantsData);
      });
    } catch (err) {
      safeError('Error loading reports data:', err);
      startTransition(() => setError('Erro ao carregar dados para relatórios'));
    } finally {
      startTransition(() => setLoading(false));
    }
  }, []);

  const loadHistory = useCallback(() => {
    try {
      const raw = localStorage.getItem(EXPORT_HISTORY_KEY);
      const parsed = raw ? JSON.parse(raw) : [];
      if (Array.isArray(parsed)) {
        startTransition(() => setExportHistory(parsed));
      }
    } catch (err) {
      safeError('Error loading export history:', err);
      startTransition(() => setExportHistory([]));
    }
  }, []);

  useEffect(() => {
    startTransition(() => {
      loadData();
      loadHistory();
    });
  }, [loadData, loadHistory]);

  useEffect(() => {
    if (!actionError) return;
    const id = setTimeout(() => setActionError(null), 5000);
    return () => clearTimeout(id);
  }, [actionError]);

  const saveHistoryEntry = useCallback((type, format, records) => {
    const nextEntry = {
      id: `${Date.now()}_${idCounterRef.current}_${Math.random().toString(36).slice(2, 8)}`,
      createdAt: new Date().toISOString(),
      type,
      format,
      records,
      user: user?.name || user?.email || 'N/A',
    };

    const next = [nextEntry, ...exportHistory].slice(0, 50);
    setExportHistory(next);
    localStorage.setItem(EXPORT_HISTORY_KEY, JSON.stringify(next));
  }, [user, exportHistory]);

  const summaryByProperty = useMemo(() => {
    const grouped = new Map();

    for (const parcel of parcels) {
      const property = parcel.propertyCode || 'Sem propriedade';
      if (!grouped.has(property)) {
        grouped.set(property, {
          propriedade: property,
          parcelas: 0,
          comFotos: 0,
          sincronizadas: 0,
          pendentes: 0,
        });
      }

      const row = grouped.get(property);
      row.parcelas += 1;
      row.comFotos += parcel.photoCount > 0 ? 1 : 0;
      row.sincronizadas += parcel.prontaParaSync ? 1 : 0;
      row.pendentes += parcel.prontaParaSync ? 0 : 1;
    }

    return [...grouped.values()].sort((a, b) => b.parcelas - a.parcelas);
  }, [parcels]);

  const summaryBySpecies = useMemo(() => {
    const grouped = new Map();

    for (const plant of plants) {
      const species = (plant.especie || 'Nao informada').trim() || 'Nao informada';
      grouped.set(species, (grouped.get(species) || 0) + 1);
    }

    return [...grouped.entries()]
      .map(([especie, quantidade]) => ({ especie, quantidade }))
      .sort((a, b) => b.quantidade - a.quantidade);
  }, [plants]);

  const summaryByUser = useMemo(() => {
    const grouped = new Map();
    let unnamedCount = 0;

    for (const parcel of parcels) {
      const collector = parcel.displayUser && parcel.displayUser !== '-'
        ? parcel.displayUser
        : null;

      if (collector) {
        grouped.set(collector, (grouped.get(collector) || 0) + 1);
      } else {
        unnamedCount++;
      }
    }

    const result = [...grouped.entries()]
      .map(([usuario, parcelasCount]) => ({ usuario, parcelas: parcelasCount }))
      .sort((a, b) => b.parcelas - a.parcelas);

    if (unnamedCount > 0) {
      result.push({ usuario: 'Sem usuario atribuido', parcelas: unnamedCount });
    }

    return result;
  }, [parcels]);

  const allPhotos = useMemo(() => {
    const rows = [];

    for (const parcel of parcels) {
      for (const fileName of parcel.fotos_parcela || []) {
        rows.push({
          propriedade: parcel.propertyCode || 'Nao informada',
          ut: parcel.utCode || 'Nao informada',
          parcela: parcel.id_parcela,
          arquivo: fileName,
        });
      }
    }

    return rows;
  }, [parcels]);

  const hasPlants = plants.length > 0;
  const hasNamedUsers = summaryByUser.some((r) => r.usuario !== 'Sem usuario atribuido');

  const reportTypes = [
    {
      id: 'full',
      title: 'Relatorio Completo',
      description: 'Parcelas e plantas com dados reais do banco (2 abas)',
      icon: FileSpreadsheet,
      color: 'bg-blue-500',
      records: parcels.length + plants.length,
      disabled: false,
    },
    {
      id: 'summary',
      title: 'Resumo por Propriedade',
      description: 'Consolidado real por propriedade',
      icon: MapPin,
      color: 'bg-forest-500',
      records: summaryByProperty.length,
      disabled: false,
    },
    {
      id: 'species',
      title: 'Relatorio de Especies',
      description: 'Distribuicao real de especies cadastradas',
      icon: TreePine,
      color: 'bg-green-500',
      records: summaryBySpecies.length,
      disabled: !hasPlants,
      warning: !hasPlants ? 'Nenhuma planta registrada ainda' : null,
    },
    {
      id: 'plants_detail',
      title: 'Plantas Detalhadas',
      description: 'Todas as plantas com especie, DAP, altura e parcela de origem',
      icon: TreePine,
      color: 'bg-teal-500',
      records: plants.length,
      disabled: !hasPlants,
      warning: !hasPlants ? 'Nenhuma planta registrada ainda' : null,
    },
    {
      id: 'users',
      title: 'Relatorio por Usuario',
      description: 'Parcelas agrupadas por usuario coletor',
      icon: Users,
      color: 'bg-purple-500',
      records: summaryByUser.length,
      disabled: !hasNamedUsers,
      warning: !hasNamedUsers ? 'Nenhum usuario atribuido as parcelas ainda' : null,
    },
    {
      id: 'photos',
      title: 'Exportar Metadados das Fotos',
      description: 'Lista real de arquivos de foto das parcelas',
      icon: Image,
      color: 'bg-amber-500',
      records: allPhotos.length,
      disabled: allPhotos.length === 0,
      warning: allPhotos.length === 0 ? 'Nenhuma foto registrada ainda' : null,
    },
  ];

  const downloadExcel = async (sheetName, rows, fileName) => {
    const XLSX = await import('xlsx');

    const worksheet = XLSX.utils.json_to_sheet(rows);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, sheetName);
    XLSX.writeFile(workbook, fileName);
  };

  const generateExcelReport = async (reportId, reportTitle) => {
    if (!hasPermission('export')) {
      return;
    }

    setGeneratingReportId(reportId);

    try {
      const stamp = new Date().toISOString().replace(/[:.]/g, '-');

if (reportId === 'full') {
      const parcelRows = parcels.map((parcel) => ({
        propriedade: parcel.propertyCode || '',
        ut: parcel.utCode || '',
        parcela: parcel.id_parcela,
        area_ha: parcel.area_ha != null ? parcel.area_ha : '',
        observacoes: parcel.observacoes || '',
        usuario: parcel.displayUser || '',
        status: parcel.prontaParaSync ? 'Pronto para sync' : 'Rascunho',
        fotos: parcel.photoCount || 0,
      }));

        const parcelMap = new Map(parcels.map((p) => [p.id, p]));
        const plantRows = plants.map((plant) => {
          const parentParcel = parcelMap.get(plant.parcela);
          return {
            propriedade: parentParcel?.propertyCode || '',
            ut: parentParcel?.utCode || '',
            parcela: parentParcel?.id_parcela ?? '',
            especie: plant.especie || '',
            dap_cm: plant.dap_cm ?? '',
            altura_cm: plant.altura_cm ?? '',
            categoria: plant.categoria ?? '',
            com_foto: plant.foto_especie ? 'Sim' : 'Nao',
          };
        });

        const XLSX = await import('xlsx');
        const wsParcels = XLSX.utils.json_to_sheet(parcelRows);
        const wsPlants = XLSX.utils.json_to_sheet(plantRows);
        const workbook = XLSX.utils.book_new();
        XLSX.utils.book_append_sheet(workbook, wsParcels, 'Parcelas');
        XLSX.utils.book_append_sheet(workbook, wsPlants, 'Plantas');
        XLSX.writeFile(workbook, `relatorio_completo_${stamp}.xlsx`);
        saveHistoryEntry(reportTitle, 'Excel', parcelRows.length + plantRows.length);
      }

      if (reportId === 'summary') {
        await downloadExcel('Resumo', summaryByProperty, `resumo_propriedade_${stamp}.xlsx`);
        saveHistoryEntry(reportTitle, 'Excel', summaryByProperty.length);
      }

      if (reportId === 'species') {
        await downloadExcel('Especies', summaryBySpecies, `relatorio_especies_${stamp}.xlsx`);
        saveHistoryEntry(reportTitle, 'Excel', summaryBySpecies.length);
      }

      if (reportId === 'plants_detail') {
        const parcelMap = new Map(parcels.map((p) => [p.id, p]));
        const detailRows = plants.map((plant) => {
          const parentParcel = parcelMap.get(plant.parcela);
          return {
            propriedade: parentParcel?.propertyCode || '',
            ut: parentParcel?.utCode || '',
            parcela: parentParcel?.id_parcela ?? '',
            especie: plant.especie || '',
            dap_cm: plant.dap_cm ?? '',
            altura_cm: plant.altura_cm ?? '',
            categoria: plant.categoria ?? '',
            com_foto: plant.foto_especie ? 'Sim' : 'Nao',
          };
        });
        await downloadExcel('Plantas', detailRows, `plantas_detalhadas_${stamp}.xlsx`);
        saveHistoryEntry(reportTitle, 'Excel', detailRows.length);
      }

      if (reportId === 'users') {
        await downloadExcel('Usuarios', summaryByUser, `relatorio_usuarios_${stamp}.xlsx`);
        saveHistoryEntry(reportTitle, 'Excel', summaryByUser.length);
      }

      if (reportId === 'photos') {
        await downloadExcel('Fotos', allPhotos, `metadados_fotos_${stamp}.xlsx`);
        saveHistoryEntry(reportTitle, 'Excel', allPhotos.length);
      }
    } catch (err) {
      safeError('Report generation error:', err);
      setActionError('Erro ao gerar relatorio');
    } finally {
      setGeneratingReportId(null);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="h-8 w-8 animate-spin text-forest-600" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 rounded-xl p-6 text-center">
        <p className="text-red-700">{error}</p>
        <button
          onClick={loadData}
          className="mt-4 btn-secondary"
        >
          Tentar novamente
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {actionError && (
        <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg flex items-center justify-between">
          <p className="text-red-700 text-sm">{actionError}</p>
          <button onClick={() => setActionError(null)} className="text-red-500 hover:text-red-700">
            <X className="h-4 w-4" />
          </button>
        </div>
      )}
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Relatórios</h1>
        <p className="text-gray-600 mt-1">
          Gere relatórios e exporte dados do Urutau
        </p>
      </div>

      {/* Report Cards */}
  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
    {reportTypes.map((report) => {
      const Icon = report.icon;
      const isGenerating = generatingReportId === report.id;

      return (
        <div
          key={report.id}
          className={`card hover:shadow-lg transition-shadow group ${report.disabled ? 'opacity-60' : ''}`}
        >
          <div className="flex items-start gap-4">
            <div className={`${report.color} p-4 rounded-xl text-white group-hover:scale-110 transition-transform`}>
              <Icon className="h-6 w-6" />
            </div>
            <div className="flex-1">
              <h3 className="text-lg font-semibold text-gray-900">
                {report.title}
              </h3>
              <p className="text-sm text-gray-500 mt-1">
                {report.description}
              </p>
              <p className="text-xs text-gray-400 mt-2">
                Registros: {report.records}
              </p>

              {report.warning && (
                <p className="text-xs text-amber-600 mt-2 flex items-center gap-1">
                  <AlertTriangle className="h-3 w-3" />
                  {report.warning}
                </p>
              )}

              <div className="mt-4 flex gap-2">
                <button
                  onClick={() => generateExcelReport(report.id, report.title)}
                  disabled={!hasPermission('export') || isGenerating || report.disabled}
                  className="btn-primary text-sm disabled:opacity-50"
                >
                  {isGenerating ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin" />
                      Gerando...
                    </>
                  ) : (
                    <>
                      <FileSpreadsheet className="h-4 w-4" />
                      Excel
                    </>
                  )}
                </button>
                <button
                  disabled
                  className="btn-secondary text-sm disabled:opacity-50 cursor-not-allowed"
                >
                  <FileText className="h-4 w-4" />
                  PDF (em breve)
                </button>
              </div>
            </div>
          </div>
        </div>
      );
    })}
  </div>

      {/* Export History */}
      <div className="card">
        <h2 className="text-xl font-semibold text-gray-900 mb-4">
          Histórico de Exportações
        </h2>
        <div className="overflow-x-auto">
          <table className="min-w-full">
            <thead>
              <tr className="border-b border-gray-200">
                <th className="text-left py-3 text-sm font-medium text-gray-500">Data</th>
                <th className="text-left py-3 text-sm font-medium text-gray-500">Tipo</th>
                <th className="text-left py-3 text-sm font-medium text-gray-500">Usuário</th>
                <th className="text-left py-3 text-sm font-medium text-gray-500">Registros</th>
                <th className="text-left py-3 text-sm font-medium text-gray-500">Formato</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {exportHistory.length === 0 ? (
                <tr>
                  <td className="py-6 text-sm text-gray-400" colSpan={5}>
                    Nenhuma exportação realizada nesta instalação.
                  </td>
                </tr>
              ) : (
                exportHistory.map((item) => (
                  <tr key={item.id} className="hover:bg-gray-50">
                    <td className="py-3 text-sm text-gray-900">
                      {new Date(item.createdAt).toLocaleString('pt-BR')}
                    </td>
                    <td className="py-3 text-sm text-gray-900">{item.type}</td>
                    <td className="py-3 text-sm text-gray-900">{item.user}</td>
                    <td className="py-3 text-sm text-gray-900">{item.records}</td>
                    <td className="py-3">
                      <span className="inline-flex items-center px-2 py-1 bg-forest-100 text-forest-700 rounded text-xs font-medium">
                        {item.format}
                      </span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

export default Reports;
