# webOS homebrew repository

A [Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel)
repository for rooted LG webOS TVs, listing:

| app | what it does | source |
|---|---|---|
| **Own Your Glass** | Privacy hardening: stops ACR, ad overlays, telemetry uploaders, remote support and the microphone pipelines at the source; fully reversible | [fivefold3/own-your-glass](https://github.com/fivefold3/own-your-glass) |
| **LG Input Mapper** | Remap the buttons on your LG Magic Remote, on the TV itself | [fivefold3/lginputmapper](https://github.com/fivefold3/lginputmapper) |

## Add it to Homebrew Channel

Homebrew Channel > Settings > **Add repository**, and enter:

```
https://raw.githubusercontent.com/fivefold3/webos-homebrew-repo/main/repo.json
```

The apps then appear in the list and install and update like any other
homebrew app. Both need a rooted TV (<https://www.webosbrew.org/rooting/>).

## Layout

- `repo.json` — what Homebrew Channel fetches: a `packages` list, one entry per
  app, each with a `manifestUrl` (and the manifest inlined).
- `manifests/<app id>.json` — the per-app manifest: `ipkUrl` and `ipkHash.sha256`
  of the release asset.
- `icons/` — app icons served over raw.githubusercontent.com.
- `apps.txt` and `tools/update.sh` — the list of apps and the script that
  refreshes every manifest and `repo.json` from each app's latest GitHub
  release (downloads the ipk, computes the sha256).

## Updating

Nothing to edit by hand. `.github/workflows/update.yml` runs `tools/update.sh`
and commits whatever changed (new version, ipk URL, sha256, size). Trigger it
after publishing a release, either:

- **Actions > "update repo.json" > Run workflow**, or
- automatically: have the app repo ping this one on release. Add a secret `HOMEBREW_REPO_TOKEN`
  (a fine-grained PAT with *Contents: read and write* on this repo) to the app
  repo, and this workflow next to its release workflow:

  ```yaml
  # .github/workflows/notify-homebrew-repo.yml (in the app repo)
  name: notify homebrew repo
  on:
    release:
      types: [published]
  jobs:
    notify:
      runs-on: ubuntu-latest
      steps:
        - run: |
            gh api repos/fivefold3/webos-homebrew-repo/dispatches \
              -f event_type=app-released -f 'client_payload[repo]=${{ github.repository }}'
          env:
            GH_TOKEN: ${{ secrets.HOMEBREW_REPO_TOKEN }}
  ```

To add an app, append a line to `apps.txt` (title with underscores for spaces),
drop its icon in `icons/<app id>.png`, and run or wait for the workflow. Running
locally still works too:

```sh
tools/update.sh && git commit -am "update manifests" && git push
```
