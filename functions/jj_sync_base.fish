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

function _jj_sync_base_changed_paths --argument-names from to
    # Emit the repo-root-relative paths that differ between two revisions, NUL
    # separated (so a caller can `string split0`). The diff runs from the repo
    # root because `jj diff` prints paths relative to the current directory, and
    # root-relative paths are what `_jj_root_fileset` expects.
    set -l root (jj root)
    or return 1
    set -l saved $PWD
    cd $root
    or return 1
    jj diff --from $from --to $to -T 'path.display() ++ "\0"'
    set -l diff_status $status
    cd $saved
    return $diff_status
end

function _jj_sync_base_divergence_manual --argument-names bookmark local_commit merged_commit reason
    # Explain a divergence that could not be recovered automatically and print
    # the manual recovery recipe.
    echo (set_color yellow)"Warning: @- is a divergent local copy of a change already merged into "(set_color -o -i -u cyan)"$bookmark"(set_color normal)(set_color yellow)"."(set_color normal) >&2
    echo (set_color yellow)"Automatic recovery was skipped because $reason."(set_color normal) >&2
    echo "Its merged copy ($merged_commit) is immutable. To recover manually:" >&2
    echo "  jj new $bookmark" >&2
    echo "  jj restore --from $local_commit -- <files to keep>" >&2
    echo "  jj abandon $local_commit" >&2
end

function _jj_sync_base_recover_divergence --argument-names bookmark
    # Detect and recover from the situation where @-'s change was merged into
    # $bookmark as a DIFFERENT commit: the PR merged (adding an immutable copy of
    # the change to $bookmark's history), and @- was then rewritten locally. The
    # two copies share a change id, so once `jj git fetch` makes the merged copy
    # visible again the change becomes divergent. The merged copy can never be
    # removed, so recovery re-creates any extra local work under a fresh change id
    # and abandons the local copy.
    #
    # Returns 0 when a divergence was recovered, 1 when there is no divergence
    # (the caller should continue), and 2 when a divergence needs manual handling
    # (the caller should stop).

    set -l change_id (jj log -r @- --no-graph -T 'change_id')
    set -l local_commit (jj log -r @- --no-graph -T 'commit_id')

    # The `change_id()` function expands to every visible commit sharing the id
    # (a bare change-id symbol instead errors once the id is divergent), so this
    # finds a sibling of @- that is an ancestor of (i.e. has been merged into)
    # $bookmark.
    set -l merged_commit (jj log -r "change_id($change_id) & ::$bookmark & ~@-" --no-graph -T 'commit_id ++ "\n"')
    set -l query_status $status
    if test $query_status -ne 0
        echo (set_color $fish_color_error)"Error: Failed to query divergence of @- against "(set_color -o -i -u cyan)"$bookmark"(set_color normal)(set_color $fish_color_error)"."(set_color normal) >&2
        return 2
    end
    if test (count $merged_commit) -eq 0
        return 1
    end
    if test (count $merged_commit) -gt 1
        echo (set_color yellow)"Warning: @- matches multiple merged commits in "(set_color -o -i -u cyan)"$bookmark"(set_color normal)(set_color yellow)"; skipping automatic divergence recovery."(set_color normal) >&2
        return 2
    end

    # Auto-recovery abandons the local copy of the change and the current (empty)
    # working copy, so refuse when the working copy carries uncommitted work.
    set -l wc_nonempty (jj log -r @ --no-graph -T 'if(empty, "", "1")')
    if test -n "$wc_nonempty"
        _jj_sync_base_divergence_manual "$bookmark" "$local_commit" "$merged_commit" \
            "the working copy has uncommitted changes"
        return 2
    end

    # Extra local work = paths that differ between the merged copy and the local
    # copy. The $status of a `| string split0` pipe is the split's, not jj's, so
    # a jj failure here would look like "no extra work"; the commits were just
    # resolved successfully above, so a diff between them is not expected to fail.
    set -l local_paths (_jj_sync_base_changed_paths "$merged_commit" "$local_commit" | string split0)
    set -l trunk_paths (_jj_sync_base_changed_paths "$merged_commit" "$bookmark" | string split0)

    # If any locally-changed path was also changed on $bookmark since the merged
    # copy, restoring the local version would revert that work, so bail. The
    # comparison is per exact path, so a local rename that collides with a trunk
    # edit to the old name is not caught; that only risks a leftover duplicate
    # file, never a loss of trunk work.
    set -l overlap
    for path in $local_paths
        if contains -- $path $trunk_paths
            set -a overlap $path
        end
    end
    if test (count $overlap) -gt 0
        _jj_sync_base_divergence_manual "$bookmark" "$local_commit" "$merged_commit" \
            "local edits touch files also changed on $bookmark: "(string join ", " $overlap)
        return 2
    end

    # Capture the old (empty) working copy so it can be abandoned along with the
    # divergent local copy after the recovery.
    set -l orig_wc (jj log -r @ --no-graph -T 'commit_id')

    echo (set_color yellow)"Warning: @- is a divergent local copy of a change already merged into "(set_color -o -i -u cyan)"$bookmark"(set_color normal)(set_color yellow)". Recovering onto a fresh change id..."(set_color normal)

    jj new $bookmark
    or return 2

    if test (count $local_paths) -gt 0
        # Reconstruct the extra local work on top of $bookmark. Root-anchored
        # filesets keep this correct regardless of the caller's cwd.
        set -l filesets (_jj_root_fileset $local_paths | string split0)
        jj restore --from $local_commit -- $filesets
        or return 2
        # Preserve the original description. Passed directly (not via eval), so no
        # shell escaping is needed even for a multi-line message. `string collect`
        # of an empty description yields a zero-element list, which would make
        # `jj describe -m` error on a missing value, so only set it when non-empty.
        set -l desc (jj log -r $local_commit --no-graph -T 'description' | string collect)
        if test -n "$desc"
            jj describe -r @ -m $desc
            or return 2
        end
    end

    # Remove the local push bookmark(s) on the divergent copy so abandoning it
    # does not strand them on an older commit. Any matching bookmark on the remote
    # is left untouched and reported so the user can clean it up.
    set -l prefix (jj config get git.push-bookmark-prefix 2>/dev/null)
    test -n "$prefix"; or set prefix push-
    set -l stale_bookmarks (jj log -r $local_commit --no-graph -T 'local_bookmarks.map(|b| b.name()).join("\n")' | string match -- "$prefix*")
    for bookmark_name in $stale_bookmarks
        jj bookmark delete $bookmark_name
    end

    jj abandon $local_commit $orig_wc
    or return 2

    if test (count $local_paths) -gt 0
        echo (set_color green)"Recovered "(count $local_paths)" locally-changed file(s) onto a fresh change on "(set_color -o -i -u cyan)"$bookmark"(set_color normal)(set_color green)"."(set_color normal)
    else
        echo (set_color green)"The change was fully merged into "(set_color -o -i -u cyan)"$bookmark"(set_color normal)(set_color green)"; cleaned up the divergent local copy."(set_color normal)
    end
    if test (count $stale_bookmarks) -gt 0
        echo (set_color yellow)"Deleted local bookmark(s): "(string join ", " $stale_bookmarks)". If they still exist on the remote, delete them there too."(set_color normal)
    end
    echo
    return 0
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

    if set -q argv[1]
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

        # @- is not itself an ancestor of the trunk, but its change may have been
        # merged as a divergent sibling (PR merged, then @- rewritten locally).
        _jj_sync_base_recover_divergence "$trunk"
        set -l recover_status $status
        if test $recover_status -eq 0
            return 0
        else if test $recover_status -eq 2
            return 1
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
