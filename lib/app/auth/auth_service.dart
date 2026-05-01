import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  static const String _googleServerClientId =
      '1098467181300-hh410eo4hm6dmu1tv4q7am65l24pstd4.apps.googleusercontent.com';

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _googleServerClientId,
    scopes: <String>[
      'email',
      'profile',
    ],
  );
  final ValueNotifier<bool> previewModeNotifier = ValueNotifier<bool>(false);

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;
  bool get isPreviewMode => previewModeNotifier.value;

  Future<UserCredential> signInWithGoogle() async {
    try {
      previewModeNotifier.value = false;

      debugPrint('[AuthService] Starting Google sign-in flow...');

      final GoogleSignInAccount? googleAccount = await _googleSignIn.signIn();

      if (googleAccount == null) {
        debugPrint('[AuthService] Google sign-in was canceled.');
        throw const AuthException('Google sign-in was canceled.');
      }

      debugPrint('[AuthService] Google account selected: ${googleAccount.email}');

      final GoogleSignInAuthentication googleAuth =
          await googleAccount.authentication;

      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      if (idToken == null || idToken.isEmpty) {
        debugPrint('[AuthService] idToken is null or empty.');
        throw const AuthException(
          'Google sign-in succeeded, but no ID token was returned. '
          'Please double-check your Firebase Android setup.',
        );
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      debugPrint('[AuthService] Signing into Firebase with Google credential...');

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      debugPrint(
        '[AuthService] Firebase sign-in success: ${userCredential.user?.email}',
      );

      return userCredential;
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint('[AuthService] FirebaseAuthException caught.');
      debugPrint('[AuthService] code: ${error.code}');
      debugPrint('[AuthService] message: ${error.message}');
      debugPrint('[AuthService] stackTrace: $stackTrace');
      throw AuthException(_firebaseAuthMessage(error));
    } on AuthException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('[AuthService] Unknown sign-in error type: ${error.runtimeType}');
      debugPrint('[AuthService] Unknown sign-in error: $error');
      debugPrint('[AuthService] stackTrace: $stackTrace');
      throw AuthException(_googleSignInMessage(error));
    }
  }

  Future<void> signOut() async {
    if (isPreviewMode) {
      debugPrint('[AuthService] Leaving preview mode...');
      previewModeNotifier.value = false;
      return;
    }

    try {
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
    } catch (error, stackTrace) {
      debugPrint('[AuthService] Unknown sign-out error type: ${error.runtimeType}');
      debugPrint('[AuthService] Unknown sign-out error: $error');
      debugPrint('[AuthService] stackTrace: $stackTrace');
      throw AuthException(_googleSignInMessage(error));
    }
  }

  /// Lets us enter the app UI temporarily without removing the auth system.
  ///
  /// This is useful while the real Google/Firebase flow is still being fixed.
  void enterPreviewMode() {
    debugPrint('[AuthService] Entering preview mode...');
    previewModeNotifier.value = true;
  }

  String _googleSignInMessage(Object error) {
    final String description = error.toString();
    final String lowerDescription = description.toLowerCase();

    if (lowerDescription.contains('sign_in_canceled') ||
        lowerDescription.contains('sign in canceled') ||
        lowerDescription.contains('sign-in canceled') ||
        lowerDescription.contains('canceled')) {
      return 'Google sign-in was canceled.';
    }

    if (lowerDescription.contains('network_error') ||
        lowerDescription.contains('network error') ||
        lowerDescription.contains('network')) {
      return 'Network error. Please check your connection and try again.';
    }

    if (lowerDescription.contains('sign_in_failed') ||
        lowerDescription.contains('sign in failed') ||
        lowerDescription.contains('sign-in failed') ||
        lowerDescription.contains('12500')) {
      return _withRawError(
        'Google sign-in failed on this device. Please check Firebase, '
        'SHA-1, and google-services.json.',
        description,
      );
    }

    if (lowerDescription.contains('no credentials available')) {
      return _withRawError(
        'This phone does not have an available Google sign-in credential. '
        'Please make sure the phone is signed into a Google account, Play '
        'Services is working, and then try again.',
        description,
      );
    }

    if (lowerDescription.contains('account reauth failed')) {
      return _withRawError(
        'Google account re-authentication failed on this device. '
        'This is usually a Google/Firebase Android configuration issue, not '
        'a button cancel from you. Please try reinstalling the app after a '
        'full rebuild, and if it still fails we should re-check the Firebase '
        'Android app package and SHA setup.',
        description,
      );
    }

    return _withRawError(
      'Sign-in failed for an unexpected reason. Please try again.',
      description,
    );
  }

  String _withRawError(String message, String rawError) {
    return '$message\n\nRaw error:\n$rawError';
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
