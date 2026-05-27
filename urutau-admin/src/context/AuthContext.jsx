/* eslint-disable react-refresh/only-export-components */
import { createContext, useContext, useState, useEffect, useCallback, useMemo, useRef } from 'react';
import { pb, loginUser, logoutUser, getCurrentUser, isAuthenticated, onAuthExpired } from '../services/pocketbase';

const AuthContext = createContext(null);

const useAuth = () => {
const context = useContext(AuthContext);
if (!context) {
throw new Error('useAuth must be used within an AuthProvider');
}
return context;
};

const AuthProvider = ({ children }) => {
const [user, setUser] = useState(() => {
if (isAuthenticated()) {
return getCurrentUser();
}
return null;
});
const [initializing, setInitializing] = useState(!user);
const [loading, setLoading] = useState(false);
const [error, setError] = useState(null);
const didInit = useRef(false);

useEffect(() => {
if (didInit.current) return;
didInit.current = true;
setInitializing(false);
}, []);

useEffect(() => {
const unsub = pb.authStore.onChange((_token, record) => {
if (record) {
setUser(getCurrentUser());
} else {
setUser(null);
}
});
return () => { if (typeof unsub === 'function') unsub(); };
}, []);

  const login = useCallback(async (email, password, { remember = true } = {}) => {
    setError(null);
    setLoading(true);

    try {
      const result = await loginUser(email, password, { remember });

      if (result.success) {
        setUser(result.user);
        return { success: true };
      } else {
        setError(result.error);
        return { success: false, error: result.error };
      }
    } catch (err) {
      setError(err.message);
      return { success: false, error: err.message };
    } finally {
      setLoading(false);
    }
  }, []);

  const logout = useCallback(() => {
    logoutUser();
    setUser(null);
    setError(null);
  }, []);

  useEffect(() => {
    onAuthExpired(() => {
      logout();
    });
  }, [logout]);

  const hasPermission = useCallback((action) => {
    if (!user) return false;
    switch (action) {
      case 'view':
        return user.canView;
      case 'edit':
        return user.canEdit;
      case 'delete':
        return user.canDelete;
      case 'export':
        return user.canExport;
      default:
        return false;
    }
  }, [user]);

  const value = useMemo(() => ({
    user,
    initializing,
    loading,
    error,
    login,
    logout,
    isAuthenticated: !!user,
    hasPermission,
    isAdmin: user?.role === 'admin',
  }), [user, initializing, loading, error, login, logout, hasPermission]);

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};

export { AuthContext, useAuth, AuthProvider };
export default AuthContext;
