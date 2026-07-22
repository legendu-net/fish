function _fzf_history_usage
    echo "Search for a fish history command using fzf, edit and run it.
Syntax: fzf_history [-h/--help] [-e/--edit]
Args:
    -h/--help: Show the help doc.
    -e/--edit: Edit selected commands."
end

function fzf_history --description 'Search command history with fzf'
    argparse h/help e/edit -- $argv
    or return 1
    if set -q _flag_help
        _fzf_history_usage
        return 0
    end

    commandline (history | fzf -m)
    if set -q _flag_edit
        edit_command_buffer
    end
end
