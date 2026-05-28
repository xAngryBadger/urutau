import React, { useEffect, useState, useCallback, useRef, startTransition } from 'react';
import { useAuth } from '../context/AuthContext';
import { fetchUsers, updateUserAdmin, deleteUser, getAllUsersParcelasCount, resetUserPassword } from '../services/pocketbase';
import safeError from '../services/logger';
import { Users as UsersIcon, Mail, Shield, ShieldCheck, ShieldX, Loader2, Search, Trash2, UserX, Eye, Key, AlertTriangle, UserCheck, X } from 'lucide-react';

const UserActionsModal = ({ user, userParcelasCount, onClose, onAction }) => {
const [action, setAction] = useState(null);
const [deleteUserData, setDeleteUserData] = useState(false);
const [newPassword, setNewPassword] = useState('');
const [confirmPassword, setConfirmPassword] = useState('');
const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    setAction(null);
    setDeleteUserData(false);
    setNewPassword('');
    setConfirmPassword('');
    setLoading(false);
    setError(null);
  }, [user?.id]);

  const handleDelete = async () => {
    setLoading(true);
    setError(null);
    const result = await deleteUser(user.id, deleteUserData);
    if (result.success) {
      onAction('delete');
    } else {
      setError(result.error);
    }
    setLoading(false);
  };

  const handleResetPassword = async () => {
    if (newPassword !== confirmPassword) {
      setError('As senhas não coincidem');
      return;
    }
    if (newPassword.length < 8) {
      setError('A senha deve ter pelo menos 8 caracteres');
      return;
    }
    setLoading(true);
    setError(null);
    const result = await resetUserPassword(user.id, newPassword);
    if (result.success) {
      onAction('password-reset');
    } else {
      setError(result.error);
    }
    setLoading(false);
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      onClick={onClose}
    >
      <div
        className="bg-white rounded-2xl shadow-2xl w-full max-w-md m-4"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="p-6 border-b border-gray-200">
          <h2 className="text-xl font-bold text-gray-900">
            {action === 'delete'
              ? 'Excluir Usuário'
              : action === 'reset-password'
              ? 'Redefinir Senha'
              : 'Ações'}
          </h2>
        </div>

        <div className="p-6 space-y-4">
          {!action && (
            <>
              <div className="bg-gray-50 p-4 rounded-lg">
                <p className="text-sm text-gray-600">Usuário:</p>
                <p className="font-medium text-gray-900">{user.name || user.email}</p>
                <p className="text-sm text-gray-500 mt-1">{user.email}</p>
              </div>

              <div className="space-y-3">
                <button
                  onClick={() => setAction('reset-password')}
                  className="w-full flex items-center justify-center gap-3 px-4 py-3 bg-forest-600 text-white rounded-lg hover:bg-forest-700 transition-colors"
                >
                  <Key className="h-5 w-5" />
                  Redefinir Senha
                </button>

                <button
                  onClick={() => setAction('delete')}
                  className="w-full flex items-center justify-center gap-3 px-4 py-3 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
                >
                  <Trash2 className="h-5 w-5" />
                  Excluir Usuário
                </button>
              </div>
            </>
          )}

          {action === 'delete' && (
            <>
              <div className="bg-red-50 border border-red-200 rounded-lg p-4">
                <div className="flex items-start gap-3">
                  <AlertTriangle className="h-5 w-5 text-red-600 flex-shrink-0 mt-0.5" />
                  <div>
                    <p className="font-medium text-red-900">Atenção!</p>
                    <p className="text-sm text-red-700 mt-1">
                      Esta ação{' '}
                      {deleteUserData
                        ? 'excluirá TODOS os dados deste usuário (parcelas e plantas).'
                        : 'apenas removerá o acesso do usuário.'}
                    </p>
                  </div>
                </div>
              </div>

              <div className="flex items-center gap-3 p-4 bg-gray-50 rounded-lg">
                <input
                  type="checkbox"
                  id="deleteUserData"
                  checked={deleteUserData}
                  onChange={(e) => setDeleteUserData(e.target.checked)}
                  className="h-4 w-4 text-red-600 focus:ring-red-500 border-gray-300 rounded"
                />
                <label htmlFor="deleteUserData" className="text-sm text-gray-700 font-medium">
                  Excluir também {userParcelasCount} parcela(s) deste usuário
                </label>
              </div>

              {error && (
                <div className="bg-red-50 border border-red-200 rounded-lg p-3 text-red-700 text-sm">
                  {error}
                </div>
              )}

              <div className="flex gap-3 pt-4">
                <button
                  onClick={() => setAction(null)}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  Voltar
                </button>
                <button
                  onClick={handleDelete}
                  disabled={loading}
                  className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50"
                >
                  {loading ? 'Excluindo...' : 'Excluir'}
                </button>
              </div>
            </>
          )}

          {action === 'reset-password' && (
            <>
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Nova Senha
                  </label>
                  <input
                    type="password"
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    className="input-field"
                    placeholder="Mínimo 8 caracteres"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Confirmar Senha
                  </label>
                  <input
                    type="password"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    className="input-field"
                    placeholder="Repita a senha"
                  />
                </div>
              </div>

              {error && (
                <div className="bg-red-50 border border-red-200 rounded-lg p-3 text-red-700 text-sm">
                  {error}
                </div>
              )}

              <div className="flex gap-3 pt-4">
                <button
                  onClick={() => {
                    setAction(null);
                    setNewPassword('');
                    setConfirmPassword('');
                    setError(null);
                  }}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  Cancelar
                </button>
                <button
                  onClick={handleResetPassword}
                  disabled={loading}
                  className="flex-1 px-4 py-2 bg-forest-600 text-white rounded-lg hover:bg-forest-700 disabled:opacity-50"
                >
                  {loading ? 'Redefinindo...' : 'Redefinir'}
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
};

const Users = () => {
  const { isAdmin, user: currentUser } = useAuth();
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedUser, setSelectedUser] = useState(null);
  const [parcelasCount, setParcelasCount] = useState({});
  const [actionError, setActionError] = useState(null);
  const [successMessage, setSuccessMessage] = useState(null);

  const loadUsers = useCallback(async () => {
    try {
      startTransition(() => { setLoading(true); setError(null); });
      const [data, counts] = await Promise.all([
        fetchUsers(),
        getAllUsersParcelasCount(),
      ]);
      startTransition(() => {
        setUsers(data);
        setParcelasCount(counts);
      });
    } catch (err) {
      safeError('Error loading users:', err);
      startTransition(() => setError('Erro ao carregar usuarios'));
    } finally {
      startTransition(() => setLoading(false));
    }
  }, []);

  useEffect(() => {
    if (!isAdmin) return;
    startTransition(() => { loadUsers(); });
  }, [isAdmin, loadUsers]);

  useEffect(() => {
    if (!actionError) return;
    const id = setTimeout(() => setActionError(null), 5000);
    return () => clearTimeout(id);
  }, [actionError]);

  useEffect(() => {
    if (!successMessage) return;
    const id = setTimeout(() => setSuccessMessage(null), 5000);
    return () => clearTimeout(id);
  }, [successMessage]);

  const handleToggleAdmin = async (user) => {
    if (user.id === currentUser?.id) return;
    const action = user.isAdmin ? 'remover admin de' : 'conceder admin a';
    if (!window.confirm(`Tem certeza que deseja ${action} ${user.username || user.email}?`)) return;
    const newIsAdmin = !user.isAdmin;
    const result = await updateUserAdmin(user.id, newIsAdmin);
    if (result.success) {
      loadUsers();
    } else {
      setActionError('Erro ao alterar permissão: ' + result.error);
    }
  };

  const handleUserAction = (actionType) => {
    if (actionType === 'delete') {
      loadUsers();
      setSelectedUser(null);
    } else if (actionType === 'password-reset') {
      setSuccessMessage('Senha redefinida com sucesso! A nova senha deve ser usada no proximo login.');
      setSelectedUser(null);
    }
  };

  if (!isAdmin) {
    return (
      <div className="flex items-center justify-center h-64">
        <p className="text-gray-500">Acesso restrito a administradores.</p>
      </div>
    );
  }

  const filteredUsers = users.filter((u) => {
    const term = searchTerm.toLowerCase();
    return (
      (u.name || '').toLowerCase().includes(term) ||
      (u.email || '').toLowerCase().includes(term)
    );
  });

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
      {successMessage && (
        <div className="mb-4 p-4 bg-emerald-50 border border-emerald-200 rounded-lg flex items-center justify-between">
          <p className="text-emerald-700 text-sm">{successMessage}</p>
          <button onClick={() => setSuccessMessage(null)} className="text-emerald-500 hover:text-emerald-700">
            <X className="h-4 w-4" />
          </button>
        </div>
      )}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Usuários</h1>
          <p className="text-gray-600 mt-1">{users.length} usuários cadastrados</p>
        </div>
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
          <input
            type="text"
            placeholder="Buscar por nome ou email..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="input-field pl-10 w-72"
          />
        </div>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-64">
          <Loader2 className="h-8 w-8 animate-spin text-forest-600" />
        </div>
      ) : error ? (
        <div className="bg-red-50 border border-red-200 rounded-xl p-6 text-center">
          <p className="text-red-700">{error}</p>
          <button onClick={loadUsers} className="mt-4 btn-secondary">
            Tentar novamente
          </button>
        </div>
      ) : (
        <div className="card overflow-hidden p-0">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="table-header">Nome</th>
                  <th className="table-header">Email</th>
                  <th className="table-header">Admin</th>
                  <th className="table-header">Parcelas</th>
                  <th className="table-header">Verificado</th>
                  <th className="table-header">Criado em</th>
                  <th className="table-header">Ações</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {filteredUsers.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="px-6 py-8 text-center text-gray-500">
                      {searchTerm ? 'Nenhum usuário encontrado' : 'Nenhum usuário cadastrado'}
                    </td>
                  </tr>
                ) : (
                  filteredUsers.map((u) => (
                    <tr key={u.id} className="hover:bg-gray-50">
                      <td className="table-cell">
                        <div className="flex items-center gap-3">
                          <div className="bg-forest-100 p-2 rounded-lg">
                            <UsersIcon className="h-4 w-4 text-forest-700" />
                          </div>
                          <span className="font-medium text-gray-900">{u.name || '-'}</span>
                        </div>
                      </td>
                      <td className="table-cell">
                        <div className="flex items-center gap-2">
                          <Mail className="h-4 w-4 text-gray-400" />
                          {u.email || '-'}
                        </div>
                      </td>
<td className="table-cell">
{u.id === currentUser?.id ? (
<span
title="Não é possível remover o próprio admin"
className={`inline-flex items-center gap-1 px-3 py-1 rounded-full text-xs font-medium cursor-not-allowed ${
u.isAdmin
? 'bg-emerald-100 text-emerald-700 opacity-60'
: 'bg-gray-100 text-gray-600 opacity-60'
}`}
>
{u.isAdmin ? (
<>
<ShieldCheck className="h-3 w-3" /> Admin
</>
) : (
<>
<UserX className="h-3 w-3" /> Usuário
</>
)}
</span>
) : (
<button
onClick={() => handleToggleAdmin(u)}
className={`inline-flex items-center gap-1 px-3 py-1 rounded-full text-xs font-medium transition-colors ${
u.isAdmin
? 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200'
: 'bg-gray-100 text-gray-600 hover:bg-gray-200'
}`}
>
{u.isAdmin ? (
<>
<ShieldCheck className="h-3 w-3" /> Admin
</>
) : (
<>
<UserX className="h-3 w-3" /> Usuário
</>
)}
</button>
)}
</td>
                      <td className="table-cell">
                        <span className="text-sm text-gray-600">
                          {parcelasCount[u.id] || 0}
                        </span>
                      </td>
                      <td className="table-cell">
                        {u.verified ? (
                          <span className="inline-flex items-center gap-1 px-2 py-1 bg-emerald-100 text-emerald-700 rounded-full text-xs font-medium">
                            <Shield className="h-3 w-3" /> Verificado
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 px-2 py-1 bg-amber-100 text-amber-700 rounded-full text-xs font-medium">
                            Pendente
                          </span>
                        )}
                      </td>
                      <td className="table-cell text-gray-500">
                        {u.created
                          ? new Date(u.created).toLocaleDateString('pt-BR')
                          : '-'}
                      </td>
                      <td className="table-cell">
                        <button
                          onClick={() => setSelectedUser(u)}
                          className="text-forest-600 hover:text-forest-800 p-2 rounded-lg hover:bg-forest-50 transition-colors"
                          title="Gerenciar usuário"
                        >
                          <Eye className="h-4 w-4" />
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {selectedUser && (
        <UserActionsModal
          user={selectedUser}
          userParcelasCount={parcelasCount[selectedUser.id] || 0}
          onClose={() => setSelectedUser(null)}
          onAction={handleUserAction}
        />
      )}
    </div>
  );
};

export default Users;
