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
    abbr --add gitclone git clone
    abbr --add gitcommit git commit
    abbr --add gitdiff git diff
    abbr --add gitstatus git status
    # -----------------------------------------------------
    abbr --add hgadd hg add
    abbr --add hgcommit hg commit
    abbr --add hgdiff hg diff
    abbr --add hgstatus hg status
    # -----------------------------------------------------
    abbr --add mvi mv -i
    abbr --add cpi cp -ir
    abbr --add ... cd ../..
    abbr --add .... cd ../../..
    abbr --add csh cdh
    # -----------------------------------------------------
    abbr --add fcs fzf_cs
    abbr --add fcd fzf_cs
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
