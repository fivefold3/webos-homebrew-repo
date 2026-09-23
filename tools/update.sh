#!/bin/sh
# update.sh — refresh manifests/*.json and repo.json from the latest GitHub
# release of each listed app. Needs `gh` (authenticated for public repos is
# not required) and python3. Run it after publishing a release.
#
#   tools/update.sh            # all apps in apps.txt
#
# apps.txt lines:  <owner/repo>  <app id>  <title>  <category>
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)
cd "$ROOT"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
grep -v '^#' apps.txt | while read -r repo id title category; do
    [ -n "$repo" ] || continue
    tag=$(gh release view --repo "$repo" --json tagName --jq .tagName 2>/dev/null || true)
    if [ -z "$tag" ]; then echo "$repo: no release yet, keeping manifests/$id.json as is"; continue; fi
    ipk=$(gh release view --repo "$repo" --json assets --jq '.assets[] | select(.name | endswith(".ipk")) | .name' | head -1)
    [ -n "$ipk" ] || { echo "$repo: release $tag has no .ipk"; continue; }
    gh release download "$tag" --repo "$repo" --pattern "$ipk" --dir "$TMP" --clobber >/dev/null
    sha=$(shasum -a 256 "$TMP/$ipk" | awk '{print $1}'); size=$(wc -c < "$TMP/$ipk" | tr -d ' ')
    ver=${tag#v}
    # prefer the release's own manifest for description/type if it ships one
    desc=$(gh release download "$tag" --repo "$repo" --pattern "$id.manifest.json" --dir "$TMP" --clobber >/dev/null 2>&1 && python3 -c "import json;print(json.load(open('$TMP/$id.manifest.json')).get('appDescription',''))" || gh repo view "$repo" --json description --jq .description)
    typ=$( [ -f "$TMP/$id.manifest.json" ] && python3 -c "import json;print(json.load(open('$TMP/$id.manifest.json')).get('type','web'))" || echo web)
    python3 - "$id" "$ver" "$typ" "$title" "$desc" "$repo" "$tag" "$ipk" "$sha" "$size" <<'PY'
import json, sys
id_, ver, typ, title, desc, repo, tag, ipk, sha, size = sys.argv[1:]
m = {"id": id_, "version": ver, "type": typ, "title": title, "appDescription": desc,
     "iconUri": f"https://raw.githubusercontent.com/fivefold3/webos-homebrew-repo/main/icons/{id_}.png",
     "sourceUrl": f"https://github.com/{repo}", "rootRequired": True,
     "ipkUrl": f"https://github.com/{repo}/releases/download/{tag}/{ipk}",
     "ipkHash": {"sha256": sha}, "ipkSize": int(size)}
json.dump(m, open(f"manifests/{id_}.json", "w"), indent=2); print(f"{repo}: {tag} -> manifests/{id_}.json")
PY
done
# repo.json = paging + one package per manifest
python3 - <<'PY'
import json, glob, os
pk = []
for line in open("apps.txt"):
    if not line.strip() or line.startswith("#"): continue
    repo, id_, title, category = line.split()[:4]
    p = f"manifests/{id_}.json"
    if not os.path.exists(p): continue
    m = json.load(open(p))
    pk.append({"id": id_, "title": title.replace("_", " "), "iconUri": m["iconUri"],
               "shortDescription": m.get("appDescription", ""), "category": category, "pool": "main",
               "manifestUrl": f"https://raw.githubusercontent.com/fivefold3/webos-homebrew-repo/main/manifests/{id_}.json",
               "manifest": m})
json.dump({"paging": {"page": 0, "count": len(pk), "maxPage": 0, "itemsTotal": len(pk)}, "packages": pk}, open("repo.json", "w"), indent=2)
print("repo.json:", len(pk), "packages")
PY
