# Helper function for fzf_fdind.
# Definers a previewer for files.
#     - preview a file using bat.
#     - preview a directory by listing its content.
function _fzf_fdfind_previewer --description 'Helper function for fzf_fdfind to preview files or directories'
    if test -f "$argv[1]"
        bat --style=full --color=always "$argv[1]"
    else
        ls -lha --color=auto "$argv[1]"
    end
end
