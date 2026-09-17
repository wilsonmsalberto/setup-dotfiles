#!/bin/bash
# Stable wrapper for the caveman plugin's statusline badge.
#
# The plugin's own script lives under a version-hashed cache directory that
# changes on every plugin update, so settings.json points here instead and this
# resolves the current one. Exits silently (status 0, no output) when the plugin
# is absent or disabled, leaving the statusline blank rather than erroring.

shopt -s nullglob

newest=""
for candidate in "$HOME"/.claude/plugins/cache/caveman/caveman/*/hooks/caveman-statusline.sh; do
  [ -f "$candidate" ] || continue
  if [ -z "$newest" ] || [ "$candidate" -nt "$newest" ]; then
    newest="$candidate"
  fi
done

[ -n "$newest" ] || exit 0

exec bash "$newest"
