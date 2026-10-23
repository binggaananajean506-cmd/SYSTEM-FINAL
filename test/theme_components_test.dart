import 'package:esugid/app/theme/esugid_clay_theme.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Color renderedTextColor(WidgetTester tester, String text) {
  final richText = find.descendant(
    of: find.text(text),
    matching: find.byType(RichText),
  );
  return (tester.renderObject(richText) as RenderParagraph).text.style!.color!;
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Material controls, menus and overlays follow $brightness', (
      tester,
    ) async {
      final colors = brightness == Brightness.dark
          ? ESugidColors.dark
          : ESugidColors.light;
      late BuildContext pageContext;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildESugidClayTheme(brightness),
          home: Builder(
            builder: (context) {
              pageContext = context;
              return Scaffold(
                appBar: AppBar(title: const Text('E-SUGID')),
                bottomNavigationBar: NavigationBar(
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person),
                      label: 'Profile',
                    ),
                  ],
                ),
                body: ListView(
                  children: [
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Concern details'),
                      ),
                    ),
                    TextField(
                      focusNode: focus,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe your concern',
                        helperText: 'Include useful details',
                        errorText: 'A description is required',
                      ),
                    ),
                    DropdownButton<String>(
                      value: 'All',
                      items: const ['All', 'Active']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (_) {},
                    ),
                    FilledButton(onPressed: () {}, child: const Text('Submit')),
                    const FilledButton(
                      onPressed: null,
                      child: Text('Unavailable'),
                    ),
                    DataTable(
                      columns: const [DataColumn(label: Text('Status'))],
                      rows: const [
                        DataRow(
                          selected: true,
                          cells: [DataCell(Text('Under review'))],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(Theme.of(pageContext).scaffoldBackgroundColor, colors.background);
      expect(renderedTextColor(tester, 'Concern details'), colors.textPrimary);
      expect(renderedTextColor(tester, 'Unavailable'), colors.disabled);
      expect(renderedTextColor(tester, 'Submit'), colors.onPrimary);
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      final decoration = Theme.of(pageContext).inputDecorationTheme;
      expect(decoration.fillColor, colors.inputBackground);
      expect(
        (decoration.focusedBorder as OutlineInputBorder).borderSide.color,
        colors.primaryGreen,
      );
      focus.unfocus();

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Active'), findsOneWidget);
      await tester.tap(find.text('Active'));
      await tester.pumpAndSettle();

      showDialog<void>(
        context: pageContext,
        builder: (_) => const AlertDialog(
          title: Text('Confirm concern'),
          content: Text('Review before submitting.'),
        ),
      );
      await tester.pumpAndSettle();
      expect(renderedTextColor(tester, 'Confirm concern'), colors.textPrimary);
      expect(
        Theme.of(
          tester.element(find.byType(AlertDialog)),
        ).dialogTheme.backgroundColor,
        colors.surface,
      );
      Navigator.of(pageContext).pop();
      await tester.pumpAndSettle();

      showModalBottomSheet<void>(
        context: pageContext,
        builder: (_) => const SizedBox(
          height: 120,
          child: Center(child: Text('Filter concerns')),
        ),
      );
      await tester.pumpAndSettle();
      expect(renderedTextColor(tester, 'Filter concerns'), colors.textPrimary);
      expect(
        Theme.of(pageContext).bottomSheetTheme.modalBackgroundColor,
        colors.surface,
      );
      Navigator.of(pageContext).pop();
      await tester.pumpAndSettle();
      ScaffoldMessenger.of(
        pageContext,
      ).showSnackBar(const SnackBar(content: Text('Saved locally')));
      await tester.pumpAndSettle();
      expect(renderedTextColor(tester, 'Saved locally'), colors.textPrimary);
      expect(tester.takeException(), isNull);
    });
  }
}
