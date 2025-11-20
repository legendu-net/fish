function check_fdfind
    if test (which $argv[1]) = ""
        echo -e "\n$argv[1] executable is not found! Please install it first!"
        return 1
    end
end

