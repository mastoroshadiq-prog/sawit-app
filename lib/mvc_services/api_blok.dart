import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/sync_source_config.dart';

class ApiBlok {
  static String get baseUrl => SyncSourceConfig.activeApiBaseUrl;

  static String _buildReadUrl(String route, String query) {
    if (SyncSourceConfig.useSupabase) {
      return "$baseUrl?r=$route&q=$query";
    }
    return "$baseUrl/wfs.jsp?r=$route&q=$query";
  }

  static Future<Map<String, dynamic>> getBlokList(String username) async {
    final url = Uri.parse(_buildReadUrl('blok.list', username));

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return {
            'success': true,
            'data': data,
          };
        }
        return {
          'success': false,
          'message': 'Format data blok tidak valid',
        };
      }

      return {
        'success': false,
        'message': 'Server error: ${response.statusCode}',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Tidak dapat terhubung ke server',
      };
    }
  }
}

