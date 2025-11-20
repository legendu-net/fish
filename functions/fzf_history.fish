function _fzf_history_usage
    echo "Search for a fish history command using fzf, edit and run it.
Syntax: fzf_history [-h]
"
end

function fzf_history
    argparse h/help -- $argv
    if set -q _flag_help
        _fzf_history_usage
        return 0
    end

    commandline (history | fzf -m)
    argparse e/edit -- $argv
    if set -q _flag_edit
        edit_command_buffer
    end
end
