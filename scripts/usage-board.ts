#!/usr/bin/env bun
// Claude usage across the running sessions: the account's 5-hour and 7-day limits, then each live session's
// context, cost and state. Reads what statusline.sh saves in ~/.claude/state/statusline/<session>.json.
import { readdirSync, readFileSync } from 'node:fs'

const HOME = process.env.HOME!
const LINES = `${HOME}/.claude/state/statusline`
const PIDS = `${HOME}/.claude/sessions`
const SESSION = process.env.REX_SESSION

const c = {
  reset: '\x1b[0m', bold: '\x1b[1m', dim: '\x1b[2m',
  red: '\x1b[31m', green: '\x1b[32m', yellow: '\x1b[33m', blue: '\x1b[34m', cyan: '\x1b[36m', orange: '\x1b[38;5;209m',
}
const visible = (s: string) => s.replace(/\x1b\[[0-9;]*m/g, '').length
const clip = (s: string, n: number) => (n <= 0 ? '' : s.length > n ? `${s.slice(0, Math.max(0, n - 1))}…` : s)
const pad = (s: string, n: number) => s + ' '.repeat(Math.max(0, n - visible(s)))
const tone = (pct: number) => (pct >= 80 ? c.red : pct >= 50 ? c.yellow : c.green)

function box(title: string, color: string, count: string, lines: string[], width: number) {
  const inner = width - 4
  const head = `${color}┌ ${c.bold}${title}${c.reset}${color} ${'─'.repeat(Math.max(1, width - visible(title) - visible(count) - 6))} ${c.reset}${count}${color} ┐${c.reset}`
  const body = lines.map((l) => `${color}│${c.reset} ${pad(l, inner)} ${color}│${c.reset}`)
  return [head, ...body, `${color}└${'─'.repeat(width - 2)}┘${c.reset}`]
}

// A thin line, like the app's: a dim track, the filled part in colour, with a half cell for precision.
const rgb = (r: number, g: number, b: number) => `\x1b[38;2;${r};${g};${b}m`
const fill = (pct: number) => (pct >= 80 ? rgb(239, 83, 80) : pct >= 50 ? rgb(240, 180, 60) : rgb(74, 136, 232))
const bar = (pct: number, size: number) => {
  const halves = Math.round((Math.min(100, Math.max(0, pct)) / 100) * size * 2)
  const full = Math.floor(halves / 2)
  const half = halves % 2 ? '╸' : ''
  return `${fill(pct)}${'━'.repeat(full)}${half}${c.reset}${rgb(58, 62, 70)}${'━'.repeat(size - full - (half ? 1 : 0))}${c.reset}`
}

const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const resetAt = (epoch: number) => {
  const d = new Date(epoch * 1000)
  const time = d.toTimeString().slice(0, 5)
  return d.toDateString() === new Date().toDateString() ? `at ${time}` : `${DAYS[d.getDay()]} ${time}`
}

const json = (path: string) => {
  try {
    return JSON.parse(readFileSync(path, 'utf8'))
  } catch {
    return null
  }
}

const alive = (pid: number) => {
  try {
    process.kill(pid, 0)
    return true
  } catch {
    return false
  }
}

const run = async (cmd: string[]) => {
  const p = Bun.spawn(cmd, { stdout: 'pipe', stderr: 'ignore' })
  const [out, code] = await Promise.all([new Response(p.stdout).text(), p.exited])
  return code === 0 ? out : ''
}

// pid -> Rex pane label, for the panes whose foreground program is a Claude session.
async function labels() {
  const out = new Map<number, string>()
  if (!SESSION) return out
  const blocks = JSON.parse((await run(['rex', 'block', 'ls', '-s', SESSION, '--json'])) || '{"blocks":[]}').blocks
  await Promise.all(blocks.map(async (b: { block_id: string; label?: string }) => {
    const p = JSON.parse((await run(['rex', 'block', 'call', '-s', SESSION, '-b', b.block_id, 'process'])) || '{}')
    if (p.foreground?.pid && b.label && b.label !== 'shell') out.set(p.foreground.pid, b.label)
  }))
  return out
}

type Row = { name: string; model: string; effort: string; context: number; cost: number; status: string }

let rows: Row[] = []
type Limit = { used_percentage: number; resets_at: number }
let limits: { five?: Limit; seven?: Limit } = {}
let names = new Map<number, string>()

async function refresh() {
  names = await labels()
  const live = readdirSync(PIDS)
    .filter((f) => f.endsWith('.json'))
    .map((f) => json(`${PIDS}/${f}`))
    .filter((s) => s?.pid && s.sessionId && s.kind === 'interactive' && alive(s.pid))
  limits = {}
  // An idle session keeps showing the limits of its last request: take the latest window, at its highest use.
  const latest = (a: Limit | undefined, b: Limit | undefined) =>
    !b ? a : !a || b.resets_at > a.resets_at || (b.resets_at === a.resets_at && b.used_percentage > a.used_percentage) ? b : a
  rows = live.flatMap((s): Row[] => {
    const line = json(`${LINES}/${s.sessionId}.json`)
    if (!line) return []
    limits = { five: latest(limits.five, line.rate_limits?.five_hour), seven: latest(limits.seven, line.rate_limits?.seven_day) }
    const dir = (line.cwd ?? s.cwd ?? '').split('/').pop() ?? '?'
    return [{
      name: names.get(s.pid) ?? dir,
      model: line.model?.display_name ?? '?',
      effort: line.effort?.level ?? '',
      context: Math.round(line.context_window?.used_percentage ?? 0),
      cost: line.cost?.total_cost_usd ?? 0,
      status: s.status ?? '',
    }]
  }).sort((a, b) => b.cost - a.cost)
  render()
}

function render() {
  const width = Math.min(process.stdout.columns || 100, 140)
  const inner = width - 4
  const out: string[] = []
  const limit = (label: string, l?: Limit) =>
    l ? `${pad(label, 9)}${bar(l.used_percentage, 40)}  ${tone(l.used_percentage)}${String(Math.round(l.used_percentage)).padStart(3)} %${c.reset}  ${c.dim}resets ${resetAt(l.resets_at)}${c.reset}`
      : `${pad(label, 9)}${c.dim}not known yet${c.reset}`
  out.push(...box('Account limits', c.cyan, '', [limit('Session', limits.five), limit('Week', limits.seven)], width), '')

  const total = rows.reduce((sum, r) => sum + r.cost, 0)
  const nameWidth = Math.max(12, inner - 52)
  const lines = rows.map((r) => {
    const state = r.status === 'busy' ? `${c.yellow}●${c.reset}` : `${c.dim}○${c.reset}`
    const model = `${c.dim}${clip(`${r.model}${r.effort ? ` ${r.effort}` : ''}`, 16)}${c.reset}`
    return `${state} ${pad(clip(r.name, nameWidth), nameWidth)}  ${pad(model, 16)}  ${bar(r.context, 10)} ${tone(r.context)}${String(r.context).padStart(3)} %${c.reset}  ${c.dim}$${r.cost.toFixed(2).padStart(6)}${c.reset}`
  })
  out.push(...box('Sessions', c.blue, `${rows.length} · $${total.toFixed(2)}`, lines.length ? lines : [`${c.dim}No Claude session running.${c.reset}`], width), '')
  out.push(` ${c.dim}● working  ○ idle · context · session cost · updated ${new Date().toTimeString().slice(0, 8)} · q quit${c.reset}`)
  process.stdout.write(`\x1b[H\x1b[2J${out.join('\n')}`)
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
setInterval(refresh, 10_000)
refresh()
