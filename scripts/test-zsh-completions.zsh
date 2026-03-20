#!/usr/bin/env zsh

emulate -L zsh
setopt errexit nounset pipefail extendedglob

zmodload zsh/zpty

typeset -gi assertion_count=0

repo_root=${0:A:h:h}
completion_file=${APTUNE_COMPLETION_FILE:-"$repo_root/completions/zsh/_aptune"}
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/aptune-zsh-tests.XXXXXX")
pty_name=aptune_completion_test
command_name=${APTUNE_COMPLETION_COMMAND_NAME:-aptune-completion-test}
shell_pid_file="$test_dir/shell.pid"

cleanup() {
    set +e

    terminate_shell
    rm -rf "$test_dir"
}

trap cleanup EXIT

terminate_shell() {
    local shell_pid=''
    local retries=20

    if [[ -f "$shell_pid_file" ]]; then
        shell_pid=$(<"$shell_pid_file")
    fi

    if [[ $shell_pid != <-> ]]; then
        return
    fi

    if kill -0 "$shell_pid" >/dev/null 2>&1; then
        kill -TERM "$shell_pid" >/dev/null 2>&1 || true

        while (( retries > 0 )) && kill -0 "$shell_pid" >/dev/null 2>&1; do
            sleep 0.05
            (( retries -= 1 ))
        done
    fi

    if kill -0 "$shell_pid" >/dev/null 2>&1; then
        kill -KILL "$shell_pid" >/dev/null 2>&1 || true
    fi
}

write_zshrc() {
    local rc_file="$test_dir/.zshrc"

    cat >"$rc_file" <<EOF
PS1='PROMPT> '
PROMPT2=''
setopt no_nomatch autolist listpacked
source "$completion_file"
autoload -Uz compinit
compinit -i -d "$test_dir/.zcompdump"
compdef _aptune "$command_name"
_aptune_dump_buffer() {
    print -r -- "__BUFFER__:\$BUFFER"
}
zle -N _aptune_dump_buffer
bindkey '^X^B' _aptune_dump_buffer
EOF
}

write_shell_launcher() {
    local launcher="$test_dir/start-shell.zsh"

    cat >"$launcher" <<'EOF'
#!/usr/bin/env zsh

setopt errexit nounset

pid_file=$1
zdotdir=$2

print -r -- $$ >"$pid_file"
export ZDOTDIR="$zdotdir"
exec zsh -i
EOF

    chmod +x "$launcher"
}

read_available_output() {
    local chunk collected='' idle_cycles=0

    while (( idle_cycles < 12 )); do
        if zpty -r -t "$pty_name" chunk; then
            collected+="$chunk"$'\n'
            idle_cycles=0
        else
            (( idle_cycles += 1 ))
            sleep 0.05
        fi
    done

    print -nr -- "$collected"
}

normalize_output() {
    local text=$1

    print -nr -- "$text" | perl -0pe 's/\r//g; s/\a//g; s/\e\[[0-9;?]*[A-Za-z]//g'
}

capture_completion_output() {
    local input=$1

    zpty -w "$pty_name" "$input"
    sleep 0.2

    local output
    output=$(read_available_output)

    zpty -w "$pty_name" $'\x03'
    sleep 0.1
    read_available_output >/dev/null

    normalize_output "$output"
}

assert_contains() {
    local label=$1
    local haystack=$2
    local needle=$3

    (( assertion_count += 1 ))

    if [[ $haystack == *"$needle"* ]]; then
        print -r -- "PASS: $label"
        return
    fi

    print -u2 -r -- "FAIL: $label"
    print -u2 -r -- "Expected to find: $needle"
    print -u2 -r -- "Captured output:"
    print -u2 -r -- "$haystack"
    exit 1
}

start_shell() {
    write_zshrc
    write_shell_launcher
    zpty "$pty_name" /bin/zsh "$test_dir/start-shell.zsh" "$shell_pid_file" "$test_dir"
    sleep 0.2
    read_available_output >/dev/null
}

run_tests() {
    local output

    output=$(capture_completion_output "${command_name} --lo"$'\t\x18\x02')
    assert_contains "top-level option prefix completes to --log-level" "$output" "__BUFFER__:${command_name} --log-level "

    output=$(capture_completion_output "${command_name} he"$'\t\x18\x02')
    assert_contains "top-level alias completes to help" "$output" "__BUFFER__:${command_name} help "

    output=$(capture_completion_output "${command_name} use-b"$'\t\x18\x02')
    assert_contains "subcommand completes to use-built-in-mic" "$output" "__BUFFER__:${command_name} use-built-in-mic "

    output=$(capture_completion_output "${command_name} install-p"$'\t\x18\x02')
    assert_contains "subcommand completes to install-plugin" "$output" "__BUFFER__:${command_name} install-plugin "

    output=$(capture_completion_output "${command_name} "$'\t\t\x18\x02')
    assert_contains "top-level listing includes run options" "$output" "--down-to"
    assert_contains "top-level listing includes use-built-in-mic" "$output" "use-built-in-mic"
    assert_contains "top-level listing includes install-plugin" "$output" "Install an Aptune plugin"

    output=$(capture_completion_output "${command_name} use-built-in-mic --rep"$'\t\x18\x02')
    assert_contains "use-built-in-mic option completes to --replace-running" "$output" "__BUFFER__:${command_name} use-built-in-mic --replace-running "

    output=$(capture_completion_output "${command_name} use-built-in-mic --help "$'\t\x18\x02')
    assert_contains "use-built-in-mic help flag suppresses extra args" "$output" "__BUFFER__:${command_name} use-built-in-mic --help "

    output=$(capture_completion_output "${command_name} use-built-in-mic -- --lo"$'\t\x18\x02')
    assert_contains "passthrough option completes to --log-level" "$output" "__BUFFER__:${command_name} use-built-in-mic -- --log-level "

    output=$(capture_completion_output "${command_name} use-built-in-mic -- --log-level d"$'\t\x18\x02')
    assert_contains "passthrough enum value narrows to debug" "$output" "__BUFFER__:${command_name} use-built-in-mic -- --log-level debug "

    output=$(capture_completion_output "${command_name} use-built-in-mic -- --down-to "$'\t\t\x18\x02')
    assert_contains "passthrough numeric suggestions include default ducking level" "$output" "Default ducking level"

    output=$(capture_completion_output "${command_name} install-plugin buil"$'\t\x18\x02')
    assert_contains "plugin target completes to built-in-mic" "$output" "__BUFFER__:${command_name} install-plugin built-in-mic "

    output=$(capture_completion_output "${command_name} install-plugin "$'\t\t\x18\x02')
    assert_contains "install-plugin listing includes built-in-mic target" "$output" "Install the Spotlight launcher app"

    output=$(capture_completion_output "${command_name} install-plugin built-in-mic --app"$'\t\x18\x02')
    assert_contains "plugin flag completes to --app-name" "$output" "__BUFFER__:${command_name} install-plugin built-in-mic --app-name "

    output=$(capture_completion_output "${command_name} install-plugin built-in-mic --help "$'\t\x18\x02')
    assert_contains "plugin help flag suppresses extra args" "$output" "__BUFFER__:${command_name} install-plugin built-in-mic --help "
}

start_shell
run_tests

print -r -- "All $assertion_count zsh completion assertions passed."
