if status is-interactive
    set fish_user_paths $HOME/*/bin/ \
        $HOME/.*/bin/ \
        $HOME/Library/Python/3.*/bin/ \
        /usr/local/*/bin/ \
        /opt/*/bin/
    fish_add_path --path --append /home/linuxbrew/.linuxbrew/bin
    fish_add_path --path --append /Applications/WezTerm.app/Contents/MacOS
    # =====================================================
    if command -q nvim
        set -g EDITOR nvim
        set -g VISUAL nvim
    else if command -q vim
        set -g EDITOR vim
        set -g VISUAL vim
    else if command -q vi
        set -g EDITOR vi
        set -g VISUAL vi
    else if command -q fresh
        set -g EDITOR fresh
        set -g VISUAL fresh
    end
    # =====================================================
    if command -q nvim
        abbr --add vim nvim
        abbr --add vi nvim
        abbr --add vim.gi nvim .gitignore
    end
    # -----------------------------------------------------
    abbr --add mkdir.workflow mkdir -p .github/workflows/
    abbr --add mkdir.gemini mkdir -p .gemini/
    abbr --add mkdir.zz_deprecated mkdir zz_deprecated/
    # -----------------------------------------------------
    abbr --add awk.print "awk '{print}'"
    # -----------------------------------------------------
    abbr --add jjs 'jj status && echo'
    abbr --add jjd 'jj diff && echo'
    abbr --add jjr 'jj restore && echo'
    abbr --add jjrs 'jj restore && echo'
    abbr --add jjc 'jj commit -m && echo'
    abbr --add jjde 'jj describe -m && echo'
    abbr --add jjn 'jj new && echo'
    abbr --add jja 'jj abandon && echo'
    abbr --add jje 'jj edit @- && echo'
    abbr --add jjsq 'jj squash && echo'
    abbr --add jjsy jj sync
    abbr --add jju jj upload --all
    abbr --add jjb jj bookmark
    abbr --add jjbc jj bookmark create
    abbr --add jjbcm jj bookmark create main
    abbr --add jjgp jj git push
    abbr --add jjgr jj git remote
    abbr --add jjgrl jj git remote list
    abbr --add jjgra jj git remote add
    abbr --add jjgrao jj git remote add origin URL
    abbr --add jjcsue jj config set --user user.email
    abbr --add jjue jj config set --user user.email
    abbr --add jjcsun jj config set --user user.name
    abbr --add jjun jj config set --user user.name
    # -----------------------------------------------------
    abbr --add gitadd git add
    abbr --add ga git add
    abbr --add gitbranch git branch
    abbr --add gb git branch
    abbr --add gitclone git clone
    abbr --add gcl git clone
    abbr --add gitcommit git commit -m
    abbr --add gc git commit -m
    abbr --add gitdiff git diff
    abbr --add gd git diff
    abbr --add gds git diff --staged
    abbr --add gdss 'git diff --staged | gemini --skip-trust -p "Write a concise conventional commit message for this diff. Output ONLY the message."'
    abbr --add gdni git diff --no-index
    abbr --add gitfetch git fetch
    abbr --add gfo git fetch origin
    abbr --add gitrestore git restore
    abbr --add grs git restore
    abbr --add grss git restore --staged
    abbr --add gitstatus git status
    abbr --add gs git status
    abbr --add gsp git status --porcelain
    abbr --add gitpush git push
    abbr --add gp git push
    abbr --add gpod git push origin dev
    abbr --add gpom git push origin main
    abbr --add gplod git pull origin dev
    abbr --add gplom git pull origin main
    abbr --add gitremote git remote -v
    abbr --add gr git remote -v
    abbr --add git.submodule.add 'git submodule add'
    abbr --add git.submodule.update 'git submodule init && git submodule update --recursive --remote'
    abbr --add git.modified 'git status --porcelain | grep "M " | awk -F"M " \'{print $2}\''
    abbr --add git.added 'git status --porcelain | grep "A " | awk -F"A " \'{print $2}\''
    abbr --add git.deleted 'git status --porcelain | grep "D " | awk -F "D " \'{print $2}\''
    abbr --add git.renamed 'git status --porcelain | grep "R " | awk -F "R " \'{print $2}\''
    abbr --add git.copied 'git status --porcelain | grep "C " | awk -F "C " \'{print $2}\''
    abbr --add git.unmerged 'git status --porcelain | grep "U " | awk -F "U " \'{print $2}\''
    abbr --add git.untracked 'git status --porcelain | grep "?? " | awk -F "[?][?] " \'{print $2}\''
    abbr --add colordiff git diff --no-index
    # -----------------------------------------------------
    abbr --add pmi podman images
    abbr --add pmri podman rmi
    abbr --add pmr podman rm
    abbr --add pmp podman pull
    abbr --add pms podman stop
    abbr --add pmps podman ps
    abbr --add pmpjhub podman pull quay.io/legendu/jupyterhub-ds
    abbr --add pmpcs podman pull quay.io/legendu/vscode-server
    abbr --add pmpvsc podman pull quay.io/legendu/vscode-server
    # -----------------------------------------------------
    abbr --add di docker images
    abbr --add dri docker rmi
    abbr --add dr docker rm
    abbr --add dp docker pull
    abbr --add ds docker stop
    abbr --add dps docker ps
    abbr --add dpjhub docker pull dclong/jupyterhub-ds
    abbr --add dpcs docker pull dclong/vscode-server
    abbr --add dpvsc docker pull dclong/vscode-server
    # -----------------------------------------------------
    abbr --add f 'fish --no-execute **.fish'
    abbr --add fi 'fish_indent --write **.fish && git status'
    # -----------------------------------------------------
    abbr --add cargo.publish cargo publish --allow-dirty
    abbr --add cargo.pub cargo publish --allow-dirty
    # -----------------------------------------------------
    abbr --add uv.sync uv sync --all-extras
    abbr --add uv.pyproject-fmt uv run pyproject-fmt pyproject.toml
    abbr --add uv.mdformat uv run mdformat
    abbr --add uv.ruff.format uv run ruff format
    abbr --add uv.ruff.check uv run ruff check
    abbr --add uv.ty.check uv run ty check
    abbr --add uv.deptry uv run deptry .
    abbr --add uv.pytest uv run pytest
    abbr --add uv.lint.project 'uv run ruff format && uv run ruff check && uv run ty check && uv run deptry . && uv run pytest'
    abbr --add uv.jb.start HOST=127.0.0.1 NODE_OPTIONS=--max-old-space-size=8192 uv run jupyter-book start
    abbr --add uv.jb.build HOST=127.0.0.1 NODE_OPTIONS=--max-old-space-size=8192 uv run jupyter-book build --html
    abbr --add uv.ipython uv run --python 3.14 \
        --with aiutil[all] \
        --with github_rest_api \
        --with dockeree \
        --with IPython \
        python -m IPython
    abbr --add uvx.ruff.format uvx ruff format
    abbr --add uvx.ruff.check uvx ruff check
    abbr --add uvx.mdformat uvx mdformat
    # -----------------------------------------------------
    abbr --add gol golangci-lint
    abbr --add golf golangci-lint fmt
    abbr --add golr golangci-lint run
    # -----------------------------------------------------
    abbr --add hgadd hg add
    abbr --add hgcommit hg commit
    abbr --add hgdiff hg diff
    abbr --add hgstatus hg status
    # -----------------------------------------------------
    if command -q eza
        abbr --add ls eza --color=auto -lh
        abbr --add ls.media 'eza *.{jpg,jpeg,png,mp3,avi,mkv,mov,mp4,wmv,webm}'
        abbr --add ls.archive 'eza *.{zip,7zip,rar,gz,xz,zstd,ztd,tar}'
        abbr --add ls.package 'eza *.{air,deb,rpm,appimage,snap,flatpak*,whl,jar,apk}'
    else
        abbr --add ls.media 'ls *.{jpg,jpeg,png,mp3,avi,mkv,mov,mp4,wmv,webm}'
        abbr --add ls.archive 'ls *.{zip,7zip,rar,gz,xz,zstd,ztd,tar}'
        abbr --add ls.package 'ls *.{air,deb,rpm,appimage,snap,flatpak*,whl,jar,apk}'
    end
    if command -q dust
        abbr --add du dust
    end
    if command -q btm
        abbr --add top btm
        abbr --add htop btm
    end
    abbr --add mvi mv -i
    abbr --add mv.readme mv -i readme.md README.md
    abbr --add cpi cp -ir
    abbr --add ... cd ../..
    abbr --add .... cd ../../..
    abbr --add csh cdh
    # -----------------------------------------------------
    abbr --add rsync.progress rsync -avh --info=progress2
    abbr --add rsync.progress.pc proxychains rsync -avh --info=progress2
    # -----------------------------------------------------
    abbr --add fcs SHELL=fish fzf_cs
    abbr --add fcd SHELL=fish fzf_cs
    abbr --add ffd SHELL=fish fzf_fdfind
    abbr --add frg SHELL=fish fzf_ripgrep
    abbr --add fhist fzf_history
    abbr --add fh fzf_history
    abbr --add zat 'zellij attach (zellij ls -s | fzf)'
    # -----------------------------------------------------
    abbr --add mount.hh sudo mount -t virtiofs host_home $HOME/host_home/
    # -----------------------------------------------------
    abbr --add icon.jvim.enable icon jvim --sudo --enable
    abbr --add jvim.enable icon jvim --sudo --enable
    abbr --add blog ./blog.py
    abbr --add euporie.notebook 'euporie notebook \
        --no-warn-venv \
        --show-status-bar \
        --syntax-highlighting \
        --color-depth 24 \
        --edit-mode vi \
        --cursor-blink \
        --autocomplete \
        --autosuggest smart \
        --line-numbers'
    abbr --add tnb 'euporie notebook \
        --no-warn-venv \
        --show-status-bar \
        --syntax-highlighting \
        --color-depth 24 \
        --edit-mode vi \
        --cursor-blink \
        --autocomplete \
        --autosuggest smart \
        --line-numbers'
    # =====================================================
    abbr --add flatpak.zed flatpak run dev.zed.Zed
    abbr --add flatpak.keepassxc flatpak run org.keepassxc.KeePassXC
    # =====================================================
    bind ctrl-alt-space expand_all_abbr
end
