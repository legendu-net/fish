function _tbx_bases
    # The registry of known base container names (single source of truth).
    printf '%s\n' jupyterhub-ds code-server
end

function _tbx_usage
    echo "Manage versioned toolbox/podman containers for a base image.
Versioned containers are named <base> (version 1) or <base>-N (version N>1).
Known bases: "(string join ', ' (_tbx_bases))".
Syntax:
    tbx version [-n/--next] <base>
    tbx ls [<base>...]
    tbx clean [-f/--force] [-r/--renumber] [<base>...]
    tbx renumber [-f/--force] [<base>...]
Sub-commands (each has a one-letter alias):
    version (v):  Print the newest running version's container name, creating
        version 1 if nothing is running. With --next, create the next version.
    ls (l):       List every version of each base and how many processes run inside it.
    clean (c):    Remove old (non-newest) containers that are not in use.
                  -f/--force: Remove without prompting for confirmation.
                  -r/--renumber: After cleaning, compact survivors to 1..N.
    renumber (r): Compact each base's versions to a gap-free 1..N sequence
                  (e.g. after clean): code-server-2 -> code-server, etc.
                  -f/--force: Rename without prompting for confirmation.
    ls, clean and renumber act on all known bases, or only the base(s) given.
    -h/--help: Show this help doc."
end

function _tbx_image --argument-names base
    # Map a base container name to its ':next' image. Return non-zero on unknown.
    switch "$base"
        case jupyterhub-ds
            echo quay.io/legendu/jupyterhub-ds:next
        case code-server
            echo quay.io/legendu/vscode-server:next
        case '*'
            return 1
    end
end

function _tbx_parse --argument-names base name
    # Echo the version of <name> under <base> (bare base = 1, '<base>-N' = N).
    # Return non-zero when <name> does not belong to <base>.
    set -l escaped (string escape --style=regex -- "$base")
    string match --regex -- "^$escaped(-(?<num>[0-9]+))?\$" "$name" >/dev/null
    or return 1
    if set -q num[1]; and test -n "$num"
        echo "$num"
    else
        echo 1
    end
end

function _tbx_all_versions --argument-names base
    # Print '<ver> <name>' for every existing container (running or stopped)
    # matching <base> (the bare base counts as version 1), sorted by version.
    set -l rows
    for name in (podman ps -a --format '{{.Names}}')
        set -l ver (_tbx_parse "$base" "$name")
        or continue
        set -a rows "$ver $name"
    end
    if set -q rows[1]
        printf '%s\n' $rows | sort -n
    end
end

function _tbx_proc_count --argument-names name
    # Print how many processes run inside <name> beyond its lone init process
    # (0 when created/exited or idle). Read from the container's cgroup, which
    # captures every kind of usage -- interactive shells, 'toolbox run' background
    # jobs, and daemons alike -- unlike counting shells or ptys. A started but
    # unused toolbox container holds exactly one process: 'toolbox init-container'
    # (a sleep); anything more means the container is in use. 'podman top' can't
    # be used here because toolbox shares the host PID namespace.
    set -l pid (podman inspect "$name" --format '{{.State.Pid}}' 2>/dev/null)
    if test -z "$pid"; or test "$pid" = 0
        echo 0
        return
    end
    # cgroup v2 exposes a single '0::<path>' line; map it to the procs file.
    set -l rel (string match -rg '^0::(.*)' -- (cat /proc/$pid/cgroup 2>/dev/null))
    if test -z "$rel"
        # No unified-hierarchy line (cgroup v1/hybrid host, or the container
        # exited mid-call). Report 0 rather than falling back to the host root.
        echo 0
        return
    end
    set -l procs "/sys/fs/cgroup$rel/cgroup.procs"
    if not test -r "$procs"
        echo 0
        return
    end
    set -l total (count (cat "$procs"))
    if test "$total" -gt 1
        math "$total - 1"
    else
        echo 0
    end
end

function _tbx_resolve_bases
    # Echo the bases to act on: the validated arguments, or all known bases when
    # none are given. Return non-zero (with an error) on an unknown base.
    if set -q argv[1]
        # Validate and de-duplicate (preserving order): a repeated base would
        # otherwise make renumber build a doubled plan and abort mid-rename.
        set -l seen
        for base in $argv
            if not _tbx_image "$base" >/dev/null
                echo (set_color $fish_color_error)"Error: unknown base '"(set_color -o -i -u cyan)"$base"(set_color normal)(set_color $fish_color_error)"'. Valid bases: "(string join ', ' (_tbx_bases))"."(set_color normal) >&2
                return 1
            end
            contains -- "$base" $seen; or set -a seen "$base"
        end
        printf '%s\n' $seen
    else
        _tbx_bases
    end
end

function _tbx_ls
    argparse h/help -- $argv
    or return 1
    if set -q _flag_help
        echo "List every version of each base and how many processes run inside it
(PROCS counts in-container processes beyond the idle init: 0 = unused).
Syntax: tbx ls [<base>...]"
        return 0
    end
    if not command -q podman
        echo (set_color $fish_color_error)"Error: 'podman' command is not installed."(set_color normal) >&2
        return 1
    end
    set -l bases (_tbx_resolve_bases $argv)
    or return 1

    printf '%-16s %4s  %-20s %6s  %s\n' BASE VER CONTAINER PROCS NEWEST
    for base in $bases
        set -l rows (_tbx_all_versions "$base")
        or continue
        set -q rows[1]
        or continue
        # The last row (highest version) is the newest.
        set -l newest_name (string split -f2 ' ' -- $rows[-1])
        for row in $rows
            set -l ver (string split -f1 ' ' -- $row)
            set -l name (string split -f2 ' ' -- $row)
            set -l procs (_tbx_proc_count "$name")
            set -l marker ""
            test "$name" = "$newest_name"; and set marker '*'
            printf '%-16s %4s  %-20s %6s  %s\n' $base $ver $name $procs $marker
        end
    end
end

function _tbx_clean
    argparse h/help f/force r/renumber -- $argv
    or return 1
    if set -q _flag_help
        echo "Remove old (non-newest) containers that are not in use (no process
running inside them beyond the idle init).
Syntax: tbx clean [-f/--force] [-r/--renumber] [<base>...]
    -f/--force:    Remove without prompting for confirmation.
    -r/--renumber: After cleaning, renumber the survivors to a gap-free 1..N."
        return 0
    end
    if not command -q podman
        echo (set_color $fish_color_error)"Error: 'podman' command is not installed."(set_color normal) >&2
        return 1
    end
    set -l bases (_tbx_resolve_bases $argv)
    or return 1

    # Collect non-newest containers that are not in use; report the rest.
    set -l candidates
    for base in $bases
        set -l rows (_tbx_all_versions "$base")
        or continue
        set -q rows[1]
        or continue
        # All rows except the last (highest version) are old versions.
        for row in $rows[1..-2]
            set -l name (string split -f2 ' ' -- $row)
            set -l procs (_tbx_proc_count "$name")
            if test "$procs" -gt 0
                echo (set_color yellow)"Skipping '"(set_color -o -i -u cyan)"$name"(set_color normal)(set_color yellow)"' ("$procs" process(es) running)."(set_color normal)
            else
                set -a candidates "$name"
            end
        end
    end

    # Track whether removal is unattended: set up-front by -f/--force, or turned
    # on mid-loop when the user answers 'a' at the prompt. Kept in scope past the
    # loop so the --renumber step below can inherit the same choice.
    set -l force false
    set -q _flag_force; and set force true

    if not set -q candidates[1]
        echo (set_color green)"Nothing to clean."(set_color normal)
    else
        for name in $candidates
            if test "$force" = false
                read -l -P (set_color yellow)"Remove '"(set_color -o -i -u cyan)"$name"(set_color normal)(set_color yellow)"'? [y/N/a] "(set_color normal) reply
                switch "$reply"
                    case a A
                        set force true
                    case y Y yes
                        # fall through to removal
                    case '*'
                        echo (set_color normal)"Skipped '$name'."
                        continue
                end
            end
            if podman rm -f "$name"
                echo (set_color green)"Removed '"(set_color -o -i -u cyan)"$name"(set_color normal)(set_color green)"'."(set_color normal)
            else
                echo (set_color $fish_color_error)"Error: failed to remove '"(set_color -o -i -u cyan)"$name"(set_color normal)(set_color $fish_color_error)"'."(set_color normal) >&2
            end
        end
    end

    # With --renumber, compact the survivors (passing --force through so the
    # renumber step isn't re-prompted when clean was already unattended -- either
    # forced up-front or via an 'a' answer at the prompt).
    if set -q _flag_renumber
        set -l rn_args
        test "$force" = true; and set -a rn_args --force
        _tbx_renumber $rn_args $argv
    end
end

function _tbx_renumber
    argparse h/help f/force -- $argv
    or return 1
    if set -q _flag_help
        echo "Compact each base's version numbers to a gap-free 1..N sequence (e.g. after
removing an old version): 'code-server-2' -> 'code-server', 'code-server-3' -> 'code-server-2'.
Syntax: tbx renumber [-f/--force] [<base>...]
    -f/--force: Rename without prompting for confirmation."
        return 0
    end
    if not command -q podman
        echo (set_color $fish_color_error)"Error: 'podman' command is not installed."(set_color normal) >&2
        return 1
    end
    set -l bases (_tbx_resolve_bases $argv)
    or return 1

    # Build the rename plan: map each base's sorted existing versions onto a
    # gap-free 1..N sequence; containers already in place are left untouched.
    set -l from
    set -l to
    for base in $bases
        set -l rows (_tbx_all_versions "$base")
        or continue
        set -q rows[1]
        or continue
        set -l target 0
        for row in $rows
            set target (math $target + 1)
            set -l name (string split -f2 ' ' -- $row)
            set -l want (_tbx_name "$base" "$target")
            if test "$name" != "$want"
                set -a from "$name"
                set -a to "$want"
            end
        end
    end

    if not set -q from[1]
        echo (set_color green)"Nothing to renumber."(set_color normal)
        return 0
    end

    echo (set_color yellow)"Planned renames:"(set_color normal)
    for i in (seq (count $from))
        echo "  "(set_color -o -i -u cyan)"$from[$i]"(set_color normal)" -> "(set_color -o -i -u cyan)"$to[$i]"(set_color normal)
    end

    if not set -q _flag_force
        read -l -P (set_color yellow)"Proceed? [y/N] "(set_color normal) reply
        switch "$reply"
            case y Y yes
                # proceed
            case '*'
                echo (set_color normal)"Aborted."
                return 0
        end
    end

    # Apply in the plan's order (ascending target within each base), so each
    # destination slot is guaranteed free -- lower targets are filled first,
    # vacating the next slot before it is needed.
    for i in (seq (count $from))
        if podman rename "$from[$i]" "$to[$i]"
            echo (set_color green)"Renamed '"(set_color -o -i -u cyan)"$from[$i]"(set_color normal)(set_color green)"' -> '"(set_color -o -i -u cyan)"$to[$i]"(set_color normal)(set_color green)"'."(set_color normal)
        else
            echo (set_color $fish_color_error)"Error: failed to rename '"(set_color -o -i -u cyan)"$from[$i]"(set_color normal)(set_color $fish_color_error)"' -> '"(set_color -o -i -u cyan)"$to[$i]"(set_color normal)(set_color $fish_color_error)"'. Aborting."(set_color normal) >&2
            return 1
        end
    end
end

function _tbx_name --argument-names base ver
    # Version 1 is the bare base name; version N>1 is '<base>-N'.
    if test "$ver" -le 1
        echo "$base"
    else
        echo "$base-$ver"
    end
end

function _tbx_max_running --argument-names base
    # Print the highest version among running containers matching <base>
    # (the bare base counts as version 1); print 0 when none are running.
    set -l max 0
    for name in (podman ps --format '{{.Names}}')
        set -l ver (_tbx_parse "$base" "$name")
        or continue
        if test "$ver" -gt "$max"
            set max "$ver"
        end
    end
    echo "$max"
end

function _tbx_exists --argument-names name
    # Return 0 if a container named exactly <name> exists (running or stopped).
    contains -- "$name" (podman ps -a --format '{{.Names}}')
end

function _tbx_pull_create --argument-names name image
    # Pull the latest image, then create the container. All output goes to
    # stderr so stdout stays clean for the resolved container name.
    echo (set_color yellow)"Pulling "(set_color -o -i -u cyan)"$image"(set_color normal)(set_color yellow)"..."(set_color normal) >&2
    podman pull "$image" >&2
    or return $status
    echo (set_color yellow)"Creating '"(set_color -o -i -u cyan)"$name"(set_color normal)(set_color yellow)"' from "(set_color -o -i -u cyan)"$image"(set_color normal)(set_color yellow)"..."(set_color normal) >&2
    toolbox create -c "$name" -i "$image" >&2
end

function _tbx_version
    argparse h/help n/next -- $argv
    or return 1
    if set -q _flag_help
        echo "Print the versioned container name to use for <base>, creating it if
needed. With --next, create the next version instead.
Syntax: tbx version [-n/--next] <base>
    -n/--next: Create the next version (newest running + 1) and print its name."
        return 0
    end

    if test (count $argv) -ne 1
        echo (set_color $fish_color_error)"Error: exactly one base container name is required."(set_color normal) >&2
        return 1
    end
    set -l base $argv[1]

    set -l image (_tbx_image "$base")
    set -l image_status $status
    if test $image_status -ne 0
        echo (set_color $fish_color_error)"Error: unknown base '"(set_color -o -i -u cyan)"$base"(set_color normal)(set_color $fish_color_error)"'. Valid bases: "(string join ', ' (_tbx_bases))"."(set_color normal) >&2
        return 1
    end

    for cmd in podman toolbox
        if not command -q $cmd
            echo (set_color $fish_color_error)"Error: '$cmd' command is not installed."(set_color normal) >&2
            return 1
        end
    end

    set -l max_running (_tbx_max_running "$base")

    if set -q _flag_next
        set -l ver (math "$max_running + 1")
        set -l name (_tbx_name "$base" "$ver")
        if _tbx_exists "$name"
            echo (set_color $fish_color_error)"Error: container '"(set_color -o -i -u cyan)"$name"(set_color normal)(set_color $fish_color_error)"' already exists. Remove it first or start it."(set_color normal) >&2
            return 1
        end
        _tbx_pull_create "$name" "$image"
        or return $status
        echo "$name"
        return 0
    end

    # Default mode: return the newest running version's name.
    if test "$max_running" -gt 0
        _tbx_name "$base" "$max_running"
        return 0
    end

    # Nothing is running: target version 1. Reuse an existing (stopped)
    # container with that name instead of failing to recreate it.
    set -l name (_tbx_name "$base" 1)
    if _tbx_exists "$name"
        echo (set_color yellow)"Container '"(set_color -o -i -u cyan)"$name"(set_color normal)(set_color yellow)"' exists but is not running."(set_color normal) >&2
        echo "$name"
        return 0
    end
    _tbx_pull_create "$name" "$image"
    or return $status
    echo "$name"
end

function tbx --description 'Manage versioned toolbox/podman containers'
    set -l sub $argv[1]
    if test -z "$sub"
        echo (set_color $fish_color_error)"Error: a sub-command is required."(set_color normal) >&2
        _tbx_usage >&2
        return 1
    end
    switch "$sub"
        case version v
            _tbx_version $argv[2..]
        case ls l
            _tbx_ls $argv[2..]
        case clean c
            _tbx_clean $argv[2..]
        case renumber r
            _tbx_renumber $argv[2..]
        case -h --help
            _tbx_usage
        case '*'
            echo (set_color $fish_color_error)"Error: unknown sub-command '"(set_color -o -i -u cyan)"$sub"(set_color normal)(set_color $fish_color_error)"'."(set_color normal) >&2
            _tbx_usage >&2
            return 1
    end
end
