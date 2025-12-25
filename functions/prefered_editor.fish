function _preferred_editor_usage
  echo "Find an existing editor command in the preferred order.
Syntax: preferred_editor [-h/--help] [-g/--gui]
Args:
    -h/--help: Show the help doc.
    -g/--gui: Include and prefer GUI editors.
"
end

function preferred_editor
    argparse "h/help" "g/gui" -- $argv
    if set -q _flag_help
        _preferred_editor_usage
        return 0
    end
    set editors_gui code code-server
    set editors_terminal nvim vim vi fresh
    if set -q _flag_gui
        set editors $editors_gui $editors_terminal
    else
        set editors $editors_terminal
    end
    for e in $editors
        if command -q $e
            echo $e
            return
        end
    end
end

