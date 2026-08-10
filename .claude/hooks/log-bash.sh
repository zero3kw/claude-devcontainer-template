#!/bin/bash
# PostToolUse(Bash) フック：実行ごとに 1 ファイル（プレーンテキスト）で
# コマンドと出力を保存する。機微情報はマスクする。
# 保存先は logs/bash/<utc-date>/<session-id>/<utc-time>-<ns>.txt。
# エージェントを並列で動かすと同じ日に複数セッションのログが混ざるため、
# セッションで分ける。サブエージェントは親と同じ session_id を持つので
# 親のディレクトリに入る。
#
# Bash 実行のたびに走るので外部プロセスを増やさない。
# jq・sed・date はそれぞれ1回だけ呼ぶ。

# 1行目 = session_id、2行目以降 = 本文
OUT=$(jq -r '
  (.session_id // ""),
  ( "# SESSION\n\(.session_id // "")\n"
  + "\n# CWD\n\(.cwd // "")\n"
  + "\n# IN\n\(.tool_input.command // "")\n"
  + "\n# OUT\n\(.tool_response.stdout // "")"
  + (.tool_response.stderr // "" | if . == "" then "" else "\n" + . end)
  )')

SID=${OUT%%$'\n'*}
# 名前で消す規則と、値の形で消す規則の両方を通す
BODY=$(printf '%s' "${OUT#*$'\n'}" | sed -E \
  -e 's/(x-api-key:[[:space:]]*)[^"'"'"' ]+/\1***/Ig' \
  -e 's/(authorization:[[:space:]]*(bearer|token)[[:space:]]+)[^"'"'"' ]+/\1***/Ig' \
  -e 's/((SECRET|PASSWORD|PASSWD|CREDENTIAL|TOKEN|API[_-]?KEY|ACCESS[_-]?KEY|PRIVATE[_-]?KEY)[[:space:]]*=[[:space:]]*)("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]*)/\1***/Ig' \
  -e 's/((["'"'"']?(api[_-]?key|token|secret|password)["'"'"']?[[:space:]]*:[[:space:]]*["'"'"'])[^"'"'"']*)/\2***/Ig' \
  -e 's/sk-ant-[A-Za-z0-9_-]{10,}/sk-ant-***/g' \
  -e 's/gh[pousr]_[A-Za-z0-9]{20,}/gh_***/g' \
  -e 's/xox[baprs]-[A-Za-z0-9-]{10,}/xox-***/g' \
  -e 's/AKIA[0-9A-Z]{16}/AKIA***/g' \
  -e 's/eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}/eyJ***/g' \
  -e 's#([a-z][a-z0-9+.-]*://[^:/@[:space:]]+):[^@[:space:]]+@#\1:***@#Ig')

STAMP=$(date -u +'%Y%m%dT%H%M%SZ %N')
TS=${STAMP%% *}
NS=${STAMP#* }

DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/logs/bash/${TS%%T*}/${SID}"
[ -d "$DIR" ] || mkdir -p "$DIR" 2>/dev/null || exit 0

printf '%s\n' "$BODY" > "$DIR/${TS#*T}-$NS.txt" 2>/dev/null

exit 0
