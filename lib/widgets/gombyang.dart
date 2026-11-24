import 'dart:math' as math;
import 'package:flutter/material.dart';

const gombyangAsset = 'assets/images/branding/gombyang.png';

class GombyangButton extends StatelessWidget {
  const GombyangButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final avatar = Image.asset(
      gombyangAsset,
      width: 48,
      height: 48,
      excludeFromSemantics: true,
    );
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xff00629b),
        foregroundColor: Colors.white,
        elevation: 3,
        padding: const EdgeInsets.fromLTRB(6, 4, 14, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(5),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (MediaQuery.disableAnimationsOf(context))
            avatar
          else
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              child: avatar,
              builder: (_, t, child) => Transform.translate(
                offset: Offset(0, -2.5 * math.sin(t * math.pi)),
                child: child,
              ),
            ),
          const SizedBox(width: 4),
          const Text(
            'Tanya\nGombyang',
            semanticsLabel: 'Tanya Gombyang',
            style: TextStyle(fontWeight: FontWeight.bold, height: 1.1),
          ),
        ],
      ),
    );
  }
}
