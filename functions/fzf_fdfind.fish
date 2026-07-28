function _fzf_fdfind_usage
    echo "Leverage fzf as the UI to search for files by name using fdfind,
preview it using bat, and then run external commands on open selections.
Syntax: fzf_fdfind [-h/--help] [-c/--cmd command] [-e/--edit] [-t/--type filetype] [--no-multi] [-x/--exit] [-p/--prompt] [dir]
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
    -p/--prompt: Imply -x/--exit and, once the files have been picked, open the
        resulting command line in an editor instead of running it right away.
        The buffer is prefilled with the command that would have been run
        otherwise (-c/--cmd, -e/--edit or the preferred editor) followed by the
        picked files, and everything in it is editable: the command, the file
        list, or the whole thing replaced by a multi-line fish script. Saving
        and quitting runs the buffer as it is, so nothing is appended to it
        afterwards; leaving nothing but comments in it cancels, which also makes
        the buffer the place to review a destructive command before it runs.
    dir: The directory (default to .) under which to search for files."
end

function fzf_fdfind --description 'Search files by name with fzf and open selections'
    argparse h/help e/edit x/exit p/prompt no-multi c/cmd= t/type= -- $argv
    or return 1
    if set -q _flag_help
        _fzf_fdfind_usage
        return 0
    end

    set -l prompt 0
    if set -q _flag_prompt
        set prompt 1
    end

    set -l cmd (preferred_editor)
    if set -q _flag_cmd
        set cmd $_flag_cmd
    end
    if set -q _flag_edit
        set cmd (preferred_editor -g)
    end

    # With -p/--prompt an empty default is fine: it only means the buffer is
    # prefilled with the picked files alone and the command is typed in front of
    # them, which is also how an executable that has just been picked gets run.
    if test $prompt = 0; and test -z "$cmd"
        echo (set_color $fish_color_error)"Error: no command/editor found. Please specify one with -c/--cmd."(set_color normal) >&2
        return 1
    end

    set -l exit_after 0
    if set -q _flag_exit
        set exit_after 1
    end
    # -p/--prompt runs in the current shell too, so that an edited-in command like
    # `cd` still affects the caller.
    if test $prompt = 1
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
    # Each entry is a whole path, so the previewer takes {} (the entire entry)
    # rather than the field index {1} that fzf_ripgrep uses. fzf single-quotes
    # either one, so no quoting is needed here, but {1} splits on whitespace
    # without a --delimiter and would truncate any name containing a space.
    set -l fzf_opts --read0 --ansi \
        --bind 'alt-a:select-all,alt-d:deselect-all,ctrl-/:toggle-preview' \
        --preview '_fzf_fdfind_previewer {}' \
        --preview-window '~4,<80(up)'
    if not set -q _flag_no_multi
        set -a fzf_opts --multi
    end

    if test $exit_after = 1
        # fcd-style: fzf prints the selection and exits on enter, then we run
        # the command in the current shell (no child process) so effects like
        # `cd` persist. -p/--prompt additionally opens the command line in an
        # editor first.
        # SHELL=fish is scoped to the fzf process so that its bindings (here the
        # --preview one) can run fish functions. It must NOT leak any further:
        # the command eval'd below inherits this function's environment, and a
        # bare `fish` breaks anything that resolves $SHELL elsewhere (e.g. over
        # ssh, where fish may not be on PATH).
        set -l files ($fd --no-ignore --hidden --print0 "" $search_path | \
            SHELL=fish fzf --print0 $fzf_opts | string split0)
        set -q files[1]
        or return
        # Build one escaped command line and reuse it for the editor buffer, the
        # history entry, and execution. Escaping the file names keeps it accurate
        # and safe to re-run when names contain spaces or special characters,
        # while `eval` lets fish's own tokenizer handle a multi-word command
        # (e.g. `rip -f`), including quoted arguments and repeated spaces.
        # Only the file names are escaped; $cmd (the -c value) is intentionally
        # left unescaped so it tokenizes, so it must only ever be trusted input.
        set -l cmd_line (string join ' ' -- $cmd (string escape -- $files))
        # -p/--prompt hands that whole line over to an editor, so the files are
        # editable along with the command and the result is run as it stands.
        if test $prompt = 1
            _edit_and_run $cmd_line
            return
        end
        history append -- $cmd_line
        eval $cmd_line
        return
    end

    # Editor mode stays in fzf via `execute`, opening selections with the
    # opener so the picker remains open for further selections.
    $fd --no-ignore --hidden --print0 "" $search_path | SHELL=fish fzf $fzf_opts \
        --bind "enter:execute:_fzf_fdfind_opener $cmd {+f}" \
        --bind "ctrl-o:execute:_fzf_fdfind_opener $cmd {+f}"
    history merge
end
