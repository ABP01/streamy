# 🤝 Système de Co-Host TikTok Style - Guide Complet

## 📋 Vue d'ensemble

Le système de co-host permet aux visiteurs de demander à monter sur le live (comme co-host) et à l'hôte de gérer ces demandes et co-hosts, similaire au système TikTok Live.

## 🎯 Fonctionnalités Implémentées

### 👥 Pour les Visiteurs
- **Demander le co-host** : Bouton pour demander à monter sur le live
- **Voir le statut** : Affichage si la demande est en attente
- **Annuler la demande** : Possibilité d'annuler une demande en attente
- **Quitter le co-host** : Si accepté, possibilité de quitter

### 🎪 Pour les Hôtes
- **Voir les demandes** : Liste des demandes de co-host en temps réel
- **Accepter/Refuser** : Répondre aux demandes avec boutons rapides
- **Gérer les co-hosts** : Voir la liste des co-hosts actifs
- **Retirer des co-hosts** : Pouvoir retirer des co-hosts à tout moment

## 🔧 Architecture Technique

### Modèles de Données
```dart
// CoHostRequest - Demandes de co-host
class CoHostRequest {
  final String id;
  final String liveId;
  final String requesterId;
  final String requesterName;
  final String? requesterAvatar;
  final String hostId;
  final CoHostRequestStatus status; // pending, accepted, rejected, canceled
  final DateTime createdAt;
  final DateTime? respondedAt;
}

// CoHost - Co-hosts actifs
class CoHost {
  final String id;
  final String liveId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final DateTime joinedAt;
  final bool isActive;
}
```

### Services
```dart
// CoHostService - Gestion complète des co-hosts
class CoHostService {
  // Demandes
  static Future<CoHostRequest> requestCoHost({required String liveId});
  static Future<List<CoHostRequest>> getCoHostRequests(String liveId);
  static Stream<List<CoHostRequest>> getCoHostRequestsStream(String liveId);
  
  // Réponses
  static Future<void> respondToCoHostRequest({required String requestId, required bool accept});
  
  // Gestion des co-hosts
  static Future<List<CoHost>> getActiveCoHosts(String liveId);
  static Stream<List<CoHost>> getActiveCoHostsStream(String liveId);
  static Future<void> removeCoHost({required String liveId, required String coHostUserId});
  static Future<void> leaveCoHost(String liveId);
  
  // Utilitaires
  static Future<bool> isCoHost(String liveId);
  static Future<CoHostRequest?> getPendingRequest(String liveId);
}
```

### Interface Utilisateur

#### Widget Principal
```dart
// CoHostWidget - Interface complète de gestion
class CoHostWidget extends StatefulWidget {
  final String liveId;
  final bool isHost;
  final VoidCallback? onCoHostChanged;
}
```

#### Intégration TikTok Style
- **Bouton co-host** dans la barre d'actions (icône people)
- **Indicateur en temps réel** dans le header (nombre de co-hosts)
- **Modal bottom sheet** pour la gestion complète

## 🗄️ Base de Données

### Tables Créées

#### `cohost_requests`
```sql
CREATE TABLE cohost_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  live_id UUID NOT NULL REFERENCES lives(id) ON DELETE CASCADE,
  requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  requester_name TEXT NOT NULL,
  requester_avatar TEXT,
  host_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'canceled')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  responded_at TIMESTAMP WITH TIME ZONE,
  UNIQUE(live_id, requester_id, status)
);
```

#### `cohosts`
```sql
CREATE TABLE cohosts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  live_id UUID NOT NULL REFERENCES lives(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  user_avatar TEXT,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  is_active BOOLEAN DEFAULT TRUE,
  UNIQUE(live_id, user_id)
);
```

### Fonctions SQL
- `process_cohost_request()` : Traitement automatisé des demandes
- `remove_cohost()` : Retrait sécurisé des co-hosts
- `cleanup_old_cohost_requests()` : Nettoyage automatique (24h)

### Vues et Statistiques
- `cohost_statistics` : Vue des statistiques en temps réel
- Index optimisés pour les performances
- Politiques RLS pour la sécurité

## 🎮 Utilisation dans l'Interface

### Écran TikTok Style Live

#### Header avec Indicateurs
```dart
// Affichage en temps réel du nombre de co-hosts
Widget _buildCoHostIndicator(StreamContent stream) {
  return StreamBuilder<List<CoHost>>(
    stream: CoHostService.getActiveCoHostsStream(stream.id),
    builder: (context, snapshot) {
      final coHosts = snapshot.data ?? <CoHost>[];
      if (coHosts.isEmpty) return const SizedBox.shrink();
      
      return GestureDetector(
        onTap: () => _showCoHostInterface(stream),
        child: Container(
          // Badge avec nombre de co-hosts actifs
        ),
      );
    },
  );
}
```

#### Boutons d'Action
```dart
// Bouton co-host dans la barre d'actions
_buildActionButton(
  icon: Icons.people,
  color: const Color(0xFF6C5CE7),
  onTap: () => _showCoHostInterface(stream),
),
```

#### Modal de Gestion
```dart
// Modal bottom sheet avec CoHostWidget
void _showCoHostInterface(StreamContent stream) {
  showModalBottomSheet(
    context: context,
    builder: (context) => Container(
      child: CoHostWidget(
        liveId: stream.id,
        isHost: _isCurrentUserHost(stream),
      ),
    ),
  );
}
```

## 🔒 Sécurité et Permissions

### Contrôles d'Accès
- **Vérification d'identité** : Utilisateur connecté requis
- **Validation de l'hôte** : Seul l'hôte peut accepter/refuser/retirer
- **Unicité des demandes** : Une seule demande pending par utilisateur/live
- **Isolation des données** : RLS activé sur toutes les tables

### Politiques RLS
```sql
-- Voir les demandes concernant l'utilisateur
CREATE POLICY "Users can view their own cohost requests" ON cohost_requests
  FOR SELECT USING (
    auth.uid()::text = requester_id::text OR 
    auth.uid()::text = host_id::text
  );

-- Créer des demandes
CREATE POLICY "Users can create cohost requests" ON cohost_requests
  FOR INSERT WITH CHECK (auth.uid()::text = requester_id::text);

-- Seuls les hôtes peuvent créer des co-hosts
CREATE POLICY "Only hosts can create cohosts" ON cohosts
  FOR INSERT WITH CHECK (
    auth.uid()::text IN (
      SELECT host_id::text FROM lives WHERE id = live_id
    )
  );
```

## 🧪 Tests et Validation

### Scénarios de Test

#### Test 1 : Demande de Co-host (Visiteur)
1. Ouvrir un live en tant que visiteur
2. Cliquer sur le bouton co-host (icône people)
3. Cliquer sur "Demander à être co-host"
4. Vérifier que le statut change en "Demande en attente..."

#### Test 2 : Gestion des Demandes (Hôte)
1. Créer un live en tant qu'hôte
2. Recevoir une demande de co-host
3. Voir la notification dans l'interface co-host
4. Accepter ou refuser la demande
5. Vérifier la mise à jour en temps réel

#### Test 3 : Gestion des Co-hosts Actifs (Hôte)
1. Avoir des co-hosts actifs
2. Voir l'indicateur dans le header (nombre)
3. Ouvrir l'interface de gestion
4. Retirer un co-host
5. Vérifier la mise à jour immédiate

#### Test 4 : Quitter le Co-host (Co-host)
1. Être accepté comme co-host
2. Voir le bouton "Quitter le co-host"
3. Cliquer pour quitter
4. Vérifier la disparition de l'interface co-host

## 🚀 Améliorations Futures

### Intégration Agora
- **Multi-stream** : Permettre aux co-hosts de diffuser leur caméra
- **Audio/Vidéo** : Gestion des permissions microphone/caméra
- **Layout dynamique** : Interface adaptée au nombre de co-hosts

### Fonctionnalités Avancées
- **Invitations directes** : L'hôte peut inviter des utilisateurs spécifiques
- **Permissions granulaires** : Différents niveaux de co-host (modérateur, speaker, etc.)
- **Système de réputation** : Historique des co-hosts pour confiance
- **Notifications push** : Alertes pour nouvelles demandes/acceptations

### Analytics et Statistiques
- **Temps de co-host** : Durée moyenne des sessions co-host
- **Taux d'acceptation** : Statistiques des demandes acceptées/refusées
- **Engagement** : Impact des co-hosts sur l'engagement du live

## 📱 Interface Mobile Optimisée

### Gestures et Interactions
- **Swipe pour actions rapides** : Swipe left/right sur demandes pour accepter/refuser
- **Long press** : Long press sur co-host pour options avancées
- **Double tap** : Double tap sur indicateur pour accès rapide

### Responsive Design
- **Portrait/Landscape** : Interface adaptée à l'orientation
- **Différentes tailles** : Optimisé pour phones et tablets
- **Accessibility** : Support des lecteurs d'écran et navigation par gestes

## 🎯 Résultat Final

Le système de co-host est maintenant pleinement fonctionnel et intégré dans l'expérience TikTok Style Live de Streamy :

✅ **Interface intuitive** style TikTok avec gestion en temps réel
✅ **Sécurité robuste** avec contrôles d'accès et validation
✅ **Performance optimisée** avec streams en temps réel et caching
✅ **Expérience utilisateur fluide** avec feedbacks visuels et animations
✅ **Système complet** de demandes, acceptation, gestion et retrait

Les utilisateurs peuvent maintenant demander à monter sur les lives comme co-hosts, et les hôtes ont un contrôle total sur leur communauté, reproduisant fidèlement l'expérience TikTok Live dans l'application Streamy.
