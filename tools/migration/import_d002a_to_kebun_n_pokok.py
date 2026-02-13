import datetime as dt
import uuid

import pandas as pd
import psycopg2


EXCEL_PATH = "data_block/D002A.xlsx"
TARGET_BLOK = "D002A"

# Supabase connection (sesuai environment project saat ini)
DB_CONF = {
    "host": "aws-1-ap-southeast-1.pooler.supabase.com",
    "port": 5432,
    "dbname": "postgres",
    "user": "postgres.jofdimvnknmauvfeocyu",
    "password": "786@kebunApp",
    "sslmode": "require",
}


def map_kode(kelas: str) -> str:
    s = (kelas or "").strip().upper()
    if "BERAT" in s:
        return "SB"
    if "SEDANG" in s:
        return "SS"
    if "SEHAT" in s:
        return "SH"
    return "SS"


def map_tahun_to_date(v) -> dt.date:
    current = dt.date.today().year
    try:
        y = int(float(v))
        if y < 1900 or y > current + 1:
            y = 2009
    except Exception:
        y = 2009
    return dt.date(y, 1, 1)


def main() -> None:
    df = pd.read_excel(EXCEL_PATH)
    df.columns = [str(c).strip().upper() for c in df.columns]

    required = [
        "BLOK_BARU",
        "N_BARIS",
        "N_POKOK",
        "OBJECTID",
        "TAHUN_TANAM",
        "KELASNDRE",
    ]
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise RuntimeError(f"Kolom wajib tidak ditemukan: {missing}")

    w = df[required].copy()
    w = w.dropna(subset=["BLOK_BARU", "N_BARIS", "N_POKOK", "OBJECTID"])
    w["BLOK_BARU"] = w["BLOK_BARU"].astype(str).str.strip()

    # Fokus hanya blok target dari file
    w = w[w["BLOK_BARU"] == TARGET_BLOK]

    w["N_BARIS"] = pd.to_numeric(w["N_BARIS"], errors="coerce")
    w["N_POKOK"] = pd.to_numeric(w["N_POKOK"], errors="coerce")
    w["OBJECTID"] = pd.to_numeric(w["OBJECTID"], errors="coerce")
    w = w.dropna(subset=["N_BARIS", "N_POKOK", "OBJECTID"])

    w["N_BARIS"] = w["N_BARIS"].astype(int)
    w["N_POKOK"] = w["N_POKOK"].astype(int)
    w["OBJECTID"] = w["OBJECTID"].astype(int).astype(str)

    before = len(w)
    w = w.drop_duplicates(subset=["BLOK_BARU", "N_BARIS", "N_POKOK"], keep="first")
    after = len(w)

    now = dt.datetime.now()
    rows = []
    for _, r in w.iterrows():
        rows.append(
            (
                str(uuid.uuid4()).upper(),  # id_npokok
                r["OBJECTID"],  # id_tanaman
                "TM",  # id_tipe
                int(r["N_BARIS"]),
                int(r["N_POKOK"]),
                map_tahun_to_date(r["TAHUN_TANAM"]),
                "SYSTEM",  # petugas
                now,  # from_date
                None,  # thru_date
                TARGET_BLOK,  # catatan
                map_kode(str(r["KELASNDRE"])),  # kode
            )
        )

    conn = psycopg2.connect(**DB_CONF)
    cur = conn.cursor()
    try:
        # Replace penuh per blok agar konsisten
        cur.execute("delete from dbo.kebun_n_pokok where catatan = %s", (TARGET_BLOK,))

        insert_sql = """
            insert into dbo.kebun_n_pokok
            (id_npokok,id_tanaman,id_tipe,n_baris,n_pokok,tgl_tanam,petugas,from_date,thru_date,catatan,kode)
            values (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """
        cur.executemany(insert_sql, rows)

        # Upsert master blok
        cur.execute(
            """
            insert into dbo.mst_blok (blok_code, nama_blok, estate_code, divisi_code, is_active)
            values (%s, %s, %s, %s, true)
            on conflict (blok_code)
            do update set is_active = excluded.is_active
            """,
            (TARGET_BLOK, TARGET_BLOK, "AME II", "-"),
        )

        # Clone akses user dari D001A -> D002A (jika ada)
        cur.execute(
            """
            insert into dbo.map_petugas_blok (kode_unik, blok_code, can_inspect, from_date, thru_date)
            select kode_unik, %s, can_inspect, from_date, thru_date
            from dbo.map_petugas_blok
            where blok_code = %s
            on conflict (kode_unik, blok_code)
            do update set
              can_inspect = excluded.can_inspect,
              from_date = excluded.from_date,
              thru_date = excluded.thru_date
            """,
            (TARGET_BLOK, "D001A"),
        )

        cur.execute("select count(*) from dbo.kebun_n_pokok where catatan = %s", (TARGET_BLOK,))
        inserted_count = cur.fetchone()[0]

        conn.commit()
        print(f"Excel rows (clean): {before}")
        print(f"Rows after dedup: {after}")
        print(f"Inserted rows to dbo.kebun_n_pokok for {TARGET_BLOK}: {inserted_count}")
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()

