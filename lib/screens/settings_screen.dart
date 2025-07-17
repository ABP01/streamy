import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  bool _notificationsEnabled = true;
  bool _autoplayVideos = true;
  bool _dataOptimization = false;
  String _selectedLanguage = 'Français';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Paramètres', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Section Compte
          _buildSectionHeader('Compte'),
          _buildListTile(
            icon: Icons.person,
            title: 'Modifier le profil',
            onTap: () => _editProfile(),
          ),
          _buildListTile(
            icon: Icons.security,
            title: 'Confidentialité et sécurité',
            onTap: () => _showPrivacySettings(),
          ),
          _buildListTile(
            icon: Icons.payment,
            title: 'Méthodes de paiement',
            onTap: () => _showPaymentMethods(),
          ),

          const Divider(color: Colors.grey),

          // Section Notifications
          _buildSectionHeader('Notifications'),
          _buildSwitchTile(
            icon: Icons.notifications,
            title: 'Notifications push',
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),

          const Divider(color: Colors.grey),

          // Section Lecture
          _buildSectionHeader('Lecture et données'),
          _buildSwitchTile(
            icon: Icons.play_circle,
            title: 'Lecture automatique',
            subtitle: 'Lire automatiquement les vidéos',
            value: _autoplayVideos,
            onChanged: (value) {
              setState(() {
                _autoplayVideos = value;
              });
            },
          ),
          _buildSwitchTile(
            icon: Icons.data_usage,
            title: 'Économie de données',
            subtitle: 'Réduire la qualité vidéo sur réseau mobile',
            value: _dataOptimization,
            onChanged: (value) {
              setState(() {
                _dataOptimization = value;
              });
            },
          ),

          const Divider(color: Colors.grey),

          // Section Application
          _buildSectionHeader('Application'),
          _buildListTile(
            icon: Icons.language,
            title: 'Langue',
            subtitle: _selectedLanguage,
            onTap: () => _selectLanguage(),
          ),
          _buildListTile(
            icon: Icons.info,
            title: 'À propos',
            onTap: () => _showAbout(),
          ),
          _buildListTile(
            icon: Icons.help,
            title: 'Aide et support',
            onTap: () => _showHelp(),
          ),

          const Divider(color: Colors.grey),

          // Section Danger
          _buildSectionHeader('Zone de danger'),
          _buildListTile(
            icon: Icons.logout,
            title: 'Déconnexion',
            titleColor: Colors.orange,
            onTap: () => _logout(),
          ),
          _buildListTile(
            icon: Icons.delete_forever,
            title: 'Supprimer le compte',
            titleColor: Colors.red,
            onTap: () => _deleteAccount(),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.purple,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: TextStyle(color: titleColor ?? Colors.white, fontSize: 16),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: Colors.grey))
          : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: Colors.grey))
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.purple,
      ),
    );
  }

  void _editProfile() {
    // TODO: Naviguer vers l'édition du profil
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Édition du profil - À implémenter')),
    );
  }

  void _showPrivacySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Confidentialité et sécurité',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Paramètres de confidentialité avancés.\nFonctionnalité en développement.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showPaymentMethods() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Méthodes de paiement',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Gérer vos cartes et méthodes de paiement.\nFonctionnalité en développement.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _selectLanguage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Choisir la langue',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption('Français'),
            _buildLanguageOption('English'),
            _buildLanguageOption('Español'),
            _buildLanguageOption('العربية'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String language) {
    return ListTile(
      title: Text(language, style: const TextStyle(color: Colors.white)),
      trailing: _selectedLanguage == language
          ? const Icon(Icons.check, color: Colors.purple)
          : null,
      onTap: () {
        setState(() {
          _selectedLanguage = language;
        });
        Navigator.pop(context);
      },
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'À propos de Streamy',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Streamy v2.0\nPlateforme de streaming live sociale\n\nDéveloppé avec Flutter et Supabase\n\n© 2025 Streamy Team',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Aide et support',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Besoin d\'aide ?\n\n• FAQ dans l\'app\n• Support par email\n• Centre d\'aide en ligne\n\nContact: support@streamy.app',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/auth');
              }
            },
            child: const Text(
              'Déconnexion',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Supprimer le compte',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          'ATTENTION : Cette action est irréversible.\n\nToutes vos données, lives et messages seront définitivement supprimés.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implémenter la suppression du compte
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Suppression de compte - À implémenter'),
                ),
              );
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
