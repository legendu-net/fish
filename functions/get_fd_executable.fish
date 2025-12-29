function get_fd_executable
    if command -q fdfind
        printf fdfind\n
    else if command -q fd
        printf fd\n
    else
        printf (set_color $fish_color_error)"Error: the command fdfind/fd is not found!\n"(set_color normal) >&2
        return 1
    end
end
