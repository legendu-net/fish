function _cs_usage
    printf "Enter a directory and display its content.
Syntax: cs dir
"
end

function cs
    argparse h/help -- $argv
    if set -q _flag_help
        _cs_usage
        return 0
    end

    set -l dir "$argv"
    if test -f "$dir"
        set dir (path dirname "$dir")
    end
    if test "$dir" = ""
        set dir "$HOME"
    end

    cd "$dir"
    if test $status -ne 0
        echo (set_color $fish_color_error)"Error: failed to cd into $dir!"(set_color normal) >&2
        return 1
    end
    if command -q eza
        eza -lh --color=auto
    else
        ls -lh --color=auto
    end
end
