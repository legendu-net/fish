function _fzf_bat_usage
  echo "Search for files (previewing in bat) using fzf and edit them in NeoVim.
Syntax: fzf_bat [-h/--help] [-c/--cmd command] [dir]
Args:
    -h/--help: Show the help doc.
    -c/--cmd command: Run command (default nvim) on th file.
    dir: The directory (default to .) under which to search for files.
"
end

function fzf_bat
    argparse h/help -- $argv
    if set -q _flag_help
        _fzf_bat_usage
        return 0
    end

    set -l cmd nvim
    argparse c/cmd -- $argv
    if set -q _flag_cmd
        set cmd $_flag_cmd
    end

    set -l search_path .
    if test (count $argv) -gt 0
      set search_path $argv
    end

    set -l fd (get_fd_executable)
    check_fdfind $fd; or return 1

    set -l files ($fd --type f --print0 --hidden . $search_path | fzf -m --read0 --preview 'bat --color=always {}')
    history append "$cmd $files"
    $cmd $files
end

