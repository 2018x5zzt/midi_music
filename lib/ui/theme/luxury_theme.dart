import 'package:flutter/cupertino.dart';

class LuxuryPalette {
  static const background = Color(0xFF060606);
  static const backgroundRaised = Color(0xFF111111);
  static const panel = Color(0xFF161311);
  static const panelRaised = Color(0xFF1C1815);
  static const gold = Color(0xFFD3B06D);
  static const goldBright = Color(0xFFF0D8A0);
  static const goldDim = Color(0xFF8D7443);
  static const burgundy = Color(0xFF47261A);
  static const emerald = Color(0xFF3E725D);
  static const ruby = Color(0xFFA95347);
  static const textPrimary = Color(0xFFF6F0E6);
  static const textMuted = Color(0xFFB5A58A);
  static const textSubtle = Color(0xFF7E7467);
  static const divider = Color(0x33D3B06D);
}

class LuxuryBackdrop extends StatelessWidget {
  final Widget child;

  const LuxuryBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0B0A09),
            LuxuryPalette.background,
            Color(0xFF050505),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: _Aura(
              size: 260,
              color: LuxuryPalette.burgundy.withValues(alpha: 0.34),
            ),
          ),
          Positioned(
            top: 90,
            right: -70,
            child: _Aura(
              size: 220,
              color: LuxuryPalette.gold.withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -40,
            child: _Aura(
              size: 240,
              color: LuxuryPalette.emerald.withValues(alpha: 0.16),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    CupertinoColors.black.withValues(alpha: 0.0),
                    CupertinoColors.black.withValues(alpha: 0.18),
                    CupertinoColors.black.withValues(alpha: 0.28),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class LuxuryPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool highlighted;

  const LuxuryPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: highlighted
              ? const [Color(0xFF211A14), Color(0xFF130F0D)]
              : const [LuxuryPalette.panelRaised, LuxuryPalette.panel],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: highlighted
              ? LuxuryPalette.gold.withValues(alpha: 0.34)
              : LuxuryPalette.divider,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.34),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

TextStyle luxuryDisplayStyle(
  BuildContext context, {
  double size = 36,
  Color color = LuxuryPalette.textPrimary,
}) {
  return TextStyle(
    fontSize: size,
    height: 1.06,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: color,
    fontFamily: 'Georgia',
    fontFamilyFallback: const ['Times New Roman', 'Noto Serif'],
  );
}

class _Aura extends StatelessWidget {
  final double size;
  final Color color;

  const _Aura({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, CupertinoColors.black.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}
