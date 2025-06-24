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
        errorMessage = _extractError(res);
        isLoading = false;
        notifyListeners();
        return false;
      }
      user = res.user;
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
        errorMessage = _extractError(res);
        isLoading = false;
        notifyListeners();
        return false;
      }
      user = res.user;
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
    errorMessage = null;
    notifyListeners();
  }

  String? _extractError(dynamic res) {
    if (res.error != null) return res.error.message;
    return res.toString();
  }
}
