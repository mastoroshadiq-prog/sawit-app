import json
import re
from pathlib import Path

import importlib.util


def load_module(path: Path, module_name: str):
    spec = importlib.util.spec_from_file_location(module_name, str(path))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def extract_dao_tables(dart_text: str):
    tables = set()
    # Matches db.query('table'), db.insert('table'), db.update('table'), db.delete('table')
    for m in re.finditer(r"\b(?:query|insert|update|delete)\s*\(\s*'([^']+)'", dart_text):
        tables.add(m.group(1))
    return tables


def main():
    root = Path('.')
    cfg = json.loads((root / 'tools/migration/config.json').read_text(encoding='utf-8'))

    migr = load_module(root / 'tools/migration/sqlserver_to_supabase.py', 'migr')

    src = migr.connect_sqlserver(cfg)
    dst = migr.connect_postgres(cfg)
    try:
        pg_tables = migr.fetch_tables_postgres(dst)
        src_tables = set(migr.fetch_tables_sqlserver(src, cfg.get('auto_tables', {}).get('include_schemas')))
    finally:
        src.close()
        dst.close()

    # SQLite/DAO-level table usage as a proxy of app sync surface
    lib_dir = root / 'lib'
    dao_tables = set()
    for p in lib_dir.rglob('*.dart'):
        txt = p.read_text(encoding='utf-8', errors='ignore')
        if '/mvc_dao/' in str(p).replace('\\', '/') or '/screens/sync/' in str(p).replace('\\', '/'):
            dao_tables.update(extract_dao_tables(txt))

    # Missing dependencies from view migration
    missing_dep_file = root / 'tools/migration/view_missing_dependencies.json'
    missing_deps = {}
    if missing_dep_file.exists():
        missing_deps = json.loads(missing_dep_file.read_text(encoding='utf-8'))

    # Check expected source tables existence in postgres by schema mapping
    schema_map = cfg.get('auto_tables', {}).get('schema_mapping', {})
    expected_in_pg = set()
    for s, t in src_tables:
        expected_in_pg.add((schema_map.get(s, s), t))

    missing_expected = sorted([f"{s}.{t}" for (s, t) in expected_in_pg if (s, t) not in pg_tables])

    # DAO coverage in postgres (any schema)
    pg_table_names = {t for _, t in pg_tables}
    dao_missing = sorted([t for t in dao_tables if t not in pg_table_names])

    report = {
        'supabase_table_count': len(pg_tables),
        'source_table_count': len(src_tables),
        'expected_tables_missing_in_supabase_count': len(missing_expected),
        'expected_tables_missing_in_supabase_sample': missing_expected[:80],
        'dao_detected_table_count': len(dao_tables),
        'dao_tables_missing_in_supabase_count': len(dao_missing),
        'dao_tables_missing_in_supabase': dao_missing,
        'view_missing_dependency_items': len(missing_deps),
        'view_missing_dependencies': missing_deps,
    }

    out_json = root / 'tools/migration/supabase_readiness_report.json'
    out_md = root / 'tools/migration/supabase_readiness_report.md'
    out_json.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')

    lines = []
    lines.append('# Supabase Readiness Report')
    lines.append('')
    lines.append(f"- Supabase tables: **{report['supabase_table_count']}**")
    lines.append(f"- Source SQL Server tables: **{report['source_table_count']}**")
    lines.append(f"- Expected (mapped) tables missing in Supabase: **{report['expected_tables_missing_in_supabase_count']}**")
    lines.append(f"- DAO-detected table names: **{report['dao_detected_table_count']}**")
    lines.append(f"- DAO table names missing in Supabase: **{report['dao_tables_missing_in_supabase_count']}**")
    lines.append(f"- View dependency unresolved items: **{report['view_missing_dependency_items']}**")
    lines.append('')
    lines.append('## Missing expected tables (sample)')
    for x in report['expected_tables_missing_in_supabase_sample']:
        lines.append(f"- {x}")
    lines.append('')
    lines.append('## DAO table names missing in Supabase')
    for x in report['dao_tables_missing_in_supabase']:
        lines.append(f"- {x}")
    lines.append('')
    lines.append('## View missing dependencies')
    for k, deps in report['view_missing_dependencies'].items():
        lines.append(f"- {k}")
        for d in deps:
            lines.append(f"  - {d}")

    out_md.write_text('\n'.join(lines), encoding='utf-8')
    print('generated tools/migration/supabase_readiness_report.json')
    print('generated tools/migration/supabase_readiness_report.md')


if __name__ == '__main__':
    main()

