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

After publishing a release of one of the apps:

```sh
tools/update.sh && git commit -am "update manifests" && git push
```
