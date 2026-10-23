import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The shared motion language for E-SUGID.
///
/// Keeping durations and curves here prevents each screen from feeling like a
/// different application and makes it easier to keep motion lightweight.
abstract final class ESugidMotion {
  static const Duration pressIn = Duration(milliseconds: 80);
  static const Duration quick = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 240);
  static const Duration emphasized = Duration(milliseconds: 340);

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
}

/// A short, directional transition used by named routes and MaterialPageRoutes.
/// The outgoing page stays still so navigation does not transform and composite
/// two full screens at once.
class ESugidPageTransitionsBuilder extends PageTransitionsBuilder {
  const ESugidPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return _ESugidRouteTransition(animation: animation, child: child);
  }
}

class _ESugidRouteTransition extends StatefulWidget {
  const _ESugidRouteTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_ESugidRouteTransition> createState() => _ESugidRouteTransitionState();
}

class _ESugidRouteTransitionState extends State<_ESugidRouteTransition> {
  late CurvedAnimation _incoming;
  late Animation<Offset> _position;

  void _bindAnimation() {
    _incoming = CurvedAnimation(
      parent: widget.animation,
      curve: ESugidMotion.enterCurve,
      reverseCurve: ESugidMotion.exitCurve,
    );
    _position = Tween<Offset>(
      begin: const Offset(0.06, 0),
      end: Offset.zero,
    ).animate(_incoming);
  }

  @override
  void initState() {
    super.initState();
    _bindAnimation();
  }

  @override
  void didUpdateWidget(covariant _ESugidRouteTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _incoming.dispose();
      _bindAnimation();
    }
  }

  @override
  void dispose() {
    _incoming.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _incoming,
      child: SlideTransition(
        position: _position,
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}

enum ESugidHaptic { none, selection, light }

/// Smoothly changes between loading, empty, content, and authentication states.
class ESugidAnimatedSwap extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const ESugidAnimatedSwap({
    super.key,
    required this.child,
    this.duration = ESugidMotion.standard,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: ESugidMotion.quick,
      switchInCurve: ESugidMotion.enterCurve,
      switchOutCurve: ESugidMotion.exitCurve,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Keeps tab pages mounted while giving navigation a short fade-through and
/// directional movement. Hidden pages do not paint, receive taps, run tickers,
/// or contribute semantics.
class ESugidAnimatedIndexedStack extends StatelessWidget {
  final int index;
  final List<Widget> children;

  const ESugidAnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final reduceMotion = mediaQuery.disableAnimations;
    final duration = reduceMotion ? Duration.zero : ESugidMotion.standard;

    return Stack(
      fit: StackFit.expand,
      children: List<Widget>.generate(children.length, (childIndex) {
        final selected = childIndex == index;
        final restingOffset = childIndex < index
            ? const Offset(-0.025, 0)
            : const Offset(0.025, 0);
        return IgnorePointer(
          ignoring: !selected,
          child: ExcludeSemantics(
            excluding: !selected,
            child: AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: duration,
              curve: selected
                  ? ESugidMotion.enterCurve
                  : ESugidMotion.exitCurve,
              child: AnimatedSlide(
                offset: selected ? Offset.zero : restingOffset,
                duration: duration,
                curve: selected
                    ? ESugidMotion.enterCurve
                    : ESugidMotion.exitCurve,
                child: TickerMode(
                  enabled: selected,
                  child: ExcludeFocus(
                    excluding: !selected,
                    child: MediaQuery(
                      // The visible form still follows the native keyboard.
                      // Inactive tabs retain state without rebuilding on every
                      // intermediate IME inset update.
                      data: selected
                          ? mediaQuery
                          : mediaQuery.copyWith(
                              viewInsets: EdgeInsets.zero,
                              padding: mediaQuery.viewPadding,
                            ),
                      child: RepaintBoundary(child: children[childIndex]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// A one-time, lightweight entrance for cards as they enter a lazily-built
/// feed. It uses only translation, avoiding opacity save layers and blur.
class ESugidEntrance extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Offset beginOffset;
  final bool enabled;

  const ESugidEntrance({
    super.key,
    required this.child,
    this.duration = ESugidMotion.standard,
    this.beginOffset = const Offset(0, 14),
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled || (MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: ESugidMotion.enterCurve,
      child: child,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(
          beginOffset.dx * (1 - value),
          beginOffset.dy * (1 - value),
        ),
        child: child,
      ),
    );
  }
}

/// Adds immediate, tactile press feedback to custom tappable surfaces.
/// Native Material buttons already provide their own ink and state animation.
class ESugidPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final ESugidHaptic haptic;
  final String? semanticLabel;

  const ESugidPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.96,
    this.haptic = ESugidHaptic.selection,
    this.semanticLabel,
  });

  @override
  State<ESugidPressable> createState() => _ESugidPressableState();
}

class _ESugidPressableState extends State<ESugidPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    switch (widget.haptic) {
      case ESugidHaptic.none:
        break;
      case ESugidHaptic.selection:
        HapticFeedback.selectionClick();
        break;
      case ESugidHaptic.light:
        HapticFeedback.lightImpact();
        break;
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
        onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
        onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
        onTap: widget.onTap == null ? null : _handleTap,
        child: AnimatedScale(
          scale: reduceMotion || !_pressed ? 1 : widget.pressedScale,
          duration: _pressed ? ESugidMotion.pressIn : ESugidMotion.quick,
          curve: ESugidMotion.enterCurve,
          child: widget.child,
        ),
      ),
    );
  }
}

// ─── NEW ANIMATION WIDGETS ───────────────────────────────────────────

/// Staggered cascade entrance for list children.
/// Wraps each child in a delayed fade + slide so items appear one-by-one,
/// like Instagram or official app feeds.
class ESugidStaggeredEntrance extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration staggerDelay;
  final Duration duration;
  final Offset beginOffset;

  const ESugidStaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.staggerDelay = const Duration(milliseconds: 60),
    this.duration = const Duration(milliseconds: 420),
    this.beginOffset = const Offset(0, 24),
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    final delay = Duration(milliseconds: staggerDelay.inMilliseconds * index);
    return _DelayedFadeSlide(
      delay: delay,
      duration: duration,
      beginOffset: beginOffset,
      child: child,
    );
  }
}

/// Fade + directional slide entrance for individual UI elements.
class ESugidFadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;

  const ESugidFadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
    this.beginOffset = const Offset(0, 16),
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    return _DelayedFadeSlide(
      delay: delay,
      duration: duration,
      beginOffset: beginOffset,
      child: child,
    );
  }
}

/// Elastic bounce-in scale entrance for badges, FABs, and action buttons.
class ESugidScaleEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const ESugidScaleEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<ESugidScaleEntrance> createState() => _ESugidScaleEntranceState();
}

class _ESugidScaleEntranceState extends State<ESugidScaleEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration);
    _scale = Tween<double>(begin: 0.0, end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut));
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.5, curve: Curves.easeOut),
    );
    if (widget.delay == Duration.zero) {
      _started = true;
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          setState(() => _started = true);
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return widget.child;
    }
    if (!_started) return const SizedBox.shrink();
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child),
    );
  }
}

/// Internal widget: fade + slide with an optional delay.
class _DelayedFadeSlide extends StatefulWidget {
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;
  final Widget child;

  const _DelayedFadeSlide({
    required this.delay,
    required this.duration,
    required this.beginOffset,
    required this.child,
  });

  @override
  State<_DelayedFadeSlide> createState() => _DelayedFadeSlideState();
}

class _DelayedFadeSlideState extends State<_DelayedFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration);
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.65, curve: Curves.easeOut),
    );
    _offset = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic));
    if (widget.delay == Duration.zero) {
      _started = true;
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          setState(() => _started = true);
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      return Opacity(opacity: 0, child: widget.child);
    }
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: _offset.value,
          child: child),
      ),
    );
  }
}

/// Shimmer loading placeholder that sweeps a highlight across the child.
class ESugidShimmerLoading extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const ESugidShimmerLoading({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<ESugidShimmerLoading> createState() => _ESugidShimmerLoadingState();
}

class _ESugidShimmerLoadingState extends State<ESugidShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-1.0 + 2.0 * _controller.value + 0.6, 0),
              colors: [
                Color(0x00FFFFFF),
                context.colors.surface.withValues(alpha: 0.2000),
                Color(0x00FFFFFF),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
    );
  }
}
