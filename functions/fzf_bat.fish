function _fzf_bat_usage
  echo "Search for files (previewing in bat) using fzf and edit them in NeoVim.
Syntax: fzf_bat [-h/--help] [-c/--cmd command] [-v/--vim] [-t/--type filetype] [dir]
Args:
    -h/--help: Show the help doc.
    -c/--cmd command: Run command (default nvim) on the file.
    -v/--vim: Edit the file using NeoVim (override -c/--cmd).
    -t/--type filetype: The -t/--type option of the fd command.
    dir: The directory (default to .) under which to search for files.
"
end

function fzf_bat
    argparse "h/help" "v/vim" "c/cmd=" "t/type=" -- $argv
    if set -q _flag_help
        _fzf_bat_usage
        return 0
    end

    set -l cmd ls
    if set -q _flag_cmd
        set cmd $_flag_cmd
    end
    if set -q _flag_vim
        set cmd nvim
    end

    set -l search_path .
    if test (count $argv) -gt 0
      set search_path $argv
    end

    set -l fd (get_fd_executable)
    check_fdfind $fd; or return 1

    if set -q _flag_type
        set -a fd --type $_flag_type
    end

    set -l files ($fd --print0 --hidden . $search_path | fzf -m --read0 --preview 'bat --color=always {}')
    history append "$cmd $files"
    $cmd $files
end

