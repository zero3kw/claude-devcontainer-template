# claude-devcontainer-template

Dev Container 内で Claude Code を動かすテンプレートリポジトリ。

## 使い方

### 1. テンプレートから新しいリポジトリを作る

GitHub "Use this template" から作成、ローカルなら:

```sh
PROJECT=$(date +%Y%m%d)
git clone https://github.com/zero3kw/claude-devcontainer-template.git "$PROJECT"
cd "$PROJECT" && rm -rf .git && git init
```

### 2. コンテナを開く

VS Code で `Dev Containers: Reopen in Container`。

### 3. コンテナ内で初回ログイン

```sh
claude          # ブラウザが開くので Claude アカウントで認証
codex           # ChatGPT アカウントか OPENAI_API_KEY で認証。不要なら devcontainer.json の codex を含む行を削除
gh auth login   # git push / gh pr を使うなら
```

ホストの `~/.gitconfig` と ssh-agent の鍵は Dev Containers 拡張が自動で渡す。コミット作者名はコンテナ内で直しても再作成で消えるので、ホスト側で設定する。

```sh
git config --global user.name "..."    # ホストで実行する
git config --global user.email "..."
```

### 4. CLAUDE.md を書く

[CLAUDE.md](CLAUDE.md) の空欄を埋める。手で書かなくても、作業後に `/claude-md-management:revise-claude-md` を実行すれば、その回で使ったコマンドや踏んだ落とし穴が追記される。

`<!-- -->` がある節は、それが書き方の指示なので埋めたら消す。中身のほうは、Conventions / Gotchas / Agents / Asking the user / Waiting and monitoring がプロジェクト非依存の運用ルールなので残してよい。

## ディレクトリ構成

プロジェクトのコードは submodule として `submodules/` に置き、編集はその worktree を `_worktrees/` に作って行う。

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

先頭が `_` のディレクトリは gitignore 済みで、git に入るのは `.gitkeep` だけ。ソートでまとまるので、追跡される `submodules/` と一目で区別が付く。

`_` の5つを親リポジトリの直下に置くのは、worktree を破棄してもブランチを切り替えても残る場所がここだけだから。

親リポジトリ自身（`.claude/`、`.devcontainer/`、CLAUDE.md、README）は worktree を作らず直接編集してよい。clone 直後は `git submodule update --init --recursive` を先に実行する。作成手順と落とし穴は [CLAUDE.md](CLAUDE.md) の Conventions にある。

## 設定済みのもの

### プラグイン

[.claude/settings.json](.claude/settings.json) の `enabledPlugins` で5つ有効化済み。

- [`context7`](https://github.com/anthropics/claude-plugins-official/tree/main/external_plugins/context7) — ライブラリ最新ドキュメント参照。学習データの古さの影響回避
- [`feature-dev`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/feature-dev) — 機能開発ワークフローのスキル + エージェント
- [`security-guidance`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/security-guidance) — Claude の変更を都度レビュー、脆弱性をその場で修正させる
- [`claude-md-management`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-md-management) — CLAUDE.md 採点 + 修正
- [`genshijin`](https://github.com/InterfaceX-co-jp/genshijin) — 応答を日本語超圧縮モード化しトークン削減

プラグインを足すときは `enabledPlugins` に1行追記。公式マーケットプレイス以外なら [.devcontainer/setup-plugins.sh](.devcontainer/setup-plugins.sh) の `MARKETPLACES` にもリポジトリを追記する。`genshijin` がその例。

### genshijin

genshijin が有効なので、応答は敬語なしの短文で返る。

- その場で強度変更 → `/genshijin 丁寧` / `/genshijin 通常` / `/genshijin 極限`
- 既定強度変更 → [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) の `containerEnv` に `"GENSHIJIN_DEFAULT_MODE": "polite"`（`polite` / `normal` / `extreme`）
- 黙らせる → 同じく `"GENSHIJIN_DEFAULT_MODE": "off"`
- 外す → `enabledPlugins` の行 + setup-plugins.sh の `MARKETPLACES` の genshijin を削除

### フック

[.claude/settings.json](.claude/settings.json) に1つ登録済み。不要なら `hooks` から削除。

- [log-bash.sh](.claude/hooks/log-bash.sh) — Bash 実行毎、コマンド + 出力を `.claude/logs/bash/` に1実行1ファイルで保存。`NAME=値` と `Authorization` ヘッダに加え、`sk-ant-` や `gho_` のようなトークンの形と URL 内のパスワードもマスクする。出力は gitignore 済み

### エージェント

[.claude/agents/](.claude/agents/) にサブエージェントを2つ登録済み。どちらも編集ツールを持たない。不要ならファイルを削除。

- [investigator.md](.claude/agents/investigator.md) — コードの位置と依存関係を `path:line` で返す。`Read` / `Grep` / `Glob` のみで読み取り専用。探索は機械的なので haiku
- [reviewer.md](.claude/agents/reviewer.md) — 差分を1指摘1行、重大度付きで返す。`git diff` を使うので `Bash` を持ち、書き込みは指示で止めている。判断が要るので sonnet

`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` も有効。複数の Claude を teammate として並列に動かせる。使い分けと制約は [CLAUDE.md](CLAUDE.md) の Agents にある。

### 権限の設定

[.claude/settings.json](.claude/settings.json) の `permissions.defaultMode` を `bypassPermissions` 設定済み。

VS Code 拡張は別のゲートを持つ。`permissions.defaultMode` だけでは効かず、Bash 実行のたびに確認が出る。[.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) の `customizations.vscode.settings` で拡張側を開けてある。ターミナルの `claude` だけ使うなら、拡張のゲートを通らないのでこの設定は要らない。

- `claudeCode.allowDangerouslySkipPermissions` — Bypass permissions をモード選択肢に出す
- `claudeCode.initialPermissionMode` — 新規会話の開始モード

確認を挟まないので、コンテナから出られる経路は塞ぐこと。信頼できないリポジトリを開くなら `bypassPermissions` か [docker-outside-of-docker](#コンテナ内から-docker-を使う) のどちらかを外す。

例外が `permissions.ask` で、このルールだけは `bypassPermissions` でも確認が出る。狙いは、自分のものではないリポジトリへの書き込みと、機微情報を外へ出すこと。`git push` と gh の書き込み系、別コンテナへ入る `docker exec`、それに `rm -rf` を登録済み。

前方一致なので塞げない経路が残る。`bash -c 'git push'` のようにラッパを噛ませた場合と、`curl` で外部へ送る場合。`Bash(curl *)` にすると読み取りまで止まって使えないので、通信を絞るなら下の [ネットワーク遮断](#ネットワーク遮断を入れる)を使う。

`defaultMode` に指定できる値:

- `bypassPermissions` — 確認しない。`permissions.allow` は参照されないが、`deny` と `ask` は効く
- `auto` — 確認の代わりに classifier が実行前に各アクションを判定する。Pro / Max / Team / Enterprise のみ。プロジェクト設定に書いても無視されるので、`~/.claude/settings.json` に書く
- `acceptEdits` — 読み取り、ファイル編集、一般的なファイルシステムコマンド（`mkdir`、`touch`、`mv`、`cp` など）が確認なし
- `default` — 読み取りのみ確認なし。UI 上のラベルは Manual。`defaultMode` の行削除時もこれ
- `plan` — 提示された計画を承認するまで編集がブロックされる
- `dontAsk` — `permissions.allow` に載っているものだけ実行し、それ以外は確認せず拒否する。settings.json の `allow` に基本ツールを登録済みなのは、このモードへ切り替えたとき用。`Shift+Tab` の循環には現れず、`--permission-mode dontAsk` で指定する

同じキーを `.claude/settings.local.json`（gitignore 済み）に書くと、そちらが優先される。

## カスタマイズ

### 言語ランタイムを足す

[.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) の `features` に追記。コメントアウトで Go / Python / uv の例あり。Node は Claude Code 自体が使うので削除禁止。

features に無いシステムパッケージは [.devcontainer/Dockerfile](.devcontainer/Dockerfile) の `apt-get install` へ。

### LSP を足す

[.claude/settings.json](.claude/settings.json) の `enabledPlugins` に LSP プラグインを追加する。言語サーバのバイナリはプラグインに含まれないので、別途入れる:

- TypeScript — `typescript-lsp` / 要 `typescript-language-server` / `postCreateCommand` に `npm i -g typescript-language-server typescript`
- Python — `pyright-lsp` / 要 `pyright-langserver` / `postCreateCommand` に `npm i -g pyright`
- Go — `gopls-lsp` / 要 `gopls` / features の `go:1` が同梱
- Rust — `rust-analyzer-lsp` / 要 `rust-analyzer` / features の `rust:1` が同梱

npm 製の言語サーバは `postCreateCommand` に足す。features は image のビルド後に入るので、Dockerfile の時点で `npm` が無い。

### コンテナ内から docker を使う

`docker-outside-of-docker` 導入済み。Docker in Docker ではなく、コンテナ内の `docker` コマンドがホストの Docker を操作する。注意2点:

- バインドマウントのパスはホスト基準。コンテナ内で `docker run -v $(pwd):/x` してもホスト側の同じパスが解決されるので、ワークスペース以外のパスは期待通りにならない
- docker socket はホスト root 相当権限。信頼できないリポジトリでは外すこと

DB 等のサイドカーが常時必要なら `docker-compose.yml` 記述 + `devcontainer.json` の `build` を `dockerComposeFile` + `service` に差し替え。その場合 `mounts` / `containerEnv` は compose 側の `volumes` / `environment` へ移動。

### ネットワーク遮断を入れる

公式リファレンス実装の `init-firewall.sh` を使うと、許可ドメイン以外への通信を遮断できる。

[`init-firewall.sh`](https://github.com/anthropics/claude-code/blob/main/.devcontainer/init-firewall.sh) を持ってきて、`runArgs` に `--cap-add=NET_ADMIN --cap-add=NET_RAW`、`postStartCommand` に `sudo /usr/local/bin/init-firewall.sh` を追記。

## 認証情報を消したいとき

先にコンテナを削除する。ホストで `docker rm -f <container>`、または VS Code の `Dev Containers: Clean Up Dev Containers`。停止だけでは volume は解放されない。

```sh
PROJECT=<作成時のディレクトリ名>
docker volume ls --filter name="$PROJECT"          # 消す前に何が消えるか見る
docker volume rm $(docker volume ls -q --filter name="$PROJECT")
```

## 参考

- [Settings](https://code.claude.com/docs/en/settings) — `.claude/settings.json` に書けるキー一覧
- [Permission modes](https://code.claude.com/docs/en/permission-modes) — `defaultMode` の各値の挙動
- [Worktrees](https://code.claude.com/docs/en/worktrees) — `--worktree`、`.worktreeinclude`、後片付け
- [VS Code](https://code.claude.com/docs/en/vs-code) — 拡張側の設定一覧
- [Best practices](https://code.claude.com/docs/en/best-practices) — CLAUDE.md の書き方、並列セッション
- [devcontainer リファレンス実装](https://github.com/anthropics/claude-code/tree/main/.devcontainer) — 公式の Dev Container 設定一式
- [Sharing Git credentials](https://code.visualstudio.com/remote/advancedcontainers/sharing-git-credentials) — gitconfig と SSH 鍵がコンテナに渡る仕組み、agent 転送が効かないときの前提条件
