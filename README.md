# NetBe server presets

Config that the **"NetBe Preset Paper"** Pterodactyl egg (egg 31) reads at
server-creation time. The egg fetches `<preset>.json` from this repo's `main`
branch (`raw.githubusercontent.com/netbehosting/presets/main/<preset>.json`)
based on the server's `NETBE_PRESET` variable, then provisions the server.

A preset can be defined in either of two modes:

## 1. Whole-server presets (recommended)

You build a server exactly how you want it, then publish it. New servers of that
preset are a byte-for-byte copy — no plugin version drift, perfectly configured.

The manifest is just:

```json
{ "id": "skyblock", "name": "Skyblock",
  "serverArchive": "https://github.com/netbehosting/presets/releases/download/preset-skyblock/server.tar.gz" }
```

The egg downloads the archive (a GitHub **Release** asset — used because servers
exceed GitHub's 100 MB file limit) and extracts it over the fresh server, then
downloads Paper for the JAR.

### Publishing / editing

```bash
./publish-preset.sh <preset-id> <path-to-built-server>
# e.g.
./publish-preset.sh skyblock /path/to/server
```

The script stages the server, strips runtime/regeneratable files
(`logs/`, `cache/`, `libraries/`, `versions/`, `server.jar`, world session
locks, per-player `playerdata`/`stats`/`advancements`), **blanks builder
identity/secret files** (`ops.json`, whitelist/ban lists, `usercache.json`,
`management-server-secret`, `rcon.password`), packages it, uploads it as the
`server.tar.gz` asset on the `preset-<id>` release (clobbering any previous one),
and points `<preset-id>.json` at it. Re-run any time you tweak the server.

## 2. Hybrid presets (manifest-driven)

For lightweight presets, the manifest lists plugins to download and small config
to write — no prebuilt files. Fields:

- `plugins[]` — `{ name, source: modrinth|github|direct, slug|repo+asset|url, dest? }`
- `serverProperties{}` — keys merged into `server.properties`
- `configFiles[]` — `{ path, content }` written verbatim
- `files[]` — `{ archive }` tar.gz (relative to repo) extracted into the server

`none` / `basic-smp` / `survival` / `lifesteal` use this mode. `creative`
currently uses hybrid + the shared `bundles/lobby.tar.gz`; it can be switched to
whole-server with `publish-preset.sh` once its build world is finalised.

The egg prefers `serverArchive` if present; otherwise it runs the hybrid path.
