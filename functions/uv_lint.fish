function _uv_lint_usage
    printf "Lint a script using uvx.
Syntax: uvx_lint_script [options] script
"
end

function uv_lint
    argparse h/help -- $argv
    if set -q _flag_help
        _uv_lint_usage
        return 0
    end

    set -l plus35 (string repeat -n 35 "+")
    set -l line "\n\n$plus35%s$plus35\n"

    if test (count $argv) -eq 0
        printf $line " pyproject-fmt "
        uv run pyproject-fmt pyproject.toml
        printf $line " ruff check "
        uv run ruff check
        printf $line " ruff format "
        uv run ruff format
        printf $line " ty "
        uv run ty check
        printf $line " deptry "
        uv run deptry .
        printf $line " pytest "
        uv run pytest
        return
    end

    for pyscript in $argv
        printf $line " ruff check "
        uv run --with ruff --with-requirements "$pyscript" ruff check "$pyscript"
        printf $line " ruff format "
        uv run --with ruff --with-requirements "$pyscript" ruff format "$pyscript"
        printf $line " ty "
        uv run --with ty --with-requirements "$pyscript" ty check "$pyscript"
        printf $line " pytest "
        uv run --with pytest --with-requirements "$pyscript" pytest check "$pyscript"
    end
end
