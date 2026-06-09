function _jj_auto_commit_usage
    echo "Auto-generate a commit message for staged changes and open it in editor.
Syntax: jj_auto_commit [-h/--help]"
end

function jj_auto_commit --description 'Auto-generate a commit message and open it in editor'
    argparse h/help -- $argv
    if set -q _flag_help
        _jj_auto_commit_usage
        return 0
    end

    if not command -q jj
        echo (set_color $fish_color_error)"Error: 'jj' is not installed."(set_color normal) >&2
        return 1
    end

    jj root >/dev/null 2>&1
    set -l root_status $status
    if test $root_status -ne 0
        echo (set_color $fish_color_error)"Error: The current directory is not a Jujutsu repository."(set_color normal) >&2
        return $root_status
    end

    if not command -q agy
        echo (set_color $fish_color_error)"Error: 'agy' is not installed."(set_color normal) >&2
        return 1
    end

    set -l diff_output (jj diff | string collect)
    if test -z "$diff_output"
        echo (set_color yellow)"No changes to commit."(set_color normal)
        return 0
    end

    echo "Generating commit message with Gemini..."
    set -l msg (printf '%s\n' "$diff_output" | agy --prompt 'write a concise conventional commit message for this diff. Output ONLY the message' --model 'Gemini 3.5 Flash (Low)')

    if test $status -ne 0
        echo (set_color $fish_color_error)"Error: Failed to generate commit message."(set_color normal) >&2
        return 1
    end

    set msg (string join \n -- $msg)

    if test -z "$msg"
        echo (set_color $fish_color_error)"Error: Generated message is empty."(set_color normal) >&2
        return 1
    end

    set -l tmpdir (mktemp -d)
    set -l tmpfile $tmpdir/commit.txt
    printf '%s\n' "$msg" >$tmpfile

    set -l editor (preferred_editor)
    if test -z "$editor"
        set editor $EDITOR
    end
    if test -z "$editor"
        set editor vi
    end

    eval $editor (string escape -- $tmpfile)

    set -l edited_msg (string collect < $tmpfile)
    rm -rf $tmpdir

    if test -z "$edited_msg"
        echo (set_color $fish_color_error)"Error: Commit message was emptied. Aborting."(set_color normal) >&2
        return 1
    end

    set -l safe_msg (string replace -a '\\' '\\\\' "$edited_msg" | string replace -a "'" "\\'" | string collect)
    set -l cmd "jj commit -m '$safe_msg'"

    commandline -r -- $cmd
end
