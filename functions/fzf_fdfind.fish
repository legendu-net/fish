function _fzf_fdfind_usage
    echo "Leverage fzf as the UI to search for files by name using fdfind,
preview it using bat, and then run external commands on open selections.
Syntax: fzf_fdfind [-h/--help] [-c/--cmd command] [-e/--edit] [-t/--type filetype] [--no-multi] [-x/--exit] [--confirm] [dir]
Args:
    -h/--help: Show the help doc.
    -c/--cmd command: Run command (default nvim) on the file.
    -e/--edit: Edit the file using the editor returned by `preferred_editor -g`.
    -t/--type filetype: The -t/--type option of the fd command.
    --no-multi: Disable multi-selection so only a single entry can be picked
        (e.g. for a cd picker like fcd).
    -x/--exit: Exit fzf on enter and run the command in the current shell
        instead of a child process, so effects like `cd` persist. Use this
        for commands (e.g. cs) that must act on the calling shell.
    --confirm: Imply -x/--exit and, on top of it, log the command and ask for
        confirmation before running it (useful for destructive commands such as rip).
    dir: The directory (default to .) under which to search for files."
end

function fzf_fdfind --description 'Search files by name with fzf and open selections'
    argparse h/help e/edit x/exit confirm no-multi c/cmd= t/type= -- $argv
    or return 1
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

    if test -z "$cmd"
        echo (set_color $fish_color_error)"Error: no command/editor found. Please specify one with -c/--cmd."(set_color normal) >&2
        return 1
    end

    set -l confirm 0
    set -l exit_after 0
    if set -q _flag_confirm
        set confirm 1
    end
    if set -q _flag_exit
        set exit_after 1
    end
    # --confirm builds on -x/--exit: it runs in the current shell too, adding a
    # log and a prompt on top.
    if test $confirm = 1
        set exit_after 1
    end

    set -l search_path .
    if set -q argv[1]
        set search_path $argv
    end

    set -l fd (get_fd_executable; or return 1)
    if set -q _flag_type
        set -a fd --type $_flag_type
    end

    # Shared fzf options for both the exit-mode and the editor pipelines.
    set -l fzf_opts --read0 --ansi \
        --bind 'alt-a:select-all,alt-d:deselect-all,ctrl-/:toggle-preview' \
        --preview '_fzf_fdfind_previewer {1}' \
        --preview-window '~4,+{2}+4/3,<80(up)'
    if not set -q _flag_no_multi
        set -a fzf_opts --multi
    end

    if test $exit_after = 1
        # fcd-style: fzf prints the selection and exits on enter, then we run
        # the command in the current shell (no child process) so effects like
        # `cd` persist. --confirm additionally logs the command and prompts.
        set -l files ($fd --no-ignore --hidden --print0 "" $search_path | \
            fzf --print0 $fzf_opts | string split0)
        set -q files[1]
        or return
        # Build one escaped command line and reuse it for the log, the history
        # entry, and execution. Escaping the file names keeps it accurate and
        # safe to re-run when names contain spaces or special characters, while
        # `eval` lets fish's own tokenizer handle a multi-word command (e.g.
        # `rip -f`), including quoted arguments and repeated spaces.
        # Only the file names are escaped; $cmd (the -c value) is intentionally
        # left unescaped so it tokenizes, so -c must only ever be trusted input.
        set -l cmd_line (string join ' ' -- $cmd (string escape -- $files))
        if test $confirm = 1
            echo "The following command will be run:"
            echo "  $cmd_line"
            read -l -P "Proceed? [y/N] " reply
            or return
            string match -qri '^y(es)?$' -- $reply
            or return
        end
        history append -- $cmd_line
        eval $cmd_line
        return
    end

    # Editor mode stays in fzf via `execute`, opening selections with the
    # opener so the picker remains open for further selections.
    $fd --no-ignore --hidden --print0 "" $search_path | fzf $fzf_opts \
        --bind "enter:execute:_fzf_fdfind_opener $cmd {+f}" \
        --bind "ctrl-o:execute:_fzf_fdfind_opener $cmd {+f}"
    history merge
end
