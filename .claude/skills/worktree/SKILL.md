---
name: worktree
description: submodule のコードを変更するときに使う。worktree の作成からセッション移動、作業後の削除までの手順。
---

親リポジトリのルートで実行する。

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

`worktree.baseRef` や `.worktreeinclude` のような worktree の作り方の設定は、Claude Code が作る worktree にしか効かない。上の手動 `git worktree add` は対象外なので、基点は `origin/main` のように毎回明示する。

`EnterWorktree` に `path` を渡して入った worktree は、`ExitWorktree` の `remove` では消せない。
