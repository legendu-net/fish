function get_fd_executable --description 'Get the name of the fd/fdfind executable'
    if command -q fdfind
        echo fdfind
    else if command -q fd
        echo fd
    else
        echo (set_color $fish_color_error)"Error: the command fdfind/fd is not found!"(set_color normal) >&2
        return 1
    end
end
