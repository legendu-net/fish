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
    set -l duration (string replace -fr '^duration=' '' -- $info)
    # Matroska and friends record it on the container instead.
    if not string match -qr '^[0-9]{1,7}(\.[0-9]+)?$' -- "$duration"
        set duration (ffprobe -v quiet -show_entries format=duration -of csv=p=0 -- "$argv[1]")
    end
    # A video shorter than the window is sampled across the whole of it. One
    # that reports no length at all is left to run into the window and give
    # whatever it has. The digits are counted because these numbers come out of
    # the file: `test` and `math` both write to stderr, and so into the pane,
    # when handed something too large to hold, and a length of more than a few
    # months of seconds is a broken file rather than a long one.
    set -l span $max_span
    if string match -qr '^[0-9]{1,7}(\.[0-9]+)?$' -- "$duration"; and test "$duration" -gt 0
        set span (math "min($duration, $max_span)")
    end
    # Sampling more often than the video has frames would only repeat pictures,
    # so a clip holding fewer than the maximum is shown frame for frame. The
    # rate is reported as a rational, 30/1 and so on, or 0/0 when unknown.
    set -l count $max_frames
    set -l rate (string replace -fr '^avg_frame_rate=' '' -- $info)
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

# Helper function for _fzf_fdfind_previewer.
# Writes a number of seconds as h:mm:ss, or as m:ss under the hour.
function _fzf_fdfind_duration
    set -l total (math --scale 0 "floor($argv[1])")
    set -l hours (math --scale 0 "floor($total / 3600)")
    set -l minutes (math --scale 0 "floor($total % 3600 / 60)")
    set -l seconds (math --scale 0 "$total % 60")
    if test $hours -gt 0
        printf '%d:%02d:%02d\n' $hours $minutes $seconds
        return
    end
    printf '%d:%02d\n' $minutes $seconds
end

# Helper function for _fzf_fdfind_previewer.
# Writes what identifies an audio file: the tags it carries, then its format.
# Returns non-zero if it found nothing at all to say.
function _fzf_fdfind_audio_info
    set -l info (ffprobe -v quiet -select_streams a:0 -of default=nw=1 -show_entries \
        'format=duration,bit_rate:format_tags=title,artist,album,date:stream=codec_name,sample_rate,channels' \
        -- "$argv[1]")
    # Anchored, because the keys are only keys at the start of a line: a tag
    # whose value happens to read `TAG:album=...` would otherwise have that
    # taken for an album and shown as one.
    set -l title (string replace -fr '^TAG:title=' '' -- $info)
    set -l artist (string replace -fr '^TAG:artist=' '' -- $info)
    set -l album (string replace -fr '^TAG:album=' '' -- $info)
    set -l date (string replace -fr '^TAG:date=' '' -- $info)
    set -l said 1
    # Whichever of the two are there, in the order a listing would show them.
    set -l heading (string join ' — ' -- $artist $title)
    if test -n "$heading"
        echo $heading
        set said 0
    end
    if test -n "$album"
        test -n "$date"; and set album "$album ($date)"
        echo $album
        set said 0
    end
    # The format line reads as prose rather than as a table: it is one line of
    # facts about a file, not something anybody scans down a column of.
    set -l facts (string replace -fr '^codec_name=' '' -- $info)
    # The digits are counted on every number below: they come out of the file,
    # and `math` writes to stderr, and so into the pane, when handed one too
    # large to hold.
    set -l bitrate (string replace -fr '^bit_rate=' '' -- $info)
    if string match -qr '^[0-9]{1,9}$' -- "$bitrate"
        set -a facts (math --scale 0 "$bitrate / 1000")" kb/s"
    end
    set -l rate (string replace -fr '^sample_rate=' '' -- $info)
    if string match -qr '^[0-9]{1,9}$' -- "$rate"
        set -a facts (math "$rate / 1000")" kHz"
    end
    set -l channels (string replace -fr '^channels=' '' -- $info)
    switch "$channels"
        case 1
            set -a facts mono
        case 2
            set -a facts stereo
        case ''
        case '*'
            set -a facts "$channels channels"
    end
    set -l duration (string replace -fr '^duration=' '' -- $info)
    if string match -qr '^[0-9]{1,7}(\.[0-9]+)?$' -- "$duration"
        set -a facts (_fzf_fdfind_duration $duration)
    end
    if set -q facts[1]
        string join ', ' -- $facts
        set said 0
    end
    return $said
end

# Helper function for _fzf_fdfind_previewer.
# Previews an audio file: what identifies it, then a picture of it.
# Returns non-zero if neither had anything to show.
function _fzf_fdfind_audio
    # Only the opening is drawn. showwavespic decodes every second it is handed,
    # which on an hour-long file holds the pane up for a couple of them.
    set -l max_span 120
    set -l said 1
    _fzf_fdfind_audio_info "$argv[1]"
    and set said 0
    # Cover art travels as a video stream, so it is copied out rather than
    # decoded, and it identifies an album far quicker than any waveform. Asking
    # first is cheaper than letting the extraction fail, and it keeps chafa from
    # writing its cursor sequences into the pane ahead of the waveform below.
    set -l art (ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_name \
        -of csv=p=0 -- "$argv[1]")
    if test -n "$art"
        ffmpeg -v quiet -i "$argv[1]" -an -c:v copy -f image2 - 2>/dev/null \
            | chafa (_fzf_fdfind_chafa_size 1) - 2>/dev/null
        and return 0
    end
    # Nothing to look at, so draw the shape of the sound instead: for a voice
    # memo or a stem, where the silence and the loud parts fall is the thing
    # that tells one file from another.
    ffmpeg -v quiet -t $max_span -i "$argv[1]" -filter_complex showwavespic=s=640x200 \
        -frames:v 1 -f image2 -c:v png - | chafa (_fzf_fdfind_chafa_size 1) - 2>/dev/null
    or return $said
end

# Helper function for fzf_fdind.
# Definers a previewer for files.
#     - preview an image using chafa.
#     - preview a video using chafa on a few frames sampled across it.
#     - preview an audio file using its tags plus its cover art or a waveform.
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
            # Containers are named for what they can hold rather than for what
            # they do hold, so an audio-only mkv or mp4 arrives here with no
            # frames to give. It is still worth describing as the audio it is.
            or _fzf_fdfind_audio "$argv[1]"
            or _fzf_fdfind_hexdump "$argv[1]"
        case 'audio/*'
            # The tags come first: for audio they are what identifies the file,
            # and the picture is the garnish.
            _fzf_fdfind_audio "$argv[1]"
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
