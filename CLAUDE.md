# CLAUDE.md

## Overview

<!-- 何を作っているか。README を読めば分かることは書かない -->

## Commands

<!-- 実プロジェクトでは必ず埋める。Claude が自力で検証できる手段がないと、
     「できたように見える」以外に作業を止める条件がなくなる -->

| 目的 | コマンド |
| --- | --- |
| セットアップ | |
| ビルド | |
| テスト | |
| Lint / Format | |

## Layout

```
submodules/<submodule>/           プロジェクトのコード。git submodule add で追加
_worktrees/<submodule>-<branch>/  編集用の worktree
_data/raw/                        取得したままのデータ。編集しない
_data/processed/                  加工後のデータ
_references/                      調査で読む外部資料
_reports/                         分析の成果物
_drafts/                          下書きの md
.claude/worktrees/                Claude Code が自動で作る worktree。gitignore 済み
```

## Conventions

<!-- コードから読み取れない前提・落とし穴だけを書く。git log で分かることは書かない -->

設定変更・カスタマイズ・文書改訂は Claude が実行する。人間に手作業を求めてよいのは、ホストでしか実行できない操作だけ。カスタマイズの手順は README にある。

IMPORTANT: submodule のコード変更は必ず worktree で行う — 単独作業でも submodule のチェックアウトでは編集しない。ブランチの切り替えと未コミットの変更が、並列セッションの作業とも後続の作業とも衝突する。

例外は親リポジトリ自身（`.claude/`、`.devcontainer/`、CLAUDE.md、README）。worktree のコストが変更量に見合わないので、そのまま編集してよい。

worktree の作成から削除までの手順は `worktree` skill にある。

親リポジトリで `claude --worktree` や `claude --bg` が作るのは親リポジトリの worktree で、その中の submodule ディレクトリは空になる。`git worktree list` も親リポジトリと submodule で別なので、submodule 分は `git -C submodules/<submodule> worktree list` で見る。

## Gotchas

<!-- 一度ハマったら二度目を防ぎたいものを書く -->

他のコンテナへの接続は compose のネットワークに参加して直結する — `host.docker.internal` はホストの公開ポート経由になり、Docker Desktop のポート転送を通る。この転送は大量のデータを読み出すと固まることがあり、直結のほうが数倍速い。

```bash
docker ps --format '{{.Names}}'   # このコンテナ名を確認
docker network connect <COMPOSE_PROJECT_NAME>_default <this-container>
# 以後 <service>:<container-port> で届く。ホストへのポート公開は不要
```

参加は devcontainer を作り直すと消えるので、そのつど実行する。ネットワークが無いと devcontainer が起動できなくなるため、compose 側に external network として宣言する方法は使わない。

## Agents

### 使い分け

- 調査・探索・読み込み → サブエージェント。結果だけ返り、主コンテキストが汚れない
- 多観点で叩く（レビュー、仮説の競合、設計案の比較）→ agent teams。`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 有効済み
- 別ブランチで並列実装 → 手動 worktree + 別セッション。team ではやらない
- 長時間流して後で見る → `claude --bg`。親リポジトリの worktree で動くので submodule の作業には使えない

IMPORTANT: teammate に submodule のコード変更をさせない — 読み取り（調査・レビュー）のみ。teammate は lead と同じ cwd で動き `submodules/<submodule>/` を共有するので、編集すると worktree 規約が防いでいる失敗が lead と全 teammate で起きる。

### spawn 時

- lead の会話履歴は継承されない → 前提・対象・報告形式を spawn プロンプトに全部書く
- 観点は明示的に分ける。「3人でレビュー」ではなく「セキュリティ / 性能 / テスト網羅」
- 人数は3〜5人
- submodule への Edit / Write は PreToolUse hook が拒否するが、`Bash` 経由の書き込みは通る。`Bash` を持つ teammate には触ってよい範囲を指示でも縛る
- teammate は lead のモデルを継承しない。安いモデルで回すなら spawn プロンプトで指定する

## Asking the user

ユーザへの確認は `AskUserQuestion` で選択肢にする。自由記述で聞くと、ユーザーが文章を打つ手間になる。聞くのは次の2つだけで、「テストを実行していい？」のような既定が明らかなことや、コード・git log を読めば分かることは聞かずに進める。

- 取り消しづらい操作の前 — push、PR や issue の作成・編集・コメント、外部への送信、ファイルやリソースの削除
- 分岐があるとき — 「タイトルだけ直す / コメントも足す / 両方やる」のように、選択肢そのものを提案の形にする

選択肢はそれぞれ1行で「選ぶと何が起きるか」を書く。推す案は先頭に置いて `(推奨)` を付ける。

## Waiting and monitoring

IMPORTANT: 長時間の状態変化待ちには `Monitor` を使う — `Bash` のフォアグラウンドな `until ... sleep ...` ループは禁止（CI 完了待ち、デプロイ待機、クラウドリソースの作成・削除待ちなど）。60秒未満で確実に終わる待機だけ通常の `sleep` を使ってよい。60秒以上の単発 `sleep` は Claude Code 組み込みが弾くが、フォアグラウンドのループは弾かれない。

通知が1回でよければ `Bash` の `run_in_background`、起きるたびに欲しければ `Monitor`。

監視を開始したら1行報告し、以降の報告には毎回、現在時刻と監視開始からの経過時間を付ける。監視対象をそれより前に起動していたなら、その起動時刻も書く。時刻の無い通知は、いつの出来事で何分待った結果なのか分からない。

```bash
START=$(date +%s)
el() { printf '%s (%dm%02ds elapsed)' "$(date '+%H:%M:%S')" $(( ($(date +%s)-START)/60 )) $(( ($(date +%s)-START)%60 )); }
echo "$(date '+%H:%M:%S') watch started"
# ... echo "$(el) done: $status"
```
