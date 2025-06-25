import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  bool isLoading = false;
  User? user;
  String? errorMessage;
  String? accessToken;

  AuthProvider() {
    user = Supabase.instance.client.auth.currentUser;
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      user = data.session?.user;
      notifyListeners();
    });
  }

  Future<void> syncUserToTable() async {
    if (user == null) return;
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('id', user!.id)
          .maybeSingle();
      if (res == null) {
        await Supabase.instance.client.from('users').insert({
          'id': user!.id,
          'email': user!.email,
          'created_at': user!.createdAt,
        });
      }
    } catch (e) {
      // Optionnel: log ou notifier
    }
  }

  Future<bool> signIn(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.session == null) {
        errorMessage = res.user == null
            ? 'Email ou mot de passe incorrect.'
            : _extractError(res);
        isLoading = false;
        notifyListeners();
        return false;
      }
      user = res.user;
      accessToken = res.session?.accessToken;
      await syncUserToTable();
      isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
    } catch (e) {
      errorMessage = e.toString();
    }
    isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> signUp(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      if (res.user == null) {
        errorMessage = res.user == null && res.session == null
            ? "Vérifiez votre email pour valider l'inscription."
            : _extractError(res);
        isLoading = false;
        notifyListeners();
        return false;
      }
      user = res.user;
      accessToken = res.session?.accessToken;
      await syncUserToTable();
      isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
    } catch (e) {
      errorMessage = e.toString();
    }
    isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    user = null;
    accessToken = null;
    errorMessage = null;
    notifyListeners();
  }

  String? _extractError(dynamic res) {
    if (res.error != null) return res.error.message;
    return res.toString();
  }
}
