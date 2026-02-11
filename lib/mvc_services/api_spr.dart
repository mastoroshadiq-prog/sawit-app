import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/sync_source_config.dart';

class ApiSPR {
  //static const String baseUrlX = "https://aaa.com/auth";
  static String get baseUrl => SyncSourceConfig.activeApiBaseUrl;

  static Future<Map<String, dynamic>> getSprBlok(String blok) async {
    // Bentuk URL
    //final url = Uri.parse("$baseUrl/wfs.jsp?r=spk.pohon&q=$username");
    Uri url = Uri.parse("$baseUrl/wfs.jsp?r=spr.blok&q=$blok");
    try {
      final response = await http.get(url);
      //print('pohon:$data');
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          //print('SPR: ${response.body}');
          // Jika berhasil parsing dan berupa list dengan isi → login sukses
          if (data is List && data.isNotEmpty) {
            return {
              "success": true,
              "data": data,
            };
          } else {
            return {
              "success": false,
              "message": "Data Pohon tidak ditemukan",
            };
          }
        } catch (e) {
          // Jika gagal decode JSON → kemungkinan error server seperti "index out of range -1"
          return {
            "success": false,
            "message": "Data Pohon tidak ditemukan",
          };
        }
      } else {
        return {
          "success": false,
          "message": "Server error: ${response.statusCode}",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "message": "Tidak dapat terhubung ke server",
      };
    }
  }
}
