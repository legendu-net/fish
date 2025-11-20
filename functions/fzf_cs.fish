function _fzf_cs_usage
    echo "Search for a directory using fzf, cd into it, and run ls.
Syntax: fzf_cs [-h] [dir]
Args:
    dir: The directory (default to .) under which to search for sub directories.
"
end

function fzf_cs
    argparse h/help -- $argv
    if set -q _flag_help
        _fzf_cs_usage
        return 0
    end

    set -l fd (get_fd_executable)
    check_fdfind $fd; or return 1

    set -l search_path .
    if test (count $argv) -gt 0
        set search_path $argv
    end

    cd ($fd --type d --print0 --hidden . $search_path | fzf --read0)
    ls
end

