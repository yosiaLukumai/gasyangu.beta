import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'home.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;
  late Animation<double> _ringOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 1.0, end: 1.10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _ringOpacity = Tween<double>(begin: 0.15, end: 0.45).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondary) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondary, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: _goHome,
      child: Scaffold(
        body: Stack(
          children: [
            // ── Gradient background ────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF012333), // darker than brandPrimary
                    AppColors.brandPrimary,
                    Color(0xFF014D6E), // between primary and secondary
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // ── Decorative circle top-right ────────────────────────────────
            Positioned(
              top: -size.width * 0.25,
              right: -size.width * 0.20,
              child: Container(
                width: size.width * 0.75,
                height: size.width * 0.75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brandSecondary.withValues(alpha: 0.10),
                  border: Border.all(
                    color: AppColors.brandSecondary.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
              ),
            ),

            // ── Decorative circle bottom-left ──────────────────────────────
            Positioned(
              bottom: -size.width * 0.30,
              left: -size.width * 0.25,
              child: Container(
                width: size.width * 0.80,
                height: size.width * 0.80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brandAccent.withValues(alpha: 0.06),
                  border: Border.all(
                    color: AppColors.brandAccent.withValues(alpha: 0.10),
                    width: 1,
                  ),
                ),
              ),
            ),

            // ── Small dot accents ──────────────────────────────────────────
            Positioned(
              top: size.height * 0.18,
              left: size.width * 0.10,
              child: _Dot(color: AppColors.brandAccentLight, size: 6),
            ),
            Positioned(
              top: size.height * 0.30,
              right: size.width * 0.12,
              child: _Dot(color: AppColors.brandNeutral, size: 4),
            ),
            Positioned(
              bottom: size.height * 0.22,
              right: size.width * 0.15,
              child: _Dot(color: AppColors.brandAccent, size: 5),
            ),

            // ── Main content ───────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Pulsing icon
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return SizedBox(
                        width: 200,
                        height: 200,
                        child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer breathing ring
                          Opacity(
                            opacity: _ringOpacity.value,
                            child: Transform.scale(
                              scale: _pulse.value * 1.45,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.brandAccent,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Middle ring
                          Opacity(
                            opacity: _ringOpacity.value * 0.7,
                            child: Transform.scale(
                              scale: _pulse.value * 1.20,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.brandAccent.withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Icon container
                          Transform.scale(
                            scale: _pulse.value,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.brandAccentLight,
                                    AppColors.brandAccent,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.brandAccent.withValues(
                                      alpha: 0.45,
                                    ),
                                    blurRadius: 32,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.gas_meter_outlined,
                                size: 54,
                                color: AppColors.textOnBrand,
                              ),
                            ),
                          ),
                        ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 44),

                  // App name
                  const Text(
                    'GasYangu',
                    style: TextStyle(
                      color: AppColors.textOnBrand,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Tagline
                  const Text(
                    'Smart gas cylinder monitor',
                    style: TextStyle(
                      color: AppColors.brandNeutral,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Accent divider
                  Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.brandAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Tap hint
                  Padding(
                    padding: const EdgeInsets.only(bottom: 48),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (_, child) => Opacity(
                            opacity: _ringOpacity.value / 0.45,
                            child: child,
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: AppColors.brandNeutral,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap anywhere to continue',
                          style: TextStyle(
                            color: AppColors.brandNeutral.withValues(
                              alpha: 0.65,
                            ),
                            fontSize: 13,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Small decorative dot widget
class _Dot extends StatelessWidget {
  final Color color;
  final double size;
  const _Dot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}