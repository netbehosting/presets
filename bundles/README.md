# Lobby bundle

`lobby.tar.gz` is the shared NetBe lobby payload, extracted into the server root
at install time by the **NetBe Preset Paper** egg (referenced via the `files`
field in a preset manifest).

Contents (game-agnostic):
- `world/`, `world_nether/`, `world_the_end/` — the protected lobby world
- `plugins/Skript/` — config + `scripts/lobby.sk` (`/lobby` `/hub` `/l` `/spawn`)
- `plugins/WorldGuard/worlds/world/` — `__global__` lobby protection region
- `plugins/DecentHolograms/` — base config/lang (the hologram itself is written
  per-preset via the manifest's `configFiles`)
- `plugins/Multiverse-Core/` — config + worlds.yml trimmed to lobby dimensions

Referenced by: `skyblock.json`, `creative.json`.

The required plugin JARs (Skript, WorldGuard, FastAsyncWorldEdit,
DecentHolograms, Multiverse-Core, LuckPerms, Vault, EssentialsX) are downloaded
fresh via each manifest's `plugins` list — not bundled here.

## Rebuilding
Built from a prepared server in `_/` (git-ignored). See repo history / the
session that introduced this for the exact assembly steps.
