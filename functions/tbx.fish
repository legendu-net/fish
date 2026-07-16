function _tbx_bases
    # The registry of known base container names (single source of truth).
    printf '%s\n' jupyterhub-ds code-server
end

function _tbx_usage
    echo "Manage versioned toolbox/podman containers for a base image.
Versioned containers are named <base> (version 1) or <base>-N (version N>1).
Known bases: "(string join ', ' (_tbx_bases))".
Syntax:
    tbx version [<base>]
    tbx new [-f/--force] [<base>]
    tbx procs [<base>]
    tbx ls [<base>...]
    tbx clean [-f/--force] [<base>...]
Sub-commands (each has a one-letter alias):
    version (v):  Print the newest running version's container name, creating
        version 1 if nothing is running.
        <base> is optional; when omitted, pick one interactively with fzf.
    new (n):      Pull the latest image; create the next version (above every
        existing container) only when the image changed, otherwise reuse and
        print the latest existing container. -f/--force: create even when the
        image is not updated.
        <base> is optional; when omitted, pick one interactively with fzf.
    procs (p):    Print (then run) a 'procs' command showing the detailed
        processes inside the base's newest running container. <base> is
        optional; when omitted, pick one interactively with fzf.
    ls (l):       List every version of each base and how many processes run inside it.
    clean (c):    Remove old (non-newest) containers that are not in use.
                  -f/--force: Remove without prompting for confirmation.
    ls and clean act on all known bases, or only the base(s) given.
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

function _tbx_latest_name --argument-names base
    # Echo the newest existing container's name for <base> (running or stopped);
    # return non-zero (echoing nothing) when none exist.
    set -l rows (_tbx_all_versions "$base")
    set -q rows[1]
    or return 1
    string split -f2 ' ' -- $rows[-1]
end

function _tbx_cgroup_procs --argument-names name
    # Echo the path to <name>'s unified-hierarchy 'cgroup.procs' file by mapping
    # the container PID's cgroup onto it. Echo nothing (returning non-zero) when
    # the container has no live PID or no cgroup v2 '0::' line (cgroup v1/hybrid
    # host, or the container exited mid-call) -- callers must not fall back to the
    # host root. 'podman top' can't be used here because toolbox shares the host
    # PID namespace.
    set -l pid (podman inspect "$name" --format '{{.State.Pid}}' 2>/dev/null)
    if test -z "$pid"; or test "$pid" = 0
        return 1
    end
    # cgroup v2 exposes a single '0::<path>' line; map it to the procs file.
    set -l rel (string match -rg '^0::(.*)' -- (cat /proc/$pid/cgroup 2>/dev/null))
    if test -z "$rel"
        return 1
    end
    echo "/sys/fs/cgroup$rel/cgroup.procs"
end

function _tbx_proc_count --argument-names name
    # Print how many processes run inside <name> beyond its lone init process
    # (0 when created/exited or idle). Read from the container's cgroup, which
    # captures every kind of usage -- interactive shells, 'toolbox run' background
    # jobs, and daemons alike -- unlike counting shells or ptys. A started but
    # unused toolbox container holds exactly one process: 'toolbox init-container'
    # (a sleep); anything more means the container is in use.
    set -l procs (_tbx_cgroup_procs "$name")
    if test -z "$procs"; or not test -r "$procs"
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
        # Validate and de-duplicate (preserving order) so a repeated base is
        # not processed twice.
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
    argparse h/help f/force -- $argv
    or return 1
    if set -q _flag_help
        echo "Remove old (non-newest) containers that are not in use (no process
running inside them beyond the idle init).
Syntax: tbx clean [-f/--force] [<base>...]
    -f/--force: Remove without prompting for confirmation."
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
    # on mid-loop when the user answers 'a' at the prompt.
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

function _tbx_max_version --argument-names base
    # Print the highest version among all existing containers (running or
    # stopped) matching <base>; print 0 when none exist. Used to pick the next
    # free version so 'new' never collides with a stopped container.
    set -l rows (_tbx_all_versions "$base")
    set -q rows[1]
    or begin
        echo 0
        return
    end
    string split -f1 ' ' -- $rows[-1]
end

function _tbx_exists --argument-names name
    # Return 0 if a container named exactly <name> exists (running or stopped).
    contains -- "$name" (podman ps -a --format '{{.Names}}')
end

function _tbx_image_id --argument-names image
    # Echo the local image's ID, or nothing when the image is not present.
    podman image inspect --format '{{.Id}}' "$image" 2>/dev/null
end

function _tbx_pull --argument-names image
    # Pull the latest image. All output goes to stderr so stdout stays clean.
    echo (set_color yellow)"Pulling "(set_color -o -i -u cyan)"$image"(set_color normal)(set_color yellow)"..."(set_color normal) >&2
    podman pull "$image" >&2
end

function _tbx_create --argument-names name image
    # Create the container. All output goes to stderr so stdout stays clean.
    echo (set_color yellow)"Creating '"(set_color -o -i -u cyan)"$name"(set_color normal)(set_color yellow)"' from "(set_color -o -i -u cyan)"$image"(set_color normal)(set_color yellow)"..."(set_color normal) >&2
    toolbox create -c "$name" -i "$image" >&2
end

function _tbx_pull_create --argument-names name image
    # Pull the latest image, then create the container. All output goes to
    # stderr so stdout stays clean for the resolved container name.
    _tbx_pull "$image"
    or return $status
    _tbx_create "$name" "$image"
end

function _tbx_pick_base
    # Resolve the single base to act on: validate the lone argument, or pick one
    # interactively with fzf when none is given. Echo the validated base name;
    # return non-zero (with an error on stderr) on misuse, cancel, or unknown base.
    if test (count $argv) -gt 1
        echo (set_color $fish_color_error)"Error: at most one base container name is allowed."(set_color normal) >&2
        return 1
    end
    set -l base $argv[1]
    if test -z "$base"
        # No base given: let the user pick one interactively.
        if not command -q fzf
            echo (set_color $fish_color_error)"Error: 'fzf' is not installed; specify a base explicitly."(set_color normal) >&2
            return 1
        end
        set base (_tbx_bases | fzf --height=40% --reverse --prompt='base> ')
        # fzf returns non-zero (and prints nothing) when the user cancels.
        if test -z "$base"
            return 1
        end
    end
    if not _tbx_image "$base" >/dev/null
        echo (set_color $fish_color_error)"Error: unknown base '"(set_color -o -i -u cyan)"$base"(set_color normal)(set_color $fish_color_error)"'. Valid bases: "(string join ', ' (_tbx_bases))"."(set_color normal) >&2
        return 1
    end
    echo "$base"
end

function _tbx_version
    argparse h/help -- $argv
    or return 1
    if set -q _flag_help
        echo "Print the versioned container name to use for <base>, creating version 1
if nothing is running. When <base> is omitted, pick one interactively with fzf.
Syntax: tbx version [<base>]"
        return 0
    end

    set -l base (_tbx_pick_base $argv)
    or return 1
    set -l image (_tbx_image "$base")

    for cmd in podman toolbox
        if not command -q $cmd
            echo (set_color $fish_color_error)"Error: '$cmd' command is not installed."(set_color normal) >&2
            return 1
        end
    end

    set -l max_running (_tbx_max_running "$base")

    # Return the newest running version's name.
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

function _tbx_new
    argparse h/help f/force -- $argv
    or return 1
    if set -q _flag_help
        echo "Pull the latest image for <base> and create the next version (above
every existing container), printing its name. When the image is not updated,
skip creating and print the latest existing container instead. When <base> is
omitted, pick one interactively with fzf.
Syntax: tbx new [-f/--force] [<base>]
    -f/--force: Create a new container even when the image is not updated."
        return 0
    end

    set -l base (_tbx_pick_base $argv)
    or return 1
    set -l image (_tbx_image "$base")

    for cmd in podman toolbox
        if not command -q $cmd
            echo (set_color $fish_color_error)"Error: '$cmd' command is not installed."(set_color normal) >&2
            return 1
        end
    end

    # Pull first, then decide: skip creating when the image is unchanged and an
    # existing container can be reused, unless --force is given.
    set -l old_id (_tbx_image_id "$image")
    _tbx_pull "$image"
    or return $status
    set -l new_id (_tbx_image_id "$image")

    if not set -q _flag_force; and test -n "$old_id"; and test "$old_id" = "$new_id"
        set -l latest (_tbx_latest_name "$base")
        if test -n "$latest"
            echo (set_color yellow)"Image "(set_color -o -i -u cyan)"$image"(set_color normal)(set_color yellow)" is not updated; reusing '"(set_color -o -i -u cyan)"$latest"(set_color normal)(set_color yellow)"' (use -f/--force to create anyway)."(set_color normal) >&2
            echo "$latest"
            return 0
        end
        # No existing container to reuse: create despite the unchanged image.
    end

    # Create the next free version (above every existing container, running or
    # stopped) so the name never collides with a leftover stopped container.
    set -l ver (math (_tbx_max_version "$base") + 1)
    set -l name (_tbx_name "$base" "$ver")
    _tbx_create "$name" "$image"
    or return $status
    echo "$name"
end

function _tbx_procs
    argparse h/help -- $argv
    or return 1
    if set -q _flag_help
        echo "Show the detailed processes running inside a base's newest running
container. The 'procs' command that renders them is printed to stdout first so
it can be copied and customized, then run. When <base> is omitted, pick one
interactively with fzf.
Syntax: tbx procs [<base>]"
        return 0
    end
    for cmd in podman procs
        if not command -q $cmd
            echo (set_color $fish_color_error)"Error: '$cmd' command is not installed."(set_color normal) >&2
            return 1
        end
    end
    set -l base (_tbx_pick_base $argv)
    or return 1

    # 'procs' reads a live cgroup, so target the newest *running* version.
    set -l max_running (_tbx_max_running "$base")
    if test "$max_running" -le 0
        echo (set_color $fish_color_error)"Error: no running container for base '"(set_color -o -i -u cyan)"$base"(set_color normal)(set_color $fish_color_error)"'."(set_color normal) >&2
        return 1
    end
    set -l name (_tbx_name "$base" "$max_running")

    set -l procs (_tbx_cgroup_procs "$name")
    if test -z "$procs"; or not test -r "$procs"
        echo (set_color $fish_color_error)"Error: could not locate or read the cgroup for '"(set_color -o -i -u cyan)"$name"(set_color normal)(set_color $fish_color_error)"'."(set_color normal) >&2
        return 1
    end

    # Run the command, then print it (blank line on each side) so the user can
    # copy and tweak it. The printed line is a quoted literal that matches the
    # command just run: fish performs no command substitution inside double
    # quotes, so '(cat $procs)' stays verbatim, keeping the printed command
    # self-contained and re-runnable (it re-reads the live cgroup on each run).
    procs --insert State --or (cat $procs)
    echo
    echo "procs --insert State --or (cat $procs)"
    echo
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
        case new n
            _tbx_new $argv[2..]
        case procs p
            _tbx_procs $argv[2..]
        case ls l
            _tbx_ls $argv[2..]
        case clean c
            _tbx_clean $argv[2..]
        case -h --help
            _tbx_usage
        case '*'
            echo (set_color $fish_color_error)"Error: unknown sub-command '"(set_color -o -i -u cyan)"$sub"(set_color normal)(set_color $fish_color_error)"'."(set_color normal) >&2
            _tbx_usage >&2
            return 1
    end
end
