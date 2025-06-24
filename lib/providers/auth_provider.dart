import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  bool isLoading = false;
  User? user;
  String? errorMessage;

  AuthProvider() {
    user = Supabase.instance.client.auth.currentUser;
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      user = data.session?.user;
      notifyListeners();
    });
  }

  Future<void> signIn(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
      if (res.session == null) {
        errorMessage = res.toString(); // fallback, affichera le contenu de la réponse
      }
    } catch (e) {
      errorMessage = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> signUp(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final res = await Supabase.instance.client.auth.signUp(email: email, password: password);
      if (res.session == null && res.user == null) {
        errorMessage = res.toString(); // fallback, affichera le contenu de la réponse
      }
    } catch (e) {
      errorMessage = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    user = null;
    errorMessage = null;
    notifyListeners();
  }
}
