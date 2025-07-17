# 🎥 Guide de résolution des problèmes de caméra - Streamy

## 🔍 Problème identifié
Lorsque vous lancez un live, la caméra ne s'affiche pas et vous voyez seulement un écran avec l'icône de caméra.

## 🛠️ Solutions implémentées

### 1. **Diagnostic amélioré**
- ✅ Ajout de logs détaillés dans `HostLiveScreen`
- ✅ Vérification des permissions plus robuste
- ✅ Écran de test de caméra (`CameraTestScreen`)
- ✅ Widget de debug accessible depuis l'écran principal

### 2. **Corrections dans `HostLiveScreen`**
- ✅ Amélioration de la configuration `VideoViewController`
- ✅ Ajout de `renderMode` et `mirrorMode` pour optimiser l'affichage
- ✅ Vérification de l'état du moteur Agora avant d'afficher la vue
- ✅ Configuration vidéo optimisée avec résolution et frame rate

### 3. **Gestion des permissions**
- ✅ Vérification détaillée des permissions avec logs
- ✅ Gestion des permissions définitivement refusées
- ✅ Messages d'erreur plus informatifs

## 🚀 Comment tester les corrections

### Étape 1: Utiliser l'écran de test
1. Démarrez l'application
2. Sur l'écran principal, appuyez sur le bouton rouge "Test Caméra" en haut à droite
3. Suivez les logs pour identifier le problème exact

### Étape 2: Vérifier les permissions
- Allez dans Paramètres > Applications > Streamy > Permissions
- Assurez-vous que Caméra et Microphone sont autorisés

### Étape 3: Test du live normal
1. Appuyez sur "Go Live"
2. Surveillez les logs dans la console pour identifier les erreurs

## 🔧 Codes de diagnostic ajoutés

### Dans `HostLiveScreen._initializeAgora()`:
```dart
// Logs détaillés pour chaque étape
print('🔧 Initialisation du moteur Agora...');
print('✅ Moteur Agora créé avec App ID: ${AppConfig.agoraAppId.substring(0, 8)}...');
print('🎥 Aperçu de la caméra démarré');
```

### Dans `HostLiveScreen._buildCameraView()`:
```dart
// Vérification supplémentaire du moteur
if (_engine == null) {
  print('❌ Moteur Agora non initialisé pour la vue caméra');
  return /* widget d'erreur */;
}
```

## ⚠️ Points d'attention

1. **App ID Agora**: Vérifiez que l'App ID dans `app_config.dart` est correct
2. **Permissions Android**: Le `AndroidManifest.xml` doit contenir les permissions CAMERA et RECORD_AUDIO
3. **Token Agora**: En mode développement, vous pouvez désactiver les tokens en modifiant `useAgoraToken = false`

## 🐛 Messages d'erreur courants

### "Invalid App ID"
- Vérifiez l'App ID dans `AppConfig.agoraAppId`
- Assurez-vous qu'il correspond à votre projet Agora

### "Permission denied"
- Accordez les permissions manuellement dans les paramètres
- Redémarrez l'application après avoir accordé les permissions

### "Camera preview failed"
- Vérifiez que la caméra n'est pas utilisée par une autre application
- Redémarrez l'appareil si nécessaire

## 📱 Test sur appareil réel
Il est recommandé de tester sur un appareil Android physique car l'émulateur peut avoir des limitations avec la caméra.

## 🔄 Étapes suivantes
1. Testez avec l'écran de diagnostic
2. Partagez les logs si le problème persiste
3. Vérifiez la configuration Agora dans votre console développeur
