function _fzf_ripgrep_nvim_usage
    echo "Leverage fzf as the UI to search for files by content using ripgrep,
preview it using bat, and open selections using NeoVim.
Syntax: fzf_ripgrep_nvim [-h] [dir]
Args:
    dir: The directory (default to .) under which to search for files.
"
end

function fzf_ripgrep_nvim
    argparse h/help -- $argv
    if set -q _flag_help
        _fzf_ripgrep_nvim_usage
        return 0
    end

    set -l search_path .
    if test (count $argv) -gt 0
      set search_path $argv
    end

    set -l reload "reload:rg --column --color=always --smart-case {q} $search_path || :"
    set -l opener 'if [[ $FZF_SELECT_COUNT -eq 0 ]]; then
                        history append "nvim {1} +{2}"
                        nvim {1} +{2}
                   else
                        history append "nvim +cw -q {+f}"
                        nvim +cw -q {+f}
                   fi'
    fzf --disabled --ansi --multi \
      --bind "start:$reload" --bind "change:$reload" \
      --bind "enter:become:$opener" \
      --bind "ctrl-o:execute:$opener" \
      --bind 'alt-a:select-all,alt-d:deselect-all,ctrl-/:toggle-preview' \
      --delimiter : \
      --preview 'bat --style=full --color=always --highlight-line {2} {1}' \
      --preview-window '~4,+{2}+4/3,<80(up)' \
      --query "$argv"
end

