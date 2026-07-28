function _fzf_jj_status_usage
    echo "Leverage fzf as the UI to pick files changed in a jj revision,
preview their diff, and then run a command (jj diff by default) on the selection.
Syntax: fzf_jj_status [-h/--help] [-r/--revision revision] [-c/--cmd command]
    [-p/--prompt]
Args:
    -h/--help: Show the help doc.
    -r/--revision revision: The revision (default @, i.e. the working copy) whose
        changed files are listed and previewed.
    -c/--cmd command: Run command (default \`jj diff\`) on the picked files
        instead. The revision is not passed to a custom command, since commands
        such as \`jj restore\` take --from/--to rather than --revision.
        The picked files are passed as \`file:\"...\"\` filesets if the command
        starts with jj (or \`command jj\`), and as ./-prefixed paths otherwise.
    -p/--prompt: Once the files have been picked, open the resulting command line
        in an editor instead of running it right away. The buffer is prefilled
        with the command that would have been run otherwise (-c/--cmd or the
        default \`jj diff\`) followed by the picked files, and everything in it is
        editable: the command, the file list, or the whole thing replaced by a
        multi-line fish script. Saving and quitting runs the buffer as it is, so
        nothing is appended to it afterwards; leaving nothing but comments in it
        cancels, which also makes the buffer the place to review a destructive
        command before it runs. Whether the files are prefilled as filesets or as
        paths follows -c/--cmd, so editing a jj command into a non-jj one means
        turning the \`file:\"...\"\` filesets into plain paths by hand.
fzf leaves on enter and the command runs in the current shell, so its output
lands in the pager and the scrollback just like a hand-typed jj diff."
end

function fzf_jj_status --description 'Pick files changed in a jj revision with fzf and diff them'
    argparse --max-args=0 h/help p/prompt r/revision= c/cmd= -- $argv
    or return 1
    if set -q _flag_help
        _fzf_jj_status_usage
        return 0
    end

    set -l prompt 0
    if set -q _flag_prompt
        set prompt 1
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
    # With -p/--prompt an empty command is fine: it only means the buffer is
    # prefilled with the picked files alone and the command is typed in front of
    # them.
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
        --preview-window '~4,80%,<80(up)' | string split0)
    set -q files[1]
    or return

    # jj parses positional arguments as filesets, other commands take the paths
    # as they are, so the choice follows -c/--cmd. Under -p/--prompt that is only
    # the prefill: an edit turning a jj command into something else has to turn
    # the filesets into paths too. $cmd can be empty here, and `string match`
    # would then read from stdin instead of matching nothing.
    # The ./ prefix keeps a name starting with a dash from being parsed as an
    # option by the command, and makes a picked file runnable as the command
    # itself once -p/--prompt has been used to clear the command, since a bare
    # relative path is looked up in $PATH rather than in the current directory.
    # fd prints its paths ./-prefixed already, which is why fzf_fdfind needs no
    # equivalent.
    set -l targets ./$files
    set -l quoted (string escape -- $targets)
    if test -n "$cmd"; and string match --quiet --regex '^\s*(command\s+)?jj(\s|$)' -- $cmd
        set targets (_jj_cwd_fileset $files | string split0)
        # `string escape` backslash-escapes the double quotes of a `file:"..."`
        # fileset, which is accurate but noisy to read and edit in the -p/--prompt
        # buffer. Single quotes wrap the whole fileset in one go and keep it
        # legible. A target containing a single quote or a backslash has no
        # single-quoted form, so it falls back to `string escape`.
        set quoted
        for target in $targets
            if string match --quiet --regex "['\\\\]" -- $target
                set -a quoted (string escape -- $target)
            else
                set -a quoted "'$target'"
            end
        end
    end

    # Build one quoted command line and reuse it for the editor buffer, the
    # history entry, and execution. Quoting the targets keeps it accurate and
    # safe to re-run when names contain spaces or special characters, while
    # `eval` lets fish's own tokenizer handle a multi-word command (e.g. `jj
    # restore`), including quoted arguments and repeated spaces.
    # Only the targets are quoted; $cmd (the -c value) is intentionally left
    # unquoted so it tokenizes, so it must only ever be trusted input.
    set -l cmd_line (string join ' ' -- $cmd $quoted)
    # -p/--prompt hands that whole line over to an editor, so the files are
    # editable along with the command and the result is run as it stands.
    if test $prompt = 1
        _edit_and_run $cmd_line
        return
    end
    history append -- $cmd_line
    eval $cmd_line
end
