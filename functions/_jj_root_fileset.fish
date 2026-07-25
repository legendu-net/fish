# Helper function for jj_sync_base divergence recovery.
# Converts repo-root-relative paths (as produced by a `jj diff` `path.display()`
# template that was run from the repository root) into exact root-anchored
# fileset patterns, so a `jj restore` using them behaves identically regardless
# of the caller's current directory.
# A bare path passed to a jj command is parsed as a cwd-relative `prefix-glob:`
# pattern, so a name containing glob or fileset meta characters (e.g. `[id].tsx`)
# would match something other than itself. `root-file:"..."` matches the literal
# path from the repository root.
function _jj_root_fileset --description 'Convert root-relative paths into exact root-anchored jj fileset patterns'
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
