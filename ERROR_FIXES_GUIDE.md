# 🔧 Guide de Résolution des Erreurs - Streamy

## ✅ Problème Résolu : ScaffoldMessenger dans initState()

### Erreur
```
dependOnInheritedWidgetOfExactType<_ScaffoldMessengerScope>() or dependOnInheritedElement() was called before _TikTokStyleLiveScreenState.initState() completed.
```

### Cause
Appel de `ScaffoldMessenger.of(context)` dans `initState()` avant que le widget soit complètement construit.

### Solution Appliquée
```dart
// ❌ Ancien code (dans initState)
_autoJoinCurrentLive();

// ✅ Nouveau code (dans initState)
WidgetsBinding.instance.addPostFrameCallback((_) {
  _autoJoinCurrentLive();
});
```

### Explication
- `WidgetsBinding.instance.addPostFrameCallback()` retarde l'exécution jusqu'après la construction complète du widget
- Le `context` est alors disponible pour accéder à `ScaffoldMessenger`

## 🚀 Bonnes Pratiques pour Éviter ces Erreurs

### 1. **Utilisation de ScaffoldMessenger**
```dart
// ✅ Dans build() ou méthodes appelées après construction
void _showMessage() {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Message')),
  );
}

// ✅ Avec vérification mounted
void _showMessageSafe() {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Message')),
    );
  }
}

// ✅ Retardé après construction
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _showMessage();
  });
}
```

### 2. **Alternatives pour initState()**
```dart
// Option 1: didChangeDependencies
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (!_initialized) {
    _autoJoinCurrentLive();
    _initialized = true;
  }
}

// Option 2: addPostFrameCallback
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _autoJoinCurrentLive();
  });
}

// Option 3: Future.delayed
@override
void initState() {
  super.initState();
  Future.delayed(Duration.zero, () {
    _autoJoinCurrentLive();
  });
}
```

### 3. **Gestion des Contextes Asynchrones**
```dart
// ✅ Toujours vérifier mounted avant utilisation async
Future<void> _performAsyncOperation() async {
  await someAsyncOperation();
  
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opération terminée')),
    );
  }
}
```

## 🛡️ Autres Erreurs Communes à Éviter

### 1. **Navigation sans context valide**
```dart
// ❌ Peut causer des erreurs
Navigator.of(context).pop();

// ✅ Avec vérification
if (mounted && Navigator.canPop(context)) {
  Navigator.of(context).pop();
}
```

### 2. **setState après dispose**
```dart
// ✅ Toujours vérifier mounted
void _updateState() {
  if (mounted) {
    setState(() {
      // Mise à jour
    });
  }
}
```

### 3. **Timer et Stream non nettoyés**
```dart
Timer? _timer;
StreamSubscription? _subscription;

@override
void dispose() {
  _timer?.cancel();
  _subscription?.cancel();
  super.dispose();
}
```

## 📱 Spécifique à TikTokStyleLiveScreen

### Séquence d'Initialisation Corrigée
1. **initState()** : Configuration des contrôleurs, timers
2. **addPostFrameCallback()** : Auto-join initial, notifications
3. **onPageChanged()** : Auto-join lors du scroll (context disponible)
4. **dispose()** : Nettoyage des ressources

### Méthodes Sécurisées
```dart
void _autoJoinCurrentLive() {
  if (!mounted || _currentIndex >= widget.liveStreams.length) return;
  
  final currentStream = widget.liveStreams[_currentIndex];
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Vous regardez maintenant: ${currentStream.title}'),
      backgroundColor: const Color(0xFF6C5CE7),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}
```

## 🔍 Debug et Tests

### Commandes de Vérification
```bash
# Analyser le code
flutter analyze

# Tests de widgets
flutter test

# Vérifier les performances
flutter run --profile
```

### Logs de Debug
```dart
// Ajouter des logs pour debugger
void _autoJoinCurrentLive() {
  debugPrint('Auto-join: mounted=$mounted, index=$_currentIndex');
  if (!mounted) return;
  
  // ... reste du code
}
```

## 📝 Checklist Avant Commit

- [ ] Aucun appel à `ScaffoldMessenger.of(context)` dans `initState()`
- [ ] Tous les `Timer` et `StreamSubscription` sont nettoyés dans `dispose()`
- [ ] Vérification `mounted` avant `setState()` asynchrone
- [ ] Tests d'intégration pour les transitions de page
- [ ] Analyse Flutter sans erreurs (`flutter analyze`)

---

*Ce guide sera mis à jour au fur et à mesure des nouvelles corrections apportées au projet.*
