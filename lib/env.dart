import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;

class Env {
  static String? supabaseUrl;
  static String? supabaseKey;
  static String? agoraAppId;
  static String? agoraCertificate;

  static Future<void> load() async {
    final env = await rootBundle.loadString('assets/.env');
    for (final line in env.split('\n')) {
      if (line.startsWith('SUPABASE_URL=')) {
        supabaseUrl = line.split('=')[1].trim();
      } else if (line.startsWith('SUPABASE_KEY=')) {
        supabaseKey = line.split('=')[1].trim();
      } else if (line.startsWith('AGORA_APP_ID=')) {
        agoraAppId = line.split('=')[1].trim();
      } else if (line.startsWith('AGORA_CERTIFICATE=')) {
        agoraCertificate = line.split('=')[1].trim();
      }
    }
  }
}
