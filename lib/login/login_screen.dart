import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_button/sign_in_button.dart';

/// A super-exclusive 8/16-bit Star Wars–inspired login screen for “DART SIDIOUS”
/// • Background is a pixel-art Death Star rising against a starfield
/// • Crisp green PressStart2P title and buttons
/// • 8-bit pixel ground
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn(scopes: ['email']);
  bool _loading = false;

  // Pre-generate static star positions
  final List<Offset> _stars = List.generate(
    100,
        (_) => Offset(Random().nextDouble(), Random().nextDouble()),
  );

  @override
  void initState() {
    super.initState();
    // Try silent sign-in after a short delay
    Future.delayed(const Duration(milliseconds: 800), _checkSilent);
  }

  Future<void> _checkSilent() async {
    if (_auth.currentUser != null) {
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }
    try {
      final acct = await _google.signInSilently();
      if (acct != null) {
        final auth = await acct.authentication;
        final cred = GoogleAuthProvider.credential(
          accessToken: auth.accessToken,
          idToken:     auth.idToken,
        );
        await _auth.signInWithCredential(cred);
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (_) {
      // ignore errors
    }
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      final acct = await _google.signIn();
      if (acct == null) return;
      final auth = await acct.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken:     auth.idToken,
      );
      await _auth.signInWithCredential(cred);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          // 1) Pixel-art background
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _PixelBackgroundPainter(_stars),
          ),
          // 2) Login card
          Center(
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                border: Border.all(color: const Color(0xFF00FF00), width: 2),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.8),
                    offset: const Offset(4, 4),
                    blurRadius: 4,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('DART SIDIOUS', style: titleStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text('PRESS START', style: subStyle),
                  const SizedBox(height: 24),
                  _loading
                      ? const CircularProgressIndicator(color: Color(0xFF00FF00))
                      : SignInButton(
                    Buttons.google,
                    text: 'continue with google'.toUpperCase(),
                    onPressed: _signIn,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.pushReplacementNamed(context, '/home'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF00FF00), width: 2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
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

class _PixelBackgroundPainter extends CustomPainter {
  final List<Offset> stars;
  _PixelBackgroundPainter(this.stars);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    // Fill background (deep space)
    paint.color = const Color(0xFF000010);
    canvas.drawRect(Offset.zero & size, paint);

    // Draw 8-bit stars
    paint.color = Colors.white;
    for (var star in stars) {
      final dx = star.dx * size.width;
      final dy = star.dy * size.height;
      canvas.drawRect(Rect.fromLTWH(dx, dy, 2, 2), paint);
    }

    // Draw Death Star pixel-art
    final dsPaint = Paint()..color = const Color(0xFF444444);
    final cx = size.width * 0.7;
    final cy = size.height * 0.3;
    const block = 8.0;
    const radius = 80;
    for (int gx = -radius; gx <= radius; gx += block.toInt()) {
      for (int gy = -radius; gy <= radius; gy += block.toInt()) {
        if (gx * gx + gy * gy <= radius * radius) {
          canvas.drawRect(
            Rect.fromLTWH(cx + gx, cy + gy, block, block),
            dsPaint,
          );
        }
      }
    }
    // Death Star dish detail
    final dishPaint = Paint()..color = const Color(0xFF222222);
    for (int gx = -30; gx <= 30; gx += block.toInt()) {
      // horizontal strip for dish
      canvas.drawRect(
        Rect.fromLTWH(cx + gx, cy - 10, block, block),
        dishPaint,
      );
    }

    // Draw ground (8-bit tiles)
    final groundPaint = Paint()..color = const Color(0xFF001100);
    const tileSize = 16.0;
    final rows = (size.width / tileSize).ceil();
    for (int i = 0; i < rows; i++) {
      final dx = i * tileSize;
      canvas.drawRect(
        Rect.fromLTWH(dx, size.height - tileSize, tileSize, tileSize),
        groundPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PixelBackgroundPainter old) => false;
}
