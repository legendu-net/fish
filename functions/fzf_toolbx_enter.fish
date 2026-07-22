function _fzf_toolbx_enter_usage
    echo "Pick a toolbox container with fzf and enter it.
Syntax: fzf_toolbx_enter [-h/--help]"
end

function fzf_toolbx_enter --description 'Pick a toolbox container with fzf and enter it'
    argparse h/help -- $argv
    or return 1
    if set -q _flag_help
        _fzf_toolbx_enter_usage
        return 0
    end

    for cmd in toolbox fzf
        if not command -q $cmd
            echo (set_color $fish_color_error)"Error: '$cmd' command is not installed."(set_color normal) >&2
            return 1
        end
    end

    # 'toolbox list -c' prints a header then one container per row; the name is
    # the second column (both id and name are single tokens).
    set -l line (toolbox list -c | tail -n +2 | \
        fzf --ansi --height 40% --reverse --header 'Enter which toolbox container?')
    test -n "$line"; or return 0

    SHELL=fish toolbox enter (string split -f 2 -n ' ' -- $line)
end
