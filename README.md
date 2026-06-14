# تقرير تقدّم سِجِلاتي — التقرير الشهري

تقرير تنفيذي تفاعلي لتقدّم تطوير منصّة سِجِلاتي.

**الفترة:** 15 مايو – 14 يونيو 2026

**الرابط المباشر:** https://rixtrayker.github.io/monthly-report/

## الملفّات

- `index.html` — صفحة التقرير التفاعلية (تُفتح مباشرة أو عبر GitHub Pages)
- `report-data.json` — بيانات التقرير (المصدر الوحيد للحقيقة)
- `build.sh` — يُعيد تضمين البيانات داخل الصفحة (انظر أدناه)
- `2026-05-15-to-2026-06-14-progress-report.md` — النسخة النصّية

تُنشر الصفحة تلقائيًا عبر GitHub Pages عند كل `push` إلى فرع `main`.

---

## How to update the report going forward

> **Edit `report-data.json`, never edit the numbers inside `index.html` by hand.**
> The HTML reads its data from the JSON; the build step keeps the two in sync.

### Why a build step exists

`index.html` consumes the report data **two ways**:

1. **`fetch('report-data.json')`** — used when the page is served over HTTP
   (this is what GitHub Pages does).
2. **`window.__EMBED__`** — a copy of the JSON baked into `index.html` as a
   fallback, so the page still renders when opened directly from disk
   (`file://`, double-click) where `fetch` is blocked.

If you change `report-data.json` but forget to refresh the embedded copy, the
live site (which fetches) updates, but the standalone file shows **stale
numbers**. `build.sh` re-syncs the embedded copy so both paths always match.

### The workflow

```bash
cd /Users/amr/dev/sijilati/monthly-report

# 1. Edit the data (KPIs, themes, timeline, risks, …)
$EDITOR report-data.json

# 2. Re-embed the JSON into index.html (keeps the file:// fallback in sync)
./build.sh

# 3. (optional) Preview locally — open index.html in a browser,
#    or serve it so fetch() works exactly like Pages:
python3 -m http.server 8000   # then visit http://localhost:8000

# 4. Commit + push — GitHub Pages redeploys automatically (~1–2 min)
git add -A
git commit -m "update report"
git push
```

### Verify the embed is in sync (CI-friendly)

```bash
./build.sh --check   # exits 0 if in sync, 1 if it drifted (writes nothing)
```

### After pushing

- Pages rebuilds in ~1–2 minutes. Check status:
  `gh api repos/rixtrayker/monthly-report/pages/builds/latest --jq .status`
  (look for `built`).
- If the live URL still shows old content, it's CDN caching —
  hard-refresh with **Cmd/Ctrl + Shift + R**.

### Editing the page design (not the data)

CSS/JS/layout live in `index.html`. Edit those directly — they aren't generated.
Only the `window.__EMBED__ = { … }` block is managed by `build.sh`; leave it alone.
