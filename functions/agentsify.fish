function _agentsify_usage
    echo "Unify AI agent context files into AGENTS.md and skills dirs into .agents/skills.
Renames CLAUDE.md/GEMINI.md to AGENTS.md and links CLAUDE.md -> AGENTS.md.
Merges .claude/.gemini/.codex skills/ into .agents/skills and links skills/ back.
Syntax: agentsify [dir]"
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

function _agentsify_files --description 'Unify AI agent context files into AGENTS.md'
    set -l dir "$argv[1]"
    set -l agents "$dir/AGENTS.md"
    if test -L "$agents"
        echo (set_color $fish_color_error)"Error: $agents is a symlink; resolve it into a regular file first."(set_color normal) >&2
        return 1
    end

    # Ensure AGENTS.md exists, renaming the first real source file into it.
    if not test -e "$agents"
        set -l source ""
        for name in CLAUDE.md GEMINI.md
            set -l file "$dir/$name"
            if test -f "$file"; and not test -L "$file"
                set source "$file"
                break
            end
        end
        if test -z "$source"
            # Nothing to unify; the caller decides whether that is an error.
            return 2
        end
        mv -- "$source" "$agents"
        or return 1
        echo "Renamed "(path basename -- "$source")" -> AGENTS.md"
    end

    # Fold any remaining real CLAUDE.md/GEMINI.md into AGENTS.md.
    set -l conflict 0
    for name in CLAUDE.md GEMINI.md
        set -l file "$dir/$name"
        if test -L "$file"; or not test -e "$file"
            continue
        end
        if cmp -s -- "$file" "$agents"
            rm -- "$file"
        else
            echo (set_color $fish_color_error)"Error: $file differs from AGENTS.md; merge it manually."(set_color normal) >&2
            set conflict 1
        end
    end

    # Link CLAUDE.md -> AGENTS.md, since the claude cli only reads CLAUDE.md.
    set -l claude "$dir/CLAUDE.md"
    if test -L "$claude"
        set -l target (readlink "$claude")
        if test "$target" != AGENTS.md
            echo "Replacing CLAUDE.md symlink that pointed to $target"
        end
        rm -- "$claude"
    end
    if test -e "$claude"
        echo (set_color $fish_color_error)"Error: a real CLAUDE.md remains; cannot create the symlink."(set_color normal) >&2
        return 1
    end
    if ln -s AGENTS.md "$claude"
        echo "Linked CLAUDE.md -> AGENTS.md"
    else
        set conflict 1
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

function agentsify --description 'Unify AI agent context files into AGENTS.md and skills dirs into .agents/skills'
    argparse h/help -- $argv
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

    _agentsify_files "$dir"
    set -l files_status $status
    _agentsify_skills "$dir"
    set -l skills_status $status

    if test $files_status -eq 2; and test $skills_status -eq 2
        echo (set_color $fish_color_error)"Error: no AGENTS.md, CLAUDE.md, GEMINI.md or agent skills directory found in $dir!"(set_color normal) >&2
        return 1
    end
    if test $files_status -eq 1; or test $skills_status -eq 1
        return 1
    end

    return 0
end
