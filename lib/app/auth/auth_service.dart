import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleIsInitialized = false;

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();

      debugPrint('[AuthService] Starting Google sign-in flow...');

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      debugPrint('[AuthService] Google account selected: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final String? idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        debugPrint('[AuthService] idToken is null or empty.');
        throw const AuthException(
          'Google sign-in succeeded, but no ID token was returned. '
          'Please double-check your Firebase Android setup.',
        );
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      debugPrint('[AuthService] Signing into Firebase with Google credential...');

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      debugPrint(
        '[AuthService] Firebase sign-in success: ${userCredential.user?.email}',
      );

      return userCredential;
    } on GoogleSignInException catch (error, stackTrace) {
      debugPrint('[AuthService] GoogleSignInException caught.');
      debugPrint('[AuthService] code: ${error.code}');
      debugPrint('[AuthService] description: ${error.description}');
      debugPrint('[AuthService] stackTrace: $stackTrace');
      throw AuthException(_googleSignInMessage(error));
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint('[AuthService] FirebaseAuthException caught.');
      debugPrint('[AuthService] code: ${error.code}');
      debugPrint('[AuthService] message: ${error.message}');
      debugPrint('[AuthService] stackTrace: $stackTrace');
      throw AuthException(_firebaseAuthMessage(error));
    } on AuthException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('[AuthService] Unknown sign-in error: $error');
      debugPrint('[AuthService] stackTrace: $stackTrace');
      throw const AuthException(
        'Sign-in failed for an unexpected reason. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _ensureGoogleInitialized();

      debugPrint('[AuthService] Signing out from Google and Firebase...');

      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();

      debugPrint('[AuthService] Sign-out completed.');
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint('[AuthService] FirebaseAuthException during sign-out.');
      debugPrint('[AuthService] code: ${error.code}');
      debugPrint('[AuthService] message: ${error.message}');
      debugPrint('[AuthService] stackTrace: $stackTrace');
      throw AuthException(_firebaseAuthMessage(error));
    } on GoogleSignInException catch (error, stackTrace) {
      debugPrint('[AuthService] GoogleSignInException during sign-out.');
      debugPrint('[AuthService] code: ${error.code}');
      debugPrint('[AuthService] description: ${error.description}');
      debugPrint('[AuthService] stackTrace: $stackTrace');
      throw AuthException(_googleSignInMessage(error));
    } catch (error, stackTrace) {
      debugPrint('[AuthService] Unknown sign-out error: $error');
      debugPrint('[AuthService] stackTrace: $stackTrace');
      throw const AuthException(
        'Sign-out failed for an unexpected reason. Please try again.',
      );
    }
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleIsInitialized) return;

    debugPrint('[AuthService] Initializing GoogleSignIn...');
    await _googleSignIn.initialize();
    _googleIsInitialized = true;
    debugPrint('[AuthService] GoogleSignIn initialized.');
  }

  String _googleSignInMessage(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Google sign-in was canceled.';
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google sign-in is not configured correctly yet. '
            'Please check Firebase, SHA-1, and google-services.json.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google sign-in UI is unavailable right now. Please try again.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Google sign-in was interrupted. Please try again.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'Google account mismatch detected. Please sign out and try again.';
      case GoogleSignInExceptionCode.unknownError:
        return error.description ??
            'An unknown Google sign-in error occurred.';
    }
  }

  String _firebaseAuthMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'account-exists-with-different-credential':
        return 'This email is already connected to another sign-in method.';
      case 'invalid-credential':
        return 'The Google credential is invalid. Please try again.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'operation-not-allowed':
        return 'Google sign-in is not enabled in Firebase Authentication.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}