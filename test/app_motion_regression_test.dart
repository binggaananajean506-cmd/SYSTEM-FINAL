import 'package:esugid/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TrackedAnimation extends Animation<double> {
  final statusListeners = <AnimationStatusListener>{};
  final listeners = <VoidCallback>{};
  @override
  double get value => 0.7;
  @override
  AnimationStatus get status => AnimationStatus.forward;
  @override
  void addListener(VoidCallback listener) => listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => listeners.remove(listener);
  @override
  void addStatusListener(AnimationStatusListener listener) =>
      statusListeners.add(listener);
  @override
  void removeStatusListener(AnimationStatusListener listener) =>
      statusListeners.remove(listener);
}

class _InsetProbe extends StatelessWidget {
  const _InsetProbe(this.values);
  final List<double> values;
  @override
  Widget build(BuildContext context) {
    values.add(MediaQuery.viewInsetsOf(context).bottom);
    return const SizedBox.expand();
  }
}

void main() {
  testWidgets('route rebuilds retain one curve and dispose its listeners', (
    tester,
  ) async {
    final incoming = _TrackedAnimation();
    final outgoing = _TrackedAnimation();
    final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return const ESugidPageTransitionsBuilder().buildTransitions<void>(
              route,
              context,
              incoming,
              outgoing,
              const Text('Destination'),
            );
          },
        ),
      ),
    );
    for (var index = 0; index < 12; index++) {
      rebuild(() {});
      await tester.pump();
    }
    expect(incoming.statusListeners.length, lessThanOrEqualTo(1));
    expect(outgoing.statusListeners, isEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(incoming.statusListeners, isEmpty);
    expect(outgoing.statusListeners, isEmpty);
  });

  for (final reducedMotion in [false, true]) {
    testWidgets(
      'keyboard updates only the active tab (reduced=$reducedMotion)',
      (tester) async {
        final visibleInsets = <double>[];
        final hiddenInsets = <double>[];
        final tabs = ESugidAnimatedIndexedStack(
          index: 0,
          children: [_InsetProbe(visibleInsets), _InsetProbe(hiddenInsets)],
        );
        Widget host(double inset) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 800),
              disableAnimations: reducedMotion,
              viewInsets: EdgeInsets.only(bottom: inset),
            ),
            child: tabs,
          ),
        );
        await tester.pumpWidget(host(0));
        final hiddenBuilds = hiddenInsets.length;
        for (final inset in [40.0, 100.0, 180.0, 280.0]) {
          await tester.pumpWidget(host(inset));
        }
        expect(visibleInsets.last, 280);
        expect(hiddenInsets, everyElement(0));
        expect(hiddenInsets.length, hiddenBuilds);
      },
    );

    testWidgets(
      'inactive tabs mute tickers and retain state (reduced=$reducedMotion)',
      (tester) async {
        var selected = 0;
        late StateSetter select;
        final tickerModes = <int, bool>{};
        final tabChildren = List.generate(
          2,
          (index) => Builder(
            builder: (context) {
            tickerModes[index] = TickerMode.valuesOf(context).enabled;
              return TextField(key: ValueKey('field-$index'));
            },
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reducedMotion),
              child: StatefulBuilder(
                builder: (context, setState) {
                  select = setState;
                  return Material(
                    child: ESugidAnimatedIndexedStack(
                      index: selected,
                      children: tabChildren,
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.enterText(
          find.byKey(const ValueKey('field-0')),
          'Keep draft',
        );
        expect(tickerModes, {0: true, 1: false});
        select(() => selected = 1);
        await tester.pumpAndSettle();
        expect(tickerModes, {0: false, 1: true});
        select(() => selected = 0);
        await tester.pumpAndSettle();
        expect(find.text('Keep draft'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
