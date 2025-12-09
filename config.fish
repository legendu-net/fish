if status is-interactive
    set -g EDITOR nvim
    set -g VISUAL nvim

    set fish_user_paths $HOME/*/bin/ \
        $HOME/.*/bin/ \
        $HOME/Library/Python/3.*/bin/ \
        /usr/local/*/bin/ \
        /opt/*/bin/
    fish_add_path --path --append /Applications/WezTerm.app/Contents/MacOS/

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

