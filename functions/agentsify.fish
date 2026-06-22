function _agentsify_usage
    echo "Unify AI agent context files into AGENTS.md.
Renames CLAUDE.md/GEMINI.md to AGENTS.md and links CLAUDE.md -> AGENTS.md.
Syntax: agentsify [dir]"
end

function agentsify --description 'Unify AI agent context files into AGENTS.md with a CLAUDE.md symlink'
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
            echo (set_color $fish_color_error)"Error: no AGENTS.md, CLAUDE.md or GEMINI.md found in $dir!"(set_color normal) >&2
            return 1
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
    ln -s AGENTS.md "$claude"
    echo "Linked CLAUDE.md -> AGENTS.md"

    return $conflict
end
