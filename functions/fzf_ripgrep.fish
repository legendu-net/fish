function _fzf_ripgrep_usage
    echo "Leverage fzf as the UI to search for files by content using ripgrep,
preview it using bat, and open selections using external editors.
Syntax: fzf_ripgrep [-h] [-e/--edit] [dir]
Args:
    dir: The directory (default to .) under which to search for files.
"
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

    set -l reload "reload:rg --column --color=always --smart-case {q} $search_path || :"
    set -l opener
    switch $editor
        case nvim vim vi
            set opener (string replace --all EDITOR $editor \
                            'if test "$FZF_SELECT_COUNT" = "0"
                                history append "EDITOR {1} +{2}"
                                EDITOR {1} +{2}
                            else
                                history append "EDITOR +cw -q {+f}"
                                EDITOR +cw -q {+f}
                            end' | string collect)
        case code code-server
            set opener (string replace --all EDITOR $editor \
                'set -l files (cat {+f} | awk -F\': \' \'{print $1}\')
                history append "EDITOR -g $files"
                EDITOR -g $files' | string collect)
        case "*"
            echo "$editor is not support!"
            return 1
    end
    fzf --disabled --ansi --multi \
      --bind "start:$reload" --bind "change:$reload" \
      --bind "enter:execute:$opener" \
      --bind "ctrl-o:execute:$opener" \
      --bind 'alt-a:select-all,alt-d:deselect-all,ctrl-/:toggle-preview' \
      --delimiter : \
      --preview 'bat --style=full --color=always --highlight-line {2} {1}' \
      --preview-window '~4,+{2}+4/3,<80(up)' \
      --query "$argv"
    history merge
end

