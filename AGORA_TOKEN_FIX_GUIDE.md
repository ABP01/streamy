# 🚨 Guide de résolution - Erreur Agora Token

## Erreur: `ErrorCodeType.errInvalidToken`

Cette erreur indique que le token Agora fourni est invalide, expiré ou mal configuré.

## ✅ Solutions appliquées

### 1. Mode développement sans token
- **Fichier modifié**: `lib/config/app_config.dart`
- **Changement**: Ajout de `useAgoraToken = false` en mode debug
- **Effet**: Désactive l'authentification par token en développement

### 2. Gestion robuste des tokens
- **Fichier modifié**: `lib/main.dart`
- **Changement**: Vérification de la validité avant utilisation
- **Effet**: Utilise un token vide si pas de token valide disponible

### 3. Débogage amélioré
- **Nouveau fichier**: `lib/services/agora_debug_service.dart`
- **Effet**: Affiche des informations détaillées sur les erreurs

## 🔧 Configuration actuelle

```dart
// En mode debug: pas de token requis
static const bool useAgoraToken = kDebugMode ? false : true;
```

## 🧪 Test de la solution

1. **Lancer l'application en mode debug**
   ```bash
   flutter run
   ```

2. **Vérifier les logs de débogage**
   - Recherchez "🔧 TEST CONFIGURATION AGORA"
   - Vérifiez que "Token requis: false"

3. **Tester la connexion**
   - Créez un live
   - Rejoignez un live existant
   - Les erreurs de token ne devraient plus apparaître

## 🚀 Pour la production

Pour la production, vous devrez:

1. **Configurer un serveur de tokens**
   - Implémenter un endpoint pour générer des tokens
   - Utiliser l'App Certificate d'Agora

2. **Modifier la configuration**
   ```dart
   static const bool useAgoraToken = true; // En production
   ```

3. **Implémenter la génération côté serveur**
   - Le service `AgoraTokenService` contient la base
   - À compléter avec votre backend

## 📋 Checklist de vérification

- [ ] L'app se lance sans erreur de token
- [ ] Possible de créer un live
- [ ] Possible de rejoindre un live
- [ ] Les logs de debug s'affichent
- [ ] Pas d'erreur `errInvalidToken`

## 🆘 Si le problème persiste

1. Vérifiez l'App ID Agora dans `app_config.dart`
2. Assurez-vous que `flutter clean && flutter pub get` a été exécuté
3. Redémarrez l'application complètement
4. Consultez les logs détaillés dans la console

---
**Note**: Cette solution est optimisée pour le développement. En production, implémentez un système de tokens sécurisé.
