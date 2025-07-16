import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'config/app_config.dart';
import 'models/live_stream.dart';
import 'screens/main_navigation_screen.dart';
import 'services/agora_backend_service.dart';
import 'services/agora_error_handler.dart';
import 'services/auth_service.dart';
import 'services/live_stream_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Test de connexion au backend
  final backendHealthy = await AgoraBackendService.testConnection();
  if (backendHealthy) {
    print('✅ Backend connecté et opérationnel');
  } else {
    print('⚠️ Backend non accessible - fonctionnement en mode dégradé');
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const StreamyApp());
}

class StreamyApp extends StatelessWidget {
  const StreamyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Streamy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const AuthPage();
        } else {
          return const MainNavigationScreen();
        }
      },
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  final AuthService _authService = AuthService();

  Future<void> _authenticate() async {
    if (!mounted) return;

    // Validation des champs
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    // Validation améliorée
    if (email.isEmpty) {
      setState(() {
        _error = 'Veuillez entrer votre email';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _error = 'Veuillez entrer votre mot de passe';
      });
      return;
    }

    if (_isSignUp && username.isEmpty) {
      setState(() {
        _error = 'Veuillez choisir un nom d\'utilisateur';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _error = 'Le mot de passe doit contenir au moins 6 caractères';
      });
      return;
    }

    if (_isSignUp && !email.contains('@')) {
      setState(() {
        _error = 'Adresse email invalide';
      });
      return;
    }

    if (_isSignUp && (username.length < 3 || username.length > 20)) {
      setState(() {
        _error = 'Le nom d\'utilisateur doit contenir entre 3 et 20 caractères';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_isSignUp) {
        // Inscription sans vérification email
        final response = await _authService.signUp(
          email: email,
          password: password,
          username: username,
        );
        if (response.user != null) {
          await _createUserProfile(response.user!, username);

          // Afficher un message de succès
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Compte créé avec succès ! Bienvenue sur Streamy !',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        await _authService.signIn(email: email, password: password);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.message.contains('Invalid login credentials')) {
          _error = 'Email ou mot de passe incorrect';
        } else if (e.message.contains('User already registered')) {
          _error = 'Cet email est déjà utilisé';
        } else {
          _error = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            'Une erreur inattendue s\'est produite. Vérifiez votre connexion internet.';
      });
      debugPrint('Erreur d\'authentification: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createUserProfile(User user, String username) async {
    try {
      await Supabase.instance.client.from('users').insert({
        'id': user.id,
        'email': user.email,
        'username': username.isNotEmpty ? username : null,
        'full_name': username.isNotEmpty ? username : null,
        'tokens_balance': 100, // Tokens de bienvenue
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Erreur lors de la création du profil: $e');
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.8)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo animé
                  TweenAnimationBuilder<double>(
                    duration: const Duration(seconds: 1),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.2),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.videocam,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Titre
                  const Text(
                    'Streamy',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp ? 'Créer un compte' : 'Bienvenue !',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Formulaire avec animation
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Nom d'utilisateur (seulement pour l'inscription)
                        if (_isSignUp) ...[
                          _buildTextField(
                            controller: _usernameController,
                            label: 'Nom d\'utilisateur',
                            icon: Icons.person,
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Email
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),

                        // Mot de passe
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Mot de passe',
                          icon: Icons.lock,
                          obscureText: true,
                        ),
                        const SizedBox(height: 30),

                        // Message d'erreur
                        if (_error != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Bouton principal
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _authenticate,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryColor,
                                    ),
                                  )
                                : Icon(
                                    _isSignUp ? Icons.person_add : Icons.login,
                                    color: AppTheme.primaryColor,
                                  ),
                            label: Text(
                              _isSignUp ? 'Créer un compte' : 'Se connecter',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Basculer entre connexion/inscription
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _isSignUp = !_isSignUp;
                                    _error = null;
                                  });
                                },
                          child: Text(
                            _isSignUp
                                ? 'Déjà un compte ? Se connecter'
                                : 'Pas de compte ? S\'inscrire',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Note de bienvenue
                  if (_isSignUp)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.celebration,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Obtenez 100 tokens gratuits en vous inscrivant !',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LiveSwipePage extends StatefulWidget {
  const LiveSwipePage({super.key});

  @override
  State<LiveSwipePage> createState() => _LiveSwipePageState();
}

class _LiveSwipePageState extends State<LiveSwipePage> {
  late Future<List<LiveStream>> _livesFuture;
  final PageController _pageController = PageController();
  final LiveStreamService _liveService = LiveStreamService();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _livesFuture = _liveService.fetchLiveStreams();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _startLive() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const StartLivePage()));
    if (result == true) {
      setState(() {
        _livesFuture = _liveService.fetchLiveStreams();
      });
    }
  }

  void _showUserProfile() {
    // TODO: Naviguer vers la page de profil
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil utilisateur - À implémenter')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.person, color: Colors.white),
          onPressed: _showUserProfile,
        ),
        title: const Text(
          'Streamy',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            tooltip: 'Démarrer un live',
            onPressed: _startLive,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              switch (value) {
                case 'logout':
                  await Supabase.instance.client.auth.signOut();
                  break;
                case 'refresh':
                  setState(() {
                    _livesFuture = _liveService.fetchLiveStreams();
                  });
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Actualiser'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Déconnexion'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<LiveStream>>(
        future: _livesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Chargement des lives...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          } else if (snapshot.hasError) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.white, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Erreur de chargement',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Erreur: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _livesFuture = _liveService.fetchLiveStreams();
                        });
                      },
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.videocam_off,
                      color: Colors.white,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Aucun live en cours',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Soyez le premier à lancer un live !',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _startLive,
                      icon: const Icon(Icons.videocam),
                      label: const Text('Démarrer un live'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF667eea),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final lives = snapshot.data!;
          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: lives.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return LiveStreamViewer(
                live: lives[index],
                isCurrentPage: index == _currentIndex,
              );
            },
          );
        },
      ),
    );
  }
}

class LiveStreamViewer extends StatefulWidget {
  final LiveStream live;
  final bool isCurrentPage;

  const LiveStreamViewer({
    super.key,
    required this.live,
    this.isCurrentPage = false,
  });

  @override
  State<LiveStreamViewer> createState() => _LiveStreamViewerState();
}

class _LiveStreamViewerState extends State<LiveStreamViewer> {
  late final RtcEngine _engine;
  int? _remoteUid;
  bool _joined = false;
  bool _isLiked = false;
  String? _agoraError;

  @override
  void initState() {
    super.initState();
    if (widget.isCurrentPage) {
      _initAgora();
    }
  }

  @override
  void didUpdateWidget(LiveStreamViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentPage && !oldWidget.isCurrentPage) {
      _initAgora();
    } else if (!widget.isCurrentPage && oldWidget.isCurrentPage) {
      _leaveChannel();
    }
  }

  @override
  void dispose() {
    _leaveChannel();
    super.dispose();
  }

  Future<void> _initAgora() async {
    try {
      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(appId: AppConfig.agoraAppId));

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            AgoraErrorHandler.resetReconnectionAttempts(); // Réinitialiser le compteur
            setState(() {
              _joined = true;
              _agoraError = null;
            });
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            setState(() {
              _remoteUid = remoteUid;
            });
          },
          onUserOffline: (connection, remoteUid, reason) {
            setState(() {
              _remoteUid = null;
            });
          },
          onError: (err, msg) {
            debugPrint('Agora Error: $err - $msg');
            final errorMessage = AgoraErrorHandler.getErrorMessage(err);
            setState(() {
              _agoraError = errorMessage;
            });

            // Reconnexion automatique pour les erreurs de token (avec limite)
            if (AgoraErrorHandler.isTokenRelatedError(err) &&
                AgoraErrorHandler.canAttemptReconnection()) {
              AgoraErrorHandler.incrementReconnectionAttempts();
              _handleTokenError();
            } else if (AgoraErrorHandler.isTokenRelatedError(err)) {
              setState(() {
                _agoraError =
                    'Trop de tentatives de reconnexion. Mode sans token recommandé.';
              });
            }
          },
        ),
      );

      await _engine.enableVideo();

      // Obtenir le token pour ce spectateur
      final liveService = LiveStreamService();
      final currentUser = Supabase.instance.client.auth.currentUser;
      final token = await liveService.getViewerToken(
        widget.live.id,
        currentUser?.id ?? 'anonymous',
      );

      // Debug pour diagnostiquer les problèmes de token
      debugPrint('Token debugging for live: ${widget.live.id}');

      // Générer un token via le backend pour le viewer
      String finalToken = '';
      if (AppConfig.useAgoraToken) {
        try {
          final backendToken = await AgoraBackendService.getViewerToken(
            liveId: widget.live.agoraChannelId ?? widget.live.id,
            userId:
                Supabase.instance.client.auth.currentUser?.id ?? 'anonymous',
          );
          finalToken = backendToken.token;
          print(
            '✅ Token viewer obtenu via backend pour ${widget.live.agoraChannelId}',
          );
        } catch (e) {
          print('⚠️ Erreur token backend, utilisation du token existant: $e');
          finalToken = token;
        }
      }

      await _engine.joinChannel(
        token: finalToken,
        channelId: widget.live.agoraChannelId ?? widget.live.id,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
        ),
      );
    } catch (e) {
      debugPrint('Erreur Agora: $e');
      setState(() {
        _agoraError = 'Erreur Agora: $e';
      });
    }
  }

  Future<void> _leaveChannel() async {
    try {
      if (_joined) {
        await _engine.leaveChannel();
        await _engine.release();
      }
    } catch (e) {
      debugPrint('Erreur lors de la sortie du canal: $e');
    }
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });
    // TODO: Envoyer la réaction à la base de données
  }

  void _showGifts() {
    // TODO: Afficher le panel des cadeaux
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Panel des cadeaux - À implémenter')),
    );
  }

  void _showComments() {
    // TODO: Afficher/masquer les commentaires
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Commentaires - À implémenter')),
    );
  }

  Future<void> _handleTokenError() async {
    try {
      // Si on est en mode sans token, ne pas essayer de renouveler
      if (!AppConfig.useAgoraToken) {
        debugPrint('Mode sans token activé - pas de renouvellement nécessaire');
        setState(() {
          _agoraError =
              'Mode test sans token. Vérifiez la configuration Agora.';
        });
        return;
      }

      debugPrint('Token invalide, tentative de renouvellement...');

      // Quitter le canal actuel
      await _engine.leaveChannel();

      // Obtenir un nouveau token
      final liveService = LiveStreamService();
      final currentUser = Supabase.instance.client.auth.currentUser;
      final newToken = await liveService.getViewerToken(
        widget.live.id,
        currentUser?.id ?? 'anonymous',
      );

      // Rejoindre avec le nouveau token
      final finalNewToken = (AppConfig.useAgoraToken && newToken.isNotEmpty)
          ? newToken
          : '';
      await _engine.joinChannel(
        token: finalNewToken,
        channelId: widget.live.agoraChannelId ?? widget.live.id,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
        ),
      );

      debugPrint('Reconnexion réussie avec le nouveau token');
    } catch (e) {
      debugPrint('Erreur lors de la reconnexion: $e');
      setState(() {
        _agoraError = 'Impossible de se reconnecter. Vérifiez votre connexion.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Vidéo background
        _buildVideoView(),

        // Overlay avec informations
        _buildOverlay(),

        // Interface utilisateur
        _buildUI(),
      ],
    );
  }

  Widget _buildVideoView() {
    if (_agoraError != null) {
      debugPrint(
        '[DEBUG] Erreur Agora détectée dans _buildVideoView:  A${_agoraError!}',
      );
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _agoraError!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  debugPrint(
                    '[DEBUG] Bouton Réessayer pressé, relance _initAgora',
                  );
                  _initAgora();
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    if (!_joined) {
      debugPrint('[DEBUG] Attente de connexion au live (_joined == false)');
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Connexion au live...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.live.id),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF434343), Color(0xFF000000)],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 64, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'En attente du streamer...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
    );
  }

  Widget _buildUI() {
    return SafeArea(
      child: Column(
        children: [
          // En-tête avec infos du live
          _buildHeader(),

          const Spacer(),

          // Actions et chat
          _buildBottomSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar du streamer
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white,
            child: Text(
              widget.live.hostId.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Infos du live
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.live.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.visibility,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.live.viewerCount}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Zone de commentaires (placeholder)
          Expanded(
            child: Container(
              height: 120,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chat en direct',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Les commentaires apparaîtront ici...',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Actions
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Like
              GestureDetector(
                onTap: _toggleLike,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isLiked
                        ? Colors.red
                        : Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite,
                    color: _isLiked ? Colors.white : Colors.white70,
                    size: 24,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Cadeaux
              GestureDetector(
                onTap: _showGifts,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.card_giftcard,
                    color: Colors.amber,
                    size: 24,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Commentaires
              GestureDetector(
                onTap: _showComments,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble,
                    color: Colors.white70,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StartLivePage extends StatefulWidget {
  const StartLivePage({super.key});

  @override
  State<StartLivePage> createState() => _StartLivePageState();
}

class _StartLivePageState extends State<StartLivePage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String _selectedCategory = 'Général';

  final List<String> _categories = [
    'Général',
    'Gaming',
    'Musique',
    'Art',
    'Sport',
    'Cuisine',
    'Tech',
    'Éducation',
    'Lifestyle',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createLive() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Utilisateur non authentifié';
        _isLoading = false;
      });
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _error = 'Le titre est requis';
        _isLoading = false;
      });
      return;
    }

    final liveId = const Uuid().v4();

    try {
      await Supabase.instance.client.from('lives').insert({
        'id': liveId,
        'title': title,
        'description': _descriptionController.text.trim(),
        'host_id': user.id,
        'category': _selectedCategory,
        'is_live': true,
        'started_at': DateTime.now().toIso8601String(),
        'agora_channel_id': 'live_$liveId',
        'agora_token': AppConfig.useAgoraToken ? 'temp_token' : null,
        'viewer_count': 0,
        'like_count': 0,
        'gift_count': 0,
      });

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HostLivePage(
              live: LiveStream(
                id: liveId,
                title: title,
                hostId: user.id,
                startedAt: DateTime.now(),
                isLive: true,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur lors de la création du live: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar personnalisée
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Démarrer un live',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(
                      width: 48,
                    ), // Pour équilibrer avec le bouton close
                  ],
                ),
              ),

              // Contenu principal
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Aperçu de la caméra (placeholder)
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam, size: 48, color: Colors.white),
                            SizedBox(height: 8),
                            Text(
                              'Aperçu de la caméra',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'La vidéo apparaîtra ici',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Formulaire
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Titre
                            const Text(
                              'Titre du live *',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _titleController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Donnez un titre accrocheur...',
                                hintStyle: const TextStyle(
                                  color: Colors.white54,
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              maxLength: 100,
                            ),

                            const SizedBox(height: 20),

                            // Description
                            const Text(
                              'Description',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _descriptionController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Décrivez votre live...',
                                hintStyle: const TextStyle(
                                  color: Colors.white54,
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              maxLines: 3,
                              maxLength: 500,
                            ),

                            const SizedBox(height: 20),

                            // Catégorie
                            const Text(
                              'Catégorie',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCategory,
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedCategory = newValue;
                                      });
                                    }
                                  },
                                  dropdownColor: const Color(0xFF667eea),
                                  style: const TextStyle(color: Colors.white),
                                  items: _categories
                                      .map<DropdownMenuItem<String>>((
                                        String value,
                                      ) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      })
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Message d'erreur
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Bouton de création
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createLive,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.play_arrow, size: 24),
                                    SizedBox(width: 8),
                                    Text(
                                      'Commencer le live',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HostLivePage extends StatefulWidget {
  final LiveStream live;

  const HostLivePage({super.key, required this.live});

  @override
  State<HostLivePage> createState() => _HostLivePageState();
}

class _HostLivePageState extends State<HostLivePage> {
  late final RtcEngine _engine;
  bool _joined = false;
  bool _cameraEnabled = true;
  bool _micEnabled = true;
  int _viewerCount = 0;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    _initAgora();
    _startLiveSession();
  }

  @override
  void dispose() {
    _endLiveSession();
    super.dispose();
  }

  Future<void> _initAgora() async {
    try {
      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(appId: AppConfig.agoraAppId));

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            setState(() {
              _joined = true;
            });
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            // Un spectateur a rejoint
          },
          onUserOffline: (connection, remoteUid, reason) {
            // Un spectateur a quitté
          },
        ),
      );

      await _engine.enableVideo();
      await _engine.startPreview();

      // Utiliser le token généré lors de la création du live
      final token = widget.live.agoraToken ?? '';

      // Générer un token via le backend pour l'hôte
      String finalToken = '';
      if (AppConfig.useAgoraToken) {
        try {
          final backendToken = await AgoraBackendService.getHostToken(
            liveId: widget.live.agoraChannelId ?? widget.live.id,
            userId: Supabase.instance.client.auth.currentUser?.id ?? 'host',
          );
          finalToken = backendToken.token;
          print(
            '✅ Token hôte obtenu via backend pour ${widget.live.agoraChannelId}',
          );
        } catch (e) {
          print('⚠️ Erreur token backend, utilisation du token existant: $e');
          finalToken = token;
        }
      }

      await _engine.joinChannel(
        token: finalToken,
        channelId: widget.live.agoraChannelId ?? widget.live.id,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      debugPrint('Erreur Agora: $e');
    }
  }

  Future<void> _startLiveSession() async {
    // Démarrer le suivi des statistiques en temps réel
    // TODO: Implémenter le stream des statistiques
  }

  Future<void> _endLiveSession() async {
    try {
      if (_joined) {
        await _engine.leaveChannel();
        await _engine.release();
      }

      // Marquer le live comme terminé
      await Supabase.instance.client
          .from('lives')
          .update({
            'is_live': false,
            'ended_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.live.id);
    } catch (e) {
      debugPrint('Erreur lors de la fin du live: $e');
    }
  }

  void _toggleCamera() {
    setState(() {
      _cameraEnabled = !_cameraEnabled;
    });
    _engine.enableLocalVideo(_cameraEnabled);
  }

  void _toggleMic() {
    setState(() {
      _micEnabled = !_micEnabled;
    });
    _engine.enableLocalAudio(_micEnabled);
  }

  void _switchCamera() {
    _engine.switchCamera();
  }

  Future<void> _endLive() async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminer le live'),
        content: const Text('Êtes-vous sûr de vouloir terminer ce live ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );

    if (shouldEnd == true) {
      await _endLiveSession();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const SizedBox(), // Masquer le bouton retour
        title: Text(
          widget.live.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: _endLive,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Vue de la caméra
          _buildCameraView(),

          // Statistiques en temps réel
          _buildStatsOverlay(),

          // Contrôles
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    if (!_joined) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Démarrage du live...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  Widget _buildStatsOverlay() {
    return Positioned(
      top: 100,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              Icons.visibility,
              _viewerCount.toString(),
              'Viewers',
            ),
            _buildStatItem(Icons.favorite, _likeCount.toString(), 'Likes'),
            _buildStatItem(Icons.access_time, _getStreamDuration(), 'Durée'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 50,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Basculer caméra
          _buildControlButton(
            icon: Icons.flip_camera_ios,
            onTap: _switchCamera,
          ),

          // Basculer micro
          _buildControlButton(
            icon: _micEnabled ? Icons.mic : Icons.mic_off,
            isActive: _micEnabled,
            onTap: _toggleMic,
          ),

          // Terminer le live
          _buildControlButton(
            icon: Icons.call_end,
            backgroundColor: Colors.red,
            onTap: _endLive,
          ),

          // Basculer caméra
          _buildControlButton(
            icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
            isActive: _cameraEnabled,
            onTap: _toggleCamera,
          ),

          // Menu des options
          _buildControlButton(
            icon: Icons.more_vert,
            onTap: () {
              // TODO: Afficher le menu des options
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = true,
    Color? backgroundColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color:
              backgroundColor ??
              (isActive
                  ? Colors.white.withOpacity(0.2)
                  : Colors.red.withOpacity(0.7)),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  String _getStreamDuration() {
    // TODO: Calculer la durée réelle du stream
    return '0:00';
  }
}
