import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatProvider extends ChangeNotifier {
  final String liveId;
  List<Map<String, dynamic>> messages = [];
  bool isLoading = false;
  String? errorMessage;

  ChatProvider(this.liveId) {
    fetchMessages();
    Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('live_id', liveId)
        .order('sent_at')
        .listen((data) {
          messages = List<Map<String, dynamic>>.from(data);
          notifyListeners();
        });
  }

  Future<void> fetchMessages() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final res = await Supabase.instance.client
          .from('messages')
          .select('id, sender_id, content, sent_at')
          .eq('live_id', liveId)
          .order('sent_at');
      messages = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      errorMessage = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> sendMessage(String senderId, String content) async {
    if (content.trim().isEmpty) return;
    try {
      await Supabase.instance.client.from('messages').insert({
        'live_id': liveId,
        'sender_id': senderId,
        'content': content.trim(),
      });
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }
}
