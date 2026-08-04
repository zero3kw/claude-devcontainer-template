#!/usr/bin/env bash
# .claude/settings.json の enabledPlugins を実体化する。
#
# enabledPlugins は「有効にする」宣言でしかなく、書いただけではプラグインは入らない。
# コンテナを開くたびに /plugin から手で入れるのを避けるため、ここで入れておく。
# scope は user (既定) なので ~/.claude volume に入り、リビルドをまたいで残る。
#
# 複数をまとめて渡すと最初の1つしか入らないので、1つずつ回す。
# 何度実行しても既存分は "already installed" で終わる。
#
# 公式マーケットプレイス以外のプラグインを enabledPlugins に足すときは、
# その marketplace も add する必要がある（下の MARKETPLACE を増やす）。
set -euo pipefail

SETTINGS=".claude/settings.json"
MARKETPLACE="anthropics/claude-plugins-official"

[ -f "$SETTINGS" ] || exit 0

mapfile -t PLUGINS < <(jq -r '.enabledPlugins // {} | to_entries[] | select(.value) | .key' "$SETTINGS")

# ここで失敗してもコンテナは使えるので、postCreate 全体は落とさない
claude plugin marketplace add "$MARKETPLACE" || exit 0

for p in "${PLUGINS[@]}"; do
  claude plugin install "$p" \
    || echo "setup-plugins: $p を入れられなかった。別マーケットプレイスのものなら MARKETPLACE に追加する" >&2
done
