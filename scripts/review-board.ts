#!/usr/bin/env bun
// Two sections, one above the other: PRs where I am a requested reviewer by name (Enter sends `/wt-review <n>` to the Claude session in --repo),
// and my own open PRs by review state. bun review-board.ts --repo <checkout> [--minutes 5]

const arg = (name: string) => {
  const i = process.argv.indexOf(`--${name}`)
  return i > 0 ? process.argv[i + 1] : undefined
}
const REPO = arg('repo')
const SESSION = process.env.REX_SESSION
const GH = Bun.which('gh') ?? '/opt/homebrew/bin/gh'
const REFRESH_MS = Number(arg('minutes') ?? 5) * 60_000

type Pr = {
  number: number
  title: string
  url: string
  author: string
  draft: boolean
  hours: number
  additions: number
  deletions: number
  ci: string | null
  decision: string | null
  waiting: string[]
  approvedBy: string[]
}

const FIELDS = `nodes { ... on PullRequest {
  number title url isDraft updatedAt additions deletions reviewDecision author { login }
  commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
  reviewRequests(first: 20) { nodes { requestedReviewer { ... on User { login } ... on Team { slug } } } }
  latestReviews(first: 20) { nodes { state author { login } } } } }`
const QUERY = `{
  review: search(query: "is:pr is:open user-review-requested:@me archived:false", type: ISSUE, first: 50) { ${FIELDS} }
  mine: search(query: "is:pr is:open author:@me archived:false", type: ISSUE, first: 50) { ${FIELDS} } }`

const run = async (cmd: string[]) => {
  const p = Bun.spawn(cmd, { stdout: 'pipe', stderr: 'pipe' })
  const [out, err, code] = await Promise.all([new Response(p.stdout).text(), new Response(p.stderr).text(), p.exited])
  if (code !== 0) throw new Error(err.trim() || `${cmd[0]} exited ${code}`)
  return out
}

const toPr = (n: any): Pr => ({
  number: n.number,
  title: n.title,
  url: n.url,
  author: n.author?.login ?? '?',
  draft: n.isDraft,
  hours: Math.floor((Date.now() - Date.parse(n.updatedAt)) / 3_600_000),
  additions: n.additions,
  deletions: n.deletions,
  ci: n.commits.nodes[0]?.commit.statusCheckRollup?.state ?? null,
  decision: n.reviewDecision,
  waiting: n.reviewRequests.nodes.map((r: any) => r.requestedReviewer?.login ?? r.requestedReviewer?.slug).filter(Boolean),
  approvedBy: n.latestReviews.nodes.filter((r: any) => r.state === 'APPROVED').map((r: any) => r.author?.login).filter(Boolean),
})

const fetchAll = async () => {
  const data = JSON.parse(await run([GH, 'api', 'graphql', '-f', `query=${QUERY}`])).data
  const byAge = (a: Pr, b: Pr) => a.hours - b.hours
  return { review: data.review.nodes.map(toPr).sort(byAge) as Pr[], mine: data.mine.nodes.map(toPr).sort(byAge) as Pr[] }
}

const c = {
  reset: '\x1b[0m', bold: '\x1b[1m', dim: '\x1b[2m', inverse: '\x1b[7m',
  red: '\x1b[31m', green: '\x1b[32m', yellow: '\x1b[33m', blue: '\x1b[34m', cyan: '\x1b[36m', orange: '\x1b[38;5;209m',
}
const visible = (s: string) => s.replace(/\x1b\[[0-9;]*m|\x1b\]8;;[^\x1b]*\x1b\\/g, '').length
const clip = (s: string, n: number) => (n <= 0 ? '' : s.length > n ? `${s.slice(0, Math.max(0, n - 1))}…` : s)
const link = (url: string, text: string) => `\x1b]8;;${url}\x1b\\${text}\x1b]8;;\x1b\\`
const age = (h: number) => (h < 24 ? `${h}h` : `${Math.floor(h / 24)}j`)

const ciMark = (ci: string | null) =>
  ci === 'SUCCESS' ? `${c.green}✓${c.reset}` : ci === 'FAILURE' || ci === 'ERROR' ? `${c.red}✗${c.reset}` : ci ? `${c.yellow}●${c.reset}` : ' '

function box(title: string, color: string, count: string, lines: string[], width: number) {
  const inner = width - 4
  const head = `${color}┌ ${c.bold}${title}${c.reset}${color} ${'─'.repeat(Math.max(1, width - visible(title) - visible(count) - 6))} ${c.reset}${count}${color} ┐${c.reset}`
  const body = lines.map((l) => `${color}│${c.reset} ${l}${' '.repeat(Math.max(0, inner - visible(l)))} ${color}│${c.reset}`)
  return [head, ...body, `${color}└${'─'.repeat(width - 2)}┘${c.reset}`]
}

function row(pr: Pr, selected: boolean, inner: number, who: string, sub: string) {
  const right = [who, age(pr.hours), `${c.green}+${pr.additions}${c.reset} ${c.red}−${pr.deletions}${c.reset}`].filter(Boolean).join(`${c.dim} · ${c.reset}`)
  const lead = `${selected ? `${c.orange}›${c.reset}` : ' '} ${ciMark(pr.ci)} ${link(pr.url, `${c.bold}#${pr.number}${c.reset}`)}  `
  const tail = `${c.dim}${right}${c.reset}`
  const room = inner - visible(lead) - visible(tail) - 2
  const title = clip(pr.title, room)
  const line = `${lead}${selected ? c.bold : ''}${title}${c.reset}${' '.repeat(Math.max(2, room - title.length + 2))}${tail}`
  return sub ? [line, `      ${c.dim}${clip(sub, inner - 6)}${c.reset}`] : [line]
}

type Group = { title: string; color: string; prs: Pr[]; who: (p: Pr) => string; sub: (p: Pr) => string }

const TABS = [
  {
    name: 'To review',
    empty: 'No PR is waiting for your review.',
    groups: (list: Pr[]): Group[] => [
      { title: 'To review', color: c.orange, prs: list, who: (p) => p.author, sub: () => '' },
    ],
  },
  {
    name: 'My PRs',
    empty: 'You have no open PR.',
    groups: (list: Pr[]): Group[] => {
      const waiting = (p: Pr) => (p.waiting.length ? `waiting for ${p.waiting.join(', ')}` : 'no reviewer requested')
      const approved = (p: Pr) => (p.approvedBy.length ? `approved by ${p.approvedBy.join(', ')}` : '')
      return [
        { title: 'Waiting for reviewers', color: c.orange, prs: list.filter((p) => !p.draft && !p.decision?.match(/APPROVED|CHANGES_REQUESTED/)), who: () => '', sub: waiting },
        { title: 'Changes requested', color: c.red, prs: list.filter((p) => !p.draft && p.decision === 'CHANGES_REQUESTED'), who: () => '', sub: waiting },
        { title: 'Approved', color: c.green, prs: list.filter((p) => !p.draft && p.decision === 'APPROVED'), who: () => '', sub: approved },
        { title: 'Drafts', color: c.blue, prs: list.filter((p) => p.draft), who: () => '', sub: () => '' },
      ]
    },
  },
]

let data: { review: Pr[]; mine: Pr[] } = { review: [], mine: [] }
let cursor = 0
let error = ''
let notice = ''
let updated = ''
let loading = false

const sections = () => [0, 1]
const groupsOf = (s: number) => TABS[s].groups(s === 0 ? data.review : data.mine).filter((g) => g.prs.length)
const entries = () => sections().flatMap((s) => groupsOf(s).flatMap((g) => g.prs.map((pr) => ({ pr, section: s }))))
const selected = () => entries()[cursor]?.pr

function render() {
  const width = Math.min(process.stdout.columns || 100, 140)
  const inner = width - 4
  const out: string[] = []
  let i = 0
  sections().forEach((s, n) => {
    const list = s === 0 ? data.review : data.mine
    if (n === 0 && error) out.push(...box('Error', c.red, '', [clip(error, inner)], width), '')
    const groups = groupsOf(s)
    for (const g of groups) {
      const lines = g.prs.flatMap((pr) => row(pr, i++ === cursor, inner, g.who(pr), g.sub(pr)))
      out.push(...box(g.title, g.color, String(g.prs.length), lines, width), '')
    }
    if (!groups.length && !loading) {
      const first = TABS[s].groups(list)[0]
      out.push(...box(first.title, c.green, '0', [`${c.dim}${TABS[s].empty}${c.reset}`], width), '')
    }
  })
  if (notice) out.push(` ${notice}`, '')
  const enter = entries()[cursor]?.section === 1 ? 'open' : 'review'
  out.push(` ${c.dim}${loading ? 'updating…' : `updated ${updated}`}  ·${c.reset}  ${c.dim}↑↓${c.reset} select  ${c.dim}enter${c.reset} ${enter}  ${c.dim}o${c.reset} open  ${c.dim}r${c.reset} refresh  ${c.dim}q${c.reset} quit`)
  process.stdout.write(`\x1b[H\x1b[2J${out.join('\n')}`)
}

async function refresh() {
  loading = true
  render()
  try {
    data = await fetchAll()
    error = ''
    updated = new Date().toTimeString().slice(0, 5)
  } catch (e) {
    error = `GitHub unreachable: ${(e as Error).message}`
  }
  loading = false
  cursor = Math.min(cursor, Math.max(0, entries().length - 1))
  render()
}

async function claudePane() {
  if (!REPO || !SESSION) return undefined
  const blocks = JSON.parse(await run(['rex', 'block', 'ls', '-s', SESSION, '--json'])).blocks as { block_id: string }[]
  for (const b of blocks) {
    const p = JSON.parse(await run(['rex', 'block', 'call', '-s', SESSION, '-b', b.block_id, 'process']).catch(() => '{}'))
    if (p.foreground?.argv0?.endsWith('claude') && p.foreground.cwd === REPO) return b.block_id
  }
}

async function review(pr = selected()) {
  if (!pr) return
  const TARGET = await claudePane()
  if (!TARGET || !SESSION) {
    notice = `${c.yellow}No Claude session in ${REPO ?? '--repo'}: run /wt-review ${pr.number} yourself.${c.reset}`
    return render()
  }
  try {
    await run(['rex', 'send', '-s', SESSION, '-b', TARGET, `/wt-review ${pr.number}`])
    await run(['rex', 'send-key', '-s', SESSION, '-b', TARGET, 'enter'])
    await run(['rex', 'focus', '-s', SESSION, TARGET]).catch(() => {})
    notice = `${c.green}/wt-review ${pr.number} sent to your session.${c.reset}`
  } catch (e) {
    notice = `${c.red}Could not send: ${(e as Error).message}${c.reset}`
  }
  render()
}

const open = () => {
  const pr = selected()
  if (pr) run(['open', pr.url]).catch(() => {})
}

process.stdout.write('\x1b[?1049h\x1b[?25l')
const quit = () => {
  process.stdout.write('\x1b[?25h\x1b[?1049l')
  process.exit(0)
}
process.stdin.setRawMode(true)
process.stdin.resume()
process.stdin.on('data', (buf) => {
  const k = buf.toString()
  notice = ''
  if (k === 'q' || k === '\x03') return quit()
  if (k === '\x1b[A' || k === 'k') cursor = Math.max(0, cursor - 1)
  else if (k === '\x1b[B' || k === 'j') cursor = Math.min(entries().length - 1, cursor + 1)
  else if (k === 'r') return void refresh()
  else if (k === 'o') open()
  else if (k === '\r') return void (entries()[cursor]?.section === 1 ? open() : review())
  render()
})
process.stdout.on('resize', render)
setInterval(refresh, REFRESH_MS)
refresh()
