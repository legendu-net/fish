# Helper function for fzf_ripgrep
# Defines an opener to operate on selected files.
function _fzf_ripgrep_opener
    set -l files (cat $argv[2] | awk -F: -v OFS=: '{print $1,$2,$3}')
    switch $argv[1]
        case nvim vim vi
            history append "code -g $files"
            history append "$argv[1] +cw -q $argv[2]"
            $argv[1] +cw -q $argv[2]
        case code code-server
            history append "$argv[1] -g $files"
            $argv[1] -g $files
        case "*"
            printf (set_color $fish_color_error)"Error: $argv[1] is not supported!\n"(set_color normal) >&2
            return 1
    end
end
