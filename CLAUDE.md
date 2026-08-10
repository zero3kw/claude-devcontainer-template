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

<!-- ディレクトリの役割のうち、名前から自明でないものだけ -->

## Conventions

<!-- コードから読み取れない前提・落とし穴だけを書く。git log で分かることは書かない -->

ドキュメントには読者が判断に使うものだけ書く — 変更の経緯、現状から自明なこと、保守側の都合は書かない。1行ごとに「消したら読者が困るか」を問い、困らないなら消す。絵文字と太字は使わず、状態や可否は「済」「不可」のような語で書き、重要な点は文の先頭に置く。

補足説明を括弧に入れない — 判断に要るなら本文の文に組み込み、要らないなら消す。値の列挙と「gitignore 済み」のような短い属性は例外。

IMPORTANT: submodule のコード変更は必ず worktree で行う — 単独作業でも submodule のチェックアウトでは編集しない。ブランチの切り替えと未コミットの変更が、並列セッションの作業とも後続の作業とも衝突する。

例外は親リポジトリ自身（`.claude/`、`.devcontainer/`、CLAUDE.md、README）。worktree のコストが変更量に見合わないので、そのまま編集してよい。

submodule は `submodules/<submodule>/`、その worktree は `_worktrees/<submodule>-<branch>/` に置く。どちらも親リポジトリのルート直下。

worktree の作成から削除までの手順。親リポジトリのルートで実行する。

```bash
SUB=<submodule>
BRANCH=<branch>
NAME=$SUB-$BRANCH
git -C submodules/$SUB fetch origin
git -C submodules/$SUB worktree add ../../_worktrees/$NAME origin/main -b $BRANCH
cp submodules/$SUB/.env _worktrees/$NAME/ 2>/dev/null   # gitignore したファイルは worktree に入らない
# ここで EnterWorktree に path を渡してセッションを移す
# 終了後、ExitWorktree の keep で親に戻ってから次を実行する。
# worktree にいる間は submodules/ への git -C が隔離チェックでブロックされる
git -C submodules/$SUB worktree remove ../../_worktrees/$NAME   # 自動削除されない
```

`worktree add` のパスは submodule から見た相対なので `../../` になる。

親リポジトリで `claude --worktree` や `claude --bg` が作るのは親リポジトリの worktree で、その中の submodule ディレクトリは空になる。`git worktree list` も親リポジトリと submodule で別なので、submodule 分は `git -C submodules/<submodule> worktree list` で見る。

`worktree.baseRef` や `.worktreeinclude` のような worktree の作り方の設定は、Claude Code が作る worktree にしか効かない。上の手動 `git worktree add` は対象外なので、基点は `origin/main` のように毎回明示する。

`EnterWorktree` に `path` を渡して入った worktree は、`ExitWorktree` の `remove` では消せない。

調査・分析の作業場所 `_data/` `_references/` `_reports/` `_drafts/` は親リポジトリのルート直下に置く — submodule のチェックアウトや worktree の中に置くと、worktree の破棄とブランチの切り替えで消える。先頭が `_` のディレクトリは gitignore 済みという印で、`_worktrees/` も同じ。

`_data/raw/` は取得したままにして編集しない。加工結果は `_data/processed/` に書く。

分析のコードとノートブックは submodule 側に置く。バージョン管理の対象なので、上の gitignore されるディレクトリには入れない。

## Gotchas

<!-- 一度ハマったら二度目を防ぎたいものを書く -->

IMPORTANT: submodule を init する前に `git -C submodules/<submodule>` を叩かない — ディレクトリが空の間、git は親リポジトリを対象にする。エラーにならないまま、親リポジトリに意図しない worktree やブランチが作られる。clone 直後に必ず次を実行する。

```bash
git submodule update --init --recursive
```

他のコンテナへの接続は compose のネットワークに参加して直結する — `host.docker.internal` はホストの公開ポート経由になり、Docker Desktop のポート転送を通る。この転送は大量のデータを読み出すと固まることがあり、直結のほうが数倍速い。

```bash
docker ps --format '{{.Names}}'   # このコンテナ名を確認
docker network connect <COMPOSE_PROJECT_NAME>_default <this-container>
# 以後 <service>:<container-port> で届く。ホストへのポート公開は不要
```

参加は devcontainer を作り直すと消えるので、そのつど実行する。compose 側に external network として宣言する方法は使わない — ネットワークが無いと devcontainer が起動できなくなる。

## Agents

### 使い分け

- 調査・探索・読み込み → サブエージェント。結果だけ返り、主コンテキストが汚れない
- 多観点で叩く（レビュー、仮説の競合、設計案の比較）→ agent teams。`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 有効済み
- 別ブランチで並列実装 → 手動 worktree + 別セッション。team ではやらない
- 長時間流して後で見る → `claude --bg`。親リポジトリの worktree で動くので submodule の作業には使えない

IMPORTANT: teammate に submodule のコード変更をさせない — 読み取り（調査・レビュー）のみ。teammate は lead と同じ cwd で動き `submodules/<submodule>/` を共有するので、編集すると worktree 規約が防いでいる失敗が lead と全 teammate で起きる。読み取りはブランチも作業ツリーも変えないので抵触しない。

### spawn 時

- lead の会話履歴は継承されない → 前提・対象・報告形式を spawn プロンプトに全部書く
- 観点は明示的に分ける。「3人でレビュー」ではなく「セキュリティ / 性能 / テスト網羅」
- 人数は3〜5人
- 定義済みのサブエージェントは `.claude/agents/` にある。`investigator` は位置と依存を `path:line` で返し、`Read` / `Grep` / `Glob` だけを持つ。`reviewer` は1指摘1行を重大度付きで返し、`git diff` のために `Bash` を持つ
- `tools` から編集ツールを外しても、`Bash` があれば書き込みは止まらない。上の submodule の制約は指示で支えていて、設定では担保されていない
- teammate は lead のモデルを継承しない。安いモデルで回すなら spawn プロンプトで指定する

teammate は lead の権限設定を継承する。このリポジトリは `bypassPermissions` なので承認プロンプトで止まらない。触ってよい範囲を spawn プロンプトに書く。

## Asking the user

確認は `AskUserQuestion` で選択肢にする。自由記述で聞くと、ユーザーが文章を打つ手間になる。聞くのは次の2つだけで、「テストを実行していい？」のような既定が明らかなことや、コード・git log を読めば分かることは聞かずに進める。

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
