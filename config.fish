if status is-interactive
    # =====================================================
    set fish_user_paths $HOME/*/bin/ \
        $HOME/.*/bin/ \
        $HOME/Library/Python/3.*/bin/ \
        /usr/local/*/bin/ \
        /opt/*/bin/
    fish_add_path --path --append /home/linuxbrew/.linuxbrew/bin
    fish_add_path --path --append /Applications/WezTerm.app/Contents/MacOS
    # =====================================================
    if not set -q SSH_AUTH_SOCK
        eval (ssh-agent -c) >/dev/null
    end
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
        abbr --add vim.gemini 'AVANTE_GEMINI_API_KEY=(gopass show gemini/token) nvim'
        abbr --add nvim.gemini 'AVANTE_GEMINI_API_KEY=(gopass show gemini/token) nvim'
    end
    # -----------------------------------------------------
    abbr --add mkdir.workflow mkdir -p .github/workflows/
    abbr --add mkdir.gemini mkdir -p .gemini/
    abbr --add mkdir.zz_deprecated mkdir zz_deprecated/
    # -----------------------------------------------------
    abbr --add awk.print "awk '{print}'"
    # -----------------------------------------------------
    function jj
        command jj $argv
        set -l ret $status
        isatty stdout; and echo
        return $ret
    end
    abbr --add jjsb jj_sync_base
    abbr --add jjs jj status
    abbr --add jjd jj diff
    abbr --add jjdi jj diff
    abbr --add jjds 'jj diff | agy --model "Gemini 3.5 Flash (Low)" --prompt "Write a concise conventional commit message for this diff. Output ONLY the message."'
    abbr --add jjr jj restore
    abbr --add jjrs jj restore
    abbr --add jjc 'jj commit --editor'
    abbr --add jjde 'jj describe --editor'
    abbr --add jjn jj new
    abbr --add jjsp jj split
    abbr --add jja jj abandon
    abbr --add jje jj edit @-
    abbr --add jjsq --set-cursor 'jj squash --into @- %'
    abbr --add jjrb jj rebase
    abbr --add jjrbom jj rebase --onto main
    abbr --add jjrbod jj rebase --onto dev
    abbr --add jjsy jj sync
    abbr --add jjsu 'jj sync && jj upload'
    abbr --add jjsyu 'jj sync && jj upload'
    abbr --add jjun jj undo
    abbr --add jjfu jj file untrack
    abbr --add jjup jj upload
    abbr --add jjb jj bookmark
    abbr --add jjbl jj bookmark list
    abbr --add jjbc jj bookmark create
    abbr --add jjbcm jj bookmark create main
    abbr --add jjbd jj bookmark delete
    abbr --add jjbt jj bookmark track
    abbr --add jjbtd jj bookmark track dev --remote origin
    abbr --add jjbtm jj bookmark track main --remote origin
    abbr --add jjbs jj bookmark set
    abbr --add jjbsm jj bookmark set main -r @-
    abbr --add jjgi jj git init --colocate
    abbr --add jjgf jj git fetch
    abbr --add jjgfcc --set-cursor 'jj git fetch && jj log -r "@- & ::main"%'
    abbr --add jjgp jj git push
    abbr --add jjgpp --set-cursor 'jj git push --change @-%'
    abbr --add jjgr jj git remote
    abbr --add jjgrl jj git remote list
    abbr --add jjgra jj git remote add
    abbr --add jjgrao jj git remote add origin URL
    abbr --add jjl jj log
    abbr --add jjce jj config edit
    abbr --add jjcer jj config edit --repo
    abbr --add jjcsue jj config set --user user.email
    abbr --add jjcue jj config set --user user.email
    abbr --add jjcsun --set-cursor 'jj config set --user user.name "%"'
    abbr --add jjcun --set-cursor 'jj config set --user user.name "%"'
    # -----------------------------------------------------
    abbr --add gitadd git add
    abbr --add ga git add
    abbr --add gitbranch git branch
    abbr --add gb git branch
    abbr --add gitcheckout git checkout
    abbr --add gco git checkout
    abbr --add gitclone git clone
    abbr --add gcl git clone
    abbr --add gitcommit 'git commit'
    abbr --add gc 'git commit'
    abbr --add gitdiff git diff
    abbr --add gd git diff
    abbr --add gds git diff --staged
    abbr --add gdss 'git diff --staged | agy --model "Gemini 3.5 Flash (Low)" --prompt "Write a concise conventional commit message for this diff. Output ONLY the message."'
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
    abbr --add git.submodule.add git submodule add
    abbr --add gsma git submodule add
    abbr --add git.submodule.update 'git submodule init && git submodule update --recursive --remote'
    abbr --add gsmu 'git submodule init && git submodule update --recursive --remote'
    abbr --add git.modified 'git status --porcelain | grep "M " | awk -F"M " \'{print $2}\''
    abbr --add git.added 'git status --porcelain | grep "A " | awk -F"A " \'{print $2}\''
    abbr --add git.deleted 'git status --porcelain | grep "D " | awk -F "D " \'{print $2}\''
    abbr --add git.renamed 'git status --porcelain | grep "R " | awk -F "R " \'{print $2}\''
    abbr --add git.copied 'git status --porcelain | grep "C " | awk -F "C " \'{print $2}\''
    abbr --add git.unmerged 'git status --porcelain | grep "U " | awk -F "U " \'{print $2}\''
    abbr --add git.untracked 'git status --porcelain | grep "?? " | awk -F "[?][?] " \'{print $2}\''
    abbr --add colordiff git diff --no-index
    # -----------------------------------------------------
    abbr --add gop gopass
    abbr --add gopi gopass insert
    abbr --add gops gopass show
    abbr --add gopsgh gopass show api_keys/github
    # -----------------------------------------------------
    abbr --add tbl toolbox list
    abbr --add tbe 'begin; set -l c (tbx version); and SHELL=fish toolbox enter $c; end'
    abbr --add ftbe fzf_toolbx_enter
    # -----------------------------------------------------
    abbr --add pm podman
    abbr --add pmi podman images
    abbr --add pmip podman image prune -f
    abbr --add pmri podman rmi
    abbr --add pmrmi podman rmi
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
    abbr --add rm rip
    if command -q eza
        abbr --add ls eza --color=auto -lhH
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
    abbr --add e exit
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
    # -----------------------------------------------------
    abbr --add z zellij -l welcome
    abbr --add zj zellij -l welcome
    abbr --add zbox 'begin; set -l c (tbx version); and zellij action new-pane -- cmd toolbox enter $c; end'
    abbr --add zw zellij web
    abbr --add zjw zellij web
    abbr --add zwct zellij web --create-token
    abbr --add zjwct zellij web --create-token
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
    # -----------------------------------------------------
    abbr --add calude claude
    abbr --add c claude
    # =====================================================
    abbr --add flatpak.zed flatpak run dev.zed.Zed
    abbr --add flatpak.keepassxc flatpak run org.keepassxc.KeePassXC
    # =====================================================
    bind ctrl-alt-space expand_all_abbr
end
