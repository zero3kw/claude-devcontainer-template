FROM mcr.microsoft.com/devcontainers/base:debian

# 言語ランタイム (node など) は devcontainer.json の features 側で入れる。
# ここには features に無いシステムパッケージだけを書く。
# jq / curl / git / less / tree / ps / make / gcc / locales はベースイメージに同梱済み。
#
# python3 は Claude のワンライナー用。プロジェクトの言語として Python を使うなら
# features の python:1 か uv を足す
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    ripgrep \
    fzf \
    && rm -rf /var/lib/apt/lists/*

# ロケールとタイムゾーン。ベースイメージは en_US.UTF-8 しか有効にしていない
RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime \
    && echo "Asia/Tokyo" > /etc/timezone \
    && sed -i -E 's/# (ja_JP.UTF-8)/\1/' /etc/locale.gen \
    && locale-gen
ENV LANG=ja_JP.UTF-8

# コンテナ内かどうかをスクリプトから判定できるようにする
ENV DEVCONTAINER=true

# 名前付き volume のマウント先をイメージ側に vscode 所有で用意しておく。
# こうしないと volume の初回作成時に root 所有になり、書き込めなくなる。
# この一覧は devcontainer.json の mounts と一致させること。
#
# あわせて bash 履歴を volume 側に書く。history -a で実行のたびに追記する。
# PROMPT_COMMAND はベースイメージも使うので上書きせず後ろに足す
RUN mkdir -p /home/vscode/.claude /home/vscode/.codex /home/vscode/.config/gh /commandhistory \
    && chown -R vscode:vscode /home/vscode/.claude /home/vscode/.codex /home/vscode/.config /commandhistory \
    && cat >> /home/vscode/.bashrc <<'EOF'
PROMPT_COMMAND+=('history -a')
export HISTFILE=/commandhistory/.bash_history
source /usr/share/doc/fzf/examples/key-bindings.bash
EOF
