import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { TreePine, Eye, EyeOff, Loader2, MapPin, Users } from 'lucide-react';

const Login = () => {
  const [identity, setIdentity] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(true);
  const [formError, setFormError] = useState('');
  const { login, loading, error } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();

    const normalizedIdentity = identity.trim();
    setFormError('');

    if (!normalizedIdentity || !password) {
      setFormError('Informe usuario/email e senha.');
      return;
    }

    try {
      const result = await login(normalizedIdentity, password, { remember: rememberMe });
      
      if (result.success) {
        // HashRouter precisa de /#/, não pode usar window.location
        navigate('/', { replace: true });
      } else if (result.error) {
        setFormError(result.error);
      }
    } catch (err) {
      setFormError(err.message || 'Erro ao fazer login.');
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-forest-50 to-forest-100 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-20 h-20 bg-forest-700 rounded-2xl shadow-lg mb-4">
            <TreePine className="h-10 w-10 text-white" />
          </div>
          <h1 className="text-3xl font-bold text-gray-900">Urutau</h1>
          <p className="text-gray-600 mt-2">Painel Administrativo</p>
        </div>

        {/* Login Card */}
        <div className="bg-white rounded-2xl shadow-xl p-8">
          <h2 className="text-xl font-semibold text-gray-900 mb-6 text-center">
            Entrar
          </h2>

          {(formError || error) && (
            <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm">
              {formError || error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Email Field */}
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-2">
                Email ou usuario
              </label>
              <input
                id="email"
                type="text"
                value={identity}
                onChange={(e) => setIdentity(e.target.value)}
                className="input-field"
                placeholder="seu@email.com ou usuario"
                autoComplete="username"
                required
                disabled={loading}
              />
            </div>

            {/* Password Field */}
            <div>
              <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-2">
                Senha
              </label>
              <div className="relative">
                <input
                  id="password"
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="input-field pr-10"
                  placeholder="••••••••"
                  autoComplete="current-password"
                  required
                  disabled={loading}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                  tabIndex={-1}
                >
                  {showPassword ? (
                    <EyeOff className="h-5 w-5" />
                  ) : (
                    <Eye className="h-5 w-5" />
                  )}
                </button>
              </div>
            </div>

            {/* Remember Me */}
            <div className="flex items-center">
              <input
                id="remember-me"
                type="checkbox"
                checked={rememberMe}
                onChange={(e) => setRememberMe(e.target.checked)}
                className="h-4 w-4 text-forest-600 focus:ring-forest-500 border-gray-300 rounded"
              />
              <label htmlFor="remember-me" className="ml-2 block text-sm text-gray-700">
                Lembrar-me
              </label>
            </div>

            {/* Submit Button */}
            <button
              type="submit"
              disabled={loading}
              className="w-full btn-primary justify-center py-3 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? (
                <>
                  <Loader2 className="h-5 w-5 animate-spin" />
                  Entrando...
                </>
              ) : (
                'Entrar'
              )}
            </button>
          </form>

          {/* Footer */}
          <div className="mt-8 text-center">
            <p className="text-sm text-gray-500">
              Acesso restrito a usuários autorizados
            </p>
            <p className="text-xs text-gray-400 mt-2">
              Powered by PocketBase
            </p>
          </div>
        </div>

  {/* Info Cards */}
  <div className="grid grid-cols-3 gap-4 mt-8">
    <div className="bg-white/60 backdrop-blur rounded-lg p-4 text-center">
    <div className="inline-flex items-center justify-center w-10 h-10 bg-forest-100 rounded-lg mb-2">
      <MapPin className="h-5 w-5 text-forest-700" />
    </div>
    <p className="text-xs text-gray-600">Propriedades</p>
    </div>
    <div className="bg-white/60 backdrop-blur rounded-lg p-4 text-center">
    <div className="inline-flex items-center justify-center w-10 h-10 bg-forest-100 rounded-lg mb-2">
      <TreePine className="h-5 w-5 text-forest-700" />
    </div>
    <p className="text-xs text-gray-600">Parcelas</p>
    </div>
    <div className="bg-white/60 backdrop-blur rounded-lg p-4 text-center">
    <div className="inline-flex items-center justify-center w-10 h-10 bg-forest-100 rounded-lg mb-2">
      <Users className="h-5 w-5 text-forest-700" />
    </div>
    <p className="text-xs text-gray-600">Plantas</p>
    </div>
  </div>
      </div>
    </div>
  );
};

export default Login;
