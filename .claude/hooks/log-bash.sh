#!/bin/bash
# PostToolUse(Bash) フック：実行ごとに 1 ファイル（プレーンテキスト）で
# コマンドと出力を保存する。機微情報（x-api-key・各種 KEY/TOKEN）はマスク。
# 保存先は logs/bash/<UTC日付>/<セッションID先頭8桁>/<UTC時刻>-<ns>.txt。
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
BODY=$(printf '%s' "${OUT#*$'\n'}" | sed -E \
  -e 's/(x-api-key:[[:space:]]*)[^"'"'"' ]+/\1***/Ig' \
  -e 's/(SECRET|PASSWORD|TOKEN|API[_-]?KEY|ACCESS[_-]?KEY)=[^ ]*/\1=***/Ig')

STAMP=$(date -u +'%Y%m%dT%H%M%SZ %N')
TS=${STAMP%% *}
NS=${STAMP#* }

DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/logs/bash/${TS%%T*}/${SID:0:8}"
[ -d "$DIR" ] || mkdir -p "$DIR" 2>/dev/null || exit 0

printf '%s\n' "$BODY" > "$DIR/${TS#*T}-$NS.txt" 2>/dev/null

exit 0
