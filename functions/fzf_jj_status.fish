function _fzf_jj_status_usage
    echo "Leverage fzf as the UI to pick files changed in a jj revision,
preview their diff, and then run a command (jj diff by default) on the selection.
Syntax: fzf_jj_status [-h/--help] [-r/--revision revision] [-c/--cmd command]
    [--confirm] [-p/--prompt]
Args:
    -h/--help: Show the help doc.
    -r/--revision revision: The revision (default @, i.e. the working copy) whose
        changed files are listed and previewed.
    -c/--cmd command: Run command (default \`jj diff\`) on the picked files
        instead. The revision is not passed to a custom command, since commands
        such as \`jj restore\` take --from/--to rather than --revision.
        The picked files are passed as \`file:\"...\"\` filesets if the command
        starts with jj (or \`command jj\`), and as ./-prefixed paths otherwise.
    --confirm: Log the command and ask for confirmation before running it
        (useful for destructive commands such as \`jj restore\`). Only y/yes
        (case insensitive) proceeds, so a bare enter cancels; under -p/--prompt
        the default flips and a bare enter proceeds.
    -p/--prompt: Ask for the command to run after the files have been picked.
        The prompt is prefilled with the command that would have been run
        otherwise (-c/--cmd or the default \`jj diff\`). The picked files are
        always appended at the end of whatever is typed, so a trailing comment
        or separator makes them be dropped or run as a command instead. Whether
        they are appended as filesets or as paths is decided from the command
        that has been typed. Clearing the prompt runs the picked files
        themselves (the first one as the command and the rest as its arguments);
        ctrl-c and ctrl-d cancel instead, as does answering no under --confirm.
        Combine with --confirm to see the resulting command line, including the
        files, before it runs.
fzf leaves on enter and the command runs in the current shell, so its output
lands in the pager and the scrollback just like a hand-typed jj diff."
end

function fzf_jj_status --description 'Pick files changed in a jj revision with fzf and diff them'
    argparse --max-args=0 h/help confirm p/prompt r/revision= c/cmd= -- $argv
    or return 1
    if set -q _flag_help
        _fzf_jj_status_usage
        return 0
    end

    set -l prompt 0
    if set -q _flag_prompt
        set prompt 1
    end
    set -l confirm 0
    if set -q _flag_confirm
        set confirm 1
    end

    set -l rev @
    if set -q _flag_revision
        set rev $_flag_revision
    end

    # The revision is part of the default command only when it has been asked
    # for, so that the common case stays a plain `jj diff file...`. It is escaped
    # because the command line is eval'd below and a revset commonly contains
    # characters fish tokenizes, e.g. `latest(::@)`.
    set -l cmd "jj diff"
    if set -q _flag_revision
        set cmd "jj diff --revision "(string escape -- $rev)
    end
    if set -q _flag_cmd
        set cmd $_flag_cmd
    end
    # With -p/--prompt an empty command is fine: it only means the prompt starts
    # out empty and the command is typed in after the files have been picked.
    if test $prompt = 0; and test -z "$cmd"
        echo (set_color $fish_color_error)"Error: the command passed to -c/--cmd is empty."(set_color normal) >&2
        return 1
    end

    # A template (rather than --summary or --name-only) gives NUL-separated
    # entries and a status word that can be filtered on. `path` on its own is a
    # RepoPath, i.e. jj's internal form, which is relative to the workspace root;
    # `path.display()` is the conversion the jj CLI applies to its own output and
    # is relative to the current directory, so the entries match what `jj status`
    # prints and stay usable as they are.
    set -l entries (command jj diff --revision $rev \
        --template 'path.display() ++ "\t[" ++ status ++ "]\0"' | string split0)
    # $status is the one of `string split0`, so jj's own failures (e.g. an
    # invalid revset, or not being in a repository) have to be checked for
    # separately instead of being reported as an empty revision.
    test $pipestatus[1] -eq 0
    or return 1
    if not set -q entries[1]
        echo "No changed files in $rev."
        return 0
    end

    # SHELL=fish is scoped to the fzf process so that its bindings (here the
    # --preview one) can run fish functions. It must NOT leak any further: the
    # command eval'd below inherits this function's environment, and a bare
    # `fish` breaks anything that resolves $SHELL elsewhere (e.g. over ssh,
    # where fish may not be on PATH).
    # The entries are `path<tab>status`, so both the previewer and --accept-nth
    # take everything but the last field: a file name may itself contain a tab,
    # while the status word never does. Matching is left on the whole entry on
    # purpose, so that typing e.g. `removed` filters by status.
    # --accept-nth drops the status column in fzf rather than in fish afterwards:
    # a command substitution splits on newlines unless it is fed NUL-separated
    # entries by `string split0`, so any post-processing here would break file
    # names containing a newline.
    set -l files (printf '%s\0' $entries | SHELL=fish fzf --read0 --print0 --ansi --multi \
        --delimiter \t --accept-nth '..-2' \
        --bind 'alt-a:select-all,alt-d:deselect-all,ctrl-/:toggle-preview' \
        --preview "_fzf_jj_status_previewer "(string escape -- $rev)" {..-2}" \
        --preview-window '~4,<80(up)' | string split0)
    set -q files[1]
    or return

    # -p/--prompt asks for the command only after the files are known, with the
    # default one prefilled so it can be edited or replaced. Clearing the prompt
    # runs the picked files as they are, which is what you want after picking an
    # executable. `set cmd` (empty list, not empty string) keeps it from joining
    # as a leading space below. ctrl-c/ctrl-d cancels.
    if test $prompt = 1
        read -l -P "Command: " -c "$cmd" reply
        or return
        set cmd (string trim -- $reply)
        if test -z "$cmd"
            set cmd
        end
    end

    # jj parses positional arguments as filesets, other commands take the paths
    # as they are. The command is only known here under -p/--prompt, which is why
    # the choice is made this late. $cmd can be empty at this point, and `string
    # match` would then read from stdin instead of matching nothing.
    # The ./ prefix keeps a name starting with a dash from being parsed as an
    # option by the command, and makes a picked file runnable as the command
    # itself once the -p/--prompt has been cleared, since a bare relative path is
    # looked up in $PATH rather than in the current directory. fd prints its
    # paths ./-prefixed already, which is why fzf_fdfind needs no equivalent.
    set -l targets ./$files
    if test -n "$cmd"; and string match --quiet --regex '^\s*(command\s+)?jj(\s|$)' -- $cmd
        set targets (_jj_cwd_fileset $files | string split0)
    end

    # Build one escaped command line and reuse it for the history entry and
    # execution. Escaping the targets keeps it accurate and safe to re-run when
    # names contain spaces or special characters, while `eval` lets fish's own
    # tokenizer handle a multi-word command (e.g. `jj restore`), including
    # quoted arguments and repeated spaces.
    # Only the targets are escaped; $cmd (the -c value) is intentionally left
    # unescaped so it tokenizes, so it must only ever be trusted input.
    set -l cmd_line (string join ' ' -- $cmd (string escape -- $targets))
    if test $confirm = 1
        # Enter defaults to no, except under -p/--prompt, where the command was
        # typed out a keystroke ago and answering no again is more friction than
        # protection. Destructive presets such as `-c 'jj restore' --confirm`
        # keep the safer default.
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
end
