import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared presentation extracted from Semua Komoditas; callers own data/routes.
class CommodityCard extends StatelessWidget {
  const CommodityCard({
    super.key,
    required this.name,
    required this.specs,
    required this.price,
    this.imageUrl,
    this.home = false,
  });

  final String name;
  final String specs;
  final String price;
  final String? imageUrl;
  final bool home;

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF009FE3);
    final foreground = home
        ? Colors.black87
        : Theme.of(context).colorScheme.onSurface;
    final secondary = home
        ? Colors.black87
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final accent = home ? Colors.black87 : blue;
    final priceStyle = GoogleFonts.poppins(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: accent,
    );
    final labelStyle = GoogleFonts.poppins(fontSize: 9, color: secondary);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: foreground,
          ),
        ),
        const SizedBox(height: 4),
        Text(specs, style: GoogleFonts.poppins(fontSize: 11, color: secondary)),
      ],
    );
    final pricing = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('Harga Pasar', textAlign: TextAlign.right, style: labelStyle),
        Text(price, textAlign: TextAlign.right, style: priceStyle),
      ],
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: blue.withValues(alpha: .05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: home
            ? blue
            : Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.withValues(alpha: .1)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              double widthOf(String text, TextStyle style) {
                final painter = TextPainter(
                  text: TextSpan(text: text, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout();
                final width = painter.width;
                painter.dispose();
                return width;
              }

              final priceWidth = widthOf(price, priceStyle);
              final labelWidth = widthOf('Harga Pasar', labelStyle);
              final trailingWidth = priceWidth > labelWidth
                  ? priceWidth
                  : labelWidth;
              // Keep the reference row when it fits; never shrink scaled text.
              final stacked =
                  constraints.maxWidth - 70 - trailingWidth - 12 <
                  MediaQuery.textScalerOf(context).scale(120);
              return Row(
                children: [
                  Container(
                    height: 54,
                    width: 54,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl != null && imageUrl!.isNotEmpty
                          ? Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, error, stack) =>
                                  Icon(Icons.water_drop, color: accent),
                            )
                          : Icon(Icons.water_drop, color: accent),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: stacked
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              details,
                              const SizedBox(height: 8),
                              pricing,
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: details),
                              const SizedBox(width: 12),
                              pricing,
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
