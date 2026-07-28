function _edit_and_run --description 'Edit a prefilled command line in a temp script and run it in the current shell'
    # The editor must block until the file has been written, which every entry of
    # the terminal list returned by `preferred_editor` does. `preferred_editor -g`
    # must NOT be used here: `code` returns as soon as it has handed the file to a
    # running instance unless it is passed --wait.
    set -l editor (preferred_editor)
    if test -z "$editor"
        echo (set_color $fish_color_error)"Error: no editor found to edit the command in."(set_color normal) >&2
        return 1
    end

    # The .fish suffix is what gets the buffer syntax-highlighted by the editor.
    set -l tmp (mktemp --tmpdir --suffix=.fish fish_edit_and_run.XXXXXXXX)
    or return 1
    printf '%s\n' \
        '# Edit this script, then save and quit to run it in the current shell.' \
        '# Leave nothing but comments to cancel.' \
        $argv >$tmp

    $editor $tmp
    or begin
        rm -f $tmp
        return 1
    end

    # Only a leading # counts as a comment here, so a command containing a # inside
    # a quoted string is never mistaken for one. This is just the is-it-empty check
    # (and the source of the history entry); the file itself is run as it is, with
    # fish doing its own comment handling.
    set -l lines (string match --regex --invert '^\s*(#|$)' <$tmp)
    if not set -q lines[1]
        rm -f $tmp
        return 0
    end

    # Parse the whole script up front so that a syntax error halfway down cannot
    # run the lines above it first.
    fish --no-execute $tmp
    or begin
        rm -f $tmp
        return 1
    end

    # A multi-line script is not appended: history entries are meant to be recalled
    # and edited on the command line, which a script is not.
    if test (count $lines) -eq 1
        history append -- $lines[1]
    end
    # `source` rather than `eval` so that the script keeps its line numbers in error
    # messages. It runs in the current shell either way, so effects like `cd` persist.
    source $tmp
    set -l code $status
    rm -f $tmp
    return $code
end
