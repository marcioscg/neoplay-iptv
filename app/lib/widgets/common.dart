import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

/// Marca do app.
class NeoLogo extends StatelessWidget {
  const NeoLogo({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(
              text: 'NEO',
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: AppColors.text,
              ),
            ),
            TextSpan(
              text: 'PLAY',
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: AppColors.accent,
              ),
            ),
          ]),
        ),
        SizedBox(width: size * 0.3),
        Container(
          width: size * 0.8,
          height: size * 0.8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient:
                LinearGradient(colors: [AppColors.accent, AppColors.accent2]),
          ),
          child: Icon(Icons.play_arrow_rounded,
              size: size * 0.6, color: AppColors.bg),
        ),
      ],
    );
  }
}

/// Miniatura de logo/capa com fallback em gradiente.
class ArtThumb extends StatelessWidget {
  const ArtThumb({
    super.key,
    required this.name,
    this.logo = '',
    this.width = 44,
    this.height = 44,
    this.radius = 10,
  });

  final String name;
  final String logo;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.artFor(name);
    final initials = name.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '').trim();
    final label = initials.isEmpty
        ? '?'
        : initials.length >= 2
            ? initials.substring(0, 2).toUpperCase()
            : initials.toUpperCase();

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
        alignment: Alignment.center,
        child: logo.isEmpty
            ? Text(
                label,
                style: TextStyle(
                  fontSize: width * 0.3,
                  fontWeight: FontWeight.w800,
                  color: AppColors.bg,
                ),
              )
            : Image.network(
                logo,
                width: width,
                height: height,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  label,
                  style: TextStyle(
                    fontSize: width * 0.3,
                    fontWeight: FontWeight.w800,
                    color: AppColors.bg,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Linha de canal/filme usada nas listas.
class MediaTile extends StatelessWidget {
  const MediaTile({
    super.key,
    required this.item,
    required this.index,
    required this.onTap,
    required this.onFavorite,
    required this.isFavorite,
  });

  final MediaItem item;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface1,
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            ArtThumb(name: item.name, logo: item.logo, width: 42, height: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$index. ${item.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.group,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onFavorite,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: isFavorite ? AppColors.accent : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Linha de categoria.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.title,
    required this.count,
    required this.onTap,
    this.icon,
    this.highlight = false,
  });

  final String title;
  final int count;
  final VoidCallback onTap;
  final IconData? icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.accent : AppColors.text;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface1,
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 19,
                  color: highlight ? AppColors.accent : AppColors.muted),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: color),
              ),
            ),
            if (count > 0)
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: highlight ? AppColors.accent : AppColors.muted,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF5B6274)),
          ],
        ),
      ),
    );
  }
}

/// Estado vazio / mensagem centralizada.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message = '',
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.muted),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.muted, height: 1.5),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Cabeçalho de seção.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 14, top: 16, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6F7789),
        ),
      ),
    );
  }
}
