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
      await Supabase.instance.client.from('lives').insert({
        'title': title,
        'channel_id': channelId,
        'host_id': hostId,
      });
      await fetchLives();
    } catch (e) {
      errorMessage = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }
}
