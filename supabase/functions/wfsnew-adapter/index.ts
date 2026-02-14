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

function b(value: string | undefined): boolean {
  const v = (value ?? '').trim().toLowerCase()
  return v === '1' || v === 'true' || v === 't' || v === 'y' || v === 'yes'
}

function sopConflictByTarget(target: string): string | null {
  switch (target.toUpperCase()) {
    case 'ISOPM':
      return 'sop_id'
    case 'ISOPS':
      return 'step_id'
    case 'ITSM':
      return 'map_id'
    case 'ITSC':
      return 'check_id'
    default:
      return null
  }
}

function sopTableByTarget(target: string): string | null {
  switch (target.toUpperCase()) {
    case 'ISOPM':
      return 'sop_master'
    case 'ISOPS':
      return 'sop_step'
    case 'ITSM':
      return 'task_sop_map'
    case 'ITSC':
      return 'task_sop_check'
    default:
      return null
  }
}

function sopRowByTarget(target: string, paramRaw: string): Record<string, unknown> {
  const p = splitParams(paramRaw)
  switch (target.toUpperCase()) {
    case 'ISOPM':
      return {
        sop_id: n(p[0]),
        sop_code: n(p[1]),
        sop_name: n(p[2]),
        sop_version: n(p[3]) ?? '1.0',
        task_keyword: n(p[4]) ?? '',
        is_active: b(p[5]),
        updated_at: n(p[6]) ?? new Date().toISOString(),
      }
    case 'ISOPS':
      return {
        step_id: n(p[0]),
        sop_id: n(p[1]),
        step_order: Number(n(p[2]) ?? '0'),
        step_title: n(p[3]),
        is_required: b(p[4]),
        evidence_type: n(p[5]) ?? 'none',
        is_active: b(p[6]),
        updated_at: n(p[7]) ?? new Date().toISOString(),
      }
    case 'ITSM':
      return {
        map_id: n(p[0]),
        sop_id: n(p[1]),
        assignment_id: n(p[2]),
        spk_number: n(p[3]),
        source_type: n(p[4]) ?? 'server',
        is_active: b(p[5]),
        updated_at: n(p[6]) ?? new Date().toISOString(),
      }
    case 'ITSC':
      return {
        check_id: n(p[0]),
        execution_id: n(p[1]),
        assignment_id: n(p[2]),
        spk_number: n(p[3]),
        sop_id: n(p[4]),
        step_id: n(p[5]),
        is_checked: Number(n(p[6]) ?? '0'),
        note: n(p[7]),
        evidence_path: n(p[8]),
        checked_at: n(p[9]) ?? new Date().toISOString(),
        flag: Number(n(p[10]) ?? '1'),
      }
    default:
      throw new Error(`TARGET SOP tidak dikenali: ${target}`)
  }
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
        idkesehatan: n(p[0]),
        idtanaman: n(p[1]),
        statusawal: n(p[2]),
        statusakhir: n(p[3]),
        kodestatus: n(p[4]),
        jenispohon: n(p[5]),
        petugas: n(p[6]),
        flag: 1,
      }
    case 'IRP':
      return {
        idreposisi: n(p[0]),
        idtanaman: n(p[1]),
        pohonawal: n(p[2]),
        barisawal: n(p[3]),
        pohontujuan: n(p[4]),
        baristujuan: n(p[5]),
        tiperiwayat: n(p[6]),
        keterangan: n(p[7]),
        petugas: n(p[8]),
        blok: n(p[9]),
        flag: 1,
      }
    case 'IOB':
      return {
        idobservasi: n(p[0]),
        idtanaman: n(p[1]),
        blok: n(p[2]),
        baris: n(p[3]),
        pohon: n(p[4]),
        kategori: n(p[5]),
        detail: n(p[6]),
        catatan: n(p[7]),
        petugas: n(p[8]),
        createdat: n(p[9]),
        flag: 1,
      }
    case 'IAL':
      return {
        idaudit: n(p[0]),
        userid: n(p[1]),
        action: n(p[2]),
        detail: n(p[3]),
        logdate: n(p[4]),
        device: n(p[5]),
        flag: 1,
      }
    case 'ISPR':
      return {
        idlog: n(p[0]),
        blok: n(p[1]),
        baris: n(p[2]),
        sprawal: n(p[3]),
        sprakhir: n(p[4]),
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

  if (r === 'blok.list') {
    // q: akun/kode_unik petugas
    const kodeUnik = (q ?? '').trim()
    if (kodeUnik.length === 0) return ok([])

    const mapped = await supabase
      .schema('apk')
      .from('v_apk_petugas_blok')
      .select('blok_code,nama_blok,estate,divisi')
      .eq('kode_unik', kodeUnik)
      .order('blok_code', { ascending: true })

    if (mapped.error) {
      return fail(`ERROR: ${mapped.error.message}`, 500)
    }

    if ((mapped.data?.length ?? 0) > 0) {
      const payload = (mapped.data ?? []).map((x: Record<string, unknown>) => ({
        blok: x.blok_code,
        blok_name: x.nama_blok,
        estate: x.estate,
        divisi: x.divisi,
      }))
      return ok(payload)
    }

    // fallback: single blok dari profile petugas
    const profile = await supabase
      .schema('apk')
      .from('v_apk_petugas')
      .select('blok,divisi')
      .eq('kode_unik', kodeUnik)
      .limit(1)

    if (profile.error) {
      return fail(`ERROR: ${profile.error.message}`, 500)
    }

    const p = ((profile.data ?? [])[0] as Record<string, unknown> | undefined)
    if (!p) return ok([])

    const fallbackBlok = p['blok']?.toString() ?? ''
    if (!fallbackBlok) return ok([])

    return ok([
      {
        blok: fallbackBlok,
        blok_name: fallbackBlok,
        estate: '-',
        divisi: p['divisi']?.toString() ?? '-',
      },
    ])
  }

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
      if (kode.length === 0) continue
      if (tipe == 'MANDOR' || tipe.length === 0) {
        candidates.add(kode)
      }
    }

    if (candidates.size === 0) return ok([])

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

  if (r === 'apk.sop.master') {
    const onlyActive = (q ?? '').trim().toLowerCase() !== 'all'
    let query = supabase
      .from('sop_master')
      .select('sop_id,sop_code,sop_name,sop_version,task_keyword,is_active,updated_at')
      .order('sop_code', { ascending: true })

    if (onlyActive) {
      query = query.eq('is_active', true)
    }

    const { data, error } = await query
    if (error) return fail(`ERROR: ${error.message}`, 500)

    const mapped = (data ?? []).map((x: Record<string, unknown>) => ({
      sopId: x.sop_id,
      sopCode: x.sop_code,
      sopName: x.sop_name,
      sopVersion: x.sop_version,
      taskKeyword: x.task_keyword,
      isActive: x.is_active === true ? 1 : 0,
      updatedAt: x.updated_at,
    }))
    return ok(mapped)
  }

  if (r === 'apk.sop.steps') {
    const sopId = (q ?? '').trim()
    let query = supabase
      .from('sop_step')
      .select('step_id,sop_id,step_order,step_title,is_required,evidence_type,is_active,updated_at')
      .order('step_order', { ascending: true })

    if (sopId.length > 0) {
      query = query.eq('sop_id', sopId)
    }

    const { data, error } = await query
    if (error) return fail(`ERROR: ${error.message}`, 500)

    const mapped = (data ?? []).map((x: Record<string, unknown>) => ({
      stepId: x.step_id,
      sopId: x.sop_id,
      stepOrder: x.step_order,
      stepTitle: x.step_title,
      isRequired: x.is_required === true ? 1 : 0,
      evidenceType: x.evidence_type,
      isActive: x.is_active === true ? 1 : 0,
      updatedAt: x.updated_at,
    }))
    return ok(mapped)
  }

  if (r === 'apk.sop.map') {
    const spk = (q ?? '').trim()
    let query = supabase
      .from('task_sop_map')
      .select('map_id,sop_id,assignment_id,spk_number,source_type,is_active,updated_at')
      .eq('is_active', true)
      .order('updated_at', { ascending: false })

    if (spk.length > 0) {
      query = query.eq('spk_number', spk)
    }

    const { data, error } = await query
    if (error) return fail(`ERROR: ${error.message}`, 500)

    const mapped = (data ?? []).map((x: Record<string, unknown>) => ({
      mapId: x.map_id,
      sopId: x.sop_id,
      assignmentId: x.assignment_id,
      spkNumber: x.spk_number,
      sourceType: x.source_type,
      isActive: x.is_active === true ? 1 : 0,
      updatedAt: x.updated_at,
    }))
    return ok(mapped)
  }

  if (r === 'blok.pohon.byblok') {
    const blockCode = (q ?? '').trim()
    if (blockCode.length === 0) return ok([])

    const byBlok = await supabase
      .schema('apk')
      .from('v_pohon_terkini')
      .select('*')
      .eq('blok', blockCode)

    if (byBlok.error) return fail(`ERROR: ${byBlok.error.message}`, 500)
    if ((byBlok.data?.length ?? 0) > 0) return ok(byBlok.data ?? [])

    // fallback source kebun_n_pokok untuk transisi data
    const raw = await supabase
      .schema('dbo')
      .from('kebun_n_pokok')
      .select('catatan,n_baris,n_pokok,id_tanaman')
      .eq('catatan', blockCode)

    if (raw.error) return fail(`ERROR: ${raw.error.message}`, 500)

    const mapped = (raw.data ?? []).map((x: Record<string, unknown>) => ({
      blok: x.catatan,
      nbaris: x.n_baris == null ? '' : String(x.n_baris),
      npohon: x.n_pokok == null ? '' : String(x.n_pokok),
      objectid: x.id_tanaman == null
        ? `${String(x.catatan ?? '')}-${String(x.n_baris ?? '')}-${String(x.n_pokok ?? '')}`
        : String(x.id_tanaman),
      status: '1',
      nflag: '0',
      mandor: '-',
    }))

    return ok(mapped)
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

    // Extension Tahap 2: SOP + checklist execution
    const sopTable = sopTableByTarget(target)
    if (sopTable) {
      const row = sopRowByTarget(target, item.PARAMS ?? '')
      const onConflict = sopConflictByTarget(target)
      if (!onConflict) return fail(`ERROR: onConflict TARGET SOP tidak ditemukan (${item.TARGET})`, 400)

      const { error } = await supabase.from(sopTable).upsert(row, { onConflict })
      if (error) {
        return fail(`ERROR: ${error.message}`, 500)
      }
      continue
    }

    const table = tableByTarget(target)
    if (!table) return fail(`ERROR: TARGET tidak didukung (${item.TARGET})`, 400)

    const row = rowByTarget(target, item.PARAMS ?? '')

    // upsert berdasarkan PK natural per target
    let onConflict = 'id'
    if (target === 'IKP') onConflict = 'idkesehatan'
    if (target === 'IRP') onConflict = 'idreposisi'
    if (target === 'IOB') onConflict = 'idobservasi'
    if (target === 'IAL') onConflict = 'idaudit'
    if (target === 'ISPR') onConflict = 'idlog'

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

