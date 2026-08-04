# claude-devcontainer-template

Dev Container の中で Claude Code を動かすためのテンプレートリポジトリ。

- ベースイメージ: `mcr.microsoft.com/devcontainers/base:debian`（ja_JP.UTF-8 / Asia/Tokyo）
- Claude が Bash で使う道具は同梱済み: `python3` `ripgrep`（追加）/ `jq` `curl` `git` `less` `tree` `ps` `make` `gcc`（ベースイメージ同梱）
- 人間向けに `fzf`（Ctrl+R の履歴検索）
- Claude Code は公式 feature（`ghcr.io/anthropics/devcontainer-features/claude-code`）で導入
- Codex CLI も同梱（`npm install -g @openai/codex`）。認証は `~/.codex` に永続化
- 認証情報（`~/.claude` と `gh`）とシェル履歴は名前付き volume で永続化。コンテナを作り直してもログインし直さなくてよい
- 認証方式は Claude サブスクリプション（OAuth）

[公式のリファレンス実装](https://github.com/anthropics/claude-code/tree/main/.devcontainer)に沿った構成。egress を絞る `init-firewall.sh` だけは入れていない（許可ドメインの維持が要り、外部 API を叩くプロジェクトで詰まるため。要るなら[足せる](#ネットワーク遮断を入れたくなったら)）。

## 使い方

### 1. テンプレートから新しいリポジトリを作る

GitHub の "Use this template" から作るか、ローカルなら:

```sh
git clone <this-repo> my-project && cd my-project && rm -rf .git && git init
```

### 2. CLAUDE.md を書く

[CLAUDE.md](CLAUDE.md) の空欄を埋める。ここ以外に手で書き換えるところは無い。各節の HTML コメントは書き方のガイドなので、埋めたら消す。末尾の「確認の取り方」「待機と監視」だけはプロジェクトを問わず効く運用ルールなので、そのまま残してよい。

自力で埋めなくても、同梱の `claude-md-management` に採点させて直させることもできる。作業したあとに `/claude-md-management:revise-claude-md` を叩けば、その回で分かったこと（使ったコマンド、踏んだ地雷）を追記してくれる。

- コンテナの表示名は `${localWorkspaceFolderBasename}` でディレクトリ名になる
- volume 名は `<ディレクトリ名>-claude-<devcontainerId>` の形。先頭がディレクトリ名なので `docker volume ls` で探せて、末尾の ID で同名ディレクトリの別リポジトリとも混ざらない

### 3. コンテナを開く

VS Code で `Dev Containers: Reopen in Container`。初回は Docker イメージのビルドと feature のインストールが走る。

### 4. コンテナ内で初回ログイン

```sh
claude          # ブラウザが開くので Claude アカウントで認証
codex           # 使うなら。ChatGPT アカウントか OPENAI_API_KEY で認証
gh auth login   # git push / gh pr を使うなら
```

いずれも volume に保存されるので、次回以降は不要。

ブラウザでの認証は済んだのにターミナルが待ち続ける場合は、エディタのポート転送が localhost へのコールバックを返せていない。ブラウザに表示されたコードを `Paste code here if prompted` に貼れば進む。

## カスタマイズ

### 言語ランタイムを足す

[.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) の `features` に追記する。コメントアウトで Go / Python / uv の例を置いてある。Node は Claude Code 本体が使うので消さないこと。

### コンテナ内から docker を使う

`docker-outside-of-docker` を入れてあるので、コンテナ内の `docker` コマンドがホストの Docker を操作する（Docker in Docker ではない）。テスト用の DB を上げる、イメージをビルドするといった用途に使える。

2点だけ注意:

- **バインドマウントのパスはホスト基準**。コンテナ内で `docker run -v $(pwd):/x` としても、ホスト側の同じパスが解決されるので、ワークスペース以外のパスは期待通りにならない
- **docker socket はホストの root 相当の権限**。信頼できないリポジトリでは外すこと（`features` から1エントリ消すだけ）

### システムパッケージを足す

features に無いものだけ [.devcontainer/Dockerfile](.devcontainer/Dockerfile) の `apt-get install` に足す。

同梱の `python3` は Claude のワンライナー用（pip は入れていない）。プロジェクトの言語として Python を使うなら features の `python:1` か `uv` を足すこと。

### DB などのサイドカーが要るとき

`docker-compose.yml` を書いて `devcontainer.json` の `build` を `dockerComposeFile` + `service` に差し替える。その場合 `mounts` / `containerEnv` は compose 側の `volumes` / `environment` に移す。

### ネットワーク遮断を入れたくなったら

公式の [`init-firewall.sh`](https://github.com/anthropics/claude-code/blob/main/.devcontainer/init-firewall.sh) を持ってきて、`runArgs` に `--cap-add=NET_ADMIN --cap-add=NET_RAW`、`postStartCommand` に `sudo /usr/local/bin/init-firewall.sh` を足す。

ホストの `~/.ssh` やクラウド認証情報をコンテナにマウントするのは、firewall の有無に関わらず避けること。コンテナ内で `gh auth login` して volume に持たせるほうが安全。

### LSP を足す（言語が決まったら真っ先にやる）

[.claude/settings.json](.claude/settings.json) に LSP プラグインを足すと、Claude が編集するたびに言語サーバから型エラーを受け取り、grep ではなく定義ジャンプで参照を辿れるようになる。**言語サーバのバイナリはプラグインに含まれない**ので自分で入れる必要があり、そこは devcontainer の得意分野。

「バイナリ + `enabledPlugins`」の2点セットで入れる:

| 言語 | プラグイン | 必要なバイナリ | バイナリの入れ方 |
| --- | --- | --- | --- |
| TypeScript | `typescript-lsp` | `typescript-language-server` | `postCreateCommand` に `npm i -g typescript-language-server typescript` |
| Python | `pyright-lsp` | `pyright-langserver` | `postCreateCommand` に `npm i -g pyright` |
| Go | `gopls-lsp` | `gopls` | features の `go:1` が同梱 |
| Rust | `rust-analyzer-lsp` | `rust-analyzer` | features の `rust:1` が同梱 |

**npm 製の言語サーバを Dockerfile に書いてはいけない。** features は Dockerfile のビルド後に適用されるので、ビルド時点では node も npm も存在しない。`postCreateCommand` に足すこと（codex がそうしている）。

Go の例:

```jsonc
// .devcontainer/devcontainer.json
"features": { "ghcr.io/devcontainers/features/go:1": { "version": "1.26" } }
```
```jsonc
// .claude/settings.json
"enabledPlugins": { "gopls-lsp@claude-plugins-official": true }
```

バイナリが無いと `/plugin` の Errors タブに `Executable not found in $PATH` が出る。大きなリポジトリでは `rust-analyzer` や `pyright` がメモリを食うので、重いと感じたら外す。

### 権限プロンプトを減らす

[.claude/settings.json](.claude/settings.json) の `permissions.allow` に read-only 系のコマンドを入れてある。プロジェクト共通で許可したいものはここへ、自分専用のものは `.claude/settings.local.json`（gitignore 済み）へ。

## 同梱しているもの

### プラグイン

[.claude/settings.json](.claude/settings.json) の `enabledPlugins` で3つ有効にしてある。リポジトリを clone した全員に効く（`/plugin` で個人的に外したい場合は `.claude/settings.local.json` 側で `false` にする）。

| プラグイン | 何をするか |
| --- | --- |
| `context7` | ライブラリの最新ドキュメントを引く。学習データの古さに引きずられなくなる |
| `feature-dev` | 機能開発ワークフローのスキルとエージェント |
| `security-guidance` | Claude の変更を都度レビューし、脆弱性をその場で直させる |
| `claude-md-management` | CLAUDE.md を採点して直す。`/claude-md-management:revise-claude-md` でセッションの学びを追記できる |

いずれも公式マーケットプレイス（`claude-plugins-official`）のもので、言語に依存しない。言語固有のものは上の [LSP を足す](#lsp-を足す言語が決まったら真っ先にやる)を参照。

`enabledPlugins` は「有効にする」宣言でしかなく、**書いただけではプラグインは入らない**。そこで [.devcontainer/setup-plugins.sh](.devcontainer/setup-plugins.sh) を `postCreateCommand` で回し、この設定を読んで実体を入れている。増やしたいときは `enabledPlugins` に1行足すだけでよく、スクリプトは触らなくていい。

インストール先は `~/.claude`（volume）なので、リビルドしても入れ直しにはならない。

### Bash 実行ログのフック

[.claude/hooks/log-bash.sh](.claude/hooks/log-bash.sh) を `PostToolUse(Bash)` に登録済み。Claude が Bash を実行するたび、コマンドと出力を1実行1ファイルで残す。

```
.claude/logs/bash/<UTC日付>/<セッションID先頭8桁>/<UTC時刻>-<ns>.txt
```

- 並列エージェントのログが混ざらないようセッション単位で分ける（サブエージェントは親と同じ ID なので親の下に入る）
- `x-api-key` と `SECRET` / `PASSWORD` / `TOKEN` / `API_KEY` / `ACCESS_KEY` の値はマスクして書く
- 出力は gitignore 済み。要らなければ `.claude/settings.json` の `hooks` を消す

`jq` に依存するが、ベースイメージに同梱されている。

### ポーリング待ちをブロックするフック

[.claude/hooks/block-polling-wait.sh](.claude/hooks/block-polling-wait.sh) を `PreToolUse(Bash)` に登録済み。長時間待ちを `Bash` の `sleep` ループでやらせず `Monitor` に誘導するためのもので、[CLAUDE.md](CLAUDE.md) の「待機と監視」に書いた運用ルールの機械可読版。文章のルールと違って実際にコマンドを拒否できる。

拒否時は `permissionDecision: "deny"` と理由を返すので、Claude はその場で `Monitor` か `run_in_background` に書き換えられる。フォアグラウンドの `while`/`until` + `sleep` と 60 秒以上の `sleep` が対象で、`run_in_background` の待機は通る。

判定の全ケースは [block-polling-wait.test.sh](.claude/hooks/block-polling-wait.test.sh) にある。正規表現でコマンドを見ているので、条件をいじったら回すこと:

```sh
bash .claude/hooks/block-polling-wait.test.sh
```

### Codex を使う

`codex` はコンテナに入れてあるので、初回だけ `codex` を叩いて認証する。ChatGPT アカウントでのログインか、`OPENAI_API_KEY` を渡す方法のどちらでもよい。API キーで渡すなら `.env`（gitignore 済み）に書いて `runArgs` の `--env-file` で読ませる。

公式の devcontainer feature が無いため `postCreateCommand` の npm で入れている。バージョンを固定したいなら `@openai/codex@X.Y.Z` にする。要らなければ `postCreateCommand` の `codex` の行と、`~/.codex` の volume を消す。

## 認証情報を消したいとき

volume ごと消す。名前の先頭はディレクトリ名なので絞り込める:

```sh
docker volume ls --filter name=my-project
docker volume rm $(docker volume ls -q --filter name=my-project)
```
