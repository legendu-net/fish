function _fzf_fdfind_usage
    echo "Leverage fzf as the UI to search for files by name using fdfind,
preview it using bat, and then run external commands on open selections.
Syntax: fzf_fdfind [-h/--help] [-c/--cmd command] [-e/--edit] [-t/--type filetype] [--no-multi] [-x/--exit] [--confirm] [-p/--prompt] [dir]
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
        confirmation before running it (useful for destructive commands such as
        rip). Only y/yes (case insensitive) proceeds, so a bare enter cancels;
        under -p/--prompt the default flips and a bare enter proceeds.
    -p/--prompt: Imply -x/--exit and ask for the command to run after the files
        have been picked. The prompt is prefilled with the command that would
        have been run otherwise (-c/--cmd, -e/--edit or the preferred editor).
        The picked files are always appended at the end of whatever is typed, so
        a trailing comment or separator makes them be dropped or run as a
        command instead. Clearing the prompt runs the picked files themselves
        (the first one as the command and the rest as its arguments), which is
        handy for running an executable that has just been picked; ctrl-c and
        ctrl-d cancel instead, as does answering no under --confirm. Combine
        with --confirm to see the resulting command line, including the files,
        before it runs.
    dir: The directory (default to .) under which to search for files."
end

function fzf_fdfind --description 'Search files by name with fzf and open selections'
    argparse h/help e/edit x/exit confirm p/prompt no-multi c/cmd= t/type= -- $argv
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

    # With -p/--prompt an empty default is fine: it only means the prompt starts
    # out empty and the command is typed in after the files have been picked.
    if test $prompt = 0; and test -z "$cmd"
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
    # -p/--prompt runs in the current shell too, so that a typed command like
    # `cd` still affects the caller. It composes with --confirm: typing the
    # command out does not show which files it will run on, since fzf has left
    # the alternate screen by then, so the log and the y/N prompt still add
    # something on top.
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
        # `cd` persist. --confirm additionally logs the command and prompts.
        set -l files ($fd --no-ignore --hidden --print0 "" $search_path | \
            fzf --print0 $fzf_opts | string split0)
        set -q files[1]
        or return
        # -p/--prompt asks for the command only after the files are known, with
        # the default one prefilled so it can be edited or replaced. Clearing
        # the prompt runs the picked files as they are, which is what you want
        # after picking an executable. `set cmd` (empty list, not empty string)
        # keeps it from joining as a leading space below. ctrl-c/ctrl-d cancels.
        if test $prompt = 1
            read -l -P "Command: " -c "$cmd" reply
            or return
            set cmd (string trim -- $reply)
            if test -z "$cmd"
                set cmd
            end
        end
        # Build one escaped command line and reuse it for the log, the history
        # entry, and execution. Escaping the file names keeps it accurate and
        # safe to re-run when names contain spaces or special characters, while
        # `eval` lets fish's own tokenizer handle a multi-word command (e.g.
        # `rip -f`), including quoted arguments and repeated spaces.
        # Only the file names are escaped; $cmd (the -c value or the -p answer)
        # is intentionally left unescaped so it tokenizes, so it must only ever
        # be trusted input.
        set -l cmd_line (string join ' ' -- $cmd (string escape -- $files))
        if test $confirm = 1
            # Enter defaults to no, except under -p/--prompt, where the command
            # was typed out a keystroke ago and answering no again is more
            # friction than protection. Destructive presets such as `frip -c rip
            # --confirm` keep the safer default.
            set -l accept '^y(es)?$'
            set -l label "Proceed? [y/N] "
            if test $prompt = 1
                set accept '^(y(es)?)?$'
                set label "Proceed? [Y/n] "
            end
            echo "The following command will be run:"
            echo "  $cmd_line"
            read -l -P "$label" reply
            or return
            string match -qri $accept -- $reply
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
