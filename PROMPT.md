# Exec Progress Report — Reusable Prompt & Style Guide

Use this to generate a **simplified-yet-rich, interactive, exec-facing progress
report** for *any* project, with the same accent and taste as the Sijilati
monthly report in this repo. Hand this file to the assistant along with your raw
inputs (git log, PRs, ticket exports, notes) and say: *"Build me a report like
this."*

The output is always **two files**:

1. `report-data.json` — all content as structured data (the single source of truth)
2. `index.html` (or `progress-report.html`) — a self-contained interactive page
   that renders the JSON, with the JSON also **embedded** as a `file://` fallback

Reference implementation: `index.html` + `report-data.json` in this repo. When in
doubt, copy their structure verbatim and only swap the content.

---

## 1. Audience & voice — this is for an EXECUTIVE MANAGER

- Write for someone who funds the work and reports upward — **not** an engineer.
- Lead with **outcomes**, not mechanics. "Auto-renewal is live → less manual
  billing follow-up," not "added a HyperPay webhook handler."
- Every technical theme must answer *"so what for the business?"* (the `impact`
  field, and the dedicated **Business Impact** section).
- **Be honest, not green-washed.** A report with a real Risks section is trusted
  more than one that's all ✅. Name what's stuck, stale, or blocked.
- Concise. Short sentences. No filler, no hype adjectives ("revolutionary",
  "cutting-edge"). Numbers over adjectives.
- Match the **language of the audience**. The Sijilati report is in **Arabic
  (RTL)**; produce the report in whatever language the exec reads. Keep proper
  nouns / tech terms (ZATCA, HyperPay, JWT, PR #) as-is.

---

## 2. The core editorial move — CONSOLIDATE, don't transcribe

Raw git/PR history is noisy: the same feature gets touched on scattered days,
branches overlap, work is revisited. **Do not produce a flat changelog.** Instead:

- **Merge related commits/PRs into coherent THEMES** (≈6–10 total). One theme =
  one thing the business cares about, even if it spanned many days/branches.
- When a theme was worked on across multiple sessions, mark it `revisited: true`
  and list the `revisitDays` — then show it **once**, not N times. Explain this
  consolidation in the `honestyNote`.
- Assign each theme an **honest completion %** and a **status** (see status model
  below). Don't round everything to 100%.
- Compute an **overall completion %** as a weighted-ish average of the themes,
  and state in the methodology note whether it includes not-yet-shipped work.

This is the difference between "a list of commits" and "a report an exec can act
on." It's the most important instruction here.

---

## 3. Required sections (in this order)

1. **Hero** — title, subtitle, period, "prepared for", repos; an animated
   **overall completion ring**, and a one-line `headline`.
2. **KPI strip** — 5–7 small stat cards + one full-width **lines-of-code** card
   (`+added / −removed`, green/red). Pull real numbers; don't invent.
3. **Strategic pillars** — 3 cards grouping the work into 3 themes-of-themes,
   each with an emoji icon. Followed by the **honesty/methodology note**.
4. **Business Impact** — "What this means for the business": 3–4 cards
   translating the work into outcomes the exec values.
5. **Themes** — the heart. Collapsible cards, each with: icon, title, one-line
   goal, a **completion ring**, a **status pill**, a **revisited pill** (if any),
   an **impact** paragraph, and a deliverables list (each with an **env badge**
   + date).
   - Add **filter chips** above: All / In-prod / In-dev / On-branch / Revisited.
   - Add a small **pure-SVG bar chart** "completion per theme" (sorted high→low).
6. **Timeline** — **descending (newest first)**. Each entry: a date "bubble" on a
   vertical spine, a tag, the title, env badges. Flag genuine **milestone** days
   (big merge day, major launch) with a ribbon + emphasized bubble — but be
   selective; not everything is a milestone.
7. **In-progress / awaiting-merge** + **Deployment status** (two columns).
8. **Risks / "needs attention"** — color-coded by level (high/med/low), each with
   **impact** + **required action**.
9. **Next steps** — a short numbered list of recommended actions.
10. **Footer** — a **methodology footnote** (ℹ️) explaining how the % and the LOC
    counts were derived, plus generation date + data sources.

Drop a section only if there's genuinely no content for it — don't pad.

---

## 4. Visual style / accent

Dark-first, modern, "fintech dashboard" feel. Self-contained single HTML file.

- **Theme via CSS variables** on `:root`, with a `:root[data-theme="light"]`
  override and a persisted light/dark toggle button.
- **Palette (dark):** deep navy bg (`#0b1020`), card `#161f3d`, ink `#eaf0ff`,
  dimmed `#9fb0d6`, lines `#27325c`. Accents: brand blue `#4f8cff` → violet
  `#7c5cff` (gradients), good/green `#2dd4a7`, warn/amber `#f4b740`,
  info/cyan `#58c8ff`, bad/pink `#ff6b8a`.
- Subtle radial-gradient glows behind the page; soft shadows; rounded corners
  (`--r: 18px`, cards up to 20–26px).
- **Font:** a clean Arabic-capable family (Sijilati uses *IBM Plex Sans Arabic*
  via Google Fonts). Base size **~17px** — exec reports should read large and
  comfortable, not dense. Section headings ~27px, KPI numbers ~32px.
- **Motion (tasteful, not gimmicky):** count-up animation on KPI numbers and the
  overall %, animated SVG completion rings, animated bar-chart fills,
  scroll-reveal fade-in on sections, gentle hover lift on cards.
- **Status pills & env badges are the signature detail** — small colored chips:
  - **Status:** `deployed` (green "في الإنتاج/In prod"), `dev` (cyan),
    `branch`/`pr` (amber/violet), `progress`.
  - **Env badges** with a leading dot: prod / dev / staging / branch / PR, each
    color-coded. Used in deliverables, timeline, and the deploy table.
- A `@media print` block so **print → PDF** looks clean (expand collapsibles,
  drop shadows, kill the toolbar). A toolbar with **🖨️ Print/Save-PDF** + the
  theme toggle.
- **Responsive:** grids collapse to one column under ~860px.

---

## 5. Data contract (`report-data.json`)

Drive *everything* from JSON so the report regenerates by editing data only.
Match these shapes (see this repo's `report-data.json` for a full example):

```jsonc
{
  "meta":   { "title", "subtitle", "periodLabel", "periodDays",
              "preparedFor", "generatedOn", "repos": [] },
  "kpis":   { "overallCompletion", "prsMerged", "prsOpen", "commits",
              "linesAdded", "linesRemoved", "themesDelivered", "deployedToProd" },
  "narrative": {
    "headline": "one sentence summarizing the period",
    "pillars": [ { "icon", "title", "text" } ],          // exactly 3
    "honestyNote": "explains the consolidation of revisited work"
  },
  "themes": [ {
    "id", "icon", "title", "goal", "completion": 0-100,
    "status": "deployed|dev|branch|progress",
    "revisited": true|false, "revisitDays": ["..."],
    "impact": "business outcome, 1–2 sentences",
    "deliverables": [ { "name", "status": "done|progress",
                        "where": "Prod|Dev|Staging|Branch|PR", "date" } ]
  } ],
  "timeline": [ { "date", "tag", "title", "where": "Dev/Prod" } ], // ASC; page reverses to DESC
  "inProgress":  [ { "branch", "desc", "status", "pr": null|123 } ],
  "deployments": [ { "env", "branch", "lastDeploy", "status" } ],
  "nextSteps":   [ "..." ],
  "businessImpact": [ { "icon", "title", "text" } ],     // 3–4
  "risks": [ { "level": "high|medium|low", "title", "impact", "action" } ],
  "methodology": "how % and LOC were computed; what's included"
}
```

**Status model** (keep consistent across the report):
`deployed` = live in prod · `dev` = merged to dev/staging · `branch`/`pr` =
done but not merged · `progress` = still in flight.

**Milestone tags** in the timeline: only a couple of entries should use the
"big day" tags that trigger the ribbon. Give other notable-but-routine days a
plain tag so they DON'T look like milestones. (Lesson learned: a compliance item
got wrongly bundled into a milestone — split distinct deliverables onto their own
timeline lines.)

---

## 6. The `file://` embed + build step (don't skip this)

The page must work **both** ways: served over HTTP (GitHub Pages → `fetch`) and
opened by double-click (`file://` → embedded fallback). So:

- The page tries `fetch('report-data.json')` first.
- It falls back to `window.__EMBED__ = { …the same JSON… };` baked into the HTML
  between `<!-- EMBED:START -->` / `<!-- EMBED:END -->` markers.
- Ship a **`build.sh`** that re-embeds `report-data.json` into the HTML and can
  `--check` for drift (this repo has one — copy it). Run it after every data
  edit, before commit. Otherwise the standalone file shows stale numbers.

---

## 7. How to gather the inputs (when starting from a git repo)

```bash
# Commits in the period, across all branches
git log --since=START --until=END --all --pretty=format:"%ad|%s" --date=short | sort

# Lines added/removed (exclude lockfiles/vendor/build noise)
git log --since=START --until=END --all --no-merges --pretty=tformat: --numstat \
  | awk 'NF==3 && $1!="-" && $3 !~ /(composer\.lock|package-lock\.json|vendor\/|build\/|node_modules\/)/ \
         {a+=$1; d+=$2} END {printf "added=%d removed=%d\n", a, d}'

# PRs (state, dates, base/head)
gh pr list --state all --limit 60 \
  --json number,title,state,createdAt,mergedAt,headRefName,baseRefName
```

Then **cross-check dates** to find revisited/overlapping work and consolidate it
into themes per §2. State LOC caveats (all-branches vs main-only) in the
methodology note.

---

## 8. Definition of done (checklist)

- [ ] Reads top-to-bottom as **outcomes for an exec**, not a commit log.
- [ ] Overlapping/revisited work **consolidated** into themes, marked + explained.
- [ ] Honest **completion %** per theme + an overall %; methodology note present.
- [ ] All 10 sections present (or justified-absent), in order.
- [ ] **Risks** section is real and specific (stale PRs, unmerged work, blockers).
- [ ] Status pills + **env badges** used consistently.
- [ ] Timeline is **descending**; milestones used sparingly and correctly.
- [ ] Light/dark toggle, print-to-PDF, animations, responsive all work.
- [ ] `report-data.json` drives everything; `build.sh` keeps the embed in sync.
- [ ] Opens correctly by double-click **and** when served.
