import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/storage_service.dart';
import '../../data/mascot_skins.dart';
import '../../data/star_pets.dart';

/// I65: hiển thị nhiều `PetInstance` cùng lúc trong 1 "chuồng" — kiến trúc
/// khác `StarMascot` (I30, 1 instance/1 controller). Dùng CHUNG 1
/// `AnimationController` cho mọi pet (lệch pha theo index) thay vì 1
/// controller/pet, vì số pet có thể lên tới hàng chục.
///
/// Chỉ tham khảo cách vẽ ngôi sao 5 cánh của `_StarPainter`
/// (`star_mascot.dart`) làm layout reference — không import/tái dùng
/// `StarMascot`, không sửa file đó.
class StarPetHabitat extends StatefulWidget {
  const StarPetHabitat({super.key, required this.pets, this.petSize = 64});

  final List<PetInstance> pets;
  final double petSize;

  @override
  State<StarPetHabitat> createState() => _StarPetHabitatState();
}

class _StarPetHabitatState extends State<StarPetHabitat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  bool get _reduceMotion =>
      StorageService.maybe?.getBool(StorageKeys.reduceMotion) ?? false;

  @override
  void initState() {
    super.initState();
    if (!_reduceMotion) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pets.isEmpty) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < widget.pets.length; i++)
              _buildPet(widget.pets[i], i),
          ],
        );
      },
    );
  }

  Widget _buildPet(PetInstance instance, int index) {
    final type = petTypeById(instance.typeId);
    if (type == null) return const SizedBox.shrink();
    // Lệch pha bồng bềnh theo index để đàn pet không nhún đồng loạt.
    final t = (_c.value + index * 0.37) % 1.0;
    final bob = sin(t * pi * 2) * widget.petSize * 0.06;
    return Transform.translate(
      offset: Offset(0, bob),
      child: CustomPaint(
        size: Size.square(widget.petSize),
        painter: _PetPainter(palette: type.palette),
      ),
    );
  }
}

/// Ngôi sao 5 cánh rút gọn (glow + gradient + viền, không vẽ mặt) — layout
/// tham khảo `_StarPainter` nhưng đơn giản hơn vì cần vẽ hàng chục pet/khung
/// hình cùng lúc.
class _PetPainter extends CustomPainter {
  _PetPainter({required this.palette});

  final MascotPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final rOuter = size.width * 0.46;
    final rInner = rOuter * 0.5;

    final star = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? rOuter : rInner;
      final a = -pi / 2 + i * pi / 5;
      final p = c + Offset(cos(a) * r, sin(a) * r);
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();

    canvas.drawPath(
      star,
      Paint()
        ..color = palette.glow.withValues(alpha: 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.08),
    );
    canvas.drawPath(
      star,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.gradientStart, palette.gradientEnd],
        ).createShader(Rect.fromCircle(center: c, radius: rOuter)),
    );
    canvas.drawPath(
      star,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.035
        ..strokeJoin = StrokeJoin.round
        ..color = palette.outline,
    );
  }

  @override
  bool shouldRepaint(covariant _PetPainter old) => old.palette != palette;
}
