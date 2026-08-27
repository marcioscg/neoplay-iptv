import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

/// Marca do app: gatinho estilizado + "MIAU NET".
class MiauLogo extends StatelessWidget {
  const MiauLogo({super.key, this.size = 18, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final badge = size * 1.45;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CatMark(size: badge),
        if (showWordmark) ...[
          SizedBox(width: size * 0.42),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: 'MIAU',
                style: TextStyle(
                  fontSize: size,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: AppColors.text,
                ),
              ),
              TextSpan(
                text: ' NET',
                style: TextStyle(
                  fontSize: size,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: AppColors.accent,
                ),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}

/// Selo do gatinho, usado no logo e na tela de login.
class CatMark extends StatelessWidget {
  const CatMark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accent, AppColors.accent2],
        ),
      ),
      child: CustomPaint(painter: _CatFacePainter()),
    );
  }
}

class _CatFacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final dark = Paint()
      ..color = AppColors.bg
      ..isAntiAlias = true;
    final cx = w * 0.5;
    final cy = h * 0.58;
    final r = w * 0.29;

    final ears = Path()
      ..moveTo(cx - r * 1.05, cy - r * 0.5)
      ..lineTo(w * 0.2, h * 0.14)
      ..lineTo(cx - r * 0.1, cy - r * 0.85)
      ..close()
      ..moveTo(cx + r * 1.05, cy - r * 0.5)
      ..lineTo(w * 0.8, h * 0.14)
      ..lineTo(cx + r * 0.1, cy - r * 0.85)
      ..close();
    canvas.drawPath(ears, dark);
    canvas.drawCircle(Offset(cx, cy), r, dark);

    final glow = Paint()..color = AppColors.accent;
    canvas.drawCircle(Offset(cx - r * 0.4, cy - r * 0.05), r * 0.13, glow);
    canvas.drawCircle(Offset(cx + r * 0.4, cy - r * 0.05), r * 0.13, glow);

    final whisker = Paint()
      ..color = AppColors.accent
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round;
    for (var i = -1; i <= 1; i++) {
      final dy = cy + r * 0.2 + i * r * 0.26;
      canvas.drawLine(
          Offset(cx - r * 0.5, dy), Offset(cx - r * 1.3, dy - i * r * 0.12), whisker);
      canvas.drawLine(
          Offset(cx + r * 0.5, dy), Offset(cx + r * 1.3, dy - i * r * 0.12), whisker);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
                cacheWidth: width.isFinite ? (width * 2).round() : 320,
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
        decoration: BoxDecoration(
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
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted),
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
    this.locked = false,
  });

  final String title;
  final int count;
  final VoidCallback onTap;
  final IconData? icon;
  final bool highlight;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.accent : AppColors.text;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
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
            Icon(
              locked ? Icons.lock_outline : Icons.chevron_right,
              size: locked ? 15 : 18,
              color: locked ? AppColors.accent : const Color(0xFF5B6274),
            ),
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
                style: TextStyle(
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

/// Barra horizontal proporcional com rótulo e valor à direita. Usada nos
/// gráficos simples do painel (central de uso e faturamento).
class MiniBar extends StatelessWidget {
  const MiniBar({
    super.key,
    required this.label,
    required this.amount,
    required this.max,
    required this.display,
    this.sub,
  });

  final String label;
  final String? sub;

  /// Valor desta barra e o maior valor do conjunto (para a proporção).
  final double amount;
  final double max;

  /// Texto mostrado à direita (ex.: "R$ 120,00" ou "8").
  final String display;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (amount / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
              ),
              Text(display,
                  style: TextStyle(fontSize: 12, color: AppColors.accent)),
            ],
          ),
          if (sub != null)
            Text(sub!,
                style: TextStyle(fontSize: 10.5, color: AppColors.muted)),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: ratio, minHeight: 5),
          ),
        ],
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
