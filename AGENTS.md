# GEMINI.md - Fish Shell Configuration & Utilities

This repository contains a comprehensive configuration and function library for the Fish shell,
designed to enhance productivity
through interactive tools, efficient abbreviations, and modular functions.

## Project Overview

- **Purpose:** Provide a robust, feature-rich environment for the Fish shell.
- **Key Technologies:**
  - **Fish Shell:** The core shell environment.
  - **Interactive Search:** Powered by `fzf`, `ripgrep` (`rg`), and `fd-find`.
  - **Tooling Integrations:** Extensive support and abbreviations for `git`, `jj` (Jujutsu), `docker`, `podman`, `toolbox`, `uv`, `hg`, `cargo`, and `eza`.
  - **AI Integration:** Integration with Gemini for automated tasks (e.g., generating commit messages).
  - **Editors:** Prefers `nvim`, falling back to `vim` or `vi`. Support for GUI editors like VS Code via `preferred_editor`.
  - **Completions:** Custom completions, some generated via YAML-based definitions in `completions/`.

  ## Key Features

  - **Interactive Search:** Robust interactive search and navigation powered by `fzf`, `ripgrep`, and `fd-find`.
  - **Abbreviation Expansion:** A custom `expand_all_abbr` function (bound to `ctrl-alt-space`) allows for expanding all abbreviations in the current command line.
  - **Enhanced Navigation:** The `cs` function combines directory changing with automatic listing (via `eza` or `ls`).
  - **Smart Commit Messages:** The `gdss` abbreviation uses Gemini to generate concise conventional commit messages based on staged changes.

  ## Architecture & Structure

  - `config.fish`: The main entry point for interactive sessions.
    Sets up paths, environment variables, abbreviations, and keybindings.
  - `functions/`: Contains modular Fish functions.
    Many follow a pattern of providing interactive UIs for existing CLI tools (e.g., `fzf_ripgrep`, `fzf_history`).
  - `completions/`: Command completion scripts and YAML definitions for tools like `ldc`.
  - `fish_variables`: Persistent fish variables.
## Building and Running

The best way to use this fish configuration is to install
[icon](https://github.com/legendu-net/icon)
,
and then run the following command.

```
icon fish -c
```

Technically speaking,
things will work if you just symlinking or copying the contents into `~/.config/fish/`.
However,
the above command automatically generate fish completion scripts
based on YAML definitions in `completions/` as well.

### Development & Maintenance Commands

- **Format Code:** Use `fish_indent` to format scripts.
  ```bash
  # Format all fish files
  fish_indent --write **.fish
  ```
- **Lint Code:** The CI process runs basic syntax checks.
  ```bash
  # Check formatting without writing
  fish_indent -c **.fish
  # Check for syntax errors
  fish -n **.fish
  ```
- **Common Abbreviations:**
  - **Version Control:**
    - `gs`: `git status`
    - `gc`: `git commit -m ""`
    - `gdss`: Generates commit message via Gemini
    - `jjs`: `jj status`
    - `jjd`: `jj diff`
  - **Interactive Search:**
    - `frg`: `fzf_ripgrep` (Interactive search by content)
    - `ffd`: `fzf_fdfind` (Interactive search by filename)
    - `fcs` / `fcd`: Interactive directory changer
    - `fh` / `fhist`: Interactive history search
  - **Development:**
    - `uv.lint.project`: Runs Python linting suite via `uv`
    - `fi`: Formats all fish files and shows status
    - `...`: `cd ../..` (and `....` for three levels up)

## Development Conventions

- **Formatting:** Always run `fish_indent` before committing.
- **Function Naming:** Use `_` prefix for helper functions (e.g., `_fzf_ripgrep_opener`).
- **Editor Selection:** Use the `preferred_editor` function to determine which editor to launch.
- **Tool Detection:** Assume external tools are installed and allow them to throw errors at runtime if missing. Only use `command -q <cmd>` when defining aliases or abbreviations that are designed to seamlessly replace legacy tools with better modern alternatives (e.g., using `command -q eza` to safely replace `ls`).
- **Modular Functions:** Keep functions small and focused, each in its own file within `functions/`.
