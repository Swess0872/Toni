import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/settings.dart';
import 'theme.dart';

/// Icon set from the spec, mapped to the closest rounded Material icons.
abstract final class Ic {
  static const plus = Icons.add_rounded;
  static const close = Icons.close_rounded;
  static const check = Icons.check_rounded;
  static const chevron = Icons.expand_more_rounded;
  static const chevronR = Icons.chevron_right_rounded;
  static const lock = Icons.lock_outline_rounded;
  static const trash = Icons.delete_outline_rounded;
  static const user = Icons.person_outline_rounded;
  static const bolt = Icons.bolt_rounded;
  static const back = Icons.arrow_back_ios_new_rounded;
  static const eye = Icons.visibility_outlined;
  static const eyeOff = Icons.visibility_off_outlined;
  static const power = Icons.power_settings_new_rounded;
  static const edit = Icons.edit_outlined;
  static const flame = Icons.local_fire_department_outlined;
  static const settings = Icons.tune_rounded;
}

bool reducedMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Tappable, hoverable, keyboard/remote-focusable surface with a visible focus ring.
/// Everything clickable in the app goes through this so TV remotes can reach it.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(11)),
    this.semanticLabel,
    this.autofocus = false,
    this.onHover,
  });

  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius radius;
  final String? semanticLabel;
  final bool autofocus;
  final ValueChanged<bool>? onHover;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        autofocus: widget.autofocus,
        mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onTap?.call())},
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        onShowHoverHighlight: widget.onHover,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          child: AnimatedScale(
            scale: _pressed ? 0.98 : 1,
            duration: const Duration(milliseconds: 80),
            child: Container(
              foregroundDecoration: _focused
                  ? BoxDecoration(
                      borderRadius: widget.radius,
                      border: Border.all(color: t.acid, width: t.tv ? 3.5 : 2.5),
                    )
                  : null,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds hover state for widgets that change look on hover (rows, chips).
class Hoverable extends StatefulWidget {
  const Hoverable({super.key, required this.builder, required this.onTap, this.radius, this.semanticLabel});

  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final BorderRadius? radius;
  final String? semanticLabel;

  @override
  State<Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<Hoverable> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: widget.onTap,
        radius: widget.radius ?? BorderRadius.circular(10),
        semanticLabel: widget.semanticLabel,
        onHover: (v) => setState(() => _hovered = v),
        child: widget.builder(context, _hovered),
      );
}

enum BtnVariant { primary, ghost, ja, jaOn, nein, neinOn }

enum BtnSize { sm, md, lg }

class Btn extends StatelessWidget {
  const Btn({
    super.key,
    required this.onPressed,
    this.child,
    this.icon,
    this.variant = BtnVariant.primary,
    this.size = BtnSize.md,
    this.full = false,
  });

  final VoidCallback? onPressed;
  /// Label; null for an icon-only button.
  final Widget? child;
  final IconData? icon;
  final BtnVariant variant;
  final BtnSize size;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final (Color bg, Color fg, Color border, List<BoxShadow> shadow) = switch (variant) {
      BtnVariant.primary => (t.acid, onAccent, Colors.transparent, t.glow(t.acid)),
      BtnVariant.ghost => (t.bg2, t.text, t.line, const <BoxShadow>[]),
      BtnVariant.ja => (Color.lerp(t.bg2, ToniTheme.ja, 0.16)!, t.jaText, ToniTheme.ja.withValues(alpha: 0.35), const <BoxShadow>[]),
      BtnVariant.jaOn => (ToniTheme.ja, const Color(0xFF06231A), Colors.transparent, t.glow(ToniTheme.ja, alpha: 0.35)),
      BtnVariant.nein => (Color.lerp(t.bg2, ToniTheme.nein, 0.16)!, t.neinText, ToniTheme.nein.withValues(alpha: 0.35), const <BoxShadow>[]),
      BtnVariant.neinOn => (ToniTheme.nein, const Color(0xFF2A0A10), Colors.transparent, t.glow(ToniTheme.nein, alpha: 0.35)),
    };
    final (double padV, double padH, double font, double minH) = switch (size) {
      BtnSize.sm => (8.0, 13.0, 14.0, 40.0),
      BtnSize.md => (10.0, 16.0, 15.0, 44.0),
      BtnSize.lg => (14.0, 20.0, 16.0, 50.0),
    };
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Pressable(
        onTap: onPressed,
        child: Container(
          constraints: BoxConstraints(minHeight: minH),
          width: full ? double.infinity : null,
          padding: EdgeInsets.symmetric(vertical: padV, horizontal: padH),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: border),
            boxShadow: enabled ? shadow : null,
          ),
          child: DefaultTextStyle(
            style: t.head(size: font, color: fg).copyWith(letterSpacing: 0.01 * font),
            child: IconTheme(
              data: IconThemeData(color: fg, size: font + 3),
              child: Row(
                mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) Icon(icon),
                  if (icon != null && child != null) const SizedBox(width: 8),
                  if (child != null) Flexible(child: child!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class IconBtn extends StatelessWidget {
  const IconBtn({super.key, required this.icon, required this.onPressed, required this.tooltip, this.danger = false, this.small = false});

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool danger;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final size = small ? 36.0 : 42.0;
    return Tooltip(
      message: tooltip,
      child: Hoverable(
        onTap: onPressed,
        semanticLabel: tooltip,
        radius: BorderRadius.circular(9),
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: hovered ? (danger ? ToniTheme.nein.withValues(alpha: 0.18) : t.bg2) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: small ? 16 : 19, color: hovered ? (danger ? t.neinText : t.text) : t.dim),
        ),
      ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(t.pad),
      decoration: BoxDecoration(
        color: t.bg1,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(t.r),
        boxShadow: t.cardShadow,
      ),
      child: child,
    );
  }
}

final _avatarCache = <String, Uint8List>{};

Uint8List? _decodeAvatar(String dataUrl) {
  final cached = _avatarCache[dataUrl];
  if (cached != null) return cached;
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return null;
  try {
    if (_avatarCache.length > 64) _avatarCache.clear();
    return _avatarCache[dataUrl] = base64Decode(dataUrl.substring(comma + 1));
  } on FormatException {
    return null;
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.person, this.size = 40});

  final Person? person;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = person;
    if (p == null) return SizedBox(width: size, height: size);
    final c = p.c;
    final bytes = p.avatar == null ? null : _decodeAvatar(p.avatar!);
    if (bytes != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.withValues(alpha: 0.55)),
          image: DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
        ),
      );
    }
    final initials = p.name.length >= 2 ? p.name.substring(0, 2).toUpperCase() : p.name.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: 0.24),
        border: Border.all(color: c.withValues(alpha: 0.45)),
      ),
      child: Text(initials, style: context.t.head(size: size * 0.36, color: c)),
    );
  }
}

/// Mark count as roman numerals (default), a plain number or hand-drawn tally marks.
class Tally extends StatelessWidget {
  const Tally({super.key, required this.count, this.color, this.big = false});

  final int count;
  final Color? color;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (count == 0) {
      return Text('sauber', style: t.body(size: big ? 22 : 15, color: t.dim2, style: FontStyle.italic, height: 1.2));
    }
    final c = color ?? t.amberText;
    final style = t.mono(size: big ? 26 : 15, weight: FontWeight.w700, color: c, letterSpacing: (big ? 26 : 15) * 0.04);
    return switch (t.tally) {
      TallyMode.striche => StrichMarks(count: count, color: c, big: big),
      TallyMode.zahl => Text('$count', style: style),
      TallyMode.roman => Text(toRoman(count), style: style),
    };
  }
}

class StrichMarks extends StatelessWidget {
  const StrichMarks({super.key, required this.count, required this.color, this.big = false});

  final int count;
  final Color color;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final h = big ? 26.0 : 18.0;
    final groups = <int>[for (var rest = count; rest > 0; rest -= 5) rest < 5 ? rest : 5];
    Widget bar() => Transform.rotate(
          angle: 0.105,
          child: Container(width: 2.5, height: h, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        );
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final g in groups)
          Stack(
            clipBehavior: Clip.none,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < (g < 4 ? g : 4); i++) ...[if (i > 0) const SizedBox(width: 3), bar()],
              ]),
              if (g == 5)
                Positioned(
                  left: -2,
                  top: h * 0.4,
                  child: Transform.rotate(
                    angle: -0.42,
                    child: Container(width: 26, height: 2.5, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Pulsing live indicator; static when reduced motion is requested.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = (_c.value / 0.7).clamp(0.0, 1.0);
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(color: widget.color.withValues(alpha: 0.7 * (1 - v)), spreadRadius: 8 * v),
              ],
            ),
          );
        },
      );
}

class LiveTag extends StatelessWidget {
  const LiveTag({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: ToniTheme.ja.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        LiveDot(color: ToniTheme.ja, size: 6),
        const SizedBox(width: 5),
        Text('LÄUFT', style: t.mono(size: 10, color: t.jaText, letterSpacing: 0.5)),
      ]),
    );
  }
}

class ToniBadge extends StatelessWidget {
  const ToniBadge(this.label, {super.key, required this.color, required this.textColor});

  final String label;
  final Color color;
  final Color textColor;

  factory ToniBadge.vote(BuildContext context) => ToniBadge('Abstimmung', color: context.t.magenta.withValues(alpha: 0.2), textColor: context.t.magentaText);

  factory ToniBadge.won(BuildContext context) => ToniBadge('★ gewonnen', color: context.t.amber.withValues(alpha: 0.16), textColor: context.t.amberText);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        child: Text(label.toUpperCase(), style: context.t.mono(size: 10, weight: FontWeight.w700, color: textColor, letterSpacing: 0.4)),
      );
}

class Field extends StatelessWidget {
  const Field({super.key, required this.label, this.hint, required this.child});

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
          Text(label, style: t.head(size: 14, weight: FontWeight.w600)),
          if (hint != null) Text(hint!, style: t.body(size: 12, color: t.dim2, style: FontStyle.italic)),
        ]),
        const SizedBox(height: 9),
        child,
      ]),
    );
  }
}

/// Segmented control.
class Seg<T> extends StatelessWidget {
  const Seg({super.key, required this.value, required this.options, required this.onChanged, this.mini = false, this.full = false});

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final bool mini;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    Widget item((T, String) o) {
      final on = o.$1 == value;
      return Pressable(
        onTap: () => onChanged(o.$1),
        radius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          constraints: BoxConstraints(minHeight: mini ? 34 : 40),
          padding: EdgeInsets.symmetric(horizontal: mini ? 10 : 14, vertical: mini ? 6 : 7),
          decoration: BoxDecoration(color: on ? t.bg3 : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: Text(o.$2, style: t.head(size: mini ? 12 : 14, weight: FontWeight.w600, color: on ? t.text : t.dim)),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(mini ? 2 : 3),
      decoration: BoxDecoration(color: t.bg, border: Border.all(color: t.line), borderRadius: BorderRadius.circular(11)),
      child: Row(
        mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
        children: [for (final o in options) full ? Expanded(child: item(o)) : item(o)],
      ),
    );
  }
}

/// Dashed rounded border (CSS `border: 1px dashed`).
class DashedBorder extends StatelessWidget {
  const DashedBorder({super.key, required this.child, required this.color, this.radius = 10});

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DashPainter(color, radius), child: child);
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(0.5));
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color || old.radius != radius;
}

class DashedButton extends StatelessWidget {
  const DashedButton({super.key, required this.onPressed, required this.child, this.full = false});

  final VoidCallback? onPressed;
  final Widget child;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Hoverable(
        onTap: onPressed,
        builder: (context, hovered) {
          final c = hovered ? t.acidText : t.dim;
          return DashedBorder(
            color: hovered ? t.acid : t.line2,
            child: Container(
              width: full ? double.infinity : null,
              constraints: const BoxConstraints(minHeight: 42),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: DefaultTextStyle(
                style: t.head(size: 13, weight: FontWeight.w600, color: c),
                child: IconTheme(
                  data: IconThemeData(color: c, size: 15),
                  child: Row(mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [child]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bottom sheet in the style of the prototype's modal: full width on phones,
/// centered with max width on larger screens.
Future<T?> showToniSheet<T>(BuildContext context, {required String title, required WidgetBuilder builder, bool wide = false}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    constraints: BoxConstraints(maxWidth: wide ? 720 : 520),
    builder: (ctx) => _SheetFrame(title: title, child: builder(ctx)),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
        child: Container(
          decoration: BoxDecoration(
            color: t.bg1,
            border: Border.all(color: t.line),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: FocusScope(
            autofocus: true,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: EdgeInsets.fromLTRB(t.pad, 12, t.pad - 6, 12),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
                child: Row(children: [
                  Expanded(child: Text(title, style: t.head(size: 19))),
                  IconBtn(icon: Ic.close, tooltip: 'Schliessen', onPressed: () => Navigator.of(context).maybePop()),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(t.pad, t.pad, t.pad, t.pad + mq.padding.bottom),
                  child: child,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmAction(BuildContext context, String message, {String confirmLabel = 'Löschen'}) async {
  final t = context.t;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message, style: t.body(size: 15)),
      actions: [
        Btn(variant: BtnVariant.ghost, size: BtnSize.sm, onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
        Btn(variant: BtnVariant.nein, size: BtnSize.sm, onPressed: () => Navigator.pop(ctx, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return ok ?? false;
}

/// Runs a store action and shows server errors as a snackbar.
Future<bool> guarded(BuildContext context, Future<void> Function() action) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}

/// Lets a TV remote's arrow keys move focus between controls.
const tvShortcuts = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(TraversalDirection.up),
  SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(TraversalDirection.down),
  SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(TraversalDirection.left),
  SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(TraversalDirection.right),
  SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.goBack): DismissIntent(),
};
