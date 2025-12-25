function _cs_usage
    echo "Enter a directory and display its content.
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
        echo "Failed to cd into $dir!"
        return $status
    end
    ls --color=auto
end
