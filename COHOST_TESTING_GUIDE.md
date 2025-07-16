# 🧪 Guide de Test - Système Co-Host TikTok Style

## 📱 Tests du Système Co-Host

### ✅ Test 1: Interface Co-Host (Visiteur)
**Étapes** :
1. Ouvrir TikTokStyleLiveScreen en tant que visiteur
2. Cliquer sur le bouton co-host (icône people violet)
3. Vérifier l'ouverture du modal co-host
4. Cliquer sur "Demander à être co-host"

**Résultat attendu** :
- Modal s'ouvre avec interface co-host
- Bouton "Demander à être co-host" visible
- Après clic, statut change en "Demande en attente..."
- Notification de succès affichée

### ✅ Test 2: Gestion des Demandes (Hôte)
**Étapes** :
1. Créer un live en tant qu'hôte
2. Recevoir une demande de co-host (depuis autre compte)
3. Ouvrir l'interface co-host
4. Voir la section "Demandes de co-host"
5. Cliquer sur accepter (✅) ou refuser (❌)

**Résultat attendu** :
- Section "Demandes de co-host" avec badge orange
- Liste des demandes avec avatar et nom
- Boutons accepter/refuser fonctionnels
- Mise à jour en temps réel après action

### ✅ Test 3: Indicateur Temps Réel
**Étapes** :
1. Avoir des co-hosts actifs dans un live
2. Observer le header du live
3. Vérifier l'affichage du badge co-host
4. Cliquer sur le badge

**Résultat attendu** :
- Badge violet avec icône people + nombre
- Badge cliquable ouvrant l'interface
- Mise à jour automatique du nombre
- Badge disparaît si aucun co-host

### ✅ Test 4: Gestion Co-hosts Actifs (Hôte)
**Étapes** :
1. Avoir des co-hosts acceptés et actifs
2. Ouvrir l'interface co-host
3. Voir la section "Co-hosts"
4. Cliquer sur le bouton retirer (icône rouge) d'un co-host

**Résultat attendu** :
- Liste des co-hosts avec avatars
- Boutons retirer visibles pour l'hôte
- Confirmation et mise à jour après retrait
- Notification "Co-host retiré"

### ✅ Test 5: Quitter Co-Host (Co-host)
**Étapes** :
1. Être accepté comme co-host
2. Ouvrir l'interface co-host
3. Voir le bouton "Quitter le co-host"
4. Cliquer pour quitter

**Résultat attendu** :
- Bouton rouge "Quitter le co-host" visible
- Après clic, statut change
- Notification "Vous avez quitté le co-host"
- Retour à l'état visiteur normal

### ✅ Test 6: Annulation de Demande
**Étapes** :
1. Faire une demande de co-host
2. Voir le statut "Demande en attente..."
3. Cliquer sur "Annuler la demande"

**Résultat attendu** :
- Bouton annulation disponible
- Après clic, retour à l'état initial
- Notification "Demande annulée"

## 🔄 Tests de Performance

### ✅ Test 7: Mises à Jour Temps Réel
**Étapes** :
1. Ouvrir 2 instances (hôte et visiteur)
2. Faire une demande côté visiteur
3. Observer l'apparition côté hôte
4. Accepter côté hôte
5. Observer la mise à jour côté visiteur

**Résultat attendu** :
- Demande apparaît instantanément côté hôte
- Acceptation visible instantanément côté visiteur
- Indicateur header mis à jour en temps réel
- Aucun délai perceptible

### ✅ Test 8: Multiples Co-hosts
**Étapes** :
1. Accepter plusieurs co-hosts
2. Vérifier l'affichage dans la liste
3. Observer l'indicateur header
4. Retirer un co-host
5. Vérifier la mise à jour

**Résultat attendu** :
- Tous les co-hosts listés correctement
- Badge header montre le bon nombre
- Retrait met à jour immédiatement
- Performance stable avec multiples entrées

## 🗄️ Tests Base de Données

### ✅ Test 9: Contraintes et Validations
**Étapes SQL** :
```sql
-- Tenter de créer demande duplicate
INSERT INTO cohost_requests (live_id, requester_id, requester_name, host_id, status)
VALUES ('same_live_id', 'same_user_id', 'Test User', 'host_id', 'pending');

-- Tenter de créer co-host duplicate
INSERT INTO cohosts (live_id, user_id, user_name, is_active)
VALUES ('same_live_id', 'same_user_id', 'Test User', true);
```

**Résultat attendu** :
- Erreur de contrainte unique sur demandes duplicates
- Erreur de contrainte unique sur co-hosts duplicates
- Système reste stable

### ✅ Test 10: Fonctions SQL
**Étapes SQL** :
```sql
-- Test acceptation demande
SELECT process_cohost_request('request_id', 'host_id', true);

-- Test retrait co-host
SELECT remove_cohost('live_id', 'host_id', 'cohost_user_id');

-- Test statistiques
SELECT * FROM cohost_statistics WHERE live_id = 'test_live_id';
```

**Résultat attendu** :
- Fonctions retournent JSON de succès
- Données cohérentes après opérations
- Statistiques correctes

## 🔒 Tests de Sécurité

### ✅ Test 11: Contrôles d'Accès
**Étapes** :
1. Tenter d'accepter une demande sans être hôte
2. Tenter de retirer un co-host sans être hôte
3. Tenter de voir des demandes d'autres lives

**Résultat attendu** :
- Erreurs appropriées pour actions non autorisées
- RLS bloque les accès non autorisés
- Messages d'erreur explicites

### ✅ Test 12: Nettoyage Automatique
**Étapes** :
1. Créer des demandes anciennes (>24h)
2. Créer une nouvelle demande
3. Vérifier le trigger de nettoyage

**Résultat attendu** :
- Anciennes demandes supprimées automatiquement
- Nouvelles demandes conservées
- Performance maintenue

## 📱 Tests Interface Mobile

### ✅ Test 13: Responsive Design
**Étapes** :
1. Tester sur différentes tailles d'écran
2. Rotation portrait/landscape
3. Modal bottom sheet sur petit écran

**Résultat attendu** :
- Interface s'adapte à toutes les tailles
- Modal reste utilisable en landscape
- Textes et boutons lisibles

### ✅ Test 14: Interactions Tactiles
**Étapes** :
1. Tester tous les boutons et zones tactiles
2. Vérifier la taille minimale des boutons
3. Tester le scroll dans les listes

**Résultat attendu** :
- Tous les boutons facilement cliquables
- Zones tactiles suffisamment grandes
- Scroll fluide dans les listes

## 🚀 Checklist Final Co-Host

- [ ] Bouton co-host visible dans barre d'actions
- [ ] Modal co-host s'ouvre correctement
- [ ] Demandes de co-host fonctionnent
- [ ] Acceptation/refus fonctionnent (hôte)
- [ ] Retrait de co-hosts fonctionne (hôte)
- [ ] Quitter co-host fonctionne (co-host)
- [ ] Indicateur temps réel dans header
- [ ] Mises à jour instantanées
- [ ] Sécurité et contrôles d'accès
- [ ] Performance avec multiples co-hosts
- [ ] Interface responsive
- [ ] Base de données cohérente
- [ ] Nettoyage automatique actif

---

## 🎯 Commandes de Test Utiles

### Flutter
```bash
# Vérifier compilation
flutter analyze

# Tests automatisés
flutter test

# Mode debug
flutter run --debug
```

### Base de Données (Supabase)
```sql
-- Voir les demandes actives
SELECT * FROM cohost_requests WHERE status = 'pending';

-- Voir les co-hosts actifs
SELECT * FROM cohosts WHERE is_active = true;

-- Statistiques par live
SELECT * FROM cohost_statistics;

-- Nettoyage manuel
DELETE FROM cohost_requests WHERE created_at < NOW() - INTERVAL '24 hours';
```

### Test d'Intégration
```dart
// Test service co-host
final request = await CoHostService.requestCoHost(liveId: 'test_live');
print('Demande créée: ${request.id}');

// Test stream temps réel
CoHostService.getActiveCoHostsStream('live_id').listen((coHosts) {
  print('Co-hosts actifs: ${coHosts.length}');
});
```

Le système de co-host est maintenant prêt pour les tests complets et l'utilisation en production ! 🎉
