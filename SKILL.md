---
name: mac-storage-cleanup
description: Survey a Mac for reclaimable disk space — Docker, Xcode/iOS Simulators, JetBrains and other IDEs, dev tool and browser caches, iOS device backups, Homebrew, macOS system caches, plus a generic sweep for anything else unusually large — and safely clear what's found, asking before anything that isn't pure regenerable cache. Use this whenever the user asks what's taking up space on their Mac, how to free up disk space, how to clean up storage, says they're running low on disk space, asks what "useless" files/memory/cache they can clear, or wants a Docker/Xcode/simulator/IDE-specific cleanup — even if they only mention one folder or app by name, since the real space hog is often somewhere else entirely, and may not be a category this skill has a name for.
---

# Mac storage cleanup

The point of this skill is to find real, concrete gigabytes and account for every one of them before anything gets deleted — never to guess at round numbers or clear things just because they're caches. Disk usage is almost never spread evenly: it's usually a handful of specific things that nobody actively chose to keep — an oversized Docker disk image on one machine, years of iPhone backups on another, a stale IDE version or a forgotten screen recording on a third. The categories below are the common, recurring offenders worth checking by name every time, but they're a starting point, not the whole list — the catch-all large-file sweep in the survey script exists precisely because any given machine will have something these don't anticipate. Finding what's actually there, and being honest about what's safe to touch versus what deserves a real yes/no from the user, is the whole job.

## Step 1 — Survey first, read-only, every time

Run `scripts/survey.sh`. It gathers the overall picture plus every named category below (Docker, Xcode, simulators, JetBrains, wallpaper cache, dev-tool caches, iOS device backups, Homebrew, browser caches, Trash) *and* a generic sweep for large files outside all of those, in one pass instead of a dozen separate `du`/`docker`/`simctl` calls. It makes no changes — safe to run before, during, and after a cleanup to see the effect.

Two things worth knowing going in:

- **Use `/System/Volumes/Data`, not `/`.** On current macOS, APFS splits the read-only system volume from the data volume your home directory actually lives on. `df -h /` reports the tiny system volume and makes it look like almost nothing is used — the script already does this correctly, but if you ever check disk usage by hand, use `/System/Volumes/Data`.
- **Docker needs its daemon running to report anything.** If the survey says Docker's daemon isn't responding, launch it (`open -a Docker`) and poll `docker system df` every couple of seconds until it answers — Docker Desktop takes a few seconds to come up, so one check-and-give-up isn't enough. Then re-run `docker system df -v` for the real breakdown.

## Step 2 — Don't stop at folder names, find the actual files

"`~/Library` is 80GB" tells you nothing actionable. Keep recursing into whichever subfolder is currently largest — `Application Support` → the app inside it → the subfolder inside that — until you land on something you can name and make a call about: a specific cache folder, a specific `.raw` disk image, a specific set of old version folders. The survey script gets you most of the way there for the categories below; use plain `du -sh */ | sort -rh` to go deeper wherever it points.

## Step 3 — Know how to judge what you find

This is the part that matters most. Treat each category by what it actually is, not by vibes:

**Docker** — `docker system df -v` breaks space into images / containers / local volumes / build cache.
- Build cache: always safe, clear it on sight with `docker builder prune -af`. It's intermediate layers from past builds; Docker rebuilds what it needs.
- Images with zero containers using them: *reclaimable, but ask first.* They can look identical to "junk" and still be a saved environment someone built on purpose (tagged test fixtures, a known-good base image). Show the list with sizes and names, then let the user decide — `docker image prune -a` only after they say yes.
- Volumes: **never touch without listing each one by name first.** Volume names like `*_pgdata`, `*_mongodata`, or a project name are almost always a real database for a real project. Deleting a volume is exactly as destructive as dropping that database. This is the one place in this whole skill where "ask first" isn't enough — list every volume, say what it looks like it's for, and only remove the ones the user explicitly names.

**Xcode caches** — `DerivedData/` and `UserData/Previews/` are pure build-time caches. Xcode regenerates both from source the next time it needs them. Always safe to clear.

**iOS Simulators** — don't assume "old" means "safe to delete." A simulator device only becomes truly orphaned when its iOS runtime is gone; checking `simctl list devices` for "unavailable" is the honest signal, not device age or an unfamiliar name. The bigger lever is usually the *runtime disk images* themselves (`simctl runtime list`, backed by files in `/Library/Developer/CoreSimulator/Volumes/`) — each installed iOS version can easily be 15-20GB, and most people only ever use the version matching their current Xcode. Ask which runtime(s) to keep before removing any with `simctl runtime delete <id>`, then run `simctl delete unavailable` to clean up the device shells that runtime leaves behind.

One environment quirk worth knowing: `xcrun simctl` fails whenever `xcode-select -p` points at the Command Line Tools instead of a full Xcode install. **Don't run `xcode-select -s` to fix this** — that's a system setting change, well outside what a storage cleanup needs. Just call the `simctl` binary bundled inside Xcode.app directly: `/Applications/Xcode.app/Contents/Developer/usr/bin/simctl`.

**JetBrains IDEs** (IntelliJ, PyCharm, WebStorm, etc.) — each version gets its own config folder under `~/Library/Application Support/JetBrains/<Product><Version>/`, and these survive version upgrades indefinitely. Check each installed app's actual version (its `Info.plist` → `CFBundleShortVersionString`) against the folders present; anything that doesn't match an installed app is a leftover from a version you're no longer running, and clearing it (plus its matching `~/Library/Logs/JetBrains/<Version>/`) is safe. Never touch the folder matching whatever's currently installed — that's live settings and project state, not cache.

**macOS wallpaper aerial cache** (`~/Library/Application Support/com.apple.wallpaper/aerials/`) — always safe. macOS re-downloads whichever aerials it actually displays.

**Dev tool caches** — `~/.cache/*` follows the XDG cache convention: whatever tool put a subfolder there treats it as disposable. That's true no matter which specific tools are installed on a given machine (today it might be a package manager and a language server, tomorrow something else entirely), so it's safe to clear the whole directory rather than maintaining a list of known tool names. Where a tool ships its own cache-clean command (`pip cache purge`, `npm cache clean --force`, `yarn cache clean`, `go clean -cache`, `brew cleanup`), prefer that over guessing at internal paths — it's correct regardless of how that tool is configured. Always safe.

**iOS/iPadOS device backups** (`~/Library/Application Support/MobileSync/Backup/`) — often the single biggest thing on a Mac that's ever backed up a phone or tablet through Finder, and the easiest to forget about since nothing surfaces it in normal use. Each backup can run many gigabytes, and it's common to find several, including ones for a device the person no longer owns. **Never delete one without asking** — it may be the only remaining copy of that device's data. List what's there (folder names map to device backups; the date modified is a reasonable proxy for when it was last updated) and let the user pick.

**Homebrew** — `brew --cache` holds downloaded bottles and sources; `brew cleanup -s` clears it and is always safe, same reasoning as any other package manager's cache. `brew autoremove` (orphaned dependencies) is a different kind of action — it changes what's actually installed, not just cached — so treat that as an ask-first step, not part of routine cleanup.

**Browser caches** (`~/Library/Caches/<browser>` for Safari, Chrome, Firefox, Arc, Edge, Brave, etc.) — this is the HTTP cache, not cookies, saved passwords, history, or session state, which live elsewhere. Safe to clear; the browser rebuilds it as pages load.

**Anything else large that doesn't match a named category** — don't treat the list above as exhaustive. Run a broad sweep for large files outside the locations already covered (the survey script does this) so that whatever happens to be unusually big on *this* machine — an old virtual machine image, a stray video export, a forgotten installer sitting in Downloads, something this skill has never specifically heard of — still gets surfaced. Anything caught this way is almost always personal content: list it with its size and path, and never delete without the user explicitly saying so.

**`~/.Trash`** — a sandboxed terminal is often denied permission to even look inside it ("Operation not permitted"). That's not nothing-to-see, it's a tool limitation — tell the user to check and empty it from Finder themselves rather than reporting it as empty.

**Personal files** (Desktop, Downloads, Documents, screen recordings, screenshots, anything that's clearly the user's own content rather than an app's cache) — never clear these on your own judgment, no matter how large or how plausible it looks that they're forgotten. If they're a big chunk of the total, it's fine to point them out with sizes, but only act if the user explicitly says to after seeing what's there.

## Step 4 — Present findings before clearing anything

Lay out what the survey found as a table: item, size, what it actually is, and your verdict (safe to clear / reclaimable but ask / real data, don't touch). Do this *before* running anything destructive, even for the categories you already know are safe — the user should see the shape of their disk before any of it changes, not just a final "freed X GB" afterward.

## Step 5 — Clear in two tiers

**Tier 1 — unambiguous cache.** Xcode caches, wallpaper aerials, Docker build cache, dev-tool caches, browser caches. These regenerate with zero data loss, so `scripts/safe_clear.sh` can run without a category-by-category yes — though it's still worth saying what you're about to clear and why in the same breath, so nothing happens silently.

**Tier 2 — everything else that's reclaimable.** Unused Docker images, orphaned JetBrains versions, extra simulator runtimes, old iOS device backups, anything turned up by the catch-all sweep, anything personal. Ask about each category on its own — "remove the unused Docker images too?" is a different question from "remove the old iOS runtimes?", and bundling them into one vague "okay to clean up the rest?" hides what's actually about to disappear. `AskUserQuestion` works well here: state the category, the size, and what re-acquiring it later would cost (a re-download, a rebuild, nothing at all — and for a device backup, possibly nothing, ever).

## Step 6 — Report concretely, keep a running total

Run `df -h /System/Volumes/Data` immediately before and after every round of deletion and quote the real before/after numbers — don't estimate. If this is a multi-round conversation, keep a running total of everything freed so far rather than only reporting the latest round. Always say what was explicitly left alone and why (Docker volumes with real data, the currently-installed JetBrains version, personal files), so "done" doesn't quietly imply "cleared everything in sight."

## The short version

Survey everything, read-only, before touching anything — named categories plus a generic sweep for whatever else is unusually big on this particular machine. Clear pure cache freely. Ask, by category, before clearing anything that was deliberately created, tagged, kept, or might be someone's only copy of something. Never touch another person's or project's actual data — volumes, device backups, personal files, the version someone's currently running — no matter how old it looks.
