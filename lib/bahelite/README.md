# Bahelite

Bash helper library – to everyone!

* `bahelite.sh` provides
  * A check for the bash version.
  * A check for sourced script.
  * `MYNAME`, `MYDIR`, `MYPATH`, `CMDLINE`, `ARGS`…
  * Functions to temporarily disable `xtrace`, `errexit` (with a trap on ERR) and `noglob`.
  * `check_required_utils` to make sure all binaries are available.

* `bahelite_colours.sh` provides variables to control the colour, boldness/brightness and background.
* `bahelite_error_handling.sh`
  * sets a trap on `ERR`, where it prints call stack trace, command line on which script has failed and its exit code. Calls a user’s hook, if it exists.
  * sets a trap on `EXIT`, `TERM`, `INT`, `QUIT` and `KILL`, where it removes `TMPDIR`. Calls a user’s hook, if it exists.

* `bahelite_logging.sh`
  * creates a directory named after the main script – the one that calls `bahelite.sh` – and writes a copy of all stderr and stdout in a file there. Keeps last five logs by default.
  * defines a function to print the path to the log file to the user.

* `bahelite_menus.sh`
  * defines user-friendly, arrow-controlled menu functions. Selection never was this easy and fool-proof before.

* `bahelite_messages.sh`
  * Pretty output
    * All messages are multiline by default: excess spaces on the lines next to the first are cut.
    * Messages may have their own indentation level, which is kept even.
    * Highlighing is moderate with only a coloured asterisk by default. It is possible to highlight the whole message and print the message type instead of an asterisk, that is `INFO:`, `WARNING:` or `ERROR:` for example.
  * Function sets
    * `info` function set: to print informational messages. `infon` doesn’t print a newline, (like `echo -n`), `infow` will run a command, and then print either `[ OK ]` or `[ Fail ]` depending on its status.
    * `warn` function set: for the warnings, always sent to stderr.
    * `err`: for the errors, automatically quits the program.
  * Desktop notifications
    * If not needed, can be disabled with setting `NO_DESKTOP_NOTIFICATIONS` to any value.
    * By default `err` sends a copy of the message to desktop.
    * `info` and `warn` – only when called as `info-ns` and `warn-ns` (-ns stands for `notify-send`).
  * **Keyworded messages and localisation files** are possible.

* `bahelite_misc.sh`
  * `if_true` reads a variable name and returns 0 or 1, depending on the variable contents: 0 is for y/Y/yes/Yes/on/On/enabled/Enabled/1/t/T/true/True and 1 for their counterparts.
  * `dumpvar` takes multiple variable names, passes them to `declare -p` and prettifies the output with `msg` function.

* `bahelite_versioning.sh`
  * `update_version` is a function to be used in a pre-commit hook to update the version in a specified variable in a specified file. Works with three-number `X.Y.Z` versions only, four-number ones like A.B.C.D are not supported.
  * `compare_versions` will print the biggest of the two passed versions, or `equal`, if they are equivalent.

