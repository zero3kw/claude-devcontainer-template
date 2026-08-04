#!/bin/bash
# PreToolUse(Bash) フック：フォアグラウンドの sleep ポーリング待ちをブロックして
# Monitor / run_in_background に誘導する。CLAUDE.md「待機と監視」の機械可読版。
#
# 通すもの:
#   - run_in_background の待機（条件が成立したら終了する until ループ = 正しい使い方）
#   - 60秒未満の単発 sleep
# 止めるもの:
#   - フォアグラウンドの while/until + sleep ループ
#   - 60秒以上の単発 sleep（2m, 1h のような単位付きも含む）
#
# Bash 実行のたびに走るので外部プロセスを増やさない。jq は1回だけ、
# マッチは bash 組み込みの [[ =~ ]] で済ませる。

# 1行目 = run_in_background、2行目以降 = command
J=$(jq -r '(.tool_input.run_in_background // false | tostring), (.tool_input.command // "")')
BG=${J%%$'\n'*}
CMD=${J#*$'\n'}

[ "$BG" = "true" ] && exit 0

deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' \
    "$(jq -Rs . <<<"$1")"
  exit 0
}

# 語境界。パイプや括弧の直後に来るコマンドも拾う
B='(^|[;&|(){}[:space:]])'

if [[ $CMD =~ ${B}(while|until)[[:space:]] ]] && [[ $CMD =~ ${B}sleep[[:space:]] ]]; then
  deny "フォアグラウンドの sleep ポーリングループは禁止。1回だけ通知が欲しいなら Bash の run_in_background で、条件が成立したら終了する until ループを使う。起きるたびに通知が欲しいなら Monitor ツールを使う。CLAUDE.md の「待機と監視」を参照。"
fi

if [[ $CMD =~ ${B}sleep[[:space:]]+([6-9][0-9]|[0-9]{3,}|[0-9.]+[mh])([[:space:]]|\;|$) ]]; then
  deny "60秒以上の sleep で待たない。状態変化を待つなら Monitor ツール、完了を1回だけ知りたいなら Bash の run_in_background を使う。CLAUDE.md の「待機と監視」を参照。"
fi

exit 0
