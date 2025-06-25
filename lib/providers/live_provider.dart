import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveProvider extends ChangeNotifier {
  bool isLoading = false;
  List<Map<String, dynamic>> lives = [];
  String? errorMessage;

  Future<void> fetchLives() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final res = await Supabase.instance.client
          .from('lives')
          .select('id, title, started_at, ended_at, host_id, channel_id')
          .order('started_at', ascending: false);
      lives = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      errorMessage = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> createLive(String title, String channelId, String hostId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final res = await Supabase.instance.client.from('lives').insert({
        'title': title,
        'channel_id': channelId.isNotEmpty ? channelId : null,
        'host_id': hostId,
      }).select();
      if (res.isEmpty) {
        errorMessage = "Erreur lors de la création du live.";
      }
      await fetchLives();
    } catch (e) {
      errorMessage = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> ensureUserExists(String userId) async {
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      if (res == null) {
        await Supabase.instance.client.from('users').insert({'id': userId});
      }
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<String?> createChannel(String name, String ownerId) async {
    await ensureUserExists(ownerId);
    try {
      final res = await Supabase.instance.client
          .from('channels')
          .insert({'name': name, 'owner_id': ownerId})
          .select()
          .single();
      return res['id'] as String?;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> createLiveWithChannel(String title, String ownerId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    final channelId = await createChannel(title, ownerId);
    if (channelId == null) {
      isLoading = false;
      errorMessage ??= "Erreur lors de la création du channel.";
      notifyListeners();
      return;
    }
    await createLive(title, channelId, ownerId);
  }
}
