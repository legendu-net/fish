# Helper function for fzf_jj_status.
# Defines a previewer showing the diff of a single file.
# Called as `_fzf_jj_status_previewer revision path`, where path is relative to the
# workspace root.
# --ignore-working-copy keeps the preview fast and consistent with the file list,
# which has been snapshotted already: the preview re-runs on every keystroke and
# would otherwise take the repository lock each time.
function _fzf_jj_status_previewer --description 'Helper function for fzf_jj_status to preview the diff of a file'
    command jj diff --color=always --ignore-working-copy --revision $argv[1] -- (_jj_root_fileset $argv[2] | string split0)
end
