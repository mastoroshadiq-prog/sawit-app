import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/sync_source_config.dart';

class ApiSop {
  static String get baseUrl => SyncSourceConfig.activeApiBaseUrl;

  static String _buildReadUrl(String route, String query) {
    if (SyncSourceConfig.useSupabase) {
      return '$baseUrl?r=$route&q=$query';
    }
    return '$baseUrl/wfs.jsp?r=$route&q=$query';
  }

  static Future<Map<String, dynamic>> getSopMaster({bool includeInactive = false}) async {
    final query = includeInactive ? 'all' : 'active';
    final url = Uri.parse(_buildReadUrl('apk.sop.master', query));
    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return {
          'success': true,
          'data': decoded,
        };
      }
      return {
        'success': false,
        'message': 'Format SOP master tidak valid',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Tidak dapat mengambil SOP master',
      };
    }
  }

  static Future<Map<String, dynamic>> getSopSteps({String sopId = ''}) async {
    final url = Uri.parse(_buildReadUrl('apk.sop.steps', sopId));
    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return {
          'success': true,
          'data': decoded,
        };
      }
      return {
        'success': false,
        'message': 'Format SOP step tidak valid',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Tidak dapat mengambil SOP step',
      };
    }
  }

  static Future<Map<String, dynamic>> getTaskSopMap({String spkNumber = ''}) async {
    final url = Uri.parse(_buildReadUrl('apk.sop.map', spkNumber));
    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return {
          'success': true,
          'data': decoded,
        };
      }
      return {
        'success': false,
        'message': 'Format mapping SOP tidak valid',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Tidak dapat mengambil mapping SOP',
      };
    }
  }
}

