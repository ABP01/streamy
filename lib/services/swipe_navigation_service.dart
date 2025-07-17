import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/cache_service.dart';
import '../services/live_stream_service.dart';

class SwipeNavigationService {
  static final _supabase = Supabase.instance.client;
  static final LiveStreamService _liveService = LiveStreamService();

  /// Précharger les lives pour une navigation fluide
  static Future<List<LiveStream>> preloadLives({
    int count = 10,
    String? lastLiveId,
  }) async {
    try {
      // Vérifier le cache d'abord
      final cachedLives = await CacheService.getCachedLives();
      if (cachedLives != null && cachedLives.isNotEmpty) {
        return cachedLives;
      }

      // Récupérer les lives depuis l'API
      final lives = await _liveService.fetchLiveStreams(
        limit: count,
        sort: LiveStreamSort.viewerCount,
      );

      // Mettre en cache
      await CacheService.cacheLives(lives);

      return lives;
    } catch (e) {
      print('Erreur lors du préchargement: $e');
      return [];
    }
  }

  /// Récupérer le live suivant
  static Future<LiveStream?> getNextLive({
    required String currentLiveId,
    required List<LiveStream> availableLives,
  }) async {
    try {
      final currentIndex = availableLives.indexWhere(
        (live) => live.id == currentLiveId,
      );

      if (currentIndex == -1 || currentIndex >= availableLives.length - 1) {
        // Charger plus de lives si on arrive à la fin
        final moreLives = await _liveService.fetchLiveStreams(
          limit: 10,
          offset: availableLives.length,
          sort: LiveStreamSort.viewerCount,
        );

        if (moreLives.isNotEmpty) {
          availableLives.addAll(moreLives);
          return moreLives.first;
        }
        return null;
      }

      return availableLives[currentIndex + 1];
    } catch (e) {
      print('Erreur lors de la récupération du live suivant: $e');
      return null;
    }
  }

  /// Récupérer le live précédent
  static LiveStream? getPreviousLive({
    required String currentLiveId,
    required List<LiveStream> availableLives,
  }) {
    try {
      final currentIndex = availableLives.indexWhere(
        (live) => live.id == currentLiveId,
      );

      if (currentIndex <= 0) return null;

      return availableLives[currentIndex - 1];
    } catch (e) {
      print('Erreur lors de la récupération du live précédent: $e');
      return null;
    }
  }

  /// Enregistrer l'action de swipe pour les analytics
  static Future<void> trackSwipeAction({
    required String fromLiveId,
    required String? toLiveId,
    required SwipeDirection direction,
    required Duration timeSpent,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      await _supabase.from('swipe_analytics').insert({
        'user_id': currentUser.id,
        'from_live_id': fromLiveId,
        'to_live_id': toLiveId,
        'direction': direction.name,
        'time_spent_seconds': timeSpent.inSeconds,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Analytics ne doivent pas bloquer l'UX
      print('Erreur analytics swipe: $e');
    }
  }

  /// Auto-join d'un live lors du swipe
  static Future<void> autoJoinLive({
    required String liveId,
    required SwipeDirection direction,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      // Utiliser la fonction SQL pour l'auto-join
      await _supabase.rpc(
        'auto_join_live',
        params: {
          'p_user_id': currentUser.id,
          'p_live_id': liveId,
          'p_scroll_direction': direction == SwipeDirection.up ? 'up' : 'down',
        },
      );
    } catch (e) {
      print('Erreur auto-join: $e');
    }
  }

  /// Auto-leave du live précédent
  static Future<void> autoLeaveLive() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      // Utiliser la fonction SQL pour l'auto-leave
      await _supabase.rpc(
        'auto_leave_live',
        params: {'p_user_id': currentUser.id},
      );
    } catch (e) {
      print('Erreur auto-leave: $e');
    }
  }

  /// Optimiser la performance en préparant les ressources du live suivant
  static Future<void> preloadNextLiveResources(LiveStream nextLive) async {
    try {
      // Précharger l'avatar de l'hôte si disponible
      if (nextLive.hostAvatar != null) {
        await precacheImage(
          NetworkImage(nextLive.hostAvatar!),
          NavigationService.navigatorKey.currentContext!,
        );
      }

      // Précharger la thumbnail si disponible
      if (nextLive.thumbnail != null) {
        await precacheImage(
          NetworkImage(nextLive.thumbnail!),
          NavigationService.navigatorKey.currentContext!,
        );
      }

      // Précharger les données du chat récent
      // await ChatService.preloadRecentMessages(nextLive.id);
    } catch (e) {
      print('Erreur préchargement ressources: $e');
    }
  }

  /// Récupérer les lives recommandés basés sur l'historique
  static Future<List<LiveStream>> getRecommendedLives({int limit = 20}) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        return await _liveService.fetchLiveStreams(limit: limit);
      }

      // Utiliser la fonction SQL pour les recommandations
      final response = await _supabase.rpc(
        'get_recommended_lives',
        params: {'user_id': currentUser.id, 'limit_count': limit},
      );

      return (response as List)
          .map((json) => LiveStream.fromJson(json))
          .toList();
    } catch (e) {
      print('Erreur recommandations: $e');
      // Fallback sur les lives normaux
      return await _liveService.fetchLiveStreams(limit: limit);
    }
  }

  /// Optimiser l'ordre des lives pour la navigation
  static List<LiveStream> optimizeLiveOrder({
    required List<LiveStream> lives,
    String? userPreferences,
  }) {
    // Algorithme simple de tri par pertinence
    lives.sort((a, b) {
      // Prioriser les lives avec plus de viewers
      int viewerDiff = b.viewerCount.compareTo(a.viewerCount);
      if (viewerDiff != 0) return viewerDiff;

      // Puis par nombre de likes
      int likesDiff = b.likeCount.compareTo(a.likeCount);
      if (likesDiff != 0) return likesDiff;

      // Enfin par date de création (plus récent d'abord)
      return (b.startedAt ?? DateTime.now()).compareTo(
        a.startedAt ?? DateTime.now(),
      );
    });

    return lives;
  }

  /// Nettoyer les ressources lors du changement de live
  static Future<void> cleanupPreviousLive(String liveId) async {
    try {
      // Nettoyer le cache des messages
      await CacheService.clearMessagesCache(liveId);

      // Auto-leave du live précédent
      await autoLeaveLive();
    } catch (e) {
      print('Erreur nettoyage: $e');
    }
  }
}

// Service de navigation global pour accéder au contexte
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}

// Énumération des directions de swipe
enum SwipeDirection { up, down, left, right }

// Modèle pour les analytics de swipe
class SwipeAnalytics {
  final String id;
  final String userId;
  final String fromLiveId;
  final String? toLiveId;
  final SwipeDirection direction;
  final Duration timeSpent;
  final DateTime createdAt;

  SwipeAnalytics({
    required this.id,
    required this.userId,
    required this.fromLiveId,
    this.toLiveId,
    required this.direction,
    required this.timeSpent,
    required this.createdAt,
  });

  factory SwipeAnalytics.fromJson(Map<String, dynamic> json) {
    return SwipeAnalytics(
      id: json['id'],
      userId: json['user_id'],
      fromLiveId: json['from_live_id'],
      toLiveId: json['to_live_id'],
      direction: SwipeDirection.values.firstWhere(
        (d) => d.name == json['direction'],
        orElse: () => SwipeDirection.up,
      ),
      timeSpent: Duration(seconds: json['time_spent_seconds']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'from_live_id': fromLiveId,
      'to_live_id': toLiveId,
      'direction': direction.name,
      'time_spent_seconds': timeSpent.inSeconds,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
