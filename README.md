# تقارير تقدّم سِجِلاتي التنفيذيّة

تقارير تنفيذيّة تفاعليّة لتقدّم تطوير منصّة سِجِلاتي.

## التقارير

### 1. التقرير الشهري (الخلفية + البنية التحتية)
**الفترة:** 15 مايو – 14 يونيو 2026
**الرابط:** https://rixtrayker.github.io/monthly-report/

### 2. تقرير الواجهة الجديدة — لوحة الإدارة وبوّابة المراكز فقط
**الفترة:** 14 أبريل – 13 يونيو 2026
**الرابط:** https://rixtrayker.github.io/monthly-report/frontend.html

### 3. لوحة المساهمات — آخر 3 أشهر (Commits + LoC)
**الفترة:** 20 مارس – 20 يونيو 2026
**الرابط:** https://rixtrayker.github.io/monthly-report/contributions.html
تصوّر تفاعلي لمساهمات عمرو (الـ commits وأسطر الكود) عبر كل مستودعات مساحة عمل سِجِلاتي، مع
تلوين عطلات نهاية الأسبوع (الجمعة/السبت): **أحمر زاهٍ** عند العمل و**أصفر فاتح** عند الإجازة،
وفلاتر لكل مشروع. يُولَّد آليًّا من سجلّ git عبر `extract-contrib.sh` (انظر القسم الإنجليزي أدناه).

## الملفّات

| التقرير | الصفحة (HTML) | البيانات (JSON) |
|---|---|---|
| الشهري — الخلفية | `index.html` | `report-data.json` |
| الواجهة الجديدة — إدارة + مراكز | `frontend.html` | `frontend-data.json` |
| لوحة المساهمات — 3 أشهر | `contributions.html` | `contrib-data.json` |

ملفّات مشتركة:

- `build.sh` — يُعيد تضمين البيانات داخل كل صفحة (يعالج التقارير الثلاثة معًا، انظر أدناه)
- `extract-contrib.sh` — يُولّد بيانات لوحة المساهمات (التقرير 3) من سجلّ git
- `PROMPT.md` — وصفة/برومبت قابل لإعادة الاستخدام لتوليد تقرير بنفس الأسلوب لأي مشروع
- `2026-05-15-to-2026-06-14-progress-report.md` — النسخة النصّية للتقرير الشهري

تُنشر الصفحات تلقائيًا عبر GitHub Pages عند كل `push` إلى فرع `main`.

---

## How to update a report going forward

> **Edit the report's `*-data.json`, never edit the numbers inside the HTML by hand.**
> Each page reads its data from its JSON; the build step keeps the two in sync.
>
> - Monthly (backend): edit `report-data.json` → page `index.html`
> - Frontend (admin + central): edit `frontend-data.json` → page `frontend.html`

### Why a build step exists

Each page consumes its data **two ways**:

1. **`fetch('<report>-data.json')`** — used when the page is served over HTTP
   (this is what GitHub Pages does).
2. **`window.__EMBED__`** — a copy of the JSON baked into the HTML as a fallback,
   so the page still renders when opened directly from disk (`file://`,
   double-click) where `fetch` is blocked.

If you change the JSON but forget to refresh the embedded copy, the live site
(which fetches) updates, but the standalone file shows **stale numbers**.
`build.sh` re-syncs the embedded copy for **all reports** so all paths match.

### The workflow

```bash
cd /Users/amr/dev/sijilati/monthly-report

# 1. Edit the data of whichever report you're updating
$EDITOR report-data.json        # monthly / backend
#   or
$EDITOR frontend-data.json      # frontend (admin + central)

# 2. Re-embed JSON into the HTML pages (handles ALL reports; safe no-op for
#    the ones you didn't change)
./build.sh

# 3. (optional) Preview locally — open the HTML in a browser, or serve it so
#    fetch() works exactly like Pages:
python3 -m http.server 8000     # then visit http://localhost:8000/ (or /frontend.html)

# 4. Commit + push — GitHub Pages redeploys automatically (~1–2 min)
git add -A
git commit -m "update report"
git push
```

### Verify the embeds are in sync (CI-friendly)

```bash
./build.sh --check   # exits 0 if ALL in sync, 1 if any drifted (writes nothing)
```

### After pushing

- Pages rebuilds in ~1–2 minutes. Check status:
  `gh api repos/rixtrayker/monthly-report/pages/builds/latest --jq .status`
  (look for `built`).
- If a live URL still shows old content, it's CDN caching —
  hard-refresh with **Cmd/Ctrl + Shift + R**.

### Adding a new report

1. Create `<name>-data.json` and a `<name>.html` page (copy an existing pair).
2. Point the page's `fetch('…')` at the new JSON filename.
3. Add the `"<name>-data.json:<name>.html"` pair to the `PAIRS` array in `build.sh`.
4. Run `./build.sh`, then commit + push. See `PROMPT.md` for the full report recipe.

### Editing the page design (not the data)

CSS/JS/layout live in the HTML files. Edit those directly — they aren't generated.
Only the `window.__EMBED__ = { … }` block is managed by `build.sh`; leave it alone.

---

## Report 3: contribution dashboard (git-derived)

Unlike reports 1 & 2 (hand-authored exec summaries), `contributions.html` is **generated
from git history**. Its data is not edited by hand — it's produced by a script.

**What it shows** — Amr's commits + lines of code across **all repos** under
`/Users/amr/dev/sijilati/` (including the unpushed `ehr-workspace`), for the last 3 months
(`2026-03-20 → 2026-06-20`):

- GitHub-style **contribution calendar** where weekends (Fri & Sat) are color-coded:
  🔴 **vivid red** when worked, 🟡 **light yellow** when taken off.
- **Per-project filter** (chips + bars) that re-scopes the whole dashboard.
- KPIs, by-project LoC bars, activity-by-day-of-week, and a weekend ledger.
- Commits ↔ code-LoC metric toggle; hover tooltips with per-day detail.

**Two LoC numbers:** *raw* (everything `numstat` reports) and *code* (excludes lockfiles,
vendored/generated dirs, minified assets, binaries, and design-prototype dumps). Code LoC is
the honest headline; raw is shown in tooltips.

### Regenerate the data

```bash
cd /Users/amr/dev/sijilati/monthly-report
./extract-contrib.sh   # walks every repo under ../  -> writes contrib-data.json
./build.sh             # re-embed contrib-data.json into contributions.html
```

`extract-contrib.sh` matches commits by three author identities
(`rixtrayker@hotmail.com`, `cs.elsayed@gmail.com`, GitHub noreply), excludes merge commits,
and tags weekends as **Fri–Sat** (MENA work week, commit TZ +0300). To change the window,
author set, or weekend definition, edit the variables at the top of that script.
