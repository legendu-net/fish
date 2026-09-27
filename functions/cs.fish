function _cs_usage
    echo "Enter a directory and display its content.
Syntax: cs dir"
end

function cs --description 'Change directory and list its contents'
    argparse h/help -- $argv
    or return 1
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

    set -l max_entries 1000
    set -l total (command ls | wc -l | string trim)

    set -l cmd
    if command -q eza
        set cmd eza -lh --color=auto
    else
        set cmd ls -lh --color=auto
    end

    if test $total -gt $max_entries
        echo (set_color yellow)"Note: $total entries found, showing first $max_entries."(set_color normal) >&2
        set -l names (command ls | head -n $max_entries)
        $cmd -d -- $names
    else
        $cmd
    end
end
