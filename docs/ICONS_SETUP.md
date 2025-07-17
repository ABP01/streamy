# Configuration des Icônes d'Application Streamy

## 📱 Icônes configurées

L'application Streamy utilise `logostreamypng.png` comme icône principale pour toutes les plateformes.

### Plateformes supportées :
- ✅ **Android** (icônes standard + adaptatives)
- ✅ **iOS** (toutes les tailles requises)
- ✅ **Web** (favicon + PWA)
- ✅ **Windows** (icône de l'executable)
- ✅ **macOS** (icône de l'application)

## 🔧 Configuration

Les icônes sont gérées via le package `flutter_launcher_icons` dans `pubspec.yaml` :

```yaml
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/images/logostreamypng.png"
  adaptive_icon_background: "#1976D2"
  adaptive_icon_foreground: "assets/images/logostreamypng.png"
```

## 🎨 Couleurs utilisées

- **Couleur de fond** : `#1976D2` (Material Blue)
- **Logo** : `logostreamypng.png` (transparent)

## 📋 Fichiers générés

### Android :
- `android/app/src/main/res/mipmap-*/launcher_icon.png`
- Icônes adaptatives pour Android 12+

### iOS :
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- Toutes les tailles d'icônes requises par l'App Store

### Web :
- Favicon et icônes PWA dans le dossier web/

## 🔄 Régénération

Pour régénérer les icônes après modification du logo :

```bash
# 1. Remplacer le fichier assets/images/logostreamypng.png
# 2. Exécuter la commande de génération
dart run flutter_launcher_icons
```

## 📐 Spécifications du logo

- **Format** : PNG avec transparence
- **Taille recommandée** : 1024x1024 pixels minimum
- **Style** : Logo centré avec fond transparent
- **Qualité** : Haute résolution pour éviter la pixelisation

## ✅ Vérification

Après génération, vérifier que :
- L'icône apparaît correctement sur l'écran d'accueil
- Les icônes adaptatives fonctionnent sur Android 12+
- L'icône est visible dans les stores d'applications

---

*Dernière mise à jour : July 17, 2025*
