import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    // Désactiver la vérification email côté Supabase (voir dashboard > Auth > Settings)
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username, 'full_name': username},
      emailRedirectTo: null, // Pas de redirection email
    );
    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Utilise le User de Supabase, pas le modèle local
  dynamic get currentUser => _client.auth.currentUser;

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
