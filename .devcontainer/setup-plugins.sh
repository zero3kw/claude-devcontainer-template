#!/usr/bin/env bash
# .claude/settings.json の enabledPlugins を実体化する。
#
# enabledPlugins は「有効にする」宣言でしかなく、書いただけではプラグインは入らない。
# scope は user (既定) なので ~/.claude volume に入り、リビルドをまたいで残る。
#
# 複数をまとめて渡すと最初の1つしか入らないので、1つずつ回す。
# 何度実行しても既存分は "already installed" で終わる。
#
# プラグインを enabledPlugins に足すときは、それが属する marketplace も
# add されている必要がある（下の MARKETPLACES を増やす）。
set -euo pipefail

SETTINGS=".claude/settings.json"
# owner/repo の短縮形で渡すと、SSH 鍵があるホストでは git@github.com: で clone しようとする。
# 素のコンテナには鍵が無いので、https の URL で固定する
MARKETPLACES=(
  "https://github.com/anthropics/claude-plugins-official.git"
  "https://github.com/InterfaceX-co-jp/genshijin.git"
  "https://github.com/openai/codex-plugin-cc.git"
)

[ -f "$SETTINGS" ] || exit 0

mapfile -t PLUGINS < <(jq -r '.enabledPlugins // {} | to_entries[] | select(.value) | .key' "$SETTINGS")
# mapfile はプロセス置換の終了コードを見ないので、jq が落ちても空配列で成功する
[ "${#PLUGINS[@]}" -gt 0 ] || echo "setup-plugins: $SETTINGS の enabledPlugins を読めなかった" >&2

# marketplace の add もプラグインの install も、失敗してもコンテナ自体は使える。
# 1つコケても残りを進めたいので、postCreate 全体は落とさない
for m in "${MARKETPLACES[@]}"; do
  claude plugin marketplace add "$m" \
    || echo "setup-plugins: marketplace $m を add できなかった" >&2
done

for p in "${PLUGINS[@]}"; do
  claude plugin install "$p" \
    || echo "setup-plugins: $p を入れられなかった。marketplace が MARKETPLACES にあるか確認する" >&2
done
