// Layout conformance, the Flutter side: builds every case of
// mobile/layout_conformance/cases.json as real Flutter widgets, lays it out in
// a viewport of the case's size, and writes each node's rect (and any layout
// error or overflow Flutter reported) to RUI_LAYOUT_OUT.
//
//   RUI_LAYOUT_CASES=cases.json RUI_LAYOUT_OUT=flutter.json \
//     flutter test test/layout_conformance_test.dart
//
// Run by mobile/layout_conformance/run.sh. The RUI side is rui_runner.nim.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

double? num_(dynamic v) =>
    v == null ? null : (v == 'inf' ? double.infinity : (v as num).toDouble());

EdgeInsets insets(dynamic v) => v == null
    ? EdgeInsets.zero
    : EdgeInsets.fromLTRB(num_(v[0])!, num_(v[1])!, num_(v[2])!, num_(v[3])!);

Alignment align(dynamic v, [Alignment d = Alignment.center]) =>
    v == null ? d : Alignment(num_(v[0])!, num_(v[1])!);

T pick<T extends Enum>(List<T> values, dynamic name, T d) =>
    name == null ? d : values.firstWhere((e) => e.name == name);

TextDirection? dir(dynamic v) => v == null ? null : pick(TextDirection.values, v, TextDirection.ltr);

TableColumnWidth colWidth(dynamic v) => switch (v[0]) {
      'fixed' => FixedColumnWidth(num_(v[1])!),
      'intrinsic' => const IntrinsicColumnWidth(),
      'fraction' => FractionColumnWidth(num_(v[1])!),
      _ => FlexColumnWidth(num_(v[1]) ?? 1),
    };

const fillColor = Color(0x8000AA00);

Widget build(Map node) {
  final p = (node['p'] as Map?) ?? {};
  final key = ValueKey<String>(node['id'] as String);
  final kids = node['w'] == 'Table'   // a Table's children are TableRows, not widgets
      ? <Widget>[]
      : [for (final c in (node['c'] as List? ?? [])) build(c as Map)];
  final child = kids.isEmpty ? null : kids.first;
  final mainA = pick(MainAxisAlignment.values, p['mainAxisAlignment'], MainAxisAlignment.start);
  final crossA = pick(CrossAxisAlignment.values, p['crossAxisAlignment'], CrossAxisAlignment.center);
  final mainS = pick(MainAxisSize.values, p['mainAxisSize'], MainAxisSize.max);
  final vdir = pick(VerticalDirection.values, p['verticalDirection'], VerticalDirection.down);
  final spacing = num_(p['spacing']) ?? 0;
  switch (node['w']) {
    case 'Box':
      return SizedBox(key: key, width: num_(p['width']), height: num_(p['height']),
          child: const ColoredBox(color: fillColor));
    case 'Fill':
      return Container(key: key, color: fillColor);
    case 'Text':
      return Text(p['text'] as String, key: key, softWrap: p['wrap'] as bool? ?? true,
          style: TextStyle(fontFamily: 'Roboto', fontSize: num_(p['size'])));
    case 'Row':
    case 'Column':
    case 'Flex':
      final axis = node['w'] == 'Row'
          ? Axis.horizontal
          : node['w'] == 'Column' ? Axis.vertical : pick(Axis.values, p['direction'], Axis.horizontal);
      return Flex(key: key, direction: axis, mainAxisAlignment: mainA, crossAxisAlignment: crossA,
          mainAxisSize: mainS, verticalDirection: vdir, textDirection: dir(p['textDirection']),
          spacing: spacing, children: kids);
    case 'Expanded':
      return Expanded(key: key, flex: p['flex'] ?? 1, child: child!);
    case 'Flexible':
      return Flexible(key: key, flex: p['flex'] ?? 1,
          fit: pick(FlexFit.values, p['fit'], FlexFit.loose), child: child!);
    case 'Spacer':
      return Spacer(key: key, flex: p['flex'] ?? 1);
    case 'Padding':
      return Padding(key: key, padding: insets(p['padding']), child: child);
    case 'SizedBox':
      return SizedBox(key: key, width: num_(p['width']), height: num_(p['height']), child: child);
    case 'ConstrainedBox':
      return ConstrainedBox(key: key, constraints: BoxConstraints(
          minWidth: num_(p['minWidth']) ?? 0, maxWidth: num_(p['maxWidth']) ?? double.infinity,
          minHeight: num_(p['minHeight']) ?? 0, maxHeight: num_(p['maxHeight']) ?? double.infinity),
          child: child);
    case 'LimitedBox':
      return LimitedBox(key: key, maxWidth: num_(p['maxWidth']) ?? double.infinity,
          maxHeight: num_(p['maxHeight']) ?? double.infinity, child: child);
    case 'UnconstrainedBox':
      return UnconstrainedBox(key: key, child: child);
    case 'OverflowBox':
      return OverflowBox(key: key, maxWidth: num_(p['maxWidth']), maxHeight: num_(p['maxHeight']),
          child: child);
    case 'Container':
      final hasC = p.containsKey('minWidth') || p.containsKey('minHeight');
      return Container(key: key, width: num_(p['width']), height: num_(p['height']),
          padding: p['padding'] == null ? null : insets(p['padding']),
          margin: p['margin'] == null ? null : insets(p['margin']),
          alignment: p['alignment'] == null ? null : align(p['alignment']),
          color: p['color'] == null ? null : fillColor,
          constraints: hasC
              ? BoxConstraints(minWidth: num_(p['minWidth']) ?? 0, minHeight: num_(p['minHeight']) ?? 0)
              : null,
          child: child);
    case 'Align':
      return Align(key: key, alignment: align(p['alignment']), widthFactor: num_(p['widthFactor']),
          heightFactor: num_(p['heightFactor']), child: child);
    case 'Center':
      return Center(key: key, widthFactor: num_(p['widthFactor']),
          heightFactor: num_(p['heightFactor']), child: child);
    case 'Stack':
      return Stack(key: key, alignment: align(p['alignment'], Alignment.topLeft),
          fit: pick(StackFit.values, p['fit'], StackFit.loose), textDirection: dir(p['textDirection']),
          children: kids);
    case 'Positioned':
      if (p.containsKey('start')) {
        return PositionedDirectional(key: key, start: num_(p['start']), top: num_(p['top']),
            end: num_(p['end']), bottom: num_(p['bottom']), width: num_(p['width']),
            height: num_(p['height']), child: child!);
      }
      return Positioned(key: key, left: num_(p['left']), top: num_(p['top']), right: num_(p['right']),
          bottom: num_(p['bottom']), width: num_(p['width']), height: num_(p['height']), child: child!);
    case 'IndexedStack':
      return IndexedStack(key: key, index: p['index'] ?? 0, children: kids);
    case 'Wrap':
      return Wrap(key: key, direction: pick(Axis.values, p['direction'], Axis.horizontal),
          spacing: spacing, runSpacing: num_(p['runSpacing']) ?? 0,
          alignment: pick(WrapAlignment.values, p['alignment'], WrapAlignment.start),
          runAlignment: pick(WrapAlignment.values, p['runAlignment'], WrapAlignment.start),
          crossAxisAlignment: pick(WrapCrossAlignment.values, p['crossAxisAlignment'], WrapCrossAlignment.start),
          textDirection: dir(p['textDirection']), children: kids);
    case 'Table':
      final cw = (p['columnWidths'] as Map?)?.map((k, v) => MapEntry(int.parse(k), colWidth(v)));
      return Table(key: key, columnWidths: cw,
          defaultColumnWidth: p['defaultColumnWidth'] == null
              ? const FlexColumnWidth()
              : colWidth(p['defaultColumnWidth']),
          defaultVerticalAlignment: pick(TableCellVerticalAlignment.values,
              p['defaultVerticalAlignment'], TableCellVerticalAlignment.top),
          children: [
            for (final r in node['c'] as List)
              TableRow(key: ValueKey<String>(r['id']),
                  children: [for (final c in (r['c'] as List)) build(c as Map)])
          ]);
    case 'GridView':
      if (p.containsKey('maxCrossAxisExtent')) {
        return GridView.extent(key: key, maxCrossAxisExtent: num_(p['maxCrossAxisExtent'])!,
            padding: EdgeInsets.zero, children: kids);
      }
      return GridView.count(key: key, crossAxisCount: p['crossAxisCount'] ?? 2,
          mainAxisSpacing: num_(p['mainAxisSpacing']) ?? 0,
          crossAxisSpacing: num_(p['crossAxisSpacing']) ?? 0,
          childAspectRatio: num_(p['childAspectRatio']) ?? 1, padding: EdgeInsets.zero, children: kids);
    case 'AspectRatio':
      return AspectRatio(key: key, aspectRatio: num_(p['aspectRatio'])!, child: child);
    case 'FractionallySizedBox':
      return FractionallySizedBox(key: key, widthFactor: num_(p['widthFactor']),
          heightFactor: num_(p['heightFactor']), alignment: align(p['alignment']), child: child);
    case 'IntrinsicHeight':
      return IntrinsicHeight(key: key, child: child);
    case 'IntrinsicWidth':
      return IntrinsicWidth(key: key, child: child);
    case 'Offstage':
      return Offstage(key: key, child: child);
    case 'Visibility':
      final keep = p['maintainSize'] == true;
      return Visibility(key: key, visible: p['visible'] ?? true, maintainSize: keep,
          maintainAnimation: keep, maintainState: keep, child: child!);
    case 'SingleChildScrollView':
      return SingleChildScrollView(key: key,
          scrollDirection: pick(Axis.values, p['scrollDirection'], Axis.vertical),
          padding: p['padding'] == null ? null : insets(p['padding']), child: child);
    case 'ListView':
      return ListView(key: key, scrollDirection: pick(Axis.values, p['scrollDirection'], Axis.vertical),
          itemExtent: num_(p['itemExtent']), padding: EdgeInsets.zero, children: kids);
  }
  throw UnsupportedError('no Flutter mapping for ${node['w']}');
}

Iterable<Map> walk(Map node) sync* {
  yield node;
  for (final c in (node['c'] as List? ?? [])) yield* walk(c as Map);
}

Future<void> loadRoboto(String? dir) async {
  if (dir == null) return;
  final loader = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold']) {
    loader.addFont(Future.value(ByteData.sublistView(File('$dir/Roboto-$w.ttf').readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  final env = Platform.environment;
  final cases = (jsonDecode(File(env['RUI_LAYOUT_CASES'] ?? 'cases.json').readAsStringSync())
      as Map)['cases'] as List;
  final results = <String, Object>{};

  setUpAll(() => loadRoboto(env['RUI_ROBOTO_DIR']));
  tearDownAll(() => File(env['RUI_LAYOUT_OUT'] ?? 'build/flutter_layout.json')
      .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(results)));

  for (final c in cases) {
    testWidgets(c['name'], (tester) async {
      final size = c['size'] as List;
      tester.view.physicalSize = Size(num_(size[0])!, num_(size[1])!);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final errors = <String>[];
      final saved = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString().split('\n').first);
      final rects = <String, List<double>>{};
      try {
        await tester.pumpWidget(Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(data: const MediaQueryData(), child: build(c['tree'] as Map))));
        for (final node in walk(c['tree'] as Map)) {
          if (node['w'] == 'TableRow') continue;   // not a widget: its cells are compared
          final f = find.byKey(ValueKey<String>(node['id']), skipOffstage: false);
          if (f.evaluate().isEmpty) continue;
          final ro = tester.renderObject(f);
          if (ro is! RenderBox || !ro.hasSize) continue;
          final r = tester.getRect(f);
          rects[node['id']] = [r.left, r.top, r.width, r.height];
        }
      } catch (e) {
        errors.add(e.toString().split('\n').first);
      } finally {
        FlutterError.onError = saved;
      }
      final pending = tester.takeException();
      if (pending != null) errors.add(pending.toString().split('\n').first);
      results[c['name']] = {'rects': rects, 'errors': errors};
    });
  }
}
