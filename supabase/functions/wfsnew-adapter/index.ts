// @ts-nocheck
// Supabase Edge Function: legacy wfsnew.jsp adapter
// Compatible targets: ITE, IKP, IRP, IOB, IAL, ISPR
// Compatible query modes: ?j=<json>, ?r=<route>&q=<value>

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

type LegacyItem = {
  TARGET: string
  PARAMS: string
}

const NOOP_TARGETS = new Set(['UKP', 'URP'])

const jsonHeaders = {
  'Content-Type': 'application/json',
}

function diag(scope: string, detail: Record<string, unknown>) {
  try {
    console.log(`[wfsnew-adapter] ${scope} ${JSON.stringify(detail)}`)
  } catch {
    console.log(`[wfsnew-adapter] ${scope}`)
  }
}

function ok(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: jsonHeaders })
}

function fail(message: string, status = 400) {
  return new Response(message, { status })
}

function parseLegacyPayload(raw: string): LegacyItem[] {
  const parsed = JSON.parse(raw)
  if (!Array.isArray(parsed)) throw new Error('Payload harus array')
  return parsed as LegacyItem[]
}

function splitParams(raw: string): string[] {
  return raw.split(',').map((s) => s.trim())
}

function n(value: string | undefined): string | null {
  if (value == null) return null
  const v = value.trim()
  if (v.length === 0) return null
  return v
}

function tableByTarget(target: string): string | null {
  switch (target.toUpperCase()) {
    case 'ITE':
      return 'eksekusi'
    case 'IKP':
      return 'kesehatan'
    case 'IRP':
      return 'reposisi'
    case 'IOB':
      return 'observasi_tambahan'
    case 'IAL':
      return 'auditlog'
    case 'ISPR':
      return 'spr_log'
    default:
      return null
  }
}

function rowByTarget(target: string, paramRaw: string): Record<string, unknown> {
  const p = splitParams(paramRaw)
  switch (target.toUpperCase()) {
    case 'ITE':
      return {
        id: n(p[0]),
        spk_number: n(p[1]),
        task_name: n(p[2]),
        task_state: n(p[3]),
        petugas: n(p[4]),
        task_date: n(p[5]),
        keterangan: n(p[6]),
        image_path: n(p[7]),
        flag: 1,
      }
    case 'IKP':
      return {
        idKesehatan: n(p[0]),
        idTanaman: n(p[1]),
        statusAwal: n(p[2]),
        statusAkhir: n(p[3]),
        kodeStatus: n(p[4]),
        jenisPohon: n(p[5]),
        petugas: n(p[6]),
        flag: 1,
      }
    case 'IRP':
      return {
        idReposisi: n(p[0]),
        idTanaman: n(p[1]),
        pohonAwal: n(p[2]),
        barisAwal: n(p[3]),
        pohonTujuan: n(p[4]),
        barisTujuan: n(p[5]),
        tipeRiwayat: n(p[6]),
        keterangan: n(p[7]),
        petugas: n(p[8]),
        blok: n(p[9]),
        flag: 1,
      }
    case 'IOB':
      return {
        idObservasi: n(p[0]),
        idTanaman: n(p[1]),
        blok: n(p[2]),
        baris: n(p[3]),
        pohon: n(p[4]),
        kategori: n(p[5]),
        detail: n(p[6]),
        catatan: n(p[7]),
        petugas: n(p[8]),
        createdAt: n(p[9]),
        flag: 1,
      }
    case 'IAL':
      return {
        idAudit: n(p[0]),
        userId: n(p[1]),
        action: n(p[2]),
        detail: n(p[3]),
        logDate: n(p[4]),
        device: n(p[5]),
        flag: 1,
      }
    case 'ISPR':
      return {
        idLog: n(p[0]),
        blok: n(p[1]),
        baris: n(p[2]),
        sprAwal: n(p[3]),
        sprAkhir: n(p[4]),
        keterangan: n(p[5]),
        petugas: n(p[6]),
        flag: 1,
      }
    default:
      throw new Error(`TARGET tidak dikenali: ${target}`)
  }
}

async function handleLegacyRead(
  supabase: ReturnType<typeof createClient>,
  route: string,
  q: string,
) {
  const r = route.toLowerCase()
  diag('read.start', { route: r, q })

  if (r === 'autor') {
    const [username, password] = (q || '').split(',')

    // Prioritas 1: skema legacy lama (public.petugas)
    const legacy = await supabase
      .from('petugas')
      .select('*')
      .eq('akun', username)
      .eq('password', password)
      .limit(1)

    if (!legacy.error && (legacy.data?.length ?? 0) > 0) {
      return ok(legacy.data ?? [])
    }

    // Prioritas 2: hasil migrasi view (apk.v_apk_petugas)
    // Catatan: sebagian source lama tidak punya kolom password terpisah.
    const fallback = await supabase
      .schema('apk')
      .from('v_apk_petugas')
      .select('*')
      .eq('kode_unik', username)
      .limit(1)

    if (fallback.error) {
      return fail(`ERROR: ${fallback.error.message}`, 500)
    }

    const mapped = (fallback.data ?? []).map((x: Record<string, unknown>) => ({
      id_pihak: x.id_pihak,
      tipe: x.tipe,
      nama: x.nama,
      blok: x.blok,
      divisi: x.divisi,
      akun: x.kode_unik,
    }))

    return ok(mapped)
  }

  if (r === 'apk.task') {
    const primary = await supabase
      .schema('apk')
      .from('v_apk_assignment')
      .select('*')
      .eq('mandor', q)
    if (primary.error) return fail(`ERROR: ${primary.error.message}`, 500)
    if ((primary.data?.length ?? 0) > 0) return ok(primary.data ?? [])

    // Fallback-1: query langsung tabel SPK untuk mandor login
    const direct = await supabase
      .schema('dbo')
      .from('ops_spk_tindakan')
      .select('id_spk,nomor_spk,lokasi,mandor,uraian_pekerjaan,status')
      .eq('mandor', q)
      .eq('status', 'DISETUJUI')

    if (direct.error) return fail(`ERROR: ${direct.error.message}`, 500)

    const mapTask = (x: Record<string, unknown>) => ({
      id_task: x.id_spk,
      nomor_spk: x.nomor_spk,
      lokasi: x.lokasi,
      id_tanaman: null,
      nama_task: x.uraian_pekerjaan ?? 'TASK',
      nbaris: '0',
      blok: x.lokasi,
      divisi: '-',
      estate: '-',
      mandor: x.mandor,
      n_pokok: '0',
      maks_row: '0',
    })

    if ((direct.data?.length ?? 0) > 0) {
      return ok((direct.data ?? []).map((x: Record<string, unknown>) => mapTask(x)))
    }

    // Fallback-2: resolve akun login -> kandidat mandor real dari v_apk_petugas
    // (kasus akun uji/alias tidak punya task langsung)
    const me = await supabase
      .schema('apk')
      .from('v_apk_petugas')
      .select('kode_unik,blok,divisi,tipe')
      .eq('kode_unik', q)
      .limit(1)

    if (me.error) return fail(`ERROR: ${me.error.message}`, 500)
    const meRow = ((me.data ?? [])[0] as Record<string, unknown> | undefined)
    if (!meRow) {
      return ok([])
    }

    const blok = meRow['blok']?.toString() ?? ''
    const divisi = meRow['divisi']?.toString() ?? ''

    const peers = await supabase
      .schema('apk')
      .from('v_apk_petugas')
      .select('kode_unik,blok,divisi,tipe')
      .or(`blok.eq.${blok},divisi.eq.${divisi}`)

    if (peers.error) return fail(`ERROR: ${peers.error.message}`, 500)

    const candidates = new Set<string>()
    for (const row of (peers.data ?? []) as Array<Record<string, unknown>>) {
      const kode = row['kode_unik']?.toString() ?? ''
      const tipe = row['tipe']?.toString().toUpperCase() ?? ''
      if (kode.isEmpty) continue
      if (tipe == 'MANDOR' || tipe.isEmpty) {
        candidates.add(kode)
      }
    }

    if (candidates.isEmpty) return ok([])

    const peerTasks = await supabase
      .schema('dbo')
      .from('ops_spk_tindakan')
      .select('id_spk,nomor_spk,lokasi,mandor,uraian_pekerjaan,status')
      .in('mandor', Array.from(candidates))
      .eq('status', 'DISETUJUI')

    if (peerTasks.error) return fail(`ERROR: ${peerTasks.error.message}`, 500)

    const mapped = (peerTasks.data ?? []).map((x: Record<string, unknown>) => mapTask(x))
    if (mapped.length > 0) {
      return ok(mapped)
    }

    // Fallback-3 (darurat transisi): ambil mandor dengan task DISETUJUI terbanyak.
    // Ini mencegah initial sync mentok saat akun login belum terpetakan ke data assignment.
    const anyApproved = await supabase
      .schema('dbo')
      .from('ops_spk_tindakan')
      .select('id_spk,nomor_spk,lokasi,mandor,uraian_pekerjaan,status')
      .eq('status', 'DISETUJUI')

    if (anyApproved.error) return fail(`ERROR: ${anyApproved.error.message}`, 500)

    const rows = (anyApproved.data ?? []) as Array<Record<string, unknown>>
    if (rows.length == 0) return ok([])

    const perMandor = new Map<string, number>()
    for (const row of rows) {
      const mandor = row['mandor']?.toString() ?? ''
      if (!mandor || mandor.toLowerCase() === 'simulasi') continue
      perMandor.set(mandor, (perMandor.get(mandor) ?? 0) + 1)
    }

    let winner = ''
    let maxCount = -1
    for (const [m, c] of perMandor.entries()) {
      if (c > maxCount) {
        winner = m
        maxCount = c
      }
    }

    if (!winner) {
      // jika semua hanya simulasi, kembalikan apa adanya
      return ok(rows.map((x) => mapTask(x)))
    }

    return ok(rows.filter((x) => (x['mandor']?.toString() ?? '') === winner).map((x) => mapTask(x)))
  }

  if (r === 'blok.pohon' || r === 'sim.pohon') {
    // 1) Primary source: v_pohon_terkini by mandor
    const primary = await supabase
      .schema('apk')
      .from('v_pohon_terkini')
      .select('*')
      .eq('mandor', q)
    if (primary.error) return fail(`ERROR: ${primary.error.message}`, 500)
    diag('pohon.primary', {
      route: r,
      mandor: q,
      count: primary.data?.length ?? 0,
    })
    if ((primary.data?.length ?? 0) > 0) return ok(primary.data ?? [])

    // 2) Simulasi route: try dedicated view
    if (r === 'sim.pohon') {
      const simView = await supabase
        .schema('apk')
        .from('v_simulasi_pohon')
        .select('*')
      diag('pohon.simView', {
        route: r,
        count: simView.data?.length ?? 0,
        hasError: !!simView.error,
        error: simView.error?.message ?? null,
      })
      if (!simView.error && (simView.data?.length ?? 0) > 0) {
        return ok(simView.data ?? [])
      }
    }

    // 3) Fallback transisi: pakai mandor non-simulasi dengan data terbanyak
    const allRows = await supabase
      .schema('apk')
      .from('v_pohon_terkini')
      .select('*')
    if (allRows.error) return fail(`ERROR: ${allRows.error.message}`, 500)

    const rows = (allRows.data ?? []) as Array<Record<string, unknown>>
    diag('pohon.allRows', { route: r, count: rows.length })
    if (rows.length === 0) return ok([])

    const perMandor = new Map<string, number>()
    for (const row of rows) {
      const mandor = row['mandor']?.toString() ?? ''
      if (!mandor || mandor.toLowerCase() === 'simulasi') continue
      perMandor.set(mandor, (perMandor.get(mandor) ?? 0) + 1)
    }

    let winner = ''
    let maxCount = -1
    for (const [m, c] of perMandor.entries()) {
      if (c > maxCount) {
        winner = m
        maxCount = c
      }
    }

    if (!winner) return ok(rows)
    diag('pohon.fallbackWinner', {
      route: r,
      winner,
      winnerCount: maxCount,
      totalRows: rows.length,
    })
    return ok(rows.filter((x) => (x['mandor']?.toString() ?? '') === winner))
  }

  if (r === 'spk.pohon') {
    const { data, error } = await supabase
      .schema('apk')
      .from('v_pohon_terkini')
      .select('*')
      .eq('mandor', q)
    if (error) return fail(`ERROR: ${error.message}`, 500)
    return ok(data ?? [])
  }

  if (r === 'spr.blok') {
    const primary = await supabase
      .schema('dbo')
      .from('v_spr_terkini')
      .select('*')
      .eq('blok', q)
    if (primary.error) return fail(`ERROR: ${primary.error.message}`, 500)
    if ((primary.data?.length ?? 0) > 0) return ok(primary.data ?? [])

    // Fallback hitung SPR dari kebun_n_pokok bila stand_per_row belum terisi
    let raw = await supabase
      .schema('dbo')
      .from('kebun_n_pokok')
      .select('n_baris,catatan')
      .eq('catatan', q)

    if (raw.error) return fail(`ERROR: ${raw.error.message}`, 500)

    // Jika blok dari session login tidak punya data (contoh akun uji),
    // fallback ke data blok manapun agar initial sync tidak terhenti.
    if ((raw.data?.length ?? 0) === 0) {
      raw = await supabase
        .schema('dbo')
        .from('kebun_n_pokok')
        .select('n_baris,catatan')
        .not('catatan', 'is', null)

      if (raw.error) return fail(`ERROR: ${raw.error.message}`, 500)
    }

    const counts = new Map<string, number>()
    let resolvedBlock = q
    for (const row of raw.data ?? []) {
      const nb = row?.n_baris == null ? '' : String(row.n_baris)
      const blk = row?.catatan == null ? '' : String(row.catatan)
      if (!nb) continue
      if (!blk) continue
      if (!resolvedBlock) resolvedBlock = blk
      counts.set(nb, (counts.get(nb) ?? 0) + 1)
    }

    const mapped = Array.from(counts.entries()).map(([nbaris, jml]) => ({
      id_spr: crypto.randomUUID(),
      blok: resolvedBlock,
      nbaris: String(nbaris),
      spr_awal: String(jml),
      spr_akhir: String(jml),
    }))

    return ok(mapped)
  }

  return fail(`ERROR: route tidak didukung (${route})`, 404)
}

async function handleLegacySync(
  supabase: ReturnType<typeof createClient>,
  jPayload: string,
) {
  const items = parseLegacyPayload(jPayload)
  if (items.length === 0) return ok('[Berhasil]')

  for (const item of items) {
    const target = item.TARGET?.toUpperCase()

    if (NOOP_TARGETS.has(target)) {
      // Legacy compatibility: beberapa payload hanya marker/update lama.
      continue
    }

    const table = tableByTarget(target)
    if (!table) return fail(`ERROR: TARGET tidak didukung (${item.TARGET})`, 400)

    const row = rowByTarget(target, item.PARAMS ?? '')

    // upsert berdasarkan PK natural per target
    let onConflict = 'id'
    if (target === 'IKP') onConflict = 'idKesehatan'
    if (target === 'IRP') onConflict = 'idReposisi'
    if (target === 'IOB') onConflict = 'idObservasi'
    if (target === 'IAL') onConflict = 'idAudit'
    if (target === 'ISPR') onConflict = 'idLog'

    const { error } = await supabase.from(table).upsert(row, { onConflict })
    if (error) {
      return fail(`ERROR: ${error.message}`, 500)
    }
  }

  // Sengaja plaintext agar kompatibel parser legacy di mobile
  return new Response('[Berhasil Sinkronisasi]', { status: 200 })
}

Deno.serve(async (req) => {
  try {
    const supabaseUrl =
      Deno.env.get('EDGE_SUPABASE_URL') ?? Deno.env.get('SUPABASE_URL')
    const serviceRole =
      Deno.env.get('EDGE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    diag('boot.env', {
      hasSupabaseUrl: !!supabaseUrl,
      hasServiceRole: !!serviceRole,
    })
    if (!supabaseUrl || !serviceRole) {
      return fail(
        'ERROR: env EDGE_SUPABASE_URL/EDGE_SERVICE_ROLE_KEY belum di-set',
        500,
      )
    }

    const supabase = createClient(supabaseUrl, serviceRole)
    const url = new URL(req.url)

    // Mode legacy read: ?r=...&q=...
    const route = url.searchParams.get('r')
    const q = url.searchParams.get('q') ?? ''
    diag('request', { method: req.method, route, q })
    if (route) {
      return await handleLegacyRead(supabase, route, q)
    }

    // Mode legacy write/sync: ?j=...
    let jPayload = url.searchParams.get('j')
    if (!jPayload && req.method !== 'GET') {
      const bodyText = await req.text()
      if (bodyText) {
        try {
          const bodyJson = JSON.parse(bodyText)
          if (typeof bodyJson?.j === 'string') {
            jPayload = bodyJson.j
          } else if (Array.isArray(bodyJson)) {
            jPayload = JSON.stringify(bodyJson)
          }
        } catch {
          // no-op; fallback below
        }
      }
    }

    if (!jPayload) {
      return fail('ERROR: parameter j tidak ditemukan', 400)
    }

    return await handleLegacySync(supabase, jPayload)
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'Unknown error'
    return fail(`ERROR: ${msg}`, 500)
  }
})

