import React, { useState, useCallback, useEffect } from 'react';
import { Outlet, Link, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import useServerHealth from '../hooks/useServerHealth';
import ServerOfflineBanner from './ui/ServerOfflineBanner';
import ReadOnlyBadge from './ui/ReadOnlyBadge';
import DemoBanner from './ui/DemoBanner';
import { USE_MOCK } from '../services/mock/demoData';
import {
  LayoutDashboard,
  TreePine,
  Image,
  FileSpreadsheet,
  Users,
  LogOut,
  Menu,
  X,
  ChevronRight,
  AlertTriangle,
  ClipboardList
} from 'lucide-react';

const Layout = () => {
  const { user, logout, isAdmin, isReadOnly } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [mobileOpen, setMobileOpen] = useState(false);
  const health = useServerHealth();

  // R13: alto contraste (campo sob sol) — persistido, igual ao app.
  const [hc, setHc] = useState(() => localStorage.getItem('urutau_tema') === 'hc');
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', hc ? 'hc' : 'claro');
    localStorage.setItem('urutau_tema', hc ? 'hc' : 'claro');
  }, [hc]);

  // Fecha o drawer mobile ao navegar (substitui o effect com setState —
  // o React não aceita efeito sincronizado disparando render em cascata).
  const closeMobileNav = useCallback(() => setMobileOpen(false), []);

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const navigation = [
    { name: 'Dashboard', href: '/', icon: LayoutDashboard },
    { name: 'Parcelas', href: '/parcels', icon: TreePine },
    { name: 'Incidentes', href: '/incidents', icon: AlertTriangle },
    { name: 'Projeto MRV', href: '/mrv', icon: ClipboardList },
    { name: 'Fotos', href: '/photos', icon: Image },
    { name: 'Relatórios', href: '/reports', icon: FileSpreadsheet },
    ...(isAdmin ? [{ name: 'Usuários', href: '/users', icon: Users }] : []),
  ];
  return (
    <div className="min-h-screen bg-gray-50 flex">
      {mobileOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/50 md:hidden"
          onClick={closeMobileNav}
        />
      )}

      <aside
        className={`fixed inset-y-0 left-0 z-50 w-64 transform transition-transform duration-300 ease-in-out ${mobileOpen ? 'translate-x-0' : '-translate-x-full'} md:relative md:translate-x-0 md:z-auto ${sidebarOpen ? 'md:w-64' : 'md:w-20'} bg-urutau-900 text-white flex flex-col`}
      >
        <div className="h-16 flex items-center justify-center border-b border-urutau-800">
          {sidebarOpen || mobileOpen ? (
            <div className="flex items-center gap-2">
              <img src="/urutau_logo.png" width={40} height={40} className="h-10 w-10" alt="Urutau logo" />
              <div>
                <h1 className="font-bold text-lg leading-tight">Urutau</h1>
                <p className="text-xs text-urutau-200">Painel Admin</p>
              </div>
            </div>
          ) : (
            <img src="/urutau_logo.png" width={40} height={40} className="h-10 w-10" alt="Urutau" />
          )}
        </div>

        <nav className="flex-1 py-6">
          <ul className="space-y-1 px-3">
            {navigation.map((item) => {
              const Icon = item.icon;
              const isActive = location.pathname === item.href;

              return (
                <li key={item.name}>
                  <Link
                    to={item.href}
                    onClick={closeMobileNav}
                    className={`flex items-center gap-3 px-4 py-3 rounded-lg transition-all duration-200 ${
                      isActive
                        ? 'bg-forest-700 text-white'
                        : 'text-forest-200 hover:bg-forest-800 hover:text-white'
                    }`}
                  >
                    <Icon className="h-5 w-5 flex-shrink-0" />
                    {(sidebarOpen || mobileOpen) && (
                      <span className="font-medium">{item.name}</span>
                    )}
                  </Link>
                </li>
              );
            })}
          </ul>
        </nav>

        <div className="border-t border-forest-800 p-4">
          {sidebarOpen || mobileOpen ? (
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-white truncate max-w-[140px]">
                  {user?.name || user?.email}
                </p>
                <p className="text-xs text-forest-400">
                  {user?.role === 'admin' ? 'Administrador' : 'Usuário'}
                </p>
              </div>
              <button
                onClick={handleLogout}
                className="p-2 rounded-lg hover:bg-forest-800 text-forest-200 hover:text-white transition-colors"
                title="Sair"
              >
                <LogOut className="h-5 w-5" />
              </button>
            </div>
          ) : (
            <button
              onClick={handleLogout}
              className="w-full flex justify-center p-2 rounded-lg hover:bg-forest-800 text-forest-200 hover:text-white transition-colors"
              title="Sair"
            >
              <LogOut className="h-5 w-5" />
            </button>
          )}
        </div>
      </aside>

      <div className="flex-1 flex flex-col min-w-0">
        <header className="h-16 bg-white border-b border-gray-200 flex items-center justify-between px-6">
          <div className="flex items-center gap-2">
            <button
              onClick={() => setMobileOpen(true)}
              className="md:hidden p-2 rounded-lg hover:bg-gray-100 text-gray-600 transition-colors"
              aria-label="Abrir menu"
            >
              <Menu className="h-5 w-5" />
            </button>
            <button
              onClick={() => setSidebarOpen(!sidebarOpen)}
              className="hidden md:block p-2 rounded-lg hover:bg-gray-100 text-gray-600 transition-colors"
              aria-label={sidebarOpen ? 'Recolher menu' : 'Expandir menu'}
            >
              {sidebarOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
            </button>
          </div>

          <div className="flex items-center gap-3 text-sm text-gray-500">
            <span className="hidden sm:inline">Urutau</span>
            <ChevronRight className="hidden h-4 w-4 sm:inline" />
            <span className="font-medium text-forest-700">
              {navigation.find(n => n.href === location.pathname)?.name || 'Dashboard'}
            </span>
            {isReadOnly && <ReadOnlyBadge role={user?.role} />}
            <button
              type="button"
              onClick={() => setHc((v) => !v)}
              className={`rounded-lg border px-2 py-1 text-xs font-medium transition-colors ${
                hc
                  ? 'border-hc-primary bg-hc-primary text-hc-on-primary'
                  : 'border-gray-300 text-gray-600 hover:bg-gray-100'
              }`}
              aria-pressed={hc}
              title="Alto contraste (uso em campo sob sol)"
            >
              {hc ? 'HC' : 'Alto contraste'}
            </button>
          </div>
        </header>

        <main className="flex-1 overflow-auto p-6">
          <div className="max-w-7xl mx-auto space-y-6">
            {USE_MOCK && <DemoBanner />}
            {health.status === 'offline' && (
              <ServerOfflineBanner onRetry={health.recheck} retrying={false} />
            )}
            <Outlet context={{ health }} />
          </div>
        </main>
      </div>
    </div>
  );
};

export default Layout;
