import React, { useState, useEffect, useCallback } from 'react';
import { Outlet, Link, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import {
  LayoutDashboard,
  TreePine,
  Image,
  FileSpreadsheet,
  Users,
  LogOut,
  Menu,
  X,
  ChevronRight
} from 'lucide-react';

const Layout = () => {
  const { user, logout, isAdmin } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [mobileOpen, setMobileOpen] = useState(false);

  const closeMobile = useCallback(() => setMobileOpen(false), []);

  useEffect(() => {
    closeMobile();
  }, [location.pathname, closeMobile]);

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const navigation = [
    { name: 'Dashboard', href: '/', icon: LayoutDashboard },
    { name: 'Parcelas', href: '/parcels', icon: TreePine },
    { name: 'Fotos', href: '/photos', icon: Image },
    { name: 'Relatórios', href: '/reports', icon: FileSpreadsheet },
    ...(isAdmin ? [{ name: 'Usuários', href: '/users', icon: Users }] : []),
  ];

  return (
    <div className="min-h-screen bg-gray-50 flex">
      {mobileOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/50 md:hidden"
          onClick={closeMobile}
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
            >
              <Menu className="h-5 w-5" />
            </button>
            <button
              onClick={() => setSidebarOpen(!sidebarOpen)}
              className="hidden md:block p-2 rounded-lg hover:bg-gray-100 text-gray-600 transition-colors"
            >
              {sidebarOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
            </button>
          </div>

          <div className="flex items-center gap-2 text-sm text-gray-500">
            <span>Urutau</span>
            <ChevronRight className="h-4 w-4" />
            <span className="text-forest-700 font-medium">
              {navigation.find(n => n.href === location.pathname)?.name || 'Dashboard'}
            </span>
          </div>
        </header>

        <main className="flex-1 overflow-auto p-6">
          <div className="max-w-7xl mx-auto">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
};

export default Layout;
