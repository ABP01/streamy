import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReactionProvider extends ChangeNotifier {
  final String liveId;
  List<Map<String, dynamic>> reactions = [];
  bool isLoading = false;
  String? errorMessage;

  ReactionProvider(this.liveId) {
    fetchReactions();
    Supabase.instance.client
        .from('reactions')
        .stream(primaryKey: ['id'])
        .eq('live_id', liveId)
        .order('sent_at')
        .listen((data) {
          reactions = List<Map<String, dynamic>>.from(data);
          notifyListeners();
        });
  }

  Future<void> fetchReactions() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final res = await Supabase.instance.client
          .from('reactions')
          .select('id, sender_id, type, sent_at')
          .eq('live_id', liveId)
          .order('sent_at');
      reactions = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      errorMessage = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> sendReaction(String senderId, String type) async {
    try {
      await Supabase.instance.client.from('reactions').insert({
        'live_id': liveId,
        'sender_id': senderId,
        'type': type,
      });
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }
}
