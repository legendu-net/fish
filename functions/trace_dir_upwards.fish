function _trace_dir_upwards_usage
    printf "Trace a directory upwards until the name is found.
Syntax: trace_dir_upwards <dir> <name>
"
end

function trace_dir_upwards
    argparse h/help -- $argv
    if set -q _flag_help
        _trace_dir_upwards_usage
        return 0
    end

    set -l dir "$argv[1]"
    set -l name "$argv[2]"
    set -l stem (path basename "$dir")

    while test "$stem" != "$name"
        if contains -- "$stem" / ""
            printf (set_color $fish_color_error)"Error: $name is not found in $argv[1]!\n"(set_color normal) >&2
            return 1
        end
        set dir (path dirname "$dir")
        set stem (path basename "$dir")
    end

    printf "$dir\n"
end
