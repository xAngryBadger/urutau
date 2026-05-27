import React, { useEffect, useState, useCallback, startTransition } from 'react';
import { Link } from 'react-router-dom';
import { getStats, getTopSpecies } from '../services/pocketbase';
import safeError from '../services/logger';
import {
  TreePine,
  MapPin,
  Image,
  Users,
  CheckCircle,
  Clock,
  Calendar,
  RefreshCw
} from 'lucide-react';

const Dashboard = () => {
  const [stats, setStats] = useState(null);
  const [topSpecies, setTopSpecies] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [lastUpdated, setLastUpdated] = useState(null);
  const [minutesAgo, setMinutesAgo] = useState(0);

  useEffect(() => {
    if (!lastUpdated) return;
    const update = () => {
      setMinutesAgo(Math.floor((Date.now() - lastUpdated.getTime()) / 1000 / 60));
    };
    update();
    const id = setInterval(update, 60000);
    return () => clearInterval(id);
  }, [lastUpdated]);

  const loadStats = useCallback(async () => {
    try {
      startTransition(() => { setLoading(true); setError(null); });
      const timeoutMs = 12000;
      let settled = false;
      const timeoutPromise = new Promise((_resolve, reject) =>
        setTimeout(() => {
          if (!settled) {
            settled = true;
            reject(new Error('timeout'));
          }
        }, timeoutMs)
      );
      const statsPromise = Promise.all([getStats(), getTopSpecies(5)]);
      const [statsData, speciesData] = await Promise.race([statsPromise, timeoutPromise]);
      settled = true;
      startTransition(() => {
        setStats(statsData);
        setTopSpecies(speciesData);
        setLastUpdated(new Date());
      });
    } catch (err) {
      safeError('Stats load error:', err);
      startTransition(() => {
        setError(err.message === 'timeout'
          ? 'Tempo esgotado ao carregar estatísticas. Tente novamente.'
          : 'Erro ao carregar estatísticas');
      });
    } finally {
      startTransition(() => setLoading(false));
    }
  }, []);

  useEffect(() => {
    startTransition(() => { loadStats(); });
  }, [loadStats]);

  const statCards = [
    {
      title: 'Propriedades',
      value: stats?.totalProperties || 0,
      icon: MapPin,
      color: 'bg-blue-500',
    },
    {
      title: 'UTs',
      value: stats?.totalUTs || 0,
      icon: TreePine,
      color: 'bg-forest-500',
    },
    {
      title: 'Parcelas',
      value: stats?.totalParcels || 0,
      icon: MapPin,
      color: 'bg-wood-500',
    },
    {
      title: 'Plantas',
      value: stats?.totalPlants || 0,
      icon: TreePine,
      color: 'bg-green-500',
    },
    {
      title: 'Usuários',
      value: stats?.totalUsers || 0,
      icon: Users,
      color: 'bg-purple-500',
    },
    {
      title: 'Sincronizadas',
      value: stats?.syncedParcels || 0,
      icon: CheckCircle,
      color: 'bg-emerald-500',
      subtext: `de ${stats?.totalParcels || 0} parcelas`,
    },
  ];

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-forest-700"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 rounded-xl p-6 text-center">
        <p className="text-red-700">{error}</p>
        <button 
          onClick={loadStats}
          className="mt-4 btn-secondary"
        >
          Tentar novamente
        </button>
      </div>
    );
  }

return (
    <div className="space-y-8">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
          <p className="text-gray-600 mt-1">
            Visão geral — Urutau
          </p>
          {lastUpdated && (
            <p className="text-xs text-gray-500 mt-2 flex items-center gap-1">
              <Clock className="h-3 w-3" />
              Atualizado em: {lastUpdated.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}
              <span className="text-gray-400">
                ({minutesAgo} min atrás)
              </span>
            </p>
          )}
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={loadStats}
            className="p-2 text-sm text-forest-600 hover:text-forest-800 hover:bg-forest-50 rounded-lg transition-colors"
            title="Atualizar dados"
          >
            <RefreshCw className="h-4 w-4" />
          </button>
          <div className="flex items-center gap-2 text-sm text-gray-500">
            <Calendar className="h-4 w-4" />
            {new Date().toLocaleDateString('pt-BR', {
              weekday: 'long',
              year: 'numeric',
              month: 'long',
              day: 'numeric'
            })}
          </div>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {statCards.map((stat) => {
          const Icon = stat.icon;
          return (
            <div 
              key={stat.title}
              className="card hover:shadow-md transition-shadow cursor-pointer group"
            >
              <div className="flex items-start justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">{stat.title}</p>
                  <p className="text-3xl font-bold text-gray-900 mt-2 group-hover:text-forest-700 transition-colors">
                    {stat.value}
                  </p>
                  {stat.subtext && (
                    <p className="text-sm text-gray-500 mt-1">{stat.subtext}</p>
                  )}
                </div>
                <div className={`${stat.color} p-3 rounded-lg text-white`}>
                  <Icon className="h-6 w-6" />
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Sync Status */}
      <div className="card">
        <h2 className="text-xl font-semibold text-gray-900 mb-4">
          Status de Sincronização
        </h2>
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="bg-emerald-100 p-2 rounded-lg">
                <CheckCircle className="h-5 w-5 text-emerald-600" />
              </div>
              <div>
                <p className="font-medium text-gray-900">Sincronizadas</p>
                <p className="text-sm text-gray-500">
                  {stats?.syncedParcels || 0} parcelas
                </p>
              </div>
            </div>
            <div className="text-right">
              <p className="text-2xl font-bold text-emerald-600">
                {stats?.totalParcels ? 
                  Math.round((stats.syncedParcels / stats.totalParcels) * 100) : 0}%
              </p>
            </div>
          </div>

          <div className="w-full bg-gray-200 rounded-full h-3">
            <div 
              className="bg-emerald-500 h-3 rounded-full transition-all duration-500"
              style={{ 
                width: `${stats?.totalParcels ? 
                  (stats.syncedParcels / stats.totalParcels) * 100 : 0}%` 
              }}
            ></div>
          </div>

          <div className="flex items-center justify-between pt-4 border-t border-gray-100">
              <div className="flex items-center gap-3">
                <div className="bg-amber-100 p-2 rounded-lg">
                  <Clock className="h-5 w-5 text-amber-600" />
                </div>
                <div>
                  <p className="font-medium text-gray-900">Pendentes</p>
                  <p className="text-sm text-gray-500">
                    {stats?.pendingParcels || 0} parcelas aguardando sincronização no app
                  </p>
                </div>
              </div>
              <Link to="/parcels" className="btn-secondary text-sm">
                Ver parcelas
              </Link>
          </div>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="card">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">
            Ações Rápidas
          </h3>
          <div className="space-y-3">
            <Link 
              to="/parcels" 
              className="flex items-center gap-3 p-3 rounded-lg hover:bg-gray-50 transition-colors group"
            >
              <div className="bg-forest-100 p-2 rounded-lg group-hover:bg-forest-200 transition-colors">
                <TreePine className="h-5 w-5 text-forest-700" />
              </div>
              <div className="flex-1">
                <p className="font-medium text-gray-900">Ver Parcelas</p>
                <p className="text-sm text-gray-500">Visualizar e exportar dados</p>
              </div>
            </Link>
            <Link 
              to="/photos" 
              className="flex items-center gap-3 p-3 rounded-lg hover:bg-gray-50 transition-colors group"
            >
              <div className="bg-blue-100 p-2 rounded-lg group-hover:bg-blue-200 transition-colors">
                <Image className="h-5 w-5 text-blue-700" />
              </div>
              <div className="flex-1">
                <p className="font-medium text-gray-900">Galeria de Fotos</p>
                <p className="text-sm text-gray-500">Visualizar e baixar imagens</p>
              </div>
            </Link>
          </div>
        </div>

        <div className="card">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">
            Espécies Registradas
          </h3>
          <div className="space-y-2">
            {topSpecies.length === 0 ? (
              <p className="text-sm text-gray-400">Nenhuma espécie cadastrada ainda.</p>
            ) : (
              topSpecies.map((species) => (
                <div 
                  key={species.name}
                  className="flex items-center justify-between py-2"
                >
                  <span className="text-gray-700">{species.name}</span>
                  <span className="bg-forest-100 text-forest-700 px-2 py-1 rounded-full text-sm font-medium">
                    {species.count}
                  </span>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
