import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/co_host.dart';
import '../models/models.dart';

class CoHostService {
  static final _supabase = Supabase.instance.client;

  // Demander à devenir co-host
  static Future<CoHostRequest> requestCoHost({required String liveId}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non authentifié');

    // Vérifier si l'utilisateur n'est pas déjà l'hôte
    final liveData = await _supabase
        .from('lives')
        .select('host_id')
        .eq('id', liveId)
        .single();

    if (liveData['host_id'] == user.id) {
      throw Exception('Vous êtes déjà l\'hôte de ce live');
    }

    // Vérifier si l'utilisateur n'a pas déjà une demande en attente
    final existingRequest = await _supabase
        .from('cohost_requests')
        .select('*')
        .eq('live_id', liveId)
        .eq('requester_id', user.id)
        .eq('status', 'pending')
        .maybeSingle();

    if (existingRequest != null) {
      throw Exception('Vous avez déjà une demande en attente pour ce live');
    }

    // Vérifier si l'utilisateur n'est pas déjà co-host
    final existingCoHost = await _supabase
        .from('cohosts')
        .select('*')
        .eq('live_id', liveId)
        .eq('user_id', user.id)
        .eq('is_active', true)
        .maybeSingle();

    if (existingCoHost != null) {
      throw Exception('Vous êtes déjà co-host de ce live');
    }

    // Obtenir le profil utilisateur
    final userProfile = await _getUserProfile(user.id);
    if (userProfile == null) {
      throw Exception('Profil utilisateur non trouvé');
    }

    // Créer la demande
    final requestData = {
      'live_id': liveId,
      'requester_id': user.id,
      'requester_name': userProfile.displayName,
      'requester_avatar': userProfile.avatar,
      'host_id': liveData['host_id'],
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await _supabase
        .from('cohost_requests')
        .insert(requestData)
        .select()
        .single();

    return CoHostRequest.fromJson(response);
  }

  // Obtenir les demandes de co-host pour un live (pour l'hôte)
  static Future<List<CoHostRequest>> getCoHostRequests(String liveId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non authentifié');

    final response = await _supabase
        .from('cohost_requests')
        .select('*')
        .eq('live_id', liveId)
        .eq('host_id', user.id)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => CoHostRequest.fromJson(json))
        .toList();
  }

  // Stream des demandes de co-host en temps réel
  static Stream<List<CoHostRequest>> getCoHostRequestsStream(String liveId) {
    final user = _supabase.auth.currentUser;
    if (user == null) return Stream.empty();

    return _supabase
        .from('cohost_requests')
        .stream(primaryKey: ['id'])
        .map(
          (data) => (data as List)
              .where(
                (json) =>
                    json['live_id'] == liveId &&
                    json['host_id'] == user.id &&
                    json['status'] == 'pending',
              )
              .map((json) => CoHostRequest.fromJson(json))
              .toList(),
        );
  }

  // Répondre à une demande de co-host (accepter/refuser)
  static Future<void> respondToCoHostRequest({
    required String requestId,
    required bool accept,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non authentifié');

    // Obtenir la demande
    final request = await _supabase
        .from('cohost_requests')
        .select('*')
        .eq('id', requestId)
        .eq('host_id', user.id)
        .single();

    if (request['status'] != 'pending') {
      throw Exception('Cette demande a déjà été traitée');
    }

    final status = accept ? 'accepted' : 'rejected';

    // Mettre à jour le statut de la demande
    await _supabase
        .from('cohost_requests')
        .update({
          'status': status,
          'responded_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);

    // Si acceptée, créer l'entrée co-host
    if (accept) {
      await _supabase.from('cohosts').insert({
        'live_id': request['live_id'],
        'user_id': request['requester_id'],
        'user_name': request['requester_name'],
        'user_avatar': request['requester_avatar'],
        'joined_at': DateTime.now().toIso8601String(),
        'is_active': true,
      });
    }
  }

  // Obtenir la liste des co-hosts actifs d'un live
  static Future<List<CoHost>> getActiveCoHosts(String liveId) async {
    final response = await _supabase
        .from('cohosts')
        .select('*')
        .eq('live_id', liveId)
        .eq('is_active', true)
        .order('joined_at', ascending: true);

    return (response as List).map((json) => CoHost.fromJson(json)).toList();
  }

  // Stream des co-hosts actifs en temps réel
  static Stream<List<CoHost>> getActiveCoHostsStream(String liveId) {
    return _supabase
        .from('cohosts')
        .stream(primaryKey: ['id'])
        .map(
          (data) => (data as List)
              .where(
                (json) =>
                    json['live_id'] == liveId && json['is_active'] == true,
              )
              .map((json) => CoHost.fromJson(json))
              .toList(),
        );
  }

  // Retirer un co-host (pour l'hôte)
  static Future<void> removeCoHost({
    required String liveId,
    required String coHostUserId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non authentifié');

    // Vérifier que l'utilisateur est bien l'hôte du live
    final liveData = await _supabase
        .from('lives')
        .select('host_id')
        .eq('id', liveId)
        .single();

    if (liveData['host_id'] != user.id) {
      throw Exception('Seul l\'hôte peut retirer des co-hosts');
    }

    // Désactiver le co-host
    await _supabase
        .from('cohosts')
        .update({'is_active': false})
        .eq('live_id', liveId)
        .eq('user_id', coHostUserId);
  }

  // Quitter en tant que co-host (pour le co-host)
  static Future<void> leaveCoHost(String liveId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non authentifié');

    await _supabase
        .from('cohosts')
        .update({'is_active': false})
        .eq('live_id', liveId)
        .eq('user_id', user.id);
  }

  // Annuler une demande de co-host
  static Future<void> cancelCoHostRequest(String requestId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non authentifié');

    await _supabase
        .from('cohost_requests')
        .update({
          'status': 'canceled',
          'responded_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId)
        .eq('requester_id', user.id);
  }

  // Vérifier si l'utilisateur actuel est co-host d'un live
  static Future<bool> isCoHost(String liveId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    final response = await _supabase
        .from('cohosts')
        .select('id')
        .eq('live_id', liveId)
        .eq('user_id', user.id)
        .eq('is_active', true)
        .maybeSingle();

    return response != null;
  }

  // Vérifier si l'utilisateur a une demande en attente
  static Future<CoHostRequest?> getPendingRequest(String liveId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('cohost_requests')
        .select('*')
        .eq('live_id', liveId)
        .eq('requester_id', user.id)
        .eq('status', 'pending')
        .maybeSingle();

    return response != null ? CoHostRequest.fromJson(response) : null;
  }

  // Méthode privée pour obtenir le profil utilisateur
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
}
