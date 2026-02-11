enum SyncSource {
  sqlserver,
  supabase,
}

class SyncSourceConfig {
  static const String _rawSource = String.fromEnvironment(
    'SYNC_SOURCE',
    defaultValue: 'sqlserver',
  );

  static SyncSource get source =>
      _rawSource.toLowerCase() == 'supabase' ? SyncSource.supabase : SyncSource.sqlserver;

  static bool get useSupabase => source == SyncSource.supabase;

  static String get sourceLabel => useSupabase ? 'supabase' : 'sqlserver';

  /// Base URL lama (SQL Server endpoint JSP)
  static const String sqlApiBaseUrl = String.fromEnvironment(
    'SQLSERVER_BASE_URL',
    defaultValue: 'http://13.67.47.76/bbn',
  );

  /// Base URL baru (Supabase / Edge Function / API gateway)
  static const String supabaseApiBaseUrl = String.fromEnvironment(
    'SUPABASE_API_BASE_URL',
    defaultValue: '',
  );

  /// Endpoint sinkronisasi payload batch (?j=...)
  static const String sqlSyncPostUrl = String.fromEnvironment(
    'SQLSERVER_SYNC_POST_URL',
    defaultValue: 'http://13.67.47.76/kebun/wfsnew.jsp',
  );

  static const String supabaseSyncPostUrl = String.fromEnvironment(
    'SUPABASE_SYNC_POST_URL',
    defaultValue: '',
  );

  static String get activeApiBaseUrl => useSupabase ? supabaseApiBaseUrl : sqlApiBaseUrl;

  static String get activeSyncPostUrl => useSupabase ? supabaseSyncPostUrl : sqlSyncPostUrl;

  static bool get hasRequiredConfig =>
      !useSupabase || (supabaseApiBaseUrl.isNotEmpty && supabaseSyncPostUrl.isNotEmpty);
}

