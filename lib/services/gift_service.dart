import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../config/app_config.dart';

class GiftService {
  static final _supabase = Supabase.instance.client;

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
    if (!AppConfig.giftTypes.containsKey(giftType)) {
      throw Exception('Type de gift invalide');
    }

    final giftConfig = AppConfig.giftTypes[giftType]!;
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
}
