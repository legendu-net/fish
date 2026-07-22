function _trace_dir_upwards_usage
    echo "Trace a directory upwards until the name is found.
Syntax: trace_dir_upwards <dir> <name>"
end

function trace_dir_upwards --description 'Trace directories upwards until target directory name matches'
    argparse h/help -- $argv
    or return 1
    if set -q _flag_help
        _trace_dir_upwards_usage
        return 0
    end

    if test (count $argv) -ne 2
        echo (set_color $fish_color_error)"Error: trace_dir_upwards requires exactly 2 arguments."(set_color normal) >&2
        _trace_dir_upwards_usage >&2
        return 1
    end

    set -l dir "$argv[1]"
    set -l name (path basename -- "$argv[2]")
    set -l stem (path basename -- "$dir")

    while test "$stem" != "$name"
        if contains -- "$stem" / ""
            echo (set_color $fish_color_error)"Error: $name is not found in $argv[1]!"(set_color normal) >&2
            return 1
        end

        set -l parent (path dirname -- "$dir")
        if test "$parent" = "$dir"
            set stem ""
        else
            set dir "$parent"
            set stem (path basename -- "$dir")
        end
    end

    echo "$dir"
end
