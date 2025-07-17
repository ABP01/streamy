import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/host_live_screen.dart';
import '../services/live_stream_service.dart';

/// 🔴 Bouton flottant pour démarrer un live
/// Position centrée en bas, style Instagram
class FloatingLiveButton extends StatefulWidget {
  const FloatingLiveButton({super.key});

  @override
  State<FloatingLiveButton> createState() => _FloatingLiveButtonState();
}

class _FloatingLiveButtonState extends State<FloatingLiveButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  bool _isCreatingLive = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startLive() async {
    if (_isCreatingLive) return;

    // Afficher la bottom sheet de création
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateLiveBottomSheet(onCreateLive: _createLive),
    );
  }

  Future<void> _createLive() async {
    setState(() {
      _isCreatingLive = true;
    });

    try {
      // 1. Vérifier les permissions
      final hasPermissions = await _checkPermissions();
      if (!hasPermissions) {
        _showPermissionDialog();
        return;
      }

      // 2. Créer le live via le service
      final liveService = LiveStreamService();
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _showErrorDialog('Vous devez être connecté pour démarrer un live.');
        return;
      }

      final newLive = await liveService.createLiveStream(hostId: user.id);

      // 3. Naviguer vers l'écran de live d'hôte
      if (mounted) {
        Navigator.of(context).pop(); // Fermer la bottom sheet
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HostLiveScreen(live: newLive),
          ),
        );
      }
    } catch (e) {
      print('Erreur lors de la création du live: $e');
      _showErrorDialog('Impossible de créer le live. Veuillez réessayer.');
    } finally {
      setState(() {
        _isCreatingLive = false;
      });
    }
  }

  Future<bool> _checkPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final microphoneStatus = await Permission.microphone.status;

    if (cameraStatus.isDenied || microphoneStatus.isDenied) {
      final results = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      return results[Permission.camera]!.isGranted &&
          results[Permission.microphone]!.isGranted;
    }

    return cameraStatus.isGranted && microphoneStatus.isGranted;
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Permissions requises',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'L\'accès à la caméra et au microphone est nécessaire pour démarrer un live.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Annuler',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Paramètres'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Erreur', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Effet de pulsation en arrière-plan
              Container(
                width: 70 * _pulseAnimation.value,
                height: 70 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.purple.withOpacity(0.3),
                ),
              ),

              // Bouton principal
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.purple, Colors.pink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: _isCreatingLive ? null : _startLive,
                    child: Center(
                      child: _isCreatingLive
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.videocam,
                              color: Colors.white,
                              size: 28,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bottom sheet pour configurer rapidement un live
class CreateLiveBottomSheet extends StatefulWidget {
  final VoidCallback onCreateLive;

  const CreateLiveBottomSheet({super.key, required this.onCreateLive});

  @override
  State<CreateLiveBottomSheet> createState() => _CreateLiveBottomSheetState();
}

class _CreateLiveBottomSheetState extends State<CreateLiveBottomSheet> {
  final TextEditingController _titleController = TextEditingController();
  bool _frontCamera = true;
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Titre
            const Text(
              'Créer un live',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 24),

            // Champ titre (optionnel)
            const Text(
              'Titre du live (optionnel)',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ex: Ma session de jeu en direct',
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              maxLength: 100,
            ),

            const SizedBox(height: 24),

            // Choix de la caméra
            const Text(
              'Caméra',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildCameraOption(
                    'Frontale',
                    Icons.camera_front,
                    _frontCamera,
                    () => setState(() => _frontCamera = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCameraOption(
                    'Dorsale',
                    Icons.camera_rear,
                    !_frontCamera,
                    () => setState(() => _frontCamera = false),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isCreating
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _createLive,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Démarrer le live',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraOption(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple.withOpacity(0.2) : Colors.grey[900],
          border: Border.all(
            color: isSelected ? Colors.purple : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.purple : Colors.white70,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.purple : Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createLive() async {
    setState(() => _isCreating = true);

    widget.onCreateLive();

    setState(() => _isCreating = false);
  }
}
