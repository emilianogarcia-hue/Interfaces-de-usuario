import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Foto de perfil circular con las iniciales como respaldo.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.initials,
    this.imageUrl,
    this.imageBytes,
    this.radius = 36,
    this.backgroundColor,
    this.foregroundColor = Colors.white,
  });

  final String initials;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final double radius;
  final Color? backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Text(
      initials,
      style: TextStyle(
        color: foregroundColor,
        fontSize: radius * 0.66,
        fontWeight: FontWeight.bold,
      ),
    );

    Widget? image;

    if (imageBytes != null) {
      image = Image.memory(imageBytes!, fit: BoxFit.cover);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      image = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Center(child: fallback),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.white.withValues(alpha: 0.2),
      child: image == null
          ? fallback
          : ClipOval(
              child: SizedBox(
                width: radius * 2,
                height: radius * 2,
                child: image,
              ),
            ),
    );
  }
}
