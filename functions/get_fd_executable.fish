function get_fd_executable
    set -l os_id (cat /etc/os-release 2> /dev/null | grep "^ID=")

    switch "$os_id"
        case ID=ubuntu ID=debian ID=pop ID=Deepin ID=fedora ID=\"rhel\"
            echo fdfind
        case "*"
            echo fd
    end
end

