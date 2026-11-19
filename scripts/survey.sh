#!/usr/bin/env bash
# Read-only survey of where disk space is going on this Mac. No deletions happen here.
# Safe to re-run any time, including between cleanup rounds, to see what's left.

set -u

hr() { printf '\n=== %s ===\n' "$1"; }

hr "Disk overview"
# /System/Volumes/Data is the real picture on modern macOS (APFS splits system/data volumes).
# `df -h /` alone reports the tiny read-only system volume and badly understates usage.
df -h /System/Volumes/Data 2>/dev/null

hr "Home top-level (visible + dotfiles)"
du -sh ~/* ~/.[!.]* 2>/dev/null | sort -rh | head -25

hr "~/Library breakdown"
du -sh ~/Library/*/ 2>/dev/null | sort -rh | head -20

for sub in "Application Support" Containers Developer Caches Logs; do
  if [ -d ~/Library/"$sub" ]; then
    hr "~/Library/$sub breakdown"
    du -sh ~/Library/"$sub"/*/ 2>/dev/null | sort -rh | head -15
  fi
done

hr "~/.cache breakdown"
du -sh ~/.cache/*/ 2>/dev/null | sort -rh | head -15

hr "Docker"
if command -v docker >/dev/null 2>&1; then
  if docker system df >/dev/null 2>&1; then
    docker system df -v 2>&1
  else
    echo "Docker CLI found but the daemon isn't responding (probably not running)."
    echo "Launch it with: open -a Docker"
    echo "Then poll 'docker system df' every couple seconds until it responds, and re-run this section."
  fi
else
  echo "Docker not installed."
fi

hr "Xcode"
if [ -d ~/Library/Developer/Xcode ]; then
  du -sh ~/Library/Developer/Xcode/*/ 2>/dev/null | sort -rh
else
  echo "No ~/Library/Developer/Xcode directory."
fi

hr "iOS Simulators"
SIMCTL=""
if command -v xcrun >/dev/null 2>&1 && xcrun simctl help >/dev/null 2>&1; then
  SIMCTL="xcrun simctl"
else
  for app in /Applications/Xcode*.app; do
    cand="$app/Contents/Developer/usr/bin/simctl"
    if [ -x "$cand" ]; then SIMCTL="$cand"; break; fi
  done
fi
if [ -n "$SIMCTL" ]; then
  echo "Using: $SIMCTL"
  echo "--- Installed runtimes ---"
  $SIMCTL runtime list 2>&1
  echo "--- Device data on disk ---"
  du -sh ~/Library/Developer/CoreSimulator/Devices/ 2>/dev/null
  echo "(device count: $(ls ~/Library/Developer/CoreSimulator/Devices/ 2>/dev/null | wc -l | tr -d ' '))"
  echo "--- Runtime disk images (can be 10-20GB+ each) ---"
  du -sh /Library/Developer/CoreSimulator/Volumes/*/ 2>/dev/null
else
  echo "Couldn't find a usable simctl binary (xcode-select may point at CommandLineTools instead of Xcode.app)."
  echo "Do NOT run 'xcode-select -s' just to fix this — it's a system setting change. Invoke the simctl inside"
  echo "the Xcode.app bundle directly instead, e.g. /Applications/Xcode.app/Contents/Developer/usr/bin/simctl"
fi

hr "JetBrains IDE versions: installed vs stored config"
echo "--- Installed apps (check each one's version in Finder/About if this doesn't show it) ---"
ls /Applications 2>/dev/null | grep -i -E "intellij|pycharm|webstorm|clion|rider|goland|idea|datagrip|appcode|rubymine|phpstorm|dataspell|fleet" || echo "(none found in /Applications)"
echo "--- Config folders under ~/Library/Application Support/JetBrains ---"
du -sh ~/Library/"Application Support"/JetBrains/*/ 2>/dev/null | sort -rh
echo "--- Log folders under ~/Library/Logs/JetBrains ---"
du -sh ~/Library/Logs/JetBrains/*/ 2>/dev/null | sort -rh

hr "macOS wallpaper aerial cache"
du -sh ~/Library/"Application Support"/com.apple.wallpaper/aerials 2>/dev/null || echo "(not present)"

hr "iOS/iPadOS device backups (Finder/iTunes-style)"
if [ -d ~/Library/"Application Support"/MobileSync/Backup ]; then
  du -sh ~/Library/"Application Support"/MobileSync/Backup/*/ 2>/dev/null | sort -rh
else
  echo "(none found)"
fi

hr "Homebrew cache"
if command -v brew >/dev/null 2>&1; then
  cache_dir="$(brew --cache 2>/dev/null)"
  [ -n "$cache_dir" ] && du -sh "$cache_dir" 2>/dev/null
else
  echo "Homebrew not installed."
fi

hr "Browser caches"
found_browser_cache=0
for b in Safari Google/Chrome "Microsoft Edge" Arc Firefox BraveSoftware/Brave-Browser; do
  d=~/Library/Caches/"$b"
  if [ -d "$d" ]; then
    du -sh "$d" 2>/dev/null
    found_browser_cache=1
  fi
done
[ "$found_browser_cache" = 0 ] && echo "(none of the common browser cache paths found)"

hr "Large files not already covered above (over 200MB, outside ~/Library)"
echo "Anything surfaced here is almost certainly personal content, not app cache - list it, never delete without asking."
find ~ -xdev -size +200M -not -path "*/Library/*" -not -path "*/.Trash/*" 2>/dev/null \
  | while IFS= read -r f; do du -sh "$f" 2>/dev/null; done \
  | sort -rh | head -20

hr "Trash"
du -sh ~/.Trash 2>&1 || echo "(couldn't read ~/.Trash from here — common in a sandboxed terminal; ask the user to check/empty it from Finder)"

hr "Survey complete"
echo "This was read-only. Nothing was deleted or changed."
