function _toolbox_version_usage
    echo "Resolve the versioned toolbox/podman container name for a base image.
Versioned containers are named <base> (version 1) or <base>-N (version N>1).
By default, print the newest running version's container name (creating version
1 if nothing is running). With --next, create the next version and print it.
Syntax: toolbox_version [-h/--help] [-n/--next] <base>
Args:
    -h/--help: Show the help doc.
    -n/--next: Create the next version (newest running + 1) and print its name.
    base: The base container name. One of: jupyterhub-ds, code-server."
end

function _toolbox_version_image --argument-names base
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

function _toolbox_version_name --argument-names base ver
    # Version 1 is the bare base name; version N>1 is '<base>-N'.
    if test "$ver" -le 1
        echo "$base"
    else
        echo "$base-$ver"
    end
end

function _toolbox_version_max_running --argument-names base
    # Print the highest version among running containers matching <base>
    # (the bare base counts as version 1); print 0 when none are running.
    set -l escaped (string escape --style=regex -- "$base")
    set -l max 0
    for name in (podman ps --format '{{.Names}}')
        set -l matched (string match --regex -- "^$escaped(-(?<num>[0-9]+))?\$" "$name")
        or continue
        set -l ver 1
        if set -q num[1]; and test -n "$num"
            set ver "$num"
        end
        if test "$ver" -gt "$max"
            set max "$ver"
        end
    end
    echo "$max"
end

function _toolbox_version_exists --argument-names name
    # Return 0 if a container named exactly <name> exists (running or stopped).
    contains -- "$name" (podman ps -a --format '{{.Names}}')
end

function _toolbox_version_pull_create --argument-names name image
    # Pull the latest image, then create the container. All output goes to
    # stderr so stdout stays clean for the resolved container name.
    echo (set_color yellow)"Pulling "(set_color -o -i -u cyan)"$image"(set_color normal)(set_color yellow)"..."(set_color normal) >&2
    podman pull "$image" >&2
    or return $status
    echo (set_color yellow)"Creating '"(set_color -o -i -u cyan)"$name"(set_color normal)(set_color yellow)"' from "(set_color -o -i -u cyan)"$image"(set_color normal)(set_color yellow)"..."(set_color normal) >&2
    toolbox create -c "$name" -i "$image" >&2
end

function toolbox_version --description 'Resolve the versioned toolbox/podman container name for a base image'
    argparse h/help n/next -- $argv
    or return 1
    if set -q _flag_help
        _toolbox_version_usage
        return 0
    end

    if test (count $argv) -ne 1
        echo (set_color $fish_color_error)"Error: exactly one base container name is required."(set_color normal) >&2
        _toolbox_version_usage >&2
        return 1
    end
    set -l base $argv[1]

    set -l image (_toolbox_version_image "$base")
    set -l image_status $status
    if test $image_status -ne 0
        echo (set_color $fish_color_error)"Error: unknown base '"(set_color -o -i -u cyan)"$base"(set_color normal)(set_color $fish_color_error)"'. Valid bases: jupyterhub-ds, code-server."(set_color normal) >&2
        return 1
    end

    for cmd in podman toolbox
        if not command -q $cmd
            echo (set_color $fish_color_error)"Error: '$cmd' command is not installed."(set_color normal) >&2
            return 1
        end
    end

    set -l max_running (_toolbox_version_max_running "$base")

    if set -q _flag_next
        set -l ver (math "$max_running + 1")
        set -l name (_toolbox_version_name "$base" "$ver")
        if _toolbox_version_exists "$name"
            echo (set_color $fish_color_error)"Error: container '"(set_color -o -i -u cyan)"$name"(set_color normal)(set_color $fish_color_error)"' already exists. Remove it first or start it."(set_color normal) >&2
            return 1
        end
        _toolbox_version_pull_create "$name" "$image"
        or return $status
        echo "$name"
        return 0
    end

    # Default mode: return the newest running version's name.
    if test "$max_running" -gt 0
        _toolbox_version_name "$base" "$max_running"
        return 0
    end

    # Nothing is running: target version 1. Reuse an existing (stopped)
    # container with that name instead of failing to recreate it.
    set -l name (_toolbox_version_name "$base" 1)
    if _toolbox_version_exists "$name"
        echo (set_color yellow)"Container '"(set_color -o -i -u cyan)"$name"(set_color normal)(set_color yellow)"' exists but is not running."(set_color normal) >&2
        echo "$name"
        return 0
    end
    _toolbox_version_pull_create "$name" "$image"
    or return $status
    echo "$name"
end
