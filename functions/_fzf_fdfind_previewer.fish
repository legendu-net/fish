# Helper function for _fzf_fdfind_previewer.
# Describes a file and dumps the head of it.
function _fzf_fdfind_hexdump
    file --brief --dereference -- "$argv[1]"
    xxd -l 4096 -- "$argv[1]"
end

# Helper function for _fzf_fdfind_previewer.
# Echoes chafa's --size option for an image $argv[1] preview panes tall, or
# nothing if the pane size is unknown.
function _fzf_fdfind_chafa_size
    # fzf hands the previewer a pipe instead of a tty, so chafa cannot query
    # the pane and falls back to a fixed size unless it is told the one fzf
    # exports. Outside fzf, fish's own idea of the terminal stands in: chafa
    # would otherwise squeeze a stack of frames into a single screen, leaving
    # a couple of rows apiece.
    set -l columns $FZF_PREVIEW_COLUMNS
    set -l rows $FZF_PREVIEW_LINES
    if test -z "$columns"; or test -z "$rows"
        test -n "$COLUMNS"; and test -n "$LINES"
        or return
        # One row short of the terminal, to leave the prompt that follows
        # somewhere to go. chafa keeps the same row back when it measures the
        # terminal itself, and an image that filled every row would scroll its
        # own top line away.
        set columns $COLUMNS
        set rows (math "max(1, $LINES - 1)")
    end
    printf '%s\n' --size $columns"x"(math --scale 0 "$rows * $argv[1]")
end

# Helper function for _fzf_fdfind_previewer.
# Renders frames sampled from the opening of a video, played one after another
# inside fzf and stacked on top of each other outside of it.
function _fzf_fdfind_video_frames
    # Only the opening is sampled. What a film looks like an hour in says
    # little about which file it is, and a preview that has to seek that far
    # is a preview that arrives too late to be read.
    set -l max_span 10
    set -l max_frames 10
    set -l delay 1
    # fzf honours the CSI 2 J (clear display) escape sequence in its preview
    # window precisely so that a preview can keep updating itself, so there the
    # frames are played in turn, each one taking the pane to itself. Anywhere
    # else they are simply printed one below another and nothing loops.
    #
    # A set FZF_PREVIEW_LINES is not enough to tell that this is the preview
    # pane: fzf exports it to the commands its `execute` bindings run as well,
    # and looping there would leave an animation playing underneath whatever
    # was opened. Only the preview pane is a pipe; `execute` gets the terminal.
    set -l play 0
    if test -n "$FZF_PREVIEW_LINES"; and not isatty stdout
        set play 1
    end
    # The video stream's own length, not the container's: a short clip carrying
    # a long audio tail would otherwise be sampled well past its last frame,
    # and the tile filter fills what it has no frames for with black.
    set -l info (ffprobe -v quiet -select_streams v:0 \
        -show_entries stream=duration,avg_frame_rate -of default=nw=1 -- "$argv[1]")
    set -l duration (string replace -f duration= '' -- $info)
    # Matroska and friends record it on the container instead.
    if not string match -qr '^[0-9]+(\.[0-9]+)?$' -- "$duration"
        set duration (ffprobe -v quiet -show_entries format=duration -of csv=p=0 -- "$argv[1]")
    end
    # A video shorter than the window is sampled across the whole of it. One
    # that reports no length at all is left to run into the window and give
    # whatever it has.
    set -l span $max_span
    if string match -qr '^[0-9]+(\.[0-9]+)?$' -- "$duration"; and test "$duration" -gt 0
        set span (math "min($duration, $max_span)")
    end
    # Sampling more often than the video has frames would only repeat pictures,
    # so a clip holding fewer than the maximum is shown frame for frame. The
    # rate is reported as a rational, 30/1 and so on, or 0/0 when unknown.
    set -l count $max_frames
    set -l rate (string replace -f avg_frame_rate= '' -- $info)
    if string match -qr '^[0-9]+/[0-9]*[1-9][0-9]*$' -- "$rate"
        set -l parts (string split / -- $rate)
        set count (math --scale 0 "min($max_frames, max(1, floor($span * $parts[1] / $parts[2])))")
    end
    # One ffmpeg and one chafa for the whole set: seeking to each frame with a
    # process of its own costs about four times as much, which is too slow to
    # sit behind every keystroke. The frames are tiled into a single tall image
    # and the rendering is sliced back apart below, which also keeps the whole
    # thing on a pipe with no temporary files to clean up after.
    #
    # They are drawn as text even where chafa could use a graphics protocol:
    # playing them writes the pane over and over, and a kitty or sixel frame is
    # tens of times larger, which is a lot to push down the pipe every second.
    # CSI 2 J is also defined to clear text, not to retract graphics that an
    # image protocol has already placed.
    #
    # The frames are scaled down before being tiled: the filter has to hold the
    # whole set in memory at once, which for 4K is about a gigabyte, and chafa
    # throws that resolution away regardless. Rendering is identical either way.
    set -l lines (ffmpeg -v quiet -t $span -i "$argv[1]" \
        -vf "fps=$count/$span,scale=-2:min(360\,ih),tile=1x$count" \
        -frames:v 1 -f image2 -c:v png - \
        | chafa --format symbols (_fzf_fdfind_chafa_size $count) - 2>/dev/null)
    # chafa writes the cursor-hiding sequences even when it fails, so its output
    # is never empty and only its exit status tells the two apart. It has to be
    # the last command of the substitution for that status to survive, which is
    # why the rendering is captured as lines rather than kept whole by a
    # `string collect` at the end of that pipe. The caller falls back to
    # describing the file, e.g. for a container with no decodable video stream.
    or return 1
    # chafa signs off with a cursor-showing sequence that has no newline of its
    # own, so it arrives as a trailing scrap rather than as a row of its own.
    set -l scrap (string replace -ar '\e\[[0-9?;]*[a-zA-Z]' '' -- $lines[-1])
    if test -z "$scrap"
        set -e lines[-1]
    end
    # Sliced by what chafa produced rather than by what it was asked for: it
    # fits an image to whichever dimension binds first, and for anything wider
    # than it is tall that is the width, leaving a rendering that is shorter
    # than the requested height and, crucially, not a multiple of the frame
    # count. Each boundary is therefore taken as a proportion of the whole,
    # which spreads the remainder instead of letting it accumulate into a
    # frame-long drift down the stack.
    set -l height (count $lines)
    test $height -ge $count
    or return 1
    set -l frames
    for i in (seq $count)
        set -l first (math --scale 0 "floor(($i - 1) * $height / $count) + 1")
        set -l last (math --scale 0 "floor($i * $height / $count)")
        # `string collect` stops the substitution splitting the frame right
        # back into one list element per line.
        set -a frames (string join \n -- $lines[$first..$last] | string collect)
    end
    # A lone frame has nothing to play, so it is simply left on screen.
    if test $play = 0; or test (count $frames) = 1
        printf '%s\n' $frames
        return
    end
    while true
        for frame in $frames
            # The failed write is what ends this loop if fzf dies without
            # getting to kill it, e.g. under SIGKILL. Without it the loop would
            # be left playing to a pipe nobody is reading, for ever.
            printf '\033[2J%s\n' $frame
            or return
            sleep $delay
        end
    end
end

# Helper function for fzf_fdind.
# Definers a previewer for files.
#     - preview an image using chafa.
#     - preview a video using chafa on a few frames sampled across it.
#     - preview a PDF file using the text extracted by pdftotext.
#     - preview any other binary file using a description of it and a hex dump.
#     - preview a text file using bat.
#     - preview a directory by listing its content.
function _fzf_fdfind_previewer --description 'Helper function for fzf_fdfind to preview files or directories'
    if not test -f "$argv[1]"
        ls -lha --color=auto -- "$argv[1]"
        return
    end
    # The type is decided by content rather than by extension so that files
    # named without one (or with a misleading one) still preview correctly.
    # --mime reports the type and the charset in one go (e.g. `image/png;
    # charset=binary`), which keeps this to a single `file` call per keystroke.
    # --dereference matches the `test -f` above, which follows symlinks too;
    # without it every symlink reports as inode/symlink and gets hex dumped.
    # The cases are matched in order, so the PDF one has to come before the
    # catch-all binary one: a compressed PDF is binary too.
    switch (file --brief --dereference --mime -- "$argv[1]")
        case 'image/*charset=binary'
            # Only images that are actually binary are rendered: an SVG is
            # markup, and reading it is more useful than a thumbnail of it.
            # A still frame: animating a GIF makes chafa emit cursor motion on
            # top of the pixels, which is not what a preview pane wants. chafa
            # ships no loader for some formats (e.g. BMP), so fall back rather
            # than leave the pane holding nothing but its error message.
            chafa --animate off (_fzf_fdfind_chafa_size 1) -- "$argv[1]"
            or _fzf_fdfind_hexdump "$argv[1]"
        case 'video/*'
            # A few frames tell videos apart far better than any metadata line
            # would. Files whose video stream will not decode fall back.
            _fzf_fdfind_video_frames "$argv[1]"
            or _fzf_fdfind_hexdump "$argv[1]"
        case 'application/pdf;*'
            # The version and the page count, which is all there is to show for
            # a scanned PDF: pdftotext extracts nothing from one and exits 0, so
            # without this the pane would be blank and say nothing about why.
            file --brief --dereference -- "$argv[1]"
            # Only the leading pages: the pane shows about a screenful anyway
            # and extracting a whole book on every keystroke is slow. Errors are
            # left on stderr, which fzf shows, so a damaged PDF says why too.
            pdftotext -l 5 -- "$argv[1]" - | bat --style=plain --color=always --language txt
        case '*charset=binary'
            # bat refuses to dump binary content to the terminal, so show what
            # the file is plus a hex dump of its head instead.
            _fzf_fdfind_hexdump "$argv[1]"
        case '*'
            bat --style=full --color=always -- "$argv[1]"
    end
end
