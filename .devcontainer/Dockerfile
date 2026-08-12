FROM mcr.microsoft.com/devcontainers/base:debian

# ここには features に無いシステムパッケージだけを書く。言語ランタイムは features 側。
# jq / curl / git / less / tree / ps / make / gcc / locales はベースイメージに同梱済み。
# python3 は Claude のワンライナー用
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    ripgrep \
    fzf \
    iptables \
    ipset \
    dnsutils \
    aggregate \
    && rm -rf /var/lib/apt/lists/*

# ネットワーク遮断。iptables / ipset / dnsutils / aggregate は上でこのスクリプトのために入れている。
# vscode の無制限 sudo を外し、sudo をこのスクリプトだけに絞る — エージェントが iptables を
# 直接叩いて遮断を解除できないようにするため。以後、パッケージの追加はコンテナ内の
# sudo apt-get ではなく、この Dockerfile に書いて Rebuild する
# /usr/local/bin は claude-code feature が同梱の official 版で上書きするので /usr/local/sbin に置く
COPY init-firewall.sh /usr/local/sbin/
RUN chmod 755 /usr/local/sbin/init-firewall.sh \
    && rm -f /etc/sudoers.d/vscode \
    && echo "vscode ALL=(root) NOPASSWD: /usr/local/sbin/init-firewall.sh" > /etc/sudoers.d/vscode-firewall \
    && chmod 0440 /etc/sudoers.d/vscode-firewall

# ベースイメージは en_US.UTF-8 しか有効にしていない
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
# PROMPT_COMMAND はベースイメージも使うので上書きせず後ろに足す
RUN mkdir -p /home/vscode/.claude/tmp /home/vscode/.codex /home/vscode/.config/gh /commandhistory \
    && chown -R vscode:vscode /home/vscode/.claude /home/vscode/.codex /home/vscode/.config /commandhistory \
    && cat >> /home/vscode/.bashrc <<'EOF'
PROMPT_COMMAND+=('history -a')
export HISTFILE=/commandhistory/.bash_history
source /usr/share/doc/fzf/examples/key-bindings.bash
EOF
