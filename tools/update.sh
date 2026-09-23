#!/bin/sh
# update.sh — refresh manifests/*.json and repo.json from the latest GitHub
# release of each listed app. Needs `gh` (GH_TOKEN optional; the app repos are
# public), curl and python3. Run it after publishing a release, or let
# .github/workflows/update.yml run it for you.
#
#   tools/update.sh            # all apps in apps.txt
#
# apps.txt lines:  <owner/repo>  <app id>  <title>  <category>
# Fields are whitespace-separated, so write the title with underscores for
# spaces: Own_Your_Glass -> "Own Your Glass".
#
# Everything comes from the /releases/latest API response (asset names and
# download URLs included); the /releases/tags/<tag> endpoint has been seen to
# lag behind and report no assets, so it is deliberately not used.
set -u
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)
cd "$ROOT"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
REPO_RAW=https://raw.githubusercontent.com/fivefold3/webos-homebrew-repo/main
failed=0

grep -v '^#' apps.txt | while read -r repo id title category; do
    [ -n "$repo" ] || continue
    title=$(printf %s "$title" | tr _ ' ')
    rel="$TMP/$id.release.json"
    if ! gh api "repos/$repo/releases/latest" > "$rel" 2>/dev/null; then
        echo "$repo: no release yet, keeping manifests/$id.json as is"; continue
    fi
    if ! python3 - "$rel" "$id" "$title" "$repo" "$REPO_RAW" "$TMP" <<'PY'
import json, sys, subprocess, hashlib, os
rel, id_, title, repo, raw, tmp = sys.argv[1:]
r = json.load(open(rel))
tag = r["tag_name"]; ver = tag[1:] if tag.startswith("v") else tag
assets = {a["name"]: a for a in r.get("assets", []) if a.get("state") == "uploaded"}
ipks = [n for n in assets if n.endswith(".ipk")]
if not ipks:
    sys.exit(f"{repo}: release {tag} has no .ipk asset")
ipk = assets[ipks[0]]
def fetch(asset):
    out = os.path.join(tmp, asset["name"])
    subprocess.run(["curl", "-sSfL", "-o", out, asset["browser_download_url"]], check=True)
    return out
path = fetch(ipk)
sha = hashlib.sha256(open(path, "rb").read()).hexdigest()
size = os.path.getsize(path)
if size != ipk["size"]:
    sys.exit(f"{repo}: downloaded {size} bytes but API says {ipk['size']}")
# the release's own manifest (if it ships one) supplies description and type
desc, typ = "", "web"
rm = assets.get(f"{id_}.manifest.json")
if rm:
    m = json.load(open(fetch(rm)))
    desc, typ = m.get("appDescription", ""), m.get("type", "web")
if not desc:
    desc = subprocess.run(["gh", "repo", "view", repo, "--json", "description", "--jq", ".description"],
                          capture_output=True, text=True).stdout.strip()
m = {"id": id_, "version": ver, "type": typ, "title": title, "appDescription": desc,
     "iconUri": f"{raw}/icons/{id_}.png",
     "sourceUrl": f"https://github.com/{repo}", "rootRequired": True,
     "ipkUrl": ipk["browser_download_url"],
     "ipkHash": {"sha256": sha}, "ipkSize": size}
with open(f"manifests/{id_}.json", "w") as f:
    json.dump(m, f, indent=2); f.write("\n")
print(f"{repo}: {tag} -> manifests/{id_}.json")
PY
    then echo "$repo: FAILED, keeping manifests/$id.json as is" >&2; touch "$TMP/failed"; fi
done
[ -f "$TMP/failed" ] && failed=1

# repo.json = paging + one package per manifest
python3 - "$REPO_RAW" <<'PY'
import json, os, sys
raw = sys.argv[1]
pk = []
for line in open("apps.txt"):
    if not line.strip() or line.startswith("#"): continue
    repo, id_, title, category = line.split()[:4]
    p = f"manifests/{id_}.json"
    if not os.path.exists(p): continue
    m = json.load(open(p))
    pk.append({"id": id_, "title": title.replace("_", " "), "iconUri": m["iconUri"],
               "shortDescription": m.get("appDescription", ""), "category": category, "pool": "main",
               "manifestUrl": f"{raw}/manifests/{id_}.json",
               "manifest": m})
with open("repo.json", "w") as f:
    json.dump({"paging": {"page": 0, "count": len(pk), "maxPage": 0, "itemsTotal": len(pk)}, "packages": pk}, f, indent=2)
    f.write("\n")
print("repo.json:", len(pk), "packages")
PY
exit $failed
