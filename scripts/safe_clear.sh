#!/usr/bin/env bash
# Clears ONLY categories that are pure, regenerable cache - nothing here can lose user data.
# Each category below was deliberately chosen because the thing it deletes rebuilds itself
# automatically (Xcode re-derives, macOS re-downloads aerials, package managers re-fetch).
#
# Usage:
#   safe_clear.sh                 # clear every category
#   safe_clear.sh xcode wallpaper # clear only the named categories
#
# Categories: xcode-derived, xcode-previews, wallpaper, docker-build-cache, dev-caches
#
# Deliberately NOT handled here, because they need a judgment call or explicit user
# sign-off first (see SKILL.md): Docker images/volumes, old JetBrains version folders,
# simulator runtimes, anything in the user's personal files.

set -u

wanted="${*:-all}"
want() {
  [ "$wanted" = "all" ] && return 0
  for c in $wanted; do [ "$c" = "$1" ] && return 0; done
  return 1
}

echo "Before:"
df -h /System/Volumes/Data | tail -1

if want xcode-derived; then
  if [ -d ~/Library/Developer/Xcode/DerivedData ]; then
    echo "Clearing Xcode DerivedData..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/*
  fi
fi

if want xcode-previews; then
  if [ -d ~/Library/Developer/Xcode/UserData/Previews ]; then
    echo "Clearing Xcode SwiftUI Previews cache..."
    rm -rf ~/Library/Developer/Xcode/UserData/Previews/*
  fi
fi

if want wallpaper; then
  if [ -d ~/Library/"Application Support"/com.apple.wallpaper/aerials ]; then
    echo "Clearing macOS wallpaper aerial video cache..."
    rm -rf ~/Library/"Application Support"/com.apple.wallpaper/aerials/*
  fi
fi

if want docker-build-cache; then
  if command -v docker >/dev/null 2>&1 && docker system df >/dev/null 2>&1; then
    echo "Clearing Docker build cache..."
    docker builder prune -af 2>&1 | tail -3
  else
    echo "Skipping Docker build cache (daemon not running or docker not installed)."
  fi
fi

if want dev-caches; then
  echo "Clearing known dev-tool caches (regenerate on next use)..."
  for d in huggingface uv pyright-python github-copilot pip; do
    if [ -d ~/.cache/"$d" ]; then
      rm -rf ~/.cache/"$d"
      echo "  removed ~/.cache/$d"
    fi
  done
  [ -d ~/Library/Caches/pip ] && rm -rf ~/Library/Caches/pip/*
  [ -d ~/Library/Caches/go-build ] && rm -rf ~/Library/Caches/go-build/*
fi

echo "After:"
df -h /System/Volumes/Data | tail -1
