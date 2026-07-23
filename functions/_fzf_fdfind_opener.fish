# Helper function for fzf_fdfind.
# Defines an opener to operate on selected files.
# Called as `_fzf_fdfind_opener cmd... file_list`, where file_list is fzf's {+f}
# and is therefore always the last argument. Everything before it is the command,
# which can be several words (e.g. `code -w`) since fzf runs the execute command
# through `$SHELL -c` (fish here), which tokenizes it.
# DO NOT UPDATE this function unless you absolute know what you doing.
# It is not suggested to use `cd`, `ls`, etc. as the cmd to operate on files.
#     - `cd directory` won't take effect as a new fish process is spawn.
#     - `ls file` prints results to stdout but the user see nothing before exiting the fzf UI.
#     This can confuses users.
function _fzf_fdfind_opener --description 'Helper function for fzf_fdfind to open selected files'
    set -l files (cat "$argv[-1]")
    set -l cmd $argv[1..-2]
    # Escape the file names for the history entry only, so that recalling it
    # re-runs on the same files even when their names contain spaces. The
    # execution below passes them as list elements instead, which needs no
    # escaping and is never re-parsed. This mirrors fzf_fdfind's exit mode.
    history append -- (string join ' ' -- $cmd (string escape -- $files))
    $cmd $files
end
