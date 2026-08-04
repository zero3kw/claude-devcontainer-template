#!/bin/bash
# block-polling-wait.sh のテスト。フックの正規表現をいじったら実行する。
#   bash .claude/hooks/block-polling-wait.test.sh
HOOK="$(dirname "$0")/block-polling-wait.sh"

cases() {
  cat <<'JSONL'
{"expect":"DENY","why":"フォアグラウンドの until+sleep ポーリング","tool_input":{"command":"until curl -sf localhost:3000; do sleep 1; done","run_in_background":false}}
{"expect":"ALLOW","why":"同じループでも run_in_background なら通す","tool_input":{"command":"until curl -sf localhost:3000; do sleep 1; done","run_in_background":true}}
{"expect":"DENY","why":"CI 完了待ちの while+sleep","tool_input":{"command":"while ! gh run view 123 --json status --jq '.status==\"completed\"'; do sleep 30; done","run_in_background":false}}
{"expect":"DENY","why":"長い単発 sleep","tool_input":{"command":"sleep 300 && echo done","run_in_background":false}}
{"expect":"DENY","why":"境界値の sleep 60","tool_input":{"command":"sleep 60","run_in_background":false}}
{"expect":"DENY","why":"単位付き sleep 2m","tool_input":{"command":"sleep 2m; kubectl get pods","run_in_background":false}}
{"expect":"DENY","why":"パイプ後のループ内 sleep","tool_input":{"command":"aws s3 ls | while read -r l; do sleep 5; done","run_in_background":false}}
{"expect":"ALLOW","why":"短い sleep は通す","tool_input":{"command":"sleep 5 && curl localhost:3000","run_in_background":false}}
{"expect":"ALLOW","why":"sleep 59 は上限未満","tool_input":{"command":"sleep 59","run_in_background":false}}
{"expect":"ALLOW","why":"普通のコマンド","tool_input":{"command":"npm test -- --watch=false","run_in_background":false}}
{"expect":"ALLOW","why":"sleep のない while ループ","tool_input":{"command":"cat list.txt | while read -r f; do wc -l \"$f\"; done","run_in_background":false}}
{"expect":"ALLOW","why":"sleep を含む別の語に反応しない","tool_input":{"command":"grep -r sleepless src/ && ./sleeper --help","run_in_background":false}}
JSONL
}

fail=0
n=0
while IFS= read -r line; do
  n=$((n + 1))
  expect=$(printf '%s' "$line" | jq -r '.expect')
  why=$(printf '%s' "$line" | jq -r '.why')
  cmd=$(printf '%s' "$line" | jq -r '.tool_input.command')
  out=$(printf '%s' "$line" | "$HOOK")
  got="ALLOW"
  [ -n "$out" ] && got=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision | ascii_upcase')
  if [ "$got" = "$expect" ]; then
    printf 'ok   %-6s %s\n' "$got" "$why"
  else
    printf 'FAIL want=%s got=%s | %s\n     cmd: %s\n' "$expect" "$got" "$why" "$cmd"
    fail=$((fail + 1))
  fi
done < <(cases)

echo "--- $((n - fail))/$n passed"
exit $fail
