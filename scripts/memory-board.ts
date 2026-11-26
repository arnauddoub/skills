#!/usr/bin/env bun
// The Mac's memory: pressure as macOS reports it, swap in use, and the apps holding the most, each counted with all its
// processes. bun memory-board.ts [--seconds 5]

const arg = (name: string) => {
  const i = process.argv.indexOf(`--${name}`)
  return i > 0 ? process.argv[i + 1] : undefined
}
const REFRESH_MS = Number(arg('seconds') ?? 5) * 1000

const c = {
  reset: '\x1b[0m', bold: '\x1b[1m', dim: '\x1b[2m',
  red: '\x1b[31m', green: '\x1b[32m', yellow: '\x1b[33m', blue: '\x1b[34m', cyan: '\x1b[36m', magenta: '\x1b[35m',
}
const visible = (s: string) => s.replace(/\x1b\[[0-9;]*m/g, '').length
const clip = (s: string, n: number) => (n <= 0 ? '' : s.length > n ? `${s.slice(0, Math.max(0, n - 1))}…` : s)
const pad = (s: string, n: number) => s + ' '.repeat(Math.max(0, n - visible(s)))
const tone = (pct: number) => (pct >= 80 ? c.red : pct >= 50 ? c.yellow : c.green)
const rgb = (r: number, g: number, b: number) => `\x1b[38;2;${r};${g};${b}m`
const fill = (pct: number) => (pct >= 80 ? rgb(239, 83, 80) : pct >= 50 ? rgb(240, 180, 60) : rgb(74, 136, 232))
const bar = (pct: number, size: number, color = fill(pct)) => {
  const halves = Math.round((Math.min(100, Math.max(0, pct)) / 100) * size * 2)
  const full = Math.floor(halves / 2)
  const half = halves % 2 ? '╸' : ''
  return `${color}${'━'.repeat(full)}${half}${c.reset}${rgb(58, 62, 70)}${'━'.repeat(size - full - (half ? 1 : 0))}${c.reset}`
}
const gb = (bytes: number) => `${(bytes / 2 ** 30).toFixed(1)} GB`

function box(title: string, color: string, count: string, lines: string[], width: number) {
  const inner = width - 4
  const head = `${color}┌ ${c.bold}${title}${c.reset}${color} ${count ? `${'─'.repeat(Math.max(1, width - visible(title) - visible(count) - 6))} ${c.reset}${count}${color} ` : '─'.repeat(Math.max(1, width - visible(title) - 4))}┐${c.reset}`
  const body = lines.map((l) => `${color}│${c.reset} ${pad(l, inner)} ${color}│${c.reset}`)
  return [head, ...body, `${color}└${'─'.repeat(width - 2)}┘${c.reset}`]
}

const run = async (cmd: string[]) => {
  const p = Bun.spawn(cmd, { stdout: 'pipe', stderr: 'ignore' })
  const [out] = await Promise.all([new Response(p.stdout).text(), p.exited])
  return out
}

type App = { name: string; bytes: number; count: number }
type Snapshot = { total: number; pressure: number; swapUsed: number; swapTotal: number; apps: App[] }

// "Google Chrome Helper (Renderer)" lives in Google Chrome.app: an app is counted with every process inside its bundle.
const appOf = (comm: string) => comm.match(/([^/]+)\.app\//)?.[1] ?? comm.split('/').pop() ?? comm

async function snapshot(): Promise<Snapshot> {
  const [total, level, swap, ps] = await Promise.all([
    run(['sysctl', '-n', 'hw.memsize']),
    run(['sysctl', '-n', 'kern.memorystatus_level']),
    run(['sysctl', '-n', 'vm.swapusage']),
    run(['ps', '-axo', 'rss=,comm=']),
  ])
  const mb = (key: string) => Number(swap.match(new RegExp(`${key} = ([\\d.]+)M`))?.[1] ?? 0) * 2 ** 20
  const apps = new Map<string, App>()
  for (const line of ps.split('\n')) {
    const m = line.trim().match(/^(\d+)\s+(.+)$/)
    if (!m) continue
    const name = appOf(m[2])
    const app = apps.get(name) ?? { name, bytes: 0, count: 0 }
    app.bytes += Number(m[1]) * 1024
    app.count++
    apps.set(name, app)
  }
  return {
    total: Number(total),
    pressure: 100 - Number(level),
    swapUsed: mb('used'),
    swapTotal: mb('total'),
    apps: [...apps.values()].sort((a, b) => b.bytes - a.bytes),
  }
}

let data: Snapshot | undefined
let updated = ''

function render() {
  const width = Math.min(process.stdout.columns || 80, 80)
  const inner = width - 4
  const out: string[] = []
  if (data) {
    const swapPct = data.swapTotal ? (data.swapUsed / data.swapTotal) * 100 : 0
    const size = Math.max(6, inner - 9 - 11)
    out.push(...box('Memory', c.cyan, gb(data.total), [
      `${pad('Pressure', 9)}${bar(data.pressure, size)} ${tone(data.pressure)}${String(Math.round(data.pressure)).padStart(9)}%${c.reset}`,
      `${pad('Swap', 9)}${bar(swapPct, size)} ${tone(swapPct)}${`${(data.swapUsed / 2 ** 30).toFixed(1)}/${gb(data.swapTotal)}`.padStart(10)}${c.reset}`,
    ], width), '')

    const rows = Math.min(8, Math.max(3, (process.stdout.rows || 30) - out.length - 5))
    const top = data.apps.slice(0, rows)
    const rest = data.apps.slice(rows).reduce((sum, a) => sum + a.bytes, 0)
    const largest = top[0]?.bytes || 1
    const nameWidth = Math.max(10, Math.min(22, inner - 30))
    const lines = top.map((a) => {
      const name = clip(a.name === 'claude' ? `Claude ×${a.count}` : a.name, nameWidth)
      const share = (a.bytes / data!.total) * 100
      return `${pad(name, nameWidth)} ${bar((a.bytes / largest) * 100, Math.max(4, inner - nameWidth - 14), rgb(74, 136, 232))} ${gb(a.bytes).padStart(7)} ${c.dim}${String(Math.round(share)).padStart(3)}%${c.reset}`
    })
    lines.push(`${c.dim}${pad('others', nameWidth)} ${' '.repeat(Math.max(4, inner - nameWidth - 14))} ${gb(rest).padStart(7)} ${String(Math.round((rest / data.total) * 100)).padStart(3)}%${c.reset}`)
    out.push(...box('Apps', c.blue, '', lines, width), '')
  }
  out.push(`${c.dim}${updated || '…'} · q${c.reset}`)
  process.stdout.write(`\x1b[H\x1b[2J${out.join('\n')}`)
}

async function refresh() {
  data = await snapshot()
  updated = new Date().toTimeString().slice(0, 8)
  render()
}

process.stdout.write('\x1b[?1049h\x1b[?25l')
process.stdin.setRawMode(true)
process.stdin.resume()
process.stdin.on('data', (buf) => {
  const k = buf.toString()
  if (k === 'q' || k === '\x03') {
    process.stdout.write('\x1b[?25h\x1b[?1049l')
    process.exit(0)
  }
})
process.stdout.on('resize', render)
setInterval(refresh, REFRESH_MS)
refresh()
