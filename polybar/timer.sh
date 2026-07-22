#!/usr/bin/env bash
# Countdown timer display for polybar. Polled every second (interval=1 in
# config.ini); state is written by `t` (scripts/t, on PATH as ~/.local/bin/t).
#
# State file format:
#   <phase> <end_epoch> <phase_total_seconds> <next_break_seconds> <paused_remaining>
# phase is "work" or "break"; next_break_seconds is only meaningful mid-work,
# it's the break to chain into once work hits zero (0 = no break requested).
# paused_remaining is 0 while running; when >0 the timer is frozen at that
# many seconds and end_epoch is stale (ignored until `t play` resumes it).

STATE_FILE="/tmp/polybar_timer.state"

blue="#4da3ff"
warning="#ffd6b1"
alert="#fc5ef0"
success="#86c38a"
disabled="#6f7377"

## An empty printf (not a bare `exit 0`) is required here: polybar's
## custom/script only clears the module's label when the script produces
## an actual (blank) line of output. If the script exits with no stdout at
## all, polybar keeps showing the last non-empty render indefinitely.
[[ -f "$STATE_FILE" ]] || { printf '\n'; exit 0; }

read -r phase end phase_total next_break paused_remaining < "$STATE_FILE"
paused_remaining="${paused_remaining:-0}"

if (( paused_remaining > 0 )); then
    mins=$(( paused_remaining / 60 ))
    secs=$(( paused_remaining % 60 ))
    printf '%%{F%s}%%{F-} %02d:%02d\n' "$disabled" "$mins" "$secs"
    exit 0
fi

now=$(date +%s)
remaining=$(( end - now ))

notify() {
    notify-send -a Timer "Timer" "$1" >/dev/null 2>&1 &
}

# Current phase just finished: chain into the break, or clear back to idle.
if (( remaining <= 0 )); then
    if [[ "$phase" == "work" && "$next_break" -gt 0 ]]; then
        phase="break"
        phase_total="$next_break"
        end=$(( now + next_break ))
        remaining="$phase_total"
        echo "$phase $end $phase_total 0 0" > "$STATE_FILE"
        notify "Work done, break time"
    else
        rm -f "$STATE_FILE"
        if [[ "$phase" == "break" ]]; then
            notify "Break's over"
        else
            notify "Timer done"
        fi
        printf '\n'
        exit 0
    fi
fi

mins=$(( remaining / 60 ))
secs=$(( remaining % 60 ))
pct=$(( remaining * 100 / phase_total ))

if [[ "$phase" == "break" ]]; then
    icon=""
    color="$success"
elif (( pct >= 50 )); then
    icon=""
    color="$blue"
elif (( pct >= 20 )); then
    icon=""
    color="$warning"
else
    icon=""
    color="$alert"
fi

printf '%%{F%s}%s%%{F-} %02d:%02d\n' "$color" "$icon" "$mins" "$secs"
