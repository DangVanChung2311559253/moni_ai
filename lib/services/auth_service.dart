import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  GoogleSignIn? _googleSignIn;

  GoogleSignIn get _gsi {
    _googleSignIn ??= kIsWeb
        ? GoogleSignIn(
            clientId: 'YOUR_GOOGLE_WEB_CLIENT_ID.apps.googleusercontent.com',
          )
        : GoogleSignIn();
    return _googleSignIn!;
  }

  Stream<User?> get user => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<dynamic> registerWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await result.user?.updateDisplayName(name);
      return result.user;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Đăng ký thất bại';
    } catch (e) {
      return e.toString();
    }
  }

  Future<dynamic> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Đăng nhập thất bại';
    } catch (e) {
      return e.toString();
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        final result = await _auth.signInWithPopup(provider);
        return result.user;
      } else {
        final googleUser = await _gsi.signIn();
        if (googleUser == null) return null;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final result = await _auth.signInWithCredential(credential);
        return result.user;
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (_) {}
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) await _googleSignIn?.signOut();
      await _auth.signOut();
    } catch (_) {}
  }
}
