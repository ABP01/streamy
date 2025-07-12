# 📱 Guide : Rejoindre un Live sur un Autre Téléphone

## Vue d'ensemble

Streamy permet aux utilisateurs de rejoindre facilement des lives depuis n'importe quel appareil. Voici un guide complet pour partager et rejoindre des lives.

## 🚀 Pour l'Hôte (Celui qui diffuse)

### 1. Partager le Live

Pendant que vous diffusez :

1. **Appuyez sur l'icône de partage** (🔗) en haut à droite de l'écran
2. **Choisissez votre méthode de partage :**
   - **ID du live** : Code court facile à dicter (ex: `abc123`)
   - **Lien complet** : URL cliquable (ex: `https://streamy.app/live/abc123`)

### 2. Méthodes de Partage

#### Option A : ID Simple
```
"Hey, rejoins mon live ! 
ID: abc123 
Dans l'app Streamy, clique sur 🔗 et tape cet ID"
```

#### Option B : Lien Complet
```
"Clique sur ce lien pour rejoindre mon live :
https://streamy.app/live/abc123"
```

#### Option C : Message Complet
```
"🎥 Live en cours sur Streamy !
Titre: Mon Super Live
Lien: https://streamy.app/live/abc123
Ou utilise l'ID: abc123"
```

## 📲 Pour le Spectateur (Celui qui rejoint)

### Méthode 1 : Via l'Application

1. **Ouvrir l'app Streamy**
2. **Se connecter ou créer un compte** (gratuit et instantané)
3. **Cliquer sur l'icône 🔗** en haut de l'écran d'accueil
4. **Saisir :**
   - L'ID du live (ex: `abc123`)
   - OU le lien complet
5. **Appuyer sur "Rejoindre"**

### Méthode 2 : Via un Lien (si configuré)

1. **Cliquer directement sur le lien** reçu
2. L'app s'ouvre automatiquement sur le live

### Méthode 3 : Recherche par ID

Si vous avez seulement l'ID :

1. Ouvrir l'app Streamy
2. Aller dans l'écran d'accueil
3. Cliquer sur l'icône de lien (🔗)
4. Taper l'ID reçu
5. Appuyer sur "Rejoindre"

## 🔧 Configuration Technique

### 1. Structure des IDs

Les lives utilisent des IDs uniques générés automatiquement :
- Format : UUID v4 (ex: `550e8400-e29b-41d4-a716-446655440000`)
- Raccourci affiché : Premiers caractères (ex: `550e8400`)

### 2. URLs de Partage

Format des liens de partage :
```
https://streamy.app/live/[LIVE_ID]
streamy://live/[LIVE_ID]  (deep link)
```

### 3. Gestion des Erreurs

Le système gère automatiquement :
- ✅ Live introuvable → Message d'erreur explicite
- ✅ Live terminé → Notification "Live non actif"
- ✅ Problème de connexion → Retry automatique
- ✅ Token Agora invalide → Mode dégradé en développement

## 📋 Checklist de Test

### Test Complet de Partage

- [ ] Créer un live
- [ ] Générer un lien de partage
- [ ] Copier l'ID du live
- [ ] Tester sur un autre appareil
- [ ] Vérifier la jointure automatique
- [ ] Tester avec lien et avec ID
- [ ] Vérifier le compteur de viewers
- [ ] Tester la déconnexion/reconnexion

### Scénarios d'Erreur

- [ ] ID inexistant
- [ ] Live terminé
- [ ] Utilisateur non connecté
- [ ] Connexion internet instable
- [ ] Token Agora invalide

## 🛠️ Implémentation Technique

### Services Créés

1. **`LiveJoinService`** (`lib/services/live_join_service.dart`)
   - Gestion des jointures par ID/URL
   - Validation des liens
   - Gestion d'erreurs robuste

2. **`QuickInviteWidget`** (`lib/widgets/quick_invite_widget.dart`)
   - Interface de partage rapide
   - Copie automatique dans le presse-papier
   - Instructions pour les invités

### Fonctionnalités Ajoutées

#### Dans HomeScreen
- Bouton 🔗 pour rejoindre un live par ID
- Dialog de saisie avec validation

#### Dans LiveStreamScreen  
- Bouton de partage pour l'hôte
- Widget d'invitation rapide
- Génération automatique des liens

#### Dans LiveStreamService
- Méthodes `joinLive()` et `leaveLive()`
- Gestion des tokens Agora pour spectateurs
- Compteurs de viewers en temps réel

## 🔐 Sécurité

### Tokens Agora
- En développement : Mode sans token activé
- En production : Génération côté serveur obligatoire
- Renouvellement automatique des tokens expirés

### Validation
- Vérification de l'existence des lives
- Contrôle du statut (actif/terminé)
- Gestion des permissions (privé/public)

## 📱 Exemples d'Utilisation

### Scénario 1 : Live Gaming
```
"🎮 Live Fortnite en cours !
ID: 5f7a2b1c
App: Streamy"
```

### Scénario 2 : Live Éducatif
```
"📚 Cours de maths - rejoignez maintenant :
https://streamy.app/live/8d3c1f2a"
```

### Scénario 3 : Live Familial
```
"👨‍👩‍👧‍👦 Live famille en direct
Streamy app → 🔗 → abc123"
```

## 🚀 Prochaines Améliorations

- [ ] Intégration du plugin `share_plus` pour partage système
- [ ] QR codes pour partage rapide
- [ ] Invitations par notification push
- [ ] Planification de lives à l'avance
- [ ] Lives privés avec mot de passe
- [ ] Partage sur réseaux sociaux

---

**Note :** Ce guide suppose que l'application est déployée et accessible. En développement, utilisez les adresses IP locales appropriées.
