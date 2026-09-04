// import 'package:dio/dio.dart';
// import 'dart:convert';
// import 'lib/features/map/data/ola_maps_repository.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
//
// void main() async {
//   try {
//     await dotenv.load(fileName: ".env");
//   } catch (e) {
//     print('No .env file found');
//   }
//
//   final repo = OlaMapsRepository();
//   // Akola coordinates roughly: 20.7002, 77.0082
//   // Current location roughly: 20.6975, 77.0125
//   final route = await repo.getDirections(20.6975, 77.0125, 20.7002, 77.0082);
//
//   print('Distance: \${route['distance_meters']}');
//   print('Points length: \${(route['points'] as List).length}');
//   print('First point: \${(route['points'] as List).first}');
//   print('Polyline length: \${(route['polyline'] as String).length}');
// }
