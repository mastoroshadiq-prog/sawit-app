import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/sync_source_config.dart';

class ApiAuth {
  //static const String baseUrlX = "https://aaa.com/auth";
  static String get baseUrl => SyncSourceConfig.activeApiBaseUrl;

  static String _buildReadUrl(String route, String query) {
    if (SyncSourceConfig.useSupabase) {
      return "$baseUrl?r=$route&q=$query";
    }
    return "$baseUrl/wfs.jsp?r=$route&q=$query";
  }


  /// Login user berdasarkan username & password
  static Future<Map<String, dynamic>> login(String username, String password) async {
    // Bentuk URL
    final url = Uri.parse(_buildReadUrl('autor', '$username,$password'));

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      //print("HASIL LOGIN: ${response.body}");
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);

          // Jika berhasil parsing dan berupa list dengan isi → login sukses
          if (data is List && data.isNotEmpty) {
            return {
              "success": true,
              "data": data[0], // asumsikan hanya 1 object user
            };
          } else {
            return {
              "success": false,
              "message": "Username atau password salah",
            };
          }
        } catch (e) {
          // Jika gagal decode JSON → kemungkinan error server seperti "index out of range -1"
          return {
            "success": false,
            "message": "Username atau password salah",
          };
        }
      } else {
        return {
          "success": false,
          "message": "Server error: ${response.statusCode}",
        };
      }
    } on http.ClientException {
      return {
        "success": false,
        "message": "Koneksi ke server gagal",
      };
    } on TimeoutException {
      return {
        "success": false,
        "message": "Login timeout, periksa jaringan lalu coba lagi",
      };
    } catch (e) {
      return {
        "success": false,
        "message": "Tidak dapat terhubung ke server",
      };
    }
  }
}
