# Helper function for fzf_jj_status.
# Prints the fzf actions to run for a key whose meaning depends on whether the
# preview is covering the whole screen. fzf has no notion of a mode, so the
# preview label doubles as the flag: it is set to a known text only while the
# preview is full screen, and fzf exports it to child processes as
# $FZF_PREVIEW_LABEL.
# Called as `_fzf_jj_status_preview_mode key` from a transform binding, where
# key is enter, esc, q or ctrl-/.
function _fzf_jj_status_preview_mode --description 'Helper function for fzf_jj_status to resolve a key whose meaning depends on the preview'
    # The label is compared with the exact text set below rather than tested for
    # emptiness, so that a --preview-label inherited from $FZF_DEFAULT_OPTS is
    # not taken for a full screen preview.
    set -l label ' esc / q / enter: back to the file list '
    if test "$FZF_PREVIEW_LABEL" = "$label"
        # Every key handled here leaves the full screen preview. An empty
        # change-preview-window restores the properties given by
        # --preview-window, i.e. the hidden preview fzf starts with, so the file
        # list is on its own again and needs no second spelling. hide-preview is
        # still needed, since change-preview-window shows a hidden preview
        # rather than hiding a shown one.
        echo 'change-preview-label()+change-preview-window()+hide-preview'
        return
    end
    switch $argv[1]
        case enter
            # 99% is the largest size fzf accepts, so a sliver of the file list
            # stays visible on the side. show-preview comes first because the
            # preview is hidden until asked for.
            echo "show-preview+change-preview-window(99%)+change-preview-label($label)"
        case q
            # q is an ordinary character to search with while the file list is
            # shown, and only becomes a key once the preview has taken over the
            # screen.
            echo 'put(q)'
        case esc
            echo abort
        case ctrl-/
            # The split layout, i.e. the preview beside the file list rather
            # than over it.
            echo toggle-preview
    end
end
