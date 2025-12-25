function _fzf_fdfind_usage
    echo "Leverage fzf as the UI to search for files by name using fdfind,
preview it using bat, and then run external commands on open selections.
Syntax: fzf_fdfind [-h/--help] [-c/--cmd command] [-e/--edit] [-t/--type filetype] [dir]
Args:
    -h/--help: Show the help doc.
    -c/--cmd command: Run command (default nvim) on the file.
    -e/--edit: Edit the file using the editor returned by `preferred_editor -g`.
    -t/--type filetype: The -t/--type option of the fd command.
    dir: The directory (default to .) under which to search for files.
"
end

function fzf_fdfind
    argparse h/help e/edit c/cmd= t/type= -- $argv
    if set -q _flag_help
        _fzf_fdfind_usage
        return 0
    end

    set -l cmd (preferred_editor)
    if set -q _flag_cmd
        set cmd $_flag_cmd
    end
    if set -q _flag_edit
        set cmd (preferred_editor -g)
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
    set -l reload "reload:$fd --hidden {q} $search_path || :"

    set -l opener (string replace --all CMD $cmd \
                    'set -l files (cat {+f}) 
                    history append "CMD $files"
                    CMD $files' | string collect)
    fzf --disabled --ansi --multi \
      --bind "start:$reload" --bind "change:$reload" \
      --bind "enter:execute:$opener" \
      --bind "ctrl-o:execute:$opener" \
      --bind 'alt-a:select-all,alt-d:deselect-all,ctrl-/:toggle-preview' \
      --delimiter : \
      --preview 'bat --style=full --color=always {1}' \
      --preview-window '~4,+{2}+4/3,<80(up)' \
      --query "$argv"
    history merge
end

