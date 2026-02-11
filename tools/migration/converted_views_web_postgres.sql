-- Auto-generated converted PostgreSQL VIEW DDL from SQL Server schema web
CREATE SCHEMA IF NOT EXISTS web;
-- Ordered by dependency when possible (within same schema)

-- Source view: web.v_web_pihak
CREATE OR REPLACE VIEW web.v_web_pihak AS
SELECT a.* FROM dbo.master_pihak a
;

-- Source view: web.vw_pohon_terkini
CREATE OR REPLACE VIEW web.vw_pohon_terkini AS
SELECT
	a.kode_ancak, 
	a.kode_blok AS BLOK, a.id_pohon AS OBJECTID, 
	a.nomor_pohon, a.baris_pohon, a.p_flag, 
	a.nomor_terkini, a.baris_terkini AS NBARIS,
	ROW_NUMBER() OVER (
        PARTITION BY a.baris_terkini
        ORDER BY a.nomor_terkini, a.p_flag DESC
    ) AS NPOHON,
    'RIWAYAT' AS kategori,
    a.kode, a.STATUS, a.kondisi,
    a.p_flag AS NFLAG
FROM dbo.v_pohon_terkini a
;
