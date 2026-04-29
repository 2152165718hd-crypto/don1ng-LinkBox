import 'dart:convert';
import 'dart:typed_data';

import 'package:don1ng_linkbox/storage/models.dart';
import 'package:don1ng_linkbox/thing_model/thing_model_importer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('imports valid OneNET TSL properties and skips invalid nodes', () async {
    final jsonText = jsonEncode({
      'version': '1.0',
      'properties': [
        {
          'identifier': 'Temp',
          'name': '温度',
          'accessMode': 'rw',
          'dataType': {
            'type': 'int32',
            'specs': {'min': '0', 'max': '100', 'unit': '°C'},
          },
        },
        {
          'identifier': '1Bad',
          'name': 'bad',
          'dataType': {'type': 'float'},
        },
      ],
    });

    final result = await ThingModelImporter()
        .importBytes(Uint8List.fromList(utf8.encode(jsonText)));

    expect(result.properties, hasLength(1));
    expect(result.properties.first.identifier, 'Temp');
    expect(result.properties.first.name, '温度');
    expect(result.properties.first.type, ThingDataType.int32);
    expect(result.properties.first.accessMode, AccessMode.readWrite);
    expect(result.skipped, hasLength(1));
  });
}
