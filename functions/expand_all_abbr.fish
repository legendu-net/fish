function expand_all_abbr --description 'Expand all abbreviations in the current command line'
    commandline -f beginning-of-line
    while true
        set -l pos (commandline -C)
        commandline -f forward-word expand-abbr
        if test (commandline -C) -eq $pos
            break
        end
    end
end
