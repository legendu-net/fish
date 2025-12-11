if status is-interactive
    if command -q nvim
        set -g EDITOR nvim
        set -g VISUAL nvim
    else if command -q vim
        set -g EDITOR vim
        set -g VISUAL vim
    else if command -q vi
        set -g EDITOR vi
        set -g VISUAL vi
    end

    set fish_user_paths $HOME/*/bin/ \
        $HOME/.*/bin/ \
        $HOME/Library/Python/3.*/bin/ \
        /usr/local/*/bin/ \
        /opt/*/bin/
    fish_add_path --path --append /Applications/WezTerm.app/Contents/MacOS/

    abbr --add gitstatus git status
    abbr --add gitdiff git diff
    abbr --add hgstatus hg status
    abbr --add hgdiff hg diff
    abbr --add mvi mv -i
    abbr --add cpi cp -ir
    abbr --add blog ./blog.py
    abbr --add ... cd ../..
    abbr --add .... cd ../../..
    abbr --add csh cdh
    abbr --add fcs fzf_cs
    abbr --add fcd fzf_cs
    abbr --add fbat fzf_bat
    abbr --add frgvim fzf_ripgrep_nvim
    abbr --add fhist fzf_history
    abbr --add fh fzf_history
    abbr --add zat "zellij attach (zellij ls -s | fzf)"
end

