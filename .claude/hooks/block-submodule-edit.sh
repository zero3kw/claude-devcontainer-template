#!/bin/bash
# PreToolUse (Edit / Write / NotebookEdit) で submodules/ 配下への直接編集を拒否する。
# CLAUDE.md Conventions「submodule のコード変更は必ず worktree で行う」の担保。
# Bash 経由の書き込みは止められない — そちらは指示で縛る
set -euo pipefail

path=$(jq -r '.tool_input.file_path // empty')
[ -z "$path" ] && exit 0

case "$path" in
  /*) abs=$path ;;
  *)  abs=$PWD/$path ;;
esac

case "$abs" in
  */submodules/*)
    echo "submodules/ の直接編集は禁止。_worktrees/ に worktree を作って編集する (worktree skill / CLAUDE.md Conventions)" >&2
    exit 2 ;;
esac
exit 0
