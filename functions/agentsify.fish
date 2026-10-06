function _agentsify_usage
    echo "Unify AI agent context files into AGENTS.md and skills dirs into .agents/skills.
Renames CLAUDE.md/GEMINI.md to AGENTS.md, keeping one that imports @AGENTS.md,
and removes CLAUDE.md -> AGENTS.md symlinks (claude reads AGENTS.md in projects).
Claude's config dir (\$CLAUDE_CONFIG_DIR, default ~/.claude) gets a CLAUDE.md
importing @AGENTS.md, since claude reads only CLAUDE.md there.
Merges .claude/.gemini/.codex skills/ into .agents/skills and links skills/ back.
Links entries listed in .agents/links.txt (AGENTS.md or skills/<name>) to the
same paths under \$PROMPTS_DIR (default ~/archives/prompts, cloned from
legendu-net/prompts if missing): AGENTS.md -> \$PROMPTS_DIR/AGENTS.md and
.agents/skills/<name> -> \$PROMPTS_DIR/skills/<name>. --adopt moves an entry
into \$PROMPTS_DIR first and records it in .agents/links.txt. --adopt-all adopts
every local AGENTS.md or skill identical to its copy in \$PROMPTS_DIR.
Syntax: agentsify [-a|--adopt ENTRY]... [--adopt-all] [dir]"
end

function _agentsify_kind --description 'Print the kind of a path: link, dir, file or missing'
    if test -L "$argv[1]"
        echo link
    else if test -d "$argv[1]"
        echo dir
    else if test -e "$argv[1]"
        echo file
    else
        echo missing
    end
end

function _agentsify_merge --description 'Recursively merge a source directory into an existing destination directory'
    set -l src "$argv[1]"
    set -l dst "$argv[2]"
    set -l conflict 0

    for entry in "$src"/* "$src"/.*
        set -l target "$dst/"(path basename -- "$entry")
        set -l entry_kind (_agentsify_kind "$entry")
        set -l target_kind (_agentsify_kind "$target")
        if test "$target_kind" = missing
            mv -- "$entry" "$target"
            or set conflict 1
        else if test "$entry_kind" = dir; and test "$target_kind" = dir
            _agentsify_merge "$entry" "$target"
            or set conflict 1
        else if test "$entry_kind" = link; and test "$target_kind" = link; and test "$(readlink -- "$entry")" = "$(readlink -- "$target")"
            rm -- "$entry"
        else if test "$entry_kind" = file; and test "$target_kind" = file; and cmp -s -- "$entry" "$target"
            rm -- "$entry"
        else
            echo (set_color $fish_color_error)"Error: $entry conflicts with $target; merge it manually."(set_color normal) >&2
            set conflict 1
        end
    end

    # Drop the source directory once every entry has been merged away; a
    # conflict above always leaves at least one entry behind.
    set -l leftover "$src"/* "$src"/.*
    if test (count $leftover) -eq 0
        rmdir -- "$src"
        or set conflict 1
    end

    return $conflict
end

function _agentsify_warn_gitignore --description 'Warn about .gitignore rules that reference unified directories'
    set -l dir "$argv[1]"
    set -l names $argv[2..]
    set -l file "$dir/.gitignore"
    if test (count $names) -eq 0
        return 0
    end
    if not test -f "$file"
        return 0
    end

    set -l hits
    while read -l line
        set -l pattern (string trim -- "$line")
        if test -z "$pattern"
            continue
        end
        if string match -q -- '#*' "$pattern"
            continue
        end
        for name in $names
            if string match -q -- "*$name*" "$pattern"
                set -a hits "$pattern"
                break
            end
        end
    end <"$file"

    if test (count $hits) -gt 0
        echo (set_color yellow)"Warning: $file still references the unified directories:"(set_color normal) >&2
        for hit in $hits
            echo "    $hit" >&2
        end
        echo "Git does not follow symlinks, so those rules match nothing now; point them at .agents/ instead." >&2
    end
end

function _agentsify_imports_agents --description 'Check whether a context file imports AGENTS.md via an @AGENTS.md line'
    test -f "$argv[1]"
    and string trim <"$argv[1]" | string match -q -r -- '^@(\./)?AGENTS\.md$'
end

function _agentsify_files --description 'Unify AI agent context files into AGENTS.md'
    set -l dir "$argv[1]"
    # The expected target of an AGENTS.md linked via .agents/links.txt, if any.
    set -l linked "$argv[2]"
    set -l agents "$dir/AGENTS.md"
    # Any other symlink (e.g. AGENTS.md -> CLAUDE.md) would make the folding
    # below delete the only real copy, so refuse it.
    if test -L "$agents"; and begin
            test -z "$linked"; or test "$(readlink -- "$agents")" != "$linked"
        end
        echo (set_color $fish_color_error)"Error: $agents is a symlink; resolve it into a regular file first."(set_color normal) >&2
        return 1
    end

    # Ensure AGENTS.md exists, renaming the first real source file into it.
    # Without one, still tidy up CLAUDE.md below: in a fresh checkout a
    # listed AGENTS.md is only linked later, by _agentsify_link.
    set -l found 1
    if not test -e "$agents"
        set -l source ""
        for name in CLAUDE.md GEMINI.md
            set -l file "$dir/$name"
            if test -f "$file"; and not test -L "$file"; and not _agentsify_imports_agents "$file"
                set source "$file"
                break
            end
        end
        if test -z "$source"
            set found 0
        else
            mv -- "$source" "$agents"
            or return 1
            echo "Renamed "(path basename -- "$source")" -> AGENTS.md"
        end
    end

    # Fold any remaining real CLAUDE.md/GEMINI.md into AGENTS.md.
    set -l conflict 0
    if test $found -eq 1
        for name in CLAUDE.md GEMINI.md
            set -l file "$dir/$name"
            if test -L "$file"; or not test -e "$file"
                continue
            end
            if _agentsify_imports_agents "$file"
                continue
            end
            if cmp -s -- "$file" "$agents"
                rm -- "$file"
            else
                echo (set_color $fish_color_error)"Error: $file differs from AGENTS.md; merge it manually."(set_color normal) >&2
                set conflict 1
            end
        end
    end

    # claude reads AGENTS.md in projects, so a CLAUDE.md -> AGENTS.md link
    # left by an earlier run is redundant.
    set -l claude "$dir/CLAUDE.md"
    if test -L "$claude"; and test "$(readlink -- "$claude")" = AGENTS.md
        rm -- "$claude"
        and echo "Removed CLAUDE.md -> AGENTS.md symlink"
        or set conflict 1
        set found 1
    end

    # claude reads only CLAUDE.md from its config dir, so import AGENTS.md there.
    set -l config "$CLAUDE_CONFIG_DIR"
    if test -z "$config"
        set config "$HOME/.claude"
    end
    if test -d "$config"; and test "$(path resolve -- "$dir")" = "$(path resolve -- "$config")"
        if test (_agentsify_kind "$claude") = missing; and begin
                test -e "$agents"; or test -n "$linked"
            end
            if printf '%s\n' @AGENTS.md >"$claude"
                echo "Created CLAUDE.md importing @AGENTS.md"
            else
                set conflict 1
            end
            set found 1
        end
    end

    if test $found -eq 0
        # Nothing to unify; the caller decides whether that is an error.
        return 2
    end
    return $conflict
end

function _agentsify_skills --description 'Unify per-tool skills/ directories into .agents/skills'
    set -l dir "$argv[1]"
    set -l agents_skills "$dir/.agents/skills"
    # Skills are the one thing that's genuinely portable across agent CLIs;
    # commands, settings.json etc. have per-tool schemas and are left alone.
    set -l tool_names .claude .gemini .codex

    set -l found 0
    if test -L "$agents_skills"; or test -e "$agents_skills"
        set found 1
    end
    for name in $tool_names
        if test -L "$dir/$name"; or test -L "$dir/$name/skills"; or test -e "$dir/$name/skills"
            set found 1
        end
    end
    if test $found -eq 0
        # Nothing to unify; the caller decides whether that is an error.
        return 2
    end

    if test -L "$dir/.agents"
        echo (set_color $fish_color_error)"Error: $dir/.agents is a symlink; resolve it into a real directory first."(set_color normal) >&2
        return 1
    end
    if test -L "$agents_skills"
        echo (set_color $fish_color_error)"Error: $agents_skills is a symlink; resolve it into a real directory first."(set_color normal) >&2
        return 1
    end
    mkdir -p -- "$agents_skills"
    or return 1

    set -l conflict 0

    # A tool dir that is itself a symlink could alias into .agents/skills
    # (e.g. a leftover from unifying whole tool dirs some other way) and
    # corrupt it via mkdir/merge/ln; refuse to touch those tools instead.
    set -l aliased
    for name in $tool_names
        if test -L "$dir/$name"
            echo (set_color $fish_color_error)"Error: $dir/$name is a symlink; resolve it before unifying skills."(set_color normal) >&2
            set conflict 1
            set -a aliased "$name"
        end
    end

    # Merge each tool's skills/ into .agents/skills.
    for name in $tool_names
        if contains -- "$name" $aliased
            continue
        end
        set -l skills "$dir/$name/skills"
        set -l kind (_agentsify_kind "$skills")
        if test "$kind" = missing
            continue
        else if test "$kind" = dir
            _agentsify_merge "$skills" "$agents_skills"
            or set conflict 1
        else if test "$kind" = link
            set -l target (readlink -- "$skills")
            if test "$target" = ../.agents/skills
                continue
            end
            echo "Replacing $name/skills symlink that pointed to $target"
            rm -- "$skills"
            or set conflict 1
        else
            echo (set_color $fish_color_error)"Error: $skills is not a directory."(set_color normal) >&2
            set conflict 1
        end
    end

    # Link skills/ back into every tool dir that already exists, even one
    # that never had its own skills/, so it can see what other tools bring.
    # A tool dir that doesn't exist at all is left alone rather than
    # fabricated just to hold a symlink.
    for name in $tool_names
        if contains -- "$name" $aliased
            continue
        end
        set -l tool "$dir/$name"
        if not test -d "$tool"
            continue
        end
        set -l skills "$tool/skills"
        set -l kind (_agentsify_kind "$skills")
        if test "$kind" = link
            continue
        else if test "$kind" != missing
            echo (set_color $fish_color_error)"Error: $skills remains; cannot link it to .agents/skills."(set_color normal) >&2
            set conflict 1
            continue
        end
        if ln -s ../.agents/skills "$skills"
            echo "Unified $name/skills -> .agents/skills"
        else
            set conflict 1
        end
    end

    # Only skills/ moves under a symlink; a gitignore rule for anything else
    # under a tool dir (e.g. settings.local.json) is still perfectly valid.
    _agentsify_warn_gitignore "$dir" $tool_names/skills
    return $conflict
end

function _agentsify_prompts_dir --description 'Resolve $PROMPTS_DIR, cloning legendu-net/prompts there if missing'
    set -l dir "$PROMPTS_DIR"
    if test -z "$dir"
        set dir "$HOME/archives/prompts"
    end

    if not test -e "$dir"
        if not mkdir -p -- (path dirname -- "$dir")
            return 1
        end
        # git's own clone progress goes to stderr; redirecting stdout there
        # too keeps it out of this function's command-substitution result.
        if not git clone git@github.com:legendu-net/prompts.git "$dir" >&2
            # Clean up a partial clone so the next run retries instead of
            # silently treating a broken checkout as a valid one.
            test -e "$dir"; and rip -- "$dir"
            return 1
        end
    end
    if not test -d "$dir"
        echo (set_color $fish_color_error)"Error: $dir is not a directory."(set_color normal) >&2
        return 1
    end

    path resolve -- "$dir"
end

function _agentsify_valid_skill_name --description 'Check that a string is safe to use as a single .agents/skills path segment'
    set -l name "$argv[1]"
    test -n "$name"
    and not string match -q -- '*/*' "$name"
    and not contains -- "$name" . ..
end

function _agentsify_link_entry --description 'Print the local path and kind (file or dir) that a .agents/links.txt entry maps to'
    set -l entry "$argv[1]"
    if test "$entry" = AGENTS.md
        echo AGENTS.md
        echo file
        return 0
    end
    set -l name (string replace -r -- '^skills/' '' "$entry")
    and _agentsify_valid_skill_name "$name"
    or return 1
    echo ".agents/skills/$name"
    echo dir
end

function _agentsify_guard_agents --description 'Refuse to operate through a symlinked .agents, .agents/skills or .agents/links.txt'
    set -l dir "$argv[1]"
    for rel in .agents .agents/skills .agents/links.txt
        set -l path "$dir/$rel"
        if test -L "$path"
            echo (set_color $fish_color_error)"Error: $path is a symlink; resolve it into a real file or directory first."(set_color normal) >&2
            return 1
        end
    end
    return 0
end

function _agentsify_append_line --description 'Append a line to a file, first adding a trailing newline if the file lacks one'
    set -l file "$argv[1]"
    set -l line "$argv[2]"
    if test -s "$file"; and test -n "$(tail -c1 -- "$file")"
        echo >>"$file"
        or return 1
    end
    # printf, not echo: echo reinterprets a value like "-n" as its own flag
    # instead of writing it, silently dropping the line.
    printf '%s\n' "$line" >>"$file"
end

function _agentsify_gitignore_add --description 'Ensure a line is present in a directory''s .gitignore'
    set -l dir "$argv[1]"
    set -l line "$argv[2]"
    set -l file "$dir/.gitignore"

    if test -f "$file"
        while read -l existing
            if test "$(string trim -- "$existing")" = "$line"
                return 0
            end
        end <"$file"
    end

    _agentsify_append_line "$file" "$line"
end

function _agentsify_adopt --description 'Move named project entries into $PROMPTS_DIR'
    set -l dir "$argv[1]"
    set -l entries $argv[2..]
    _agentsify_guard_agents "$dir"
    or return 1
    set -l prompts (_agentsify_prompts_dir)
    or return 1

    set -l conflict 0
    for entry in $entries
        set -l info (_agentsify_link_entry "$entry")
        if test (count $info) -ne 2
            echo (set_color $fish_color_error)"Error: '$entry' is not a supported entry (AGENTS.md or skills/<name>); cannot adopt it."(set_color normal) >&2
            set conflict 1
            continue
        end
        set -l kind $info[2]
        set -l local "$dir/$info[1]"
        set -l target "$prompts/$entry"

        if test (_agentsify_kind "$local") != $kind
            echo (set_color $fish_color_error)"Error: $local is not a real $kind; cannot adopt it."(set_color normal) >&2
            set conflict 1
            continue
        end
        # Run inside $PROMPTS_DIR, the "identical copy" is the file itself.
        if test "$(path resolve -- "$local")" = "$(path resolve -- "$target")"
            echo (set_color $fish_color_error)"Error: $local is already in $prompts; cannot adopt it."(set_color normal) >&2
            set conflict 1
            continue
        end

        set -l message ""
        set -l target_kind (_agentsify_kind "$target")
        if test "$target_kind" = missing
            if not mkdir -p -- (path dirname -- "$target"); or not mv -- "$local" "$target"
                set conflict 1
                continue
            end
            set message "Adopted $entry into $prompts"
        else if test "$target_kind" != $kind
            echo (set_color $fish_color_error)"Error: $target is not a real $kind."(set_color normal) >&2
            set conflict 1
            continue
        else if diff -rq -- "$local" "$target" >/dev/null 2>&1
            if not rip -- "$local"
                set conflict 1
                continue
            end
            set message "Dropped $local; identical copy already at $target"
        else
            echo (set_color $fish_color_error)"Error: $local differs from $target; merge it manually."(set_color normal) >&2
            set conflict 1
            continue
        end

        set -l manifest "$dir/.agents/links.txt"
        if not test -e "$manifest"; or not grep -qx -- "$entry" "$manifest"
            if not mkdir -p -- "$dir/.agents"; or not _agentsify_append_line "$manifest" "$entry"
                echo (set_color $fish_color_error)"Error: could not record $entry in $manifest."(set_color normal) >&2
                set conflict 1
                continue
            end
        end
        echo "$message"
    end

    return $conflict
end

function _agentsify_adopt_all --description 'Adopt every local AGENTS.md or skill identical to its $PROMPTS_DIR copy'
    set -l dir "$argv[1]"
    _agentsify_guard_agents "$dir"
    or return 1

    set -l candidates AGENTS.md
    for skill in "$dir"/.agents/skills/*
        set -a candidates "skills/"(path basename -- "$skill")
    end
    # Keep only real local copies, so nothing to adopt never clones prompts.
    set -l locals
    for entry in $candidates
        set -l info (_agentsify_link_entry "$entry")
        if test (count $info) -eq 2; and test (_agentsify_kind "$dir/$info[1]") = $info[2]
            set -a locals "$entry"
        end
    end
    if test (count $locals) -eq 0
        return 2
    end

    set -l prompts (_agentsify_prompts_dir)
    or return 1

    # Only identical copies are adopted; moving a new or diverged one into
    # $PROMPTS_DIR is left to an explicit --adopt.
    set -l entries
    for entry in $locals
        set -l info (_agentsify_link_entry "$entry")
        set -l kind $info[2]
        set -l target "$prompts/$entry"
        set -l target_kind (_agentsify_kind "$target")
        if test "$target_kind" = missing
            echo "Skipped $entry; not in $prompts yet (use --adopt $entry to move it there)"
        else if test "$target_kind" != $kind
            echo "Skipped $entry; $target is not a real $kind"
        else if test "$(path resolve -- "$dir/$info[1]")" = "$(path resolve -- "$target")"
            echo "Skipped $entry; it is already in $prompts"
        else if diff -rq -- "$dir/$info[1]" "$target" >/dev/null 2>&1
            set -a entries "$entry"
        else
            echo "Skipped $entry; it differs from $target"
        end
    end

    if test (count $entries) -eq 0
        return 2
    end
    _agentsify_adopt "$dir" $entries
end

function _agentsify_link --description 'Symlink entries listed in .agents/links.txt to $PROMPTS_DIR'
    set -l dir "$argv[1]"
    set -l manifest "$dir/.agents/links.txt"
    if test -L "$manifest"
        echo (set_color $fish_color_error)"Error: $manifest is a symlink; resolve it into a real file first."(set_color normal) >&2
        return 1
    end
    if not test -f "$manifest"
        return 2
    end
    _agentsify_guard_agents "$dir"
    or return 1

    set -l prompts (_agentsify_prompts_dir)
    or return 1

    set -l conflict 0
    while read -l line
        set -l entry (string trim -- "$line")
        if test -z "$entry"; or string match -q -- '#*' "$entry"
            continue
        end
        set -l info (_agentsify_link_entry "$entry")
        if test (count $info) -ne 2
            echo (set_color $fish_color_error)"Error: '$entry' in $manifest is not a supported entry (AGENTS.md or skills/<name>)."(set_color normal) >&2
            set conflict 1
            continue
        end
        set -l rel $info[1]
        set -l kind $info[2]

        set -l source "$prompts/$entry"
        if test (_agentsify_kind "$source") != $kind
            echo (set_color $fish_color_error)"Error: $source is not a real $kind; cannot link $entry."(set_color normal) >&2
            set conflict 1
            continue
        end

        set -l link "$dir/$rel"
        set -l link_kind (_agentsify_kind "$link")
        if test "$link_kind" = $kind
            echo (set_color $fish_color_error)"Error: $link is a real $kind; run 'agentsify --adopt $entry' first."(set_color normal) >&2
            set conflict 1
            continue
        else if test "$link_kind" != link; and test "$link_kind" != missing
            echo (set_color $fish_color_error)"Error: $link is a $link_kind; resolve it manually."(set_color normal) >&2
            set conflict 1
            continue
        end

        if not mkdir -p -- (path dirname -- "$link")
            set conflict 1
            continue
        end

        set -l relink 1
        if test "$link_kind" = link
            set -l target (readlink -- "$link")
            if test "$target" = "$source"
                set relink 0
            else
                echo "Replacing $rel symlink that pointed to $target"
            end
        end

        if test $relink -eq 1
            if ln -sfn -- "$source" "$link"
                echo "Linked $rel -> $source"
            else
                set conflict 1
                continue
            end
        end

        # The link points into this machine's $PROMPTS_DIR, so keep it out of git.
        if not _agentsify_gitignore_add "$dir" "/$rel"
            set conflict 1
        end
    end <"$manifest"

    return $conflict
end

function agentsify --description 'Unify AI agent context files into AGENTS.md and skills dirs into .agents/skills'
    argparse h/help a/adopt=+ adopt-all -- $argv
    or return 1
    if set -q _flag_help
        _agentsify_usage
        return 0
    end

    if test (count $argv) -gt 1
        echo (set_color $fish_color_error)"Error: agentsify accepts at most 1 argument."(set_color normal) >&2
        _agentsify_usage >&2
        return 1
    end

    set -l dir "."
    if test (count $argv) -eq 1
        set dir "$argv[1]"
    end
    if not test -d "$dir"
        echo (set_color $fish_color_error)"Error: $dir is not a directory!"(set_color normal) >&2
        return 1
    end

    # An AGENTS.md listed in links.txt is expected to be a symlink into
    # $PROMPTS_DIR; tell _agentsify_files which target to accept.
    set -l agents_target ""
    set -l manifest "$dir/.agents/links.txt"
    if test -f "$manifest"; and not test -L "$manifest"; and string trim <"$manifest" | string match -q -- AGENTS.md
        set -l prompts (_agentsify_prompts_dir)
        or return 1
        set agents_target "$prompts/AGENTS.md"
    end

    _agentsify_files "$dir" "$agents_target"
    set -l files_status $status
    _agentsify_skills "$dir"
    set -l skills_status $status

    set -l adopt_status 2
    if set -q _flag_adopt
        _agentsify_adopt "$dir" $_flag_adopt
        set adopt_status $status
    end

    set -l adopt_all_status 2
    if set -q _flag_adopt_all
        _agentsify_adopt_all "$dir"
        set adopt_all_status $status
    end

    set -l link_status 2
    if test -f "$manifest"
        _agentsify_link "$dir"
        set link_status $status
    end

    if test $files_status -eq 2; and test $skills_status -eq 2; and test $adopt_status -eq 2; and test $adopt_all_status -eq 2; and test $link_status -eq 2
        echo (set_color $fish_color_error)"Error: no AGENTS.md, CLAUDE.md, GEMINI.md, agent skills directory or links.txt found in $dir!"(set_color normal) >&2
        return 1
    end
    if test $files_status -eq 1; or test $skills_status -eq 1; or test $adopt_status -eq 1; or test $adopt_all_status -eq 1; or test $link_status -eq 1
        return 1
    end

    return 0
end
