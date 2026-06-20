#!/usr/bin/env bash
# Extract Amr's commits + LoC across all repos under the sijilati workspace,
# for the last 3 months, with weekend (Fri-Sat) tagging.
# Output: contrib-data.json  (consumed by contributions.html)
set -euo pipefail

BASE="/Users/amr/dev/sijilati"
OUT="$(cd "$(dirname "$0")" && pwd)/contrib-data.json"

# Window: last ~3 months. Inclusive of weekends.
SINCE="2026-03-20"
UNTIL="2026-06-21"   # exclusive-ish upper bound; today is 2026-06-20

# Amr's identities. macOS git --author uses BRE (no | alternation), so we pass
# multiple --author flags which OR together. Includes the cloud-worker CI bot
# that commits under his gmail.
AUTHORS=(--author='rixtrayker@hotmail.com'
         --author='cs.elsayed@gmail.com'
         --author='7710590+rixtrayker')

# Map local dir -> canonical project / github slug.
# Projects to leave out of the report entirely (tooling / meta repos).
EXCLUDE=(
  "open-gitagent/gitagent"
  "rixtrayker/monthly-report"
  "Sijilaty/pdf-generator"
)

slug_for() {
  local dir="$1"
  local url slug
  url="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
  if [ -n "$url" ]; then
    slug="$(echo "$url" | sed -E 's#(git@|https://)[^:/]+[:/]##; s#\.git$##')"
  else
    slug="(local) $(basename "$dir")"
  fi
  # Display-name overrides
  case "$slug" in
    rixtrayker/ehr-workspace) slug="ehr-workspace (local)" ;;
  esac
  echo "$slug"
}

is_excluded() {
  local p="$1"
  for x in "${EXCLUDE[@]}"; do [ "$p" = "$x" ] && return 0; done
  return 1
}

echo "Extracting from $BASE  window $SINCE .. $UNTIL" >&2

# Temp file of raw records:  project<TAB>iso_date<TAB>hash<TAB>added<TAB>deleted<TAB>subject
RAW="$(mktemp)"
trap 'rm -f "$RAW"' EXIT

for d in "$BASE"/*/; do
  [ -d "$d/.git" ] || continue
  project="$(slug_for "$d")"
  if is_excluded "$project"; then echo "  skip (excluded): $project" >&2; continue; fi
  bn="$(basename "$d")"
  # numstat per commit. Format line: @@<hash>\t<isodate>\t<subject>  then numstat rows.
  git -C "$d" log --all --no-merges \
      --since="$SINCE" --until="$UNTIL" \
      "${AUTHORS[@]}" --regexp-ignore-case \
      --date=format:'%Y-%m-%d' \
      --pretty=format:'@@%H%x09%ad%x09%s' --numstat 2>/dev/null \
  | awk -v proj="$project" -v bn="$bn" '
      function isnoise(p) {
        # generated / vendored / lockfiles / minified / binary-ish / design dumps
        if (p ~ /(^|\/)(node_modules|vendor|dist|build|out|\.next|coverage|__generated__|gen|generated)\//) return 1
        if (p ~ /(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|composer\.lock|go\.sum|Cargo\.lock|poetry\.lock|Gemfile\.lock)$/) return 1
        if (p ~ /\.(min\.js|min\.css|map|lock|svg|png|jpg|jpeg|gif|webp|ico|pdf|woff2?|ttf|eot|zip|tar|gz)$/) return 1
        if (p ~ /(^|\/)(prototypes?|design-reference|design-exploration|ehr-cool-ui|newest-ui)(\/|$)/) return 1
        return 0
      }
      /^@@/ {
        if (have) { printf "%s\t%s\t%s\t%d\t%d\t%d\t%d\t%s\n", proj, date, hash, add, del, cadd, cdel, subj }
        line=substr($0,3)
        n=split(line, a, "\t")
        hash=a[1]; date=a[2]; subj=a[3]
        for (i=4;i<=n;i++) subj=subj" "a[i]
        gsub(/\t/," ",subj)
        add=0; del=0; cadd=0; cdel=0; have=1
        next
      }
      /^[0-9-]+\t[0-9-]+\t/ {
        split($0, f, "\t")
        ad = (f[1]=="-")?0:f[1]
        de = (f[2]=="-")?0:f[2]
        path = f[3]
        for (i=4;i<=NF;i++) path=path"\t"f[i]   # rename paths contain tabs/braces; keep raw
        add += ad; del += de
        if (!isnoise(path)) { cadd += ad; cdel += de }
        next
      }
      END { if (have) { printf "%s\t%s\t%s\t%d\t%d\t%d\t%d\t%s\n", proj, date, hash, add, del, cadd, cdel, subj } }
    ' >> "$RAW"
done

echo "Raw commit records: $(wc -l < "$RAW")" >&2

# Build JSON with python (stable, handles weekend logic + aggregation).
python3 - "$RAW" "$OUT" "$SINCE" "$UNTIL" <<'PY'
import sys, json, datetime, collections, html

raw_path, out_path, since, until = sys.argv[1:5]

# Per-commit records (dedupe by project+hash because --all can repeat across refs)
seen = set()
commits = []
with open(raw_path, encoding="utf-8", errors="replace") as fh:
    for line in fh:
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 8:
            continue
        proj, date, h = parts[0], parts[1], parts[2]
        add, dele, cadd, cdel = parts[3], parts[4], parts[5], parts[6]
        subj = "\t".join(parts[7:])
        key = (proj, h)
        if key in seen:
            continue
        seen.add(key)
        try:
            add = int(add); dele = int(dele); cadd = int(cadd); cdel = int(cdel)
        except ValueError:
            add = dele = cadd = cdel = 0
        commits.append(dict(project=proj, date=date, hash=h,
                            add=add, deleted=dele, cadd=cadd, cdel=cdel, subject=subj))

# Date helpers. Weekend = Friday(4) or Saturday(5) in Python weekday() (Mon=0).
def is_weekend(d):
    return d.weekday() in (4, 5)

d0 = datetime.date.fromisoformat(since)
d1 = datetime.date.fromisoformat(until)

# Full day grid (so heatmap shows empty weekends too)
days = {}
cur = d0
while cur < d1:
    iso = cur.isoformat()
    days[iso] = dict(date=iso, dow=cur.weekday(), weekend=is_weekend(cur),
                     commits=0, add=0, deleted=0, cadd=0, cdel=0,
                     projects=collections.Counter())
    cur += datetime.timedelta(days=1)

projects = collections.Counter()
proj_add = collections.Counter()
proj_del = collections.Counter()
proj_cadd = collections.Counter()
proj_cdel = collections.Counter()
proj_days = collections.defaultdict(set)

for c in commits:
    iso = c["date"]
    if iso not in days:
        continue
    rec = days[iso]
    rec["commits"] += 1
    rec["add"] += c["add"]
    rec["deleted"] += c["deleted"]
    rec["cadd"] += c["cadd"]
    rec["cdel"] += c["cdel"]
    rec["projects"][c["project"]] += 1
    projects[c["project"]] += 1
    proj_add[c["project"]] += c["add"]
    proj_del[c["project"]] += c["deleted"]
    proj_cadd[c["project"]] += c["cadd"]
    proj_cdel[c["project"]] += c["cdel"]
    proj_days[c["project"]].add(iso)

# Serialize day grid
day_list = []
for iso in sorted(days):
    r = days[iso]
    day_list.append(dict(
        date=r["date"], dow=r["dow"], weekend=r["weekend"],
        commits=r["commits"], add=r["add"], deleted=r["deleted"],
        cadd=r["cadd"], cdel=r["cdel"],
        projects=dict(r["projects"]),
    ))

# Per-commit list trimmed for the UI (keep subject short)
commit_list = [dict(project=c["project"], date=c["date"], add=c["add"],
                    deleted=c["deleted"], cadd=c["cadd"], cdel=c["cdel"],
                    subject=c["subject"][:140])
               for c in commits]

proj_list = []
for p, n in projects.most_common():
    proj_list.append(dict(
        project=p, commits=n, add=proj_add[p], deleted=proj_del[p],
        cadd=proj_cadd[p], cdel=proj_cdel[p],
        active_days=len(proj_days[p]),
    ))

# ---- Insights ----
total_commits = sum(p["commits"] for p in proj_list)
total_add = sum(p["add"] for p in proj_list)
total_del = sum(p["deleted"] for p in proj_list)
total_cadd = sum(p["cadd"] for p in proj_list)
total_cdel = sum(p["cdel"] for p in proj_list)
active_days = sum(1 for d in day_list if d["commits"] > 0)
weekend_days_total = sum(1 for d in day_list if d["weekend"])
weekend_worked = sum(1 for d in day_list if d["weekend"] and d["commits"] > 0)
weekend_off = weekend_days_total - weekend_worked
weekend_commits = sum(d["commits"] for d in day_list if d["weekend"])
weekend_add = sum(d["add"] for d in day_list if d["weekend"])
weekend_del = sum(d["deleted"] for d in day_list if d["weekend"])
weekend_cadd = sum(d["cadd"] for d in day_list if d["weekend"])
weekend_cdel = sum(d["cdel"] for d in day_list if d["weekend"])
weekday_commits = total_commits - weekend_commits

# longest active streak (consecutive calendar days with commits)
streak = best = 0
for d in day_list:
    if d["commits"] > 0:
        streak += 1
        best = max(best, streak)
    else:
        streak = 0

# busiest day
busiest = max(day_list, key=lambda d: d["commits"]) if day_list else None

# commits by day-of-week
dow_counts = collections.Counter()
for d in day_list:
    dow_counts[d["dow"]] += d["commits"]

insights = dict(
    window=dict(since=since, until=until),
    total_commits=total_commits, total_add=total_add, total_del=total_del,
    total_cadd=total_cadd, total_cdel=total_cdel,
    net_loc=total_add - total_del, net_code=total_cadd - total_cdel,
    active_days=active_days, span_days=len(day_list),
    weekend_days_total=weekend_days_total,
    weekend_worked=weekend_worked, weekend_off=weekend_off,
    weekend_commits=weekend_commits, weekday_commits=weekday_commits,
    weekend_add=weekend_add, weekend_del=weekend_del,
    weekend_cadd=weekend_cadd, weekend_cdel=weekend_cdel,
    weekend_pct=round(100*weekend_commits/total_commits, 1) if total_commits else 0,
    longest_streak=best,
    busiest_day=busiest["date"] if busiest else None,
    busiest_day_commits=busiest["commits"] if busiest else 0,
    dow_commits={str(k): dow_counts[k] for k in range(7)},
    project_count=len(proj_list),
)

out = dict(
    generated=since + "/" + until,
    insights=insights,
    days=day_list,
    projects=proj_list,
    commits=commit_list,
)
with open(out_path, "w", encoding="utf-8") as fh:
    json.dump(out, fh, indent=1, ensure_ascii=False)

print(f"Wrote {out_path}", file=sys.stderr)
print(f"  commits={total_commits} add={total_add} del={total_del} "
      f"weekend_worked={weekend_worked}/{weekend_days_total} streak={best}", file=sys.stderr)
PY

echo "Done -> $OUT" >&2
