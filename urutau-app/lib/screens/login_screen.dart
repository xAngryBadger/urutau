import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;
import '../services/sync_service.dart';
import '../services/secure_storage_service.dart';
import '../data/database.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  AppDatabase get _db => context.read<AppDatabase>();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkFirstRun();
    _checkLastUser();
  }

  /// Verifica se é a primeira execução (sem nenhum usuário no banco).
  /// Admins são injetados fora do app; utilizadores criam conta pelo botão "Criar Conta".
  Future<void> _checkFirstRun() async {
    // Nenhum wizard de admin: primeiro utilizador cria conta normalmente
  }

  Future<void> _checkLastUser() async {
    final prefs = await SharedPreferences.getInstance();
    final lastEmail = prefs.getString('last_email_login');
    if (lastEmail != null) {
      _emailController.text = lastEmail;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  /// Validação robusta de email
  bool _isEmailValido(String email) {
    final regex = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
    return regex.hasMatch(email);
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validar email com regex
    if (!_isEmailValido(_emailController.text.trim())) {
      setState(() => _errorMessage = 'Email inválido. Verifique se incluiu o domínio completo (ex: @gmail.com)');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Autentica localmente
      var usuario = await _db.autenticarUsuario(
        _emailController.text.trim(),
        _senhaController.text,
      );

      // ── Cross-device login: se falhou local, busca no servidor ──
      if (usuario == null) {
        final syncService = context.read<SyncService>();
        if (syncService.isConfigured && await syncService.hasInternet()) {
          final serverUser = await syncService.buscarUsuarioNoServidor(
            _emailController.text.trim(),
            password: _senhaController.text,
          );
          if (serverUser != null) {
            final pbId = serverUser['id'] as String;
            final nome = serverUser['name'] as String;
            final email = serverUser['email'] as String;

            // Admins injetados fora do app: sempre criar como utilizador normal
            final isAdmin = false;

            // Cria cópia local (se ainda não existe) ou atualiza se já existe pelo UUID (ex.: após reset de senha no PocketBase)
            var existingLocal = await _db.getUsuarioByEmail(email);
            existingLocal ??= await _db.getUsuarioByUuid(pbId);
            if (existingLocal == null) {
              await _db.insertUsuario(UsuariosCompanion(
                uuid: drift.Value(pbId),
                nome: drift.Value(nome.isNotEmpty ? nome : email.split('@').first),
                email: drift.Value(email),
                senha: drift.Value(_senhaController.text),
                isAdmin: drift.Value(isAdmin),
              ));
            } else {
              // Atualiza senha local (com hash) e nome se mudou
              await _db.atualizarSenha(existingLocal.uuid, _senhaController.text);
              final nomeAtualizado = nome.isNotEmpty ? nome : email.split('@').first;
              if (existingLocal.nome != nomeAtualizado) {
                await _db.updateUsuario(
                  UsuariosCompanion(nome: drift.Value(nomeAtualizado)),
                  existingLocal.uuid,
                );
              }
            }
            // Re-autentica localmente
            usuario = await _db.autenticarUsuario(email, _senhaController.text);
          }
        }
      }

      if (usuario != null) {
        // Salva sessão local
        final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user_uuid', usuario.uuid);
    await prefs.setString('current_user_name', usuario.nome);
    await SecureStorageService.write(SecureStorageService.keyIsAdmin, usuario.isAdmin.toString());
        // Marca que wizard já foi visto (não mostra novamente mesmo se dados forem limpos)
        await prefs.setBool('first_run_wizard_skipped', true);
        // Senha vai para secure storage (não SharedPreferences)
        await SecureStorageService.write(
          SecureStorageService.keyCurrentPassword, _senhaController.text);
        await prefs.setString('last_email_login', usuario.email);

        if (!mounted) return;
        final syncService = context.read<SyncService>();
        await syncService.setCurrentUser(usuario, password: _senhaController.text);

  if (mounted) {
      final seeded = await syncService.ensureCatalogSeeded();
      if (!mounted) return;
      if (!seeded) {
        final retry = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text('Conexão necessária'),
                content: const Text(
                  'O app precisa baixar o catálogo (propriedades/UTs/parcelas) no primeiro acesso. '
                  'Conecte-se à internet e tente novamente.',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tentar novamente')),
                ],
              ),
            );
            if (retry == true) {
              final seeded2 = await syncService.ensureCatalogSeeded();
              if (!seeded2 && mounted) {
                setState(() => _isLoading = false);
                return;
              }
            } else {
              if (mounted) setState(() => _isLoading = false);
              return;
            }
          }

          // Atualizar catálogo em logins seguintes (estado das outras parcelas)
    if (await syncService.hasInternet()) {
      syncService.pullDadosDoServidor().then((_) {
        syncService.refreshPendingCount();
      });
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/explorer');
  }
      } else {
        // Mensagem mais informativa
        final syncService = context.read<SyncService>();
    final online = syncService.isConfigured && await syncService.hasInternet();
    if (!mounted) return;
    if (online) {
          setState(() => _errorMessage = 'Email ou senha incorretos.');
        } else {
          setState(() => _errorMessage = 'Conta não encontrada localmente e sem internet para verificar o servidor.');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Erro ao fazer login: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final onBg = const Color(0xFF2C3E2E);
    final fieldFill = const Color(0xFFF9F6F0);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Configurar servidor (canto superior direito)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(Icons.settings, color: Colors.grey[600]),
                tooltip: 'Configurar servidor',
                onPressed: () => _showServerConfigDialog(),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
        // Logo do Urutau (apenas o logo, sem caixa)
        Image.asset(
          'assets/images/urutau_real.png',
          width: 220,
          height: 220,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, st) => Icon(
            Icons.forest,
            size: 64,
            color: const Color(0xFF5A6B5C),
          ),
        ),
        const SizedBox(height: 24),

                      if (_isLoading)
                         const Center(child: CircularProgressIndicator())
                      else ...[
                        // Campo Email
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'exemplo@urutau.com',
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: fieldFill,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Informe seu email';
                            if (!_isEmailValido(value.trim())) {
                              return 'Email inválido (ex: nome@gmail.com)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Campo de senha
                        TextFormField(
                          controller: _senhaController,
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            hintText: 'Mínimo 8 caracteres',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: fieldFill,
                          ),
                          obscureText: _obscurePassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Informe sua senha';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Mensagem de erro
                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: Colors.red[700]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Botão de login
        SizedBox(
          width: double.infinity,
          height: 56,
          child: Semantics(
            label: 'Entrar na aplicação',
            button: true,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _login,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.login),
              label: Text(
                _isLoading ? 'Entrando...' : 'Entrar',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
                        const SizedBox(height: 24),

                        TextButton(
                          onPressed: _showRegisterDialog,
                          child: const Text('Não tem conta? Crie uma aqui.'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _showRecoverPasswordDialog,
                          child: const Text('Recuperar senha'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Recuperar senha: não temos serviço de email; o email no app é apenas identificador.
  /// Mostra aviso para contactar o administrador.
  Future<void> _showRecoverPasswordDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar senha'),
        content: const Text(
          'O servidor não tem envio de email configurado (o email no app é apenas identificador). '
          'Para redefinir a senha, contacte o administrador. '
          'Se a sua conta estiver REGISTRADA no servidor, o admin pode alterar a senha no painel.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showServerConfigDialog() async {
    final syncService = context.read<SyncService>();
    final ctrl = TextEditingController(text: syncService.serverUrl ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Servidor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('URL do PocketBase:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'https://exemplo.ngrok-free.dev',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final url = ctrl.text.trim();
              if (url.isEmpty) return;
              try {
                await syncService.setServerUrl(url);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Servidor configurado com sucesso')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Erro: $e')),
                  );
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  Future<void> _showRegisterDialog() async {
    final syncService = context.read<SyncService>();
    final scaffoldMsg = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool confirmed = false;
    bool obscurePass = true;
    bool obscureConfirm = true;
    final dialogFormKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            return AlertDialog(
              title: const Text('Novo Usuário'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Form(
                    key: dialogFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Nome Completo'),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email (ex: nome@gmail.com)'),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Obrigatório';
                            final regex = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
                            if (!regex.hasMatch(v.trim())) {
                              return 'Email inválido (inclua o domínio completo)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passCtrl,
                          decoration: InputDecoration(
                            labelText: 'Senha (min 8)',
                            suffixIcon: IconButton(
                              icon: Icon(obscurePass ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setStateBuilder(() => obscurePass = !obscurePass),
                            ),
                          ),
                          obscureText: obscurePass,
                          validator: (v) => (v?.length ?? 0) < 8 ? 'Mínimo 8 caracteres' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: confirmCtrl,
                          decoration: InputDecoration(
                            labelText: 'Confirmar Senha',
                            suffixIcon: IconButton(
                              icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setStateBuilder(() => obscureConfirm = !obscureConfirm),
                            ),
                          ),
                          obscureText: obscureConfirm,
                          validator: (v) => v != passCtrl.text ? 'Senhas não conferem' : null,
                        ),
                        const SizedBox(height: 20),
                        CheckboxListTile(
                          value: confirmed,
                          onChanged: (v) => setStateBuilder(() => confirmed = v!),
                          title: const Text(
                            'Confirmo que meus dados estão corretos e não poderão ser alterados posteriormente.',
                            style: TextStyle(fontSize: 13),
                          ),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: !confirmed
                      ? null
                      : () async {
                          if (!dialogFormKey.currentState!.validate()) return;
                          
                          try {
                            // ── Cadastro requer internet (online-first) ──
                            if (!syncService.isConfigured || !await syncService.hasInternet()) {
                              scaffoldMsg.showSnackBar(
                                const SnackBar(
                                  content: Text('Cadastro requer conexão com a internet!'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 4),
                                ),
                              );
                              return;
                            }

                            // Verifica se email já existe
                            final allUsers = await _db.getAllUsuarios();
                            if (allUsers.any((u) => u.email == emailCtrl.text.trim())) {
                               scaffoldMsg.showSnackBar(
                                 const SnackBar(content: Text('Email já cadastrado!'), backgroundColor: Colors.red),
                               );
                               return;
                            }

                            // Registra no servidor primeiro (online-first)
                            final pbId = await syncService.registrarUsuarioNoServidor(
                              nameCtrl.text.trim(),
                              emailCtrl.text.trim(),
                              passCtrl.text,
                            );

                            if (pbId == null) {
                              scaffoldMsg.showSnackBar(
                                const SnackBar(
                                  content: Text('Falha ao registrar no servidor. Verifique sua conexão.'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 4),
                                ),
                              );
                              return;
                            }

                            // Sucesso no servidor → salva localmente com ID do servidor
                            await _db.insertUsuario(UsuariosCompanion(
                              uuid: drift.Value(pbId),
                              nome: drift.Value(nameCtrl.text.trim()),
                              email: drift.Value(emailCtrl.text.trim()),
                              senha: drift.Value(passCtrl.text),
                              isAdmin: drift.Value(false),
                            ));
                            
                            Navigator.pop(ctx);
                            scaffoldMsg.showSnackBar(
                              const SnackBar(content: Text('Cadastro realizado! Faça login.'), backgroundColor: Colors.green),
                            );
                          } catch (e) {
                             scaffoldMsg.showSnackBar(
                               SnackBar(content: Text('Erro: $e')),
                             );
                          }
                      },
                  child: const Text('Criar Conta'),
                ),
              ],
            );
          },
        );
      },
    );
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();
  }

}
