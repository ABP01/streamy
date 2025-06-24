import 'dart:convert';

import 'package:http/http.dart' as http;

class AgoraTokenService {
  final String backendUrl;
  AgoraTokenService(this.backendUrl);

  Future<Map<String, dynamic>?> fetchAgoraToken({
    required String channelName,
    required String supabaseAccessToken,
    bool isBroadcaster = false,
  }) async {
    final url = Uri.parse('$backendUrl/api/agora-token');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $supabaseAccessToken',
      },
      body: jsonEncode({
        'channelName': channelName,
        'isBroadcaster': isBroadcaster,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return null;
    }
  }
}
