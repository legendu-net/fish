function _fzf_ripgrep_usage
    echo "Leverage fzf as the UI to search for files by content using ripgrep,
preview it using bat, and open selections using external editors.
Syntax: fzf_ripgrep [-h] [-e/--edit] [dir]
Args:
    -h/--help: Show the help doc.
    -e/--edit: Edit the file using the editor returned by `preferred_editor -g`.
    dir: The directory (default to .) under which to search for files."
end

function fzf_ripgrep
    argparse h/help e/edit -- $argv
    if set -q _flag_help
        _fzf_ripgrep_usage
        return 0
    end

    set -l editor (preferred_editor)
    if set -q _flag_edit
        set editor (preferred_editor -g)
    end

    set -l search_path .
    if test (count $argv) -gt 0
        set search_path $argv
    end

    # HAVE TO USE THE RELOAD TRICK instead of piping rg results to fzf!
    # Piping rg results to fzf for filtering matches patterns against file names as well.
    set -l reload "reload:rg --column --color=always --smart-case {q} $search_path || :"
    fzf --disabled --ansi --multi \
        --bind "start:$reload" --bind "change:$reload" \
        --bind "enter:execute:_fzf_ripgrep_opener $editor {+f}" \
        --bind "ctrl-o:execute:_fzf_ripgrep_opener $editor {+f}" \
        --bind 'alt-a:select-all,alt-d:deselect-all,ctrl-/:toggle-preview' \
        --delimiter : \
        --preview 'bat --style=full --color=always --highlight-line {2} {1}' \
        --preview-window '~4,+{2}+4/3,<80(up)'
    history merge
end
