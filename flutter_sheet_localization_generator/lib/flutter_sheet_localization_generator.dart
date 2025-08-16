import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/element/element2.dart';
import 'package:csv/csv.dart';
import 'package:flutter_sheet_localization/flutter_sheet_localization.dart';
import 'package:localization_builder/localization_builder.dart';
import 'package:source_gen/source_gen.dart';
import 'package:build/build.dart';
import 'package:http/http.dart' as http;

class SheetLocalizationGenerator
    extends GeneratorForAnnotation<SheetLocalization> {
  const SheetLocalizationGenerator();

  @override
  FutureOr<String> generateForAnnotatedElement(
      Element2 element, ConstantReader annotation, BuildStep buildStep) async {
    if (element is! ClassElement2) {
      throw InvalidGenerationSourceError('Generator cannot target `${element.displayName}`.',
          todo: 'Remove the SheetLocalization annotation from `${element.displayName}`.',
          element: element);
    }

    if (!element.displayName.endsWith('Delegate')) {
      final name = element.displayName;
      throw InvalidGenerationSourceError(
          'Generator for target `$name` should have a name that ends with `Delegate`.',
          todo:
              'Refactor the class name `$name` for a name ending with `Delegate` (example: `${name}Delegate`).',
          element: element);
    }

    final name = '${element.displayName.replaceAll('Delegate', '')}Data';
    final docId = annotation.objectValue.getField('docId')!.toStringValue();
    final sheetId = annotation.objectValue.getField('sheetId')!.toStringValue();
    var localizations = await _downloadGoogleSheet(
      docId!,
      sheetId!,
      name,
    );
    final builder = DartLocalizationBuilder();
    final code = StringBuffer();
    code.writeln(builder.build(localizations));
    return code.toString();
  }

  Future<Localizations> _downloadGoogleSheet(
      String documentId, String sheetId, String name) async {
    final url =
        'https://docs.google.com/spreadsheets/d/$documentId/export?format=csv&id=$documentId&gid=$sheetId';

    print('Downloading csv from Google sheet url "$url" ...');

    var response = await http
        .get(Uri.parse(url), headers: {'accept': 'text/csv;charset=UTF-8'});

    print('Google sheet csv:\n ${response.body}');

    final bytes = response.bodyBytes.toList();
    final csv = Stream<List<int>>.fromIterable([bytes]);
    final rows = await csv
        .transform(utf8.decoder)
        .transform(CsvToListConverter(
          shouldParseNumbers: false,
        ))
        .toList();
    final parser = CsvLocalizationParser();
    final result = parser.parse(input: rows, name: name);
    return result.result;
  }
}
