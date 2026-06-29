function _jj_sync_base_usage
    echo "Check if @- has been merged/advanced and auto rebase the working copy if needed.
Syntax: jj_sync_base [-h/--help] [bookmark]
Args:
    -h/--help: Show the help doc.
    bookmark: The target bookmark. If specified, @- is only checked against it
        (manual override). If not specified: @- is checked against 'dev'
        (preferred) then 'main'; if @- has merged there, the working copy is
        rebased onto it. Otherwise, the auto-created push bookmark on @- (from
        'jj git push --change @-') is followed forward when it has advanced."
end

function _jj_sync_base_bookmark_exists --argument-names bookmark
    jj log -r "$bookmark" --no-graph -T "" >/dev/null 2>&1
end

function _jj_sync_base_merged_into --argument-names bookmark
    # Return 2 (and print an error) if the query fails; otherwise return 0 when
    # @- is an ancestor of (i.e. has been merged into) $bookmark, 1 when not.
    set -l merged_commits (jj log -r "@- & ::$bookmark" --no-graph -T "commit_id")
    set -l log_status $status
    if test $log_status -ne 0
        echo (set_color $fish_color_error)"Error: Failed to query merge status of @- against "(set_color -o -i -u cyan)"$bookmark"(set_color normal)(set_color $fish_color_error)"."(set_color normal) >&2
        return 2
    end
    test -n "$merged_commits"
end

function _jj_sync_base_warn_if_merged --argument-names bookmark
    # Return 2 on query error, 0 when @- has merged into $bookmark (a warning is
    # printed and the caller should rebase onto it), 1 when @- has not merged.
    _jj_sync_base_merged_into "$bookmark"
    set -l merged_status $status
    if test $merged_status -eq 2
        return 2
    else if test $merged_status -eq 0
        echo (set_color yellow)"Warning: @- has been merged into "(set_color -o -i -u cyan)"$bookmark"(set_color normal)(set_color yellow)". Auto-rebasing..."(set_color normal)
        return 0
    end
    return 1
end

function jj_sync_base --description 'Check if @- has been merged/advanced and auto rebase if needed'
    argparse h/help -- $argv
    or return 1
    if set -q _flag_help
        _jj_sync_base_usage
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

    # An explicit bookmark argument is used verbatim (manual override). Otherwise
    # auto-detect a trunk bookmark ('dev' then 'main') and capture the auto-created
    # push bookmark on @-. The push bookmark must be captured BEFORE the fetch,
    # because the fetch may delete it (e.g. the PR was merged and its remote
    # branch removed).
    set -l explicit_bookmark ""
    set -l push_bookmark ""

    if test (count $argv) -gt 0
        set explicit_bookmark $argv[1]
        if not _jj_sync_base_bookmark_exists "$explicit_bookmark"
            echo (set_color $fish_color_error)"Error: Bookmark '"(set_color -o -i -u cyan)"$explicit_bookmark"(set_color normal)(set_color $fish_color_error)"' does not exist."(set_color normal) >&2
            return 1
        end
    else
        set -l prefix (jj config get git.push-bookmark-prefix 2>/dev/null)
        test -n "$prefix"; or set prefix push-
        set push_bookmark (jj log -r @- --no-graph -T 'local_bookmarks.map(|b| b.name()).join("\n")' | string match -- "$prefix*")
        if test (count $push_bookmark) -gt 1
            echo (set_color yellow)"Warning: Multiple push bookmarks on @- ("(string join ", " $push_bookmark)"); skipping push-bookmark tracking."(set_color normal) >&2
            set push_bookmark ""
        end
    end

    jj git fetch
    set -l fetch_status $status
    if test $fetch_status -ne 0
        echo (set_color $fish_color_error)"Error: 'jj git fetch' failed."(set_color normal) >&2
        return $fetch_status
    end

    # Manual override: keep the original behaviour of checking @- against the
    # given bookmark only.
    if test -n "$explicit_bookmark"
        _jj_sync_base_warn_if_merged "$explicit_bookmark"
        set -l merged_status $status
        if test $merged_status -eq 2
            return 1
        else if test $merged_status -eq 0
            jj rebase --onto $explicit_bookmark
            return $status
        end
        echo (set_color green)"@- is not merged into "(set_color -o -i -u cyan)"$explicit_bookmark"(set_color normal)(set_color green)". Safe to continue working on it."(set_color normal)
        echo
        return 0
    end

    # Auto mode. Trunk wins: if @- has merged into dev/main, rebase onto it.
    set -l trunk ""
    if _jj_sync_base_bookmark_exists dev
        set trunk dev
    else if _jj_sync_base_bookmark_exists main
        set trunk main
    end

    if test -n "$trunk"
        _jj_sync_base_warn_if_merged "$trunk"
        set -l merged_status $status
        if test $merged_status -eq 2
            return 1
        else if test $merged_status -eq 0
            jj rebase --onto $trunk
            return $status
        end
    end

    # Not merged into trunk: follow the push bookmark forward when it has advanced
    # to a strict descendant of @- (a safe fast-forward of our base).
    if test -n "$push_bookmark"; and _jj_sync_base_bookmark_exists "$push_bookmark"
        # A conflicted (divergent) bookmark resolves to multiple commits; rebasing
        # onto its ambiguous name would fail, so warn and skip instead.
        # The 'commit_id ++ "\n"' template is required, not redundant: with
        # --no-graph jj does NOT separate revisions (the per-line newline comes
        # from the graph renderer), so a bare 'commit_id' glues the ids together
        # and the count below would always be 1.
        set -l targets (jj log -r "$push_bookmark" --no-graph -T 'commit_id ++ "\n"')
        if test (count $targets) -gt 1
            echo (set_color yellow)"Warning: push bookmark "(set_color -o -i -u cyan)"$push_bookmark"(set_color normal)(set_color yellow)" is conflicted; skipping push-bookmark tracking."(set_color normal) >&2
        else
            set -l advanced (jj log -r "$push_bookmark & descendants(@-) & ~@-" --no-graph -T "commit_id")
            if test -n "$advanced"
                echo (set_color yellow)"Warning: push bookmark "(set_color -o -i -u cyan)"$push_bookmark"(set_color normal)(set_color yellow)" advanced past @-. Auto-rebasing onto it..."(set_color normal)
                jj rebase --onto $push_bookmark
                return $status
            end
        end
    end

    if test -z "$trunk"; and test -z "$push_bookmark"
        echo (set_color $fish_color_error)"Error: Neither 'dev'/'main' nor a push bookmark on @- was found. Please specify a bookmark name."(set_color normal) >&2
        return 1
    end

    echo (set_color green)"@- has not been merged/advanced and there is nothing to rebase onto. Safe to continue working on it."(set_color normal)
    echo
end
