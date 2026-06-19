function _jj_check_conflicts_usage
    echo "Check if @- has been merged into a bookmark and auto rebase if needed.
Syntax: jj_check_conflicts [-h/--help] [bookmark]
Args:
    -h/--help: Show the help doc.
    bookmark: The target bookmark. If not specified, 'dev' is preferred, then 'main'."
end

function jj_check_conflicts --description 'Check if @- has been merged into a bookmark and auto rebase if needed'
    argparse h/help -- $argv
    if set -q _flag_help
        _jj_check_conflicts_usage
        return 0
    end

    if not command -q jj
        echo (set_color $fish_color_error)"Error: 'jj' (Jujutsu) command is not installed."(set_color normal) >&2
        return 1
    end

    jj root >/dev/null 2>&1
    set -l root_status $status
    if test $root_status -ne 0
        echo (set_color $fish_color_error)"Error: The current directory is not a Jujutsu repository."(set_color normal) >&2
        return $root_status
    end

    set -l bookmark ""
    if test (count $argv) -gt 0
        set bookmark $argv[1]
        jj log -r "$bookmark" --no-graph -T "" >/dev/null 2>&1
        set -l bookmark_status $status
        if test $bookmark_status -ne 0
            echo (set_color $fish_color_error)"Error: Bookmark '"(set_color -o -i -u cyan)"$bookmark"(set_color normal)(set_color $fish_color_error)"' does not exist."(set_color normal) >&2
            return $bookmark_status
        end
    else
        if jj log -r dev --no-graph -T "" >/dev/null 2>&1
            set bookmark dev
        else if jj log -r main --no-graph -T "" >/dev/null 2>&1
            set bookmark main
        else
            echo (set_color $fish_color_error)"Error: Neither 'dev' nor 'main' bookmark exists. Please specify a bookmark name."(set_color normal) >&2
            return 1
        end
    end

    jj git fetch
    set -l fetch_status $status
    if test $fetch_status -ne 0
        echo (set_color $fish_color_error)"Error: 'jj git fetch' failed."(set_color normal) >&2
        return $fetch_status
    end

    set -l merged_commits (jj log -r "@- & ::$bookmark" --no-graph -T "commit_id")
    set -l log_status $status
    if test $log_status -ne 0
        echo (set_color $fish_color_error)"Error: Failed to query merge status of @- against "(set_color -o -i -u cyan)"$bookmark"(set_color normal)(set_color $fish_color_error)"."(set_color normal) >&2
        return $log_status
    end
    if test -n "$merged_commits"
        echo (set_color yellow)"Warning: @- has been merged into "(set_color -o -i -u cyan)"$bookmark"(set_color normal)(set_color yellow)". Auto-rebasing..."(set_color normal)
        jj rebase --onto $bookmark
    else
        echo (set_color green)"@- is not merged into "(set_color -o -i -u cyan)"$bookmark"(set_color normal)(set_color green)". Safe to continue working on it."(set_color normal)
        echo
    end
end
