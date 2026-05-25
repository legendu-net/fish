# Helper function for fzf_fdfind.
# Defines an opener to operate on selected files.
# DO NOT UPDATE this function unless you absolute know what you doing.
# It is not suggested to use `cd`, `ls`, etc. as the cmd to operate on files.
#     - `cd directory` won't take effect as a new fish process is spawn.
#     - `ls file` prints results to stdout but the user see nothing before exiting the fzf UI.
#     This can confuses users.
function _fzf_fdfind_opener --description 'Helper function for fzf_fdfind to open selected files'
    set -l files (cat "$argv[2]")
    history append "$argv[1] $files"
    $argv[1] $files
end
