function _expand_claude
    # Check if the hostname matches 'toolbx'
    if test (hostname) = toolbx
        echo claude
    else
        set -l container (tbx version jupyterhub-ds)
        echo "toolbox run -c $container claude"
    end
end
