import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Data Model สำหรับแกะโครงสร้าง JSON ของ Firestore REST API
class CarDocument {
  final String id;
  final Map<String, dynamic> fields;

  CarDocument({required this.id, required this.fields});

  factory CarDocument.fromJson(Map<String, dynamic> json) {
    final String fullPath = json['name'] ?? '';
    final String docId = fullPath.split('/').last;

    final Map<String, dynamic> rawFields = json['fields'] ?? {};
    final Map<String, dynamic> parsedFields = {};

    // แปลง Data Type ของ Firestore (stringValue, integerValue ฯลฯ) เป็นค่าปกติ
    rawFields.forEach((key, value) {
      parsedFields[key] = _parseFirestoreValue(value);
    });

    return CarDocument(id: docId, fields: parsedFields);
  }

  static dynamic _parseFirestoreValue(Map<String, dynamic> valueMap) {
    if (valueMap.containsKey('stringValue')) return valueMap['stringValue'];
    if (valueMap.containsKey('integerValue')) return int.tryParse(valueMap['integerValue'].toString());
    if (valueMap.containsKey('doubleValue')) return (valueMap['doubleValue'] as num).toDouble();
    if (valueMap.containsKey('booleanValue')) return valueMap['booleanValue'];
    if (valueMap.containsKey('timestampValue')) return valueMap['timestampValue'];
    if (valueMap.containsKey('arrayValue')) {
      final values = valueMap['arrayValue']['values'] as List<dynamic>?;
      return values?.map((e) => _parseFirestoreValue(e as Map<String, dynamic>)).toList() ?? [];
    }
    if (valueMap.containsKey('mapValue')) {
      final fields = valueMap['mapValue']['fields'] as Map<String, dynamic>?;
      final Map<String, dynamic> result = {};
      fields?.forEach((k, v) => result[k] = _parseFirestoreValue(v));
      return result;
    }
    return valueMap.toString();
  }
}

// ฟังก์ชันเรียก HTTP API
Future<CarDocument> fetchCarData() async {
  const String url =
      'https://firestore.googleapis.com/v1/projects/w11-c1f7d/databases/(default)/documents/wec_grid/car_12';

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final Map<String, dynamic> jsonBody = jsonDecode(response.body);
    return CarDocument.fromJson(jsonBody);
  } else {
    throw Exception('ไม่สามารถดึงข้อมูลได้ (Status Code: ${response.statusCode})');
  }
}

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firestore REST API',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const CarDetailApiScreen(),
    );
  }
}

class CarDetailApiScreen extends StatefulWidget {
  const CarDetailApiScreen({super.key});

  @override
  State<CarDetailApiScreen> createState() => _CarDetailApiScreenState();
}

class _CarDetailApiScreenState extends State<CarDetailApiScreen> {
  late Future<CarDocument> futureCarData;

  @override
  void initState() {
    super.initState();
    futureCarData = fetchCarData();
  }

  void _refresh() {
    setState(() {
      futureCarData = fetchCarData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Car 12 (REST API)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FutureBuilder<CarDocument>(
            future: futureCarData,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }

              if (snapshot.hasError) {
                return Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 8),
                        Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('ลองอีกครั้ง'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.hasData) {
                final car = snapshot.data!;
                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.directions_car, size: 40, color: Colors.blue),
                          title: Text('Document ID: ${car.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: const Text('Collection: wec_grid'),
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        ...car.fields.entries.map((entry) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('${entry.value}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }

              return const Text('ไม่พบข้อมูล');
            },
          ),
        ),
      ),
    );
  }
}