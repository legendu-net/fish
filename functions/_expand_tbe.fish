function _expand_tbe
    set -l container (tbx version jupyterhub-ds)
    or return
    echo "SHELL=fish toolbox enter $container"
end
