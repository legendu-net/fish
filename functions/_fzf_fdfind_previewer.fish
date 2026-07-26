# Helper function for _fzf_fdfind_previewer.
# Describes a file and dumps the head of it.
function _fzf_fdfind_hexdump
    file --brief --dereference -- "$argv[1]"
    xxd -l 4096 -- "$argv[1]"
end

# Helper function for fzf_fdind.
# Definers a previewer for files.
#     - preview an image using chafa.
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
            #
            # fzf hands the previewer a pipe instead of a tty, so chafa cannot
            # query the pane and falls back to a fixed size unless it is told
            # the one fzf exports. Outside fzf the variables are unset and
            # chafa's own detection is the right thing.
            set -l size
            if test -n "$FZF_PREVIEW_COLUMNS"; and test -n "$FZF_PREVIEW_LINES"
                set size --size $FZF_PREVIEW_COLUMNS"x"$FZF_PREVIEW_LINES
            end
            # A still frame: animating a GIF makes chafa emit cursor motion on
            # top of the pixels, which is not what a preview pane wants. chafa
            # ships no loader for some formats (e.g. BMP), so fall back rather
            # than leave the pane holding nothing but its error message.
            chafa --animate off $size -- "$argv[1]"
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
