function get_fd_executable
    if command -q fdfind
        printf fdfind\n
    else if command -q fd
        printf fd\n
    end
end
