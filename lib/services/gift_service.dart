import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class GiftService {
  static final _supabase = Supabase.instance.client;

  // Types de cadeaux disponibles avec leurs coûts
  static const Map<String, Map<String, dynamic>> giftTypes = {
    'heart': {
      'name': 'Cœur',
      'cost': 10,
      'emoji': '❤️',
      'color': 0xFFE91E63,
      'animation': 'heart_float',
    },
    'star': {
      'name': 'Étoile',
      'cost': 25,
      'emoji': '⭐',
      'color': 0xFFFFD700,
      'animation': 'star_sparkle',
    },
    'diamond': {
      'name': 'Diamant',
      'cost': 100,
      'emoji': '💎',
      'color': 0xFF00BCD4,
      'animation': 'diamond_shine',
    },
    'crown': {
      'name': 'Couronne',
      'cost': 500,
      'emoji': '👑',
      'color': 0xFFFFD700,
      'animation': 'crown_royal',
    },
    'rocket': {
      'name': 'Fusée',
      'cost': 1000,
      'emoji': '🚀',
      'color': 0xFF2196F3,
      'animation': 'rocket_launch',
    },
  };

  // === ENVOI DE CADEAUX ===

  // Envoyer un gift
  static Future<Gift> sendGift({
    required String liveId,
    required String receiverId,
    required String giftType,
    int quantity = 1,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non authentifié');

    // Vérifier si le type de gift existe
    if (!giftTypes.containsKey(giftType)) {
      throw Exception('Type de gift invalide');
    }

    final giftConfig = giftTypes[giftType]!;
    final totalCost = (giftConfig['cost'] as int) * quantity;

    // Vérifier le solde de tokens de l'utilisateur
    final userProfile = await _getUserProfile(user.id);
    if (userProfile == null || userProfile.tokensBalance < totalCost) {
      throw Exception('Solde de tokens insuffisant');
    }

    // Débiter les tokens
    await _debitTokens(user.id, totalCost);

    // Créditer les tokens au receveur
    await _creditTokens(receiverId, totalCost);

    // Enregistrer le gift
    final giftData = {
      'live_id': liveId,
      'sender_id': user.id,
      'sender_name': userProfile.displayName,
      'sender_avatar': userProfile.avatar,
      'receiver_id': receiverId,
      'gift_type': giftType,
      'quantity': quantity,
      'total_cost': totalCost,
      'sent_at': DateTime.now().toIso8601String(),
      'animation': giftConfig,
    };

    final response = await _supabase
        .from('gifts')
        .insert(giftData)
        .select()
        .single();

    // Incrémenter le compteur de gifts du live
    await _supabase.rpc('increment_gift_count', params: {
      'live_id': liveId,
      'gift_count': quantity,
    });

    return Gift.fromJson(response);
  }

  // Stream des gifts en temps réel
  static Stream<List<Gift>> getGiftsStream(String liveId) {
    return _supabase
        .from('gifts')
        .stream(primaryKey: ['id'])
        .eq('live_id', liveId)
        .order('sent_at')
        .map((data) => data.map((json) => Gift.fromJson(json)).toList());
  }

  // Obtenir l'historique des gifts d'un live
  static Future<List<Gift>> getLiveGifts(String liveId, {int limit = 50}) async {
    final response = await _supabase
        .from('gifts')
        .select('*')
        .eq('live_id', liveId)
        .order('sent_at', ascending: false)
        .limit(limit);

    return (response as List).map((json) => Gift.fromJson(json)).toList();
  }

  // Obtenir les gifts envoyés par un utilisateur
  static Future<List<Gift>> getUserSentGifts(String userId, {int limit = 50}) async {
    final response = await _supabase
        .from('gifts')
        .select('*')
        .eq('sender_id', userId)
        .order('sent_at', ascending: false)
        .limit(limit);

    return (response as List).map((json) => Gift.fromJson(json)).toList();
  }

  // Obtenir les gifts reçus par un utilisateur
  static Future<List<Gift>> getUserReceivedGifts(String userId, {int limit = 50}) async {
    final response = await _supabase
        .from('gifts')
        .select('*')
        .eq('receiver_id', userId)
        .order('sent_at', ascending: false)
        .limit(limit);

    return (response as List).map((json) => Gift.fromJson(json)).toList();
  }

  // Acheter des tokens
  static Future<void> purchaseTokens(int amount, String paymentMethod) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non authentifié');

    // Ici, vous intégreriez votre système de paiement (Stripe, PayPal, etc.)
    // Pour la démo, on ajoute directement les tokens
    
    await _creditTokens(user.id, amount);

    // Enregistrer la transaction
    await _supabase.from('token_transactions').insert({
      'user_id': user.id,
      'amount': amount,
      'type': 'purchase',
      'payment_method': paymentMethod,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Obtenir le solde de tokens d'un utilisateur
  static Future<int> getUserTokenBalance(String userId) async {
    final response = await _supabase
        .from('users')
        .select('tokens_balance')
        .eq('id', userId)
        .single();

    return response['tokens_balance'] as int? ?? 0;
  }

  // Méthodes privées
  static Future<UserProfile?> _getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('*')
          .eq('id', userId)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  static Future<void> _debitTokens(String userId, int amount) async {
    await _supabase.rpc('debit_tokens', params: {
      'user_id': userId,
      'amount': amount,
    });
  }

  static Future<void> _creditTokens(String userId, int amount) async {
    await _supabase.rpc('credit_tokens', params: {
      'user_id': userId,
      'amount': amount,
    });
  }

  // === ACHAT DE TOKENS ===

  /// Packages de tokens disponibles à l'achat
  static const List<Map<String, dynamic>> tokenPackages = [
    {
      'id': 'small',
      'tokens': 100,
      'price': 0.99,
      'bonus': 0,
      'name': 'Petit pack',
      'description': '100 tokens',
    },
    {
      'id': 'medium',
      'tokens': 500,
      'price': 4.99,
      'bonus': 50,
      'name': 'Pack moyen',
      'description': '500 tokens + 50 bonus',
    },
    {
      'id': 'large',
      'tokens': 1000,
      'price': 9.99,
      'bonus': 200,
      'name': 'Gros pack',
      'description': '1000 tokens + 200 bonus',
    },
    {
      'id': 'premium',
      'tokens': 2500,
      'price': 19.99,
      'bonus': 750,
      'name': 'Pack premium',
      'description': '2500 tokens + 750 bonus',
    },
    {
      'id': 'mega',
      'tokens': 5000,
      'price': 39.99,
      'bonus': 2000,
      'name': 'Méga pack',
      'description': '5000 tokens + 2000 bonus',
    },
  ];

  /// Acheter un package de tokens
  static Future<bool> purchaseTokenPackage(
    String packageId,
    String paymentMethod,
  ) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Utilisateur non authentifié');

      final package = tokenPackages.firstWhere(
        (p) => p['id'] == packageId,
        orElse: () => throw Exception('Package invalide'),
      );

      final totalTokens = package['tokens'] + package['bonus'];

      // Ici, vous intégreriez votre système de paiement réel
      // Pour la démo, on simule un paiement réussi
      await Future.delayed(const Duration(seconds: 2));

      // Créditer les tokens
      await _creditTokens(user.id, totalTokens);

      // Enregistrer la transaction
      await _supabase.from('token_transactions').insert({
        'user_id': user.id,
        'package_id': packageId,
        'tokens_amount': totalTokens,
        'price': package['price'],
        'payment_method': paymentMethod,
        'type': 'purchase',
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Erreur achat tokens: $e');
      return false;
    }
  }

  // === STATISTIQUES ET ANALYSES ===

  /// Obtenir les statistiques de cadeaux d'un utilisateur
  static Future<Map<String, dynamic>> getUserGiftStats(String userId) async {
    try {
      final sentResponse = await _supabase
          .from('gifts')
          .select('total_cost')
          .eq('sender_id', userId);

      final receivedResponse = await _supabase
          .from('gifts')
          .select('total_cost')
          .eq('receiver_id', userId);

      int totalSent = 0;
      int totalReceived = 0;
      int giftsSent = sentResponse.length;
      int giftsReceived = receivedResponse.length;

      for (final gift in sentResponse) {
        totalSent += gift['total_cost'] as int;
      }

      for (final gift in receivedResponse) {
        totalReceived += gift['total_cost'] as int;
      }

      return {
        'gifts_sent': giftsSent,
        'gifts_received': giftsReceived,
        'tokens_spent': totalSent,
        'tokens_earned': totalReceived,
        'net_balance': totalReceived - totalSent,
      };
    } catch (e) {
      return {
        'gifts_sent': 0,
        'gifts_received': 0,
        'tokens_spent': 0,
        'tokens_earned': 0,
        'net_balance': 0,
      };
    }
  }

  /// Obtenir le classement des utilisateurs par cadeaux reçus
  static Future<List<Map<String, dynamic>>> getGiftLeaderboard({
    int limit = 10,
    String period = 'all_time', // 'today', 'week', 'month', 'all_time'
  }) async {
    try {
      String timeFilter = '';
      if (period != 'all_time') {
        final now = DateTime.now();
        DateTime startDate;
        
        switch (period) {
          case 'today':
            startDate = DateTime(now.year, now.month, now.day);
            break;
          case 'week':
            startDate = now.subtract(const Duration(days: 7));
            break;
          case 'month':
            startDate = DateTime(now.year, now.month, 1);
            break;
          default:
            startDate = DateTime(2020, 1, 1);
        }
        
        timeFilter = "and(sent_at.gte.${startDate.toIso8601String()})";
      }

      dynamic query = _supabase
          .from('gifts')
          .select('''
            receiver_id,
            sum(total_cost),
            count(*),
            users!receiver_id(username, full_name, avatar, is_verified)
          ''')
          .order('sum', ascending: false)
          .limit(limit);

      if (timeFilter.isNotEmpty) {
        query = query.filter('sent_at', 'gte', timeFilter);
      }

      final response = await query;

      return (response as List).map((item) {
        final user = item['users'];
        return {
          'user_id': item['receiver_id'],
          'username': user['username'],
          'full_name': user['full_name'],
          'avatar': user['avatar'],
          'is_verified': user['is_verified'],
          'total_tokens': item['sum'],
          'gift_count': item['count'],
        };
      }).toList();
    } catch (e) {
      print('Erreur classement cadeaux: $e');
      return [];
    }
  }

  /// Obtenir les tendances de cadeaux
  static Future<List<Map<String, dynamic>>> getGiftTrends({
    int limit = 5,
  }) async {
    try {
      final response = await _supabase
          .from('gifts')
          .select('gift_type, count(*), sum(total_cost)')
          .order('count', ascending: false)
          .limit(limit);

      return (response as List).map((item) {
        final giftConfig = giftTypes[item['gift_type']];
        return {
          'gift_type': item['gift_type'],
          'name': giftConfig?['name'] ?? item['gift_type'],
          'emoji': giftConfig?['emoji'] ?? '🎁',
          'count': item['count'],
          'total_value': item['sum'],
        };
      }).toList();
    } catch (e) {
      print('Erreur tendances cadeaux: $e');
      return [];
    }
  }

  // === GAMIFICATION ===

  /// Obtenir les réalisations de cadeaux d'un utilisateur
  static Future<List<Map<String, dynamic>>> getUserGiftAchievements(
    String userId,
  ) async {
    try {
      final stats = await getUserGiftStats(userId);
      final achievements = <Map<String, dynamic>>[];

      // Réalisations basées sur les cadeaux envoyés
      final giftsSent = stats['gifts_sent'] as int;
      if (giftsSent >= 1) {
        achievements.add({
          'id': 'first_gift',
          'name': 'Premier cadeau',
          'description': 'Envoyez votre premier cadeau',
          'icon': '🎁',
          'unlocked': true,
        });
      }
      if (giftsSent >= 10) {
        achievements.add({
          'id': 'generous_heart',
          'name': 'Cœur généreux',
          'description': 'Envoyez 10 cadeaux',
          'icon': '💝',
          'unlocked': true,
        });
      }
      if (giftsSent >= 100) {
        achievements.add({
          'id': 'gift_master',
          'name': 'Maître des cadeaux',
          'description': 'Envoyez 100 cadeaux',
          'icon': '🏆',
          'unlocked': true,
        });
      }

      // Réalisations basées sur les tokens dépensés
      final tokensSpent = stats['tokens_spent'] as int;
      if (tokensSpent >= 1000) {
        achievements.add({
          'id': 'big_spender',
          'name': 'Gros dépensier',
          'description': 'Dépensez 1000 tokens en cadeaux',
          'icon': '💰',
          'unlocked': true,
        });
      }
      if (tokensSpent >= 10000) {
        achievements.add({
          'id': 'whale',
          'name': 'Baleine',
          'description': 'Dépensez 10000 tokens en cadeaux',
          'icon': '🐋',
          'unlocked': true,
        });
      }

      return achievements;
    } catch (e) {
      print('Erreur réalisations cadeaux: $e');
      return [];
    }
  }

  // === ÉVÉNEMENTS SPÉCIAUX ===

  /// Vérifier les événements de cadeaux spéciaux actifs
  static Future<List<Map<String, dynamic>>> getActiveGiftEvents() async {
    try {
      final now = DateTime.now();
      final response = await _supabase
          .from('gift_events')
          .select('*')
          .lte('start_date', now.toIso8601String())
          .gte('end_date', now.toIso8601String())
          .eq('is_active', true);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Erreur événements cadeaux: $e');
      return [];
    }
  }

  /// Appliquer un bonus d'événement sur un cadeau
  static int applyEventBonus(int baseAmount, List<Map<String, dynamic>> events) {
    double multiplier = 1.0;
    
    for (final event in events) {
      if (event['type'] == 'bonus_multiplier') {
        multiplier *= (event['multiplier'] as num).toDouble();
      } else if (event['type'] == 'bonus_flat') {
        baseAmount += event['bonus_amount'] as int;
      }
    }
    
      return (baseAmount * multiplier).round();
    }
  }
