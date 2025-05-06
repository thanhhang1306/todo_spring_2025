// ****** START OF lib/login/login_screen.dart ******

import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
// We will create a custom button, so this package is not needed:
// import 'package:sign_in_button/sign_in_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn(scopes: ['email']);
  bool _loading = false;

  final List<Offset> _stars = List.generate(
    150,
        (_) => Offset(Random().nextDouble(), Random().nextDouble()),
  );

  @override
  void initState() {
    super.initState();
    // NOTE: Removed the delayed call to _checkSilent.
    // Relying on RouterScreen with authStateChanges is the standard
    // and more reliable way to handle initial routing based on auth state.
    // This avoids the auto-relogin issue entirely.
  }

  // NOTE: Removed the _checkSilent function as it was causing
  // the auto-relogin issue and is handled by RouterScreen.
  /*
  Future<void> _checkSilent() async {
    // ... (Removed code) ...
  }
  */

  Future<void> _signInWithGoogle() async {
    if (_loading || !mounted) return;
    setState(() => _loading = true);
    try {
      final GoogleSignInAccount? googleUser = await _google.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _loading = false);
        print('Google Sign-In cancelled by user.');
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error (Google): ${e.code} - ${e.message}");
      String errorMessage = 'Sign-in failed. Please try again.';
      if (e.code == 'account-exists-with-different-credential') {
        errorMessage = 'Account exists with different credentials.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Network error. Check connection.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      print("General Sign-in Error (Google): $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('An unexpected error occurred.')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // Function for Guest Mode Button navigation
  void _navigateAsGuest() {
    if (_loading || !mounted) return;
    // Simple navigation. Assumes RouterScreen handles showing content
    // appropriately when FirebaseAuth.instance.currentUser is null
    // AFTER this navigation occurs.
    // If RouterScreen strictly requires a user, this won't keep you
    // on the home screen without further changes to RouterScreen.
    Navigator.pushReplacementNamed(context, '/home');
  }


  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.pressStart2p(
      textStyle: const TextStyle(color: Color(0xFF00FF00), fontSize: 20),
    );
    final subStyle = GoogleFonts.pressStart2p(
      textStyle: const TextStyle(color: Color(0xFF00FF00), fontSize: 10),
    );

    return Scaffold(
      body: Stack(
        children: [
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _PixelBackgroundPainter(_stars),
          ),
          Center(
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF111111).withOpacity(0.9),
                border: Border.all(color: const Color(0xFF00FF00), width: 2),
                borderRadius: BorderRadius.zero,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('DARTHUB', style: titleStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text('PRESS START', style: subStyle),
                  const SizedBox(height: 24),

                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: CircularProgressIndicator(color: Color(0xFF00FF00)),
                    )
                  else
                  // *** CORRECTED CUSTOM GOOGLE SIGN-IN BUTTON ***
                    ElevatedButton(
                      onPressed: _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, // Standard Google button background
                        foregroundColor: Colors.black87, // Text color
                        minimumSize: const Size(double.infinity, 40), // Fill width, standard height
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Sharp corners
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), // Adjust padding
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Google Logo - Requires adding the asset 'assets/images/google_logo.png'
                          Image.asset(
                            'assets/images/google_logo.png',
                            height: 18.0,
                            errorBuilder: (context, error, stackTrace) {
                              // Simple fallback if logo doesn't load
                              return const Icon(Icons.g_mobiledata_outlined, size: 24, color: Colors.grey);
                            },
                          ),
                          const SizedBox(width: 8), // Spacing
                          // Use Flexible/Expanded to allow text to shrink/wrap if needed, preventing overflow
                          Flexible( // Changed from Expanded to Flexible
                            child: Text(
                              'SIGN IN WITH GOOGLE', // Use .toUpperCase() if needed, but might take more space
                              textAlign: TextAlign.center,
                              // Removed maxLines and overflow, let Flexible handle shrinking
                              style: GoogleFonts.pressStart2p(
                                textStyle: const TextStyle(
                                  // *** START WITH A SMALLER FONT SIZE ***
                                  fontSize: 7, // Try 7 or even 6 - PressStart2P is wide
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // *** GUEST MODE BUTTON (Simple Navigation) ***
                  OutlinedButton(
                    // Calls the simple navigation function
                    onPressed: _loading ? null : _navigateAsGuest,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF00FF00), width: 2),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      foregroundColor: const Color(0xFF00FF00),
                    ),
                    child: Text('guest mode'.toUpperCase(), style: subStyle),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Background Painter (Keep as is or customize further) ---
class _PixelBackgroundPainter extends CustomPainter {
  final List<Offset> stars;
  _PixelBackgroundPainter(this.stars);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    paint.color = const Color(0xFF000010);
    canvas.drawRect(Offset.zero & size, paint);
    paint.color = Colors.white.withOpacity(0.8);
    for (var star in stars) {
      final dx = star.dx * size.width;
      final dy = star.dy * size.height;
      canvas.drawRect(Rect.fromLTWH(dx, dy, 2, 2), paint);
    }
    final dsPaint = Paint()..color = const Color(0xFF444444);
    final cx = size.width * 0.7;
    final cy = size.height * 0.3;
    const block = 8.0;
    const radius = 80;
    for (int gx = -radius; gx <= radius; gx += block.toInt()) {
      for (int gy = -radius; gy <= radius; gy += block.toInt()) {
        if (gx * gx + gy * gy <= radius * radius) {
          canvas.drawRect(Rect.fromLTWH(cx + gx, cy + gy, block, block), dsPaint,);
        }
      }
    }
    final dishPaint = Paint()..color = const Color(0xFF222222);
    const dishRadius = 30;
    const dishYOffset = -10;
    for (int gx = -dishRadius; gx <= dishRadius; gx += block.toInt()) {
      if(gx*gx <= dishRadius*dishRadius - 200) {
        canvas.drawRect(Rect.fromLTWH(cx + gx, cy + dishYOffset, block, block), dishPaint,);
      }
    }
    final groundPaint = Paint()..color = const Color(0xFF001100);
    const tileSize = 16.0;
    final rows = (size.width / tileSize).ceil();
    for (int i = 0; i < rows; i++) {
      final dx = i * tileSize;
      canvas.drawRect(Rect.fromLTWH(dx, size.height - tileSize, tileSize, tileSize), groundPaint,);
    }
  }

  @override
  bool shouldRepaint(covariant _PixelBackgroundPainter old) => false;
}

// ****** END OF lib/login/login_screen.dart ******