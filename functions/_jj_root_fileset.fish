# Helper function for fzf_jj_status.
# Converts workspace-root-relative paths (as produced by the `path` keyword of a
# jj diff template) into exact fileset patterns.
# A bare path passed to a jj command is parsed as a `prefix-glob:` pattern, so a
# name containing glob or fileset meta characters (e.g. `[id].tsx`) would match
# something else than itself. `root-file:"..."` matches the literal path.
function _jj_root_fileset --description 'Convert workspace-relative paths into exact jj fileset patterns'
    for path in $argv
        # jj string literals escape with backslashes, so a backslash has to be
        # doubled before the quotes are escaped. `string collect` keeps the
        # result in one piece, as a command substitution otherwise splits a file
        # name containing a newline.
        set -l escaped (string replace --all '\\' '\\\\' -- $path \
            | string replace --all '"' '\\"' | string collect)
        # NUL separated, so that a caller collecting the patterns with
        # `| string split0` keeps a file name containing a newline in one piece.
        printf 'root-file:"%s"\0' $escaped
    end
end
