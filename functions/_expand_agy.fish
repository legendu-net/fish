function _expand_agy --argument-names dangerous
    # Build the 'agy' invocation, optionally with --dangerously-skip-permissions.
    set -l cmd "agy --remote-control"
    if test -n "$dangerous"
        set cmd "$cmd --dangerously-skip-permissions"
    end
    # Run directly when already inside the 'toolbx' container; otherwise wrap
    # with `toolbox run` against the jupyterhub-ds container.
    if test (hostname) = toolbx
        echo $cmd
    else
        set -l container (tbx version jupyterhub-ds)
        or return
        echo "toolbox run -c $container $cmd"
    end
end
