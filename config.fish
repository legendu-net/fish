if status is-interactive
    set fish_user_paths $HOME/*/bin/ \
        $HOME/.*/bin/ \
        $HOME/Library/Python/3.*/bin/ \
        /usr/local/*/bin/ \
        /opt/*/bin/
    fish_add_path --path --append /home/linuxbrew/.linuxbrew/bin
    fish_add_path --path --append /Applications/WezTerm.app/Contents/MacOS

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

    # -----------------------------------------------------
    abbr --add gitadd git add
    abbr --add ga git add .
    abbr --add gitbranch git branch
    abbr --add gb git branch
    abbr --add gitclone git clone
    abbr --add gcl git clone
    abbr --add gitcommit git commit -m
    abbr --add gc git commit -m
    abbr --add gitdiff git diff
    abbr --add gd git diff
    abbr --add gitfetch git fetch
    abbr --add gfo git fetch origin
    abbr --add gitstatus git status
    abbr --add gs git status
    abbr --add gitpush git push
    abbr --add gp git push
    abbr --add gpod git push origin dev
    abbr --add gpom git push origin main
    abbr --add gplod git pull origin dev
    abbr --add gplom git pull origin main
    abbr --add git.submodule 'git submodule init && git submodule update --recursive --remote'
    abbr --add git.modified 'git status | grep 'modified:' | cut -d: -f2'
    abbr --add git.deleted 'git status | grep 'deleted:' | cut -d: -f2'
    abbr --add git.renamed 'git status | grep 'renamed:' | cut -d: -f2'
    abbr --add colordiff git diff --no-index
    abbr --add dp docker pull
    abbr --add dpjhub docker pull dclong/jupyterhub-ds
    abbr --add dpcs docker pull dclong/vscode-server
    # -----------------------------------------------------
    abbr --add f 'fish -n **.fish'
    abbr --add fi 'fish_indent -w **.fish && git status'
    abbr --add urrf uv run ruff format
    abbr --add urrc uv run ruff check
    abbr --add urtc uv run ty check
    abbr --add urdc uv run deptry .
    abbr --add urd uv run deptry .
    abbr --add urdt uv run deptry .
    abbr --add uv.ipython uv run --python 3.14 \
        --with aiutil[all] \
        --with github_rest_api \
        --with dockeree \
        --with IPython \
        python -m IPython
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
        abbr --add ls eza --color=auto -lha
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
    abbr --add zat "zellij attach (zellij ls -s | fzf)"
    # -----------------------------------------------------
    abbr --add mount.hh sudo mount -t virtiofs host_home $HOME/host_home/
    # -----------------------------------------------------
    abbr --add blog ./blog.py
end
