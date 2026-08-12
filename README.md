# claude-devcontainer-template

Dev Container 内で Claude Code を動かすテンプレートリポジトリ。プロジェクトのコードは submodule として `submodules/` に置き、編集はその worktree で行う。運用の詳細は [CLAUDE.md](CLAUDE.md) にある。

人間が行うのは下の使い方とホスト側の操作だけ。それ以外は Claude に依頼する。

## 使い方

### 1. テンプレートから新しいリポジトリを作る

GitHub "Use this template" から作成、ローカルなら:

```sh
PROJECT=""
PROJECT=${PROJECT:-$(date +%Y%m%d)}
git clone --depth 1 https://github.com/zero3kw/claude-devcontainer-template.git "$PROJECT"
cd "$PROJECT" && rm -rf .git && git init
git add -A && git commit -m "chore: init from claude-devcontainer-template"
```

### 2. コンテナを開く

VS Code で `Dev Containers: Reopen in Container`。

### 3. コンテナ内で初回ログイン

```sh
claude          # ブラウザが開くので Claude アカウントで認証
codex           # ChatGPT アカウントか OPENAI_API_KEY で認証。不要なら devcontainer.json の codex を含む行を削除
gh auth login   # git push / gh pr を使うなら
```

ホストの `~/.gitconfig` と ssh-agent の鍵は Dev Containers 拡張が自動で渡す。このリポジトリだけ別の作者名にするなら、[.claude/settings.local.json.example](.claude/settings.local.json.example) を `.claude/settings.local.json` にコピーして値を埋める。

### 4. CLAUDE.md を書く

[CLAUDE.md](CLAUDE.md) の更新は Claude に依頼する。作業後に `/claude-md-management:revise-claude-md` を実行すると、その回で使ったコマンドや踏んだ落とし穴が追記される。

### 5. 認証情報を消したいとき

先にコンテナを削除する。ホストで `docker rm -f <container>`、または VS Code の `Dev Containers: Clean Up Dev Containers`。停止だけでは volume は解放されない。

```sh
docker volume ls --filter name="$PROJECT"          # 消す前に何が消えるか見る
docker volume rm $(docker volume ls -q --filter name="$PROJECT")
```

## 設定済みのもの

### プラグイン

[.claude/settings.json](.claude/settings.json) の `enabledPlugins` で6つ有効化済み。

- [`context7`](https://github.com/anthropics/claude-plugins-official/tree/main/external_plugins/context7) — ライブラリ最新ドキュメント参照
- [`feature-dev`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/feature-dev) — 機能開発ワークフローの自動化
- [`security-guidance`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/security-guidance) — Claude の変更を都度レビュー、脆弱性をその場で修正させる
- [`claude-md-management`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-md-management) — CLAUDE.md の更新を自動化
- [`genshijin`](https://github.com/InterfaceX-co-jp/genshijin) — 応答を日本語超圧縮モード化しトークン削減
- [`codex-plugin-cc`](https://github.com/openai/codex-plugin-cc) — Codex レビュー

公式マーケットプレイス以外のプラグインは、[.devcontainer/setup-plugins.sh](.devcontainer/setup-plugins.sh) の `MARKETPLACES` にもリポジトリを追記する。`genshijin` がその例。

### genshijin

genshijin が有効なので、応答は敬語なしの短文で返る。強度の変更やオフの方法は [genshijin](https://github.com/InterfaceX-co-jp/genshijin) の README にある。

### フック

[.claude/settings.json](.claude/settings.json) に2つ登録済み。不要なら `hooks` から削除。

- [log-bash.sh](.claude/hooks/log-bash.sh) — Bash 実行毎、コマンド + 出力を `.claude/logs/bash/` に1実行1ファイルで保存。トークンや URL 内のパスワードはマスクする。出力は gitignore 済み
- [block-submodule-edit.sh](.claude/hooks/block-submodule-edit.sh) — `submodules/` 配下への Edit / Write を拒否する。worktree 規約の担保

### エージェント

[.claude/agents/](.claude/agents/) に investigator を登録済み。`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` も有効。使い分けと制約は [CLAUDE.md](CLAUDE.md) の Agents にある。

### 権限の設定

[.claude/settings.json](.claude/settings.json) の `permissions.defaultMode` を `bypassPermissions` に設定済み。VS Code 拡張には settings.json の `defaultMode` が効かないので、[.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) の `customizations.vscode.settings` でも拡張側を開けてある。

確認を挟まないので、コンテナから出られる経路は塞ぐこと。信頼できないリポジトリを開くなら `bypassPermissions` か [docker-outside-of-docker](#コンテナ内から-docker-を使う) のどちらかを外す。

`permissions.ask` の登録は `bypassPermissions` でも確認が出る。狙いは、自分のものではないリポジトリへの書き込みと、機微情報の持ち出しを確認制にすること。前方一致なので `bash -c 'git push'` のようなラッパは塞げない。`curl` での外部送信は[ネットワーク遮断](#ネットワーク遮断)が許可リスト外を止める。

`defaultMode` の値と挙動は [Permission modes](https://code.claude.com/docs/en/permission-modes) にある。

- settings.json の `allow` に基本ツールを登録済みなのは `dontAsk` へ切り替えたとき用
- `auto` はプロジェクト設定に書いても無視されるので、使うなら `~/.claude/settings.json` か `.claude/settings.local.json` に書く

### ネットワーク遮断

公式リファレンス実装の [init-firewall.sh](.devcontainer/init-firewall.sh) が起動のたびに走り、許可リスト外への通信を遮断する。codex の接続先と docker のアドレスプールをテンプレートで追加済み。新しい宛先を許可するにはスクリプトの domains の列挙に足す。

遮断を外すなら、devcontainer.json の `runArgs` と `postStartCommand`、Dockerfile の sudoers の行を削除。

## カスタマイズ

変更の反映は、`.claude/settings.json` が `/reload-plugins`、`.devcontainer/` がホストでの `Dev Containers: Rebuild Container`。

### 言語環境を足す

- ランタイム — [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) の `features` に追加する。一覧は [containers.dev](https://containers.dev/features)
- LSP — [Discover plugins](https://code.claude.com/docs/en/discover-plugins) の Code intelligence の手順で入れる

### コンテナ内から docker を使う

`docker-outside-of-docker` 導入済み。Docker in Docker ではなく、コンテナ内の `docker` コマンドがホストの Docker を操作する。

注意点:

- バインドマウントのパスはホスト基準。コンテナ内で `docker run -v $(pwd):/x` してもホスト側の同じパスが解決されるので、ワークスペース以外のパスは期待通りにならない
- docker socket はホスト root 相当権限。信頼できないリポジトリでは外すこと

DB 等のサイドカーが常時必要なら `docker-compose.yml` 記述 + `devcontainer.json` の `build` を `dockerComposeFile` + `service` に差し替え。その場合 `mounts` / `containerEnv` は compose 側の `volumes` / `environment` へ移動。

## 参考

- [Settings](https://code.claude.com/docs/en/settings) — `.claude/settings.json` に書けるキー一覧
- [Permission modes](https://code.claude.com/docs/en/permission-modes) — `defaultMode` の各値の挙動
- [Worktrees](https://code.claude.com/docs/en/worktrees) — `--worktree`、`.worktreeinclude`、後片付け
- [VS Code](https://code.claude.com/docs/en/vs-code) — 拡張側の設定一覧
- [Best practices](https://code.claude.com/docs/en/best-practices) — CLAUDE.md の書き方、並列セッション
- [Steering Claude Code](https://claude.com/ja/blog/steering-claude-code-skills-hooks-rules-subagents-and-more) — CLAUDE.md / rules / skills / hooks / subagents の使い分け
- [devcontainer リファレンス実装](https://github.com/anthropics/claude-code/tree/main/.devcontainer) — 公式の Dev Container 設定一式
- [Sharing Git credentials](https://code.visualstudio.com/remote/advancedcontainers/sharing-git-credentials) — gitconfig と SSH 鍵がコンテナに渡る仕組み、agent 転送が効かないときの前提条件
