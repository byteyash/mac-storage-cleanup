# mac-storage-cleanup

A [Claude Code](https://claude.com/claude-code) / Claude Agent skill that surveys a Mac for reclaimable disk space — Docker, Xcode and iOS Simulators, JetBrains IDEs, dev-tool caches, macOS system caches — and clears what it finds, asking you first about anything that isn't pure, regenerable cache.

It never touches Docker volumes, the currently-installed version of an app, or your personal files (Desktop, Downloads, screen recordings, etc.) without being asked explicitly.

## Setup

Skills live in `~/.claude/skills/<skill-name>/` and are picked up automatically — there's no install step beyond putting the folder there.

```bash
git clone https://github.com/byteyash/mac-storage-cleanup.git ~/.claude/skills/mac-storage-cleanup
```

If you already have a `~/.claude/skills/` directory with other skills in it, that's fine — just clone into a `mac-storage-cleanup` subfolder of it, as above. If the directory doesn't exist yet, the clone command creates it.

Make sure the bundled scripts are executable (the repo preserves this, but if you downloaded a zip instead of cloning, you'll need to set it yourself):

```bash
chmod +x ~/.claude/skills/mac-storage-cleanup/scripts/*.sh
```

No other dependencies are required. A few checks are skipped gracefully if the relevant tool isn't installed (Docker, Xcode).

## Usage

Just ask Claude Code naturally — you don't need to name the skill. Things like:

- "what's taking up space on my Mac?"
- "I'm running low on disk space, can you help?"
- "clean up my storage"
- "check what useless caches I can clear"
- "my Docker is huge, can you fix that?"

Claude will read the skill and follow its workflow:

1. **Survey, read-only.** Runs `scripts/survey.sh` to get a full picture — overall disk usage, then a breakdown of Docker, Xcode/Simulators, JetBrains, macOS caches, and dev-tool caches. Nothing is deleted at this stage.
2. **Present findings as a table** — what was found, how big, and whether it's safe to clear, reclaimable-but-worth-asking, or real data that won't be touched.
3. **Clear in two tiers:**
   - Pure cache (Xcode build caches, the macOS wallpaper video cache, Docker's build cache, dev-tool caches under `~/.cache` and friends) gets cleared directly via `scripts/safe_clear.sh` — these regenerate automatically, so there's nothing to lose.
   - Everything else that's reclaimable (unused Docker images, old JetBrains versions, extra iOS simulator runtimes) gets asked about one category at a time before anything happens.
4. **Reports real numbers.** Before/after disk usage from `df`, plus a running total of what's been freed across the conversation.

### Running the scripts directly

You don't need Claude in the loop to use the scripts yourself:

```bash
# Read-only survey — safe to run any time
bash ~/.claude/skills/mac-storage-cleanup/scripts/survey.sh

# Clear every pure-cache category
bash ~/.claude/skills/mac-storage-cleanup/scripts/safe_clear.sh

# Or clear just specific categories
bash ~/.claude/skills/mac-storage-cleanup/scripts/safe_clear.sh xcode-derived wallpaper
```

Valid categories for `safe_clear.sh`: `xcode-derived`, `xcode-previews`, `wallpaper`, `docker-build-cache`, `dev-caches`. With no arguments, it clears all of them.

Deliberately *not* handled by `safe_clear.sh` — these need a judgment call, so they're left to the conversation with Claude described above: unused Docker images, Docker volumes, old JetBrains IDE versions, extra iOS simulator runtimes, and anything in your personal files.

## What it does not do

- Never deletes a Docker volume without listing it by name first — volume names like `*_pgdata` or `*_mongodata` are almost always a real project database.
- Never touches the JetBrains config folder matching whatever version you currently have installed.
- Never runs `xcode-select -s` to fix a missing `simctl` — it calls the `simctl` binary bundled inside `Xcode.app` directly instead, so your Xcode selection is left alone.
- Never clears Desktop, Downloads, Documents, screenshots, or other personal files without you explicitly saying to after seeing what's there.
- Can't read `~/.Trash` from a sandboxed terminal — Claude will tell you to check/empty it from Finder yourself.
