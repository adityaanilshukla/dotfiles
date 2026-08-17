# drag-mac acceptance checklist

Tier 3 from PLAN.md. These need a human. The automated suite can prove a drag
session is constructed with the right files and that a completed drop triggers
the exit, but it cannot prove macOS actually hands the bytes to the destination
app. That gap is not theoretical: the inverted `NSDraggingContext` constant
(fixed in a99a161) passed every unit test while making the tool useless in
practice, because the test and the code shared the same wrong assumption.

Run through this after any change to the drag path.

## Setup

```sh
mkdir -p /tmp/dragdemo
printf 'alpha\n' > /tmp/dragdemo/alpha.txt
printf 'beta\n'  > /tmp/dragdemo/beta.txt
printf 'gamma\n' > /tmp/dragdemo/gamma.txt
```

## Cases

| # | Case | Steps | Expected | Status |
|---|---|---|---|---|
| 1 | Single file to Finder | `drag-mac /tmp/dragdemo/alpha.txt`, drag into a Finder window | File copied; window closes itself | PASS |
| 2 | Single file to a browser | drag into a Brave upload field | File attaches | PASS |
| 3 | Single file to a chat client | drag into WhatsApp | File attaches | PASS |
| 4 | Multi-file | `drag-mac /tmp/dragdemo/*.txt`, drag once | All 3 arrive together | MACHINE, all 3 paths reach one process and one session; the landing is unconfirmed |
| 5 | Closes after the drop | any successful drop | Window disappears without being clicked | PASS, after fixing the selector name; it never closed before that |
| 6 | Cancelled drag | start a drag, release over dead space | Window stays; no crash | TODO, and only meaningful now: until the selector fix the callback never fired at all, so nothing could distinguish a cancel from a drop |
| 7 | Escape | press Escape with the window focused | Window closes | TODO, synthetic key event only |
| 8 | Watchdog | launch, wait 2 minutes, touch nothing | Window closes on its own | MACHINE, `test_watchdog_exit` plus an observed short-timeout run |
| 9 | From ranger | `alt-n`, select a file, press `dn` | Window appears above ranger; drag works | MACHINE, ranger reported "dragging 1 file(s)" and the window was observed |
| 10 | Multi-select from ranger | mark 3 files with space, press `dn` | Caption reads "3 items"; all 3 drop | MACHINE, ranger reported "dragging 3 file(s)" with all 3 paths in the argv |
| 11 | ranger stays usable | after `dn`, type in ranger | ranger is not blocked | MACHINE, ranger kept responding to keys afterwards |
| 12 | TCC-protected folder | `dn` on a file in ~/Documents | Drops, or prompts once and then drops | PASS, dropped into Brave with no permission prompt at all |
| 13 | Filename with spaces | `dn` on a file named `with space.txt` | Correct file lands, name intact | TODO, covered in Tier 1 but not end to end |
| 14 | Fresh machine | move the venv aside and re-run `install.sh` | venv rebuilt, `dn` works again | MACHINE, rebuilt in ~6.5s with 78/78 green against the result |
| 15 | Dismiss without focus | `alt-shift-c` while another app holds focus | Window and process both gone | MACHINE |

Status values: PASS means a human watched it happen. MACHINE means it was
verified by driving ranger through tmux and reading the window server, which
covers everything up to the drop but cannot confirm the destination app
actually received the bytes. TODO means nobody has checked.

## Driving ranger from a script

`tmux send-keys -t <pane> "dn"` does **not** work: `set flushinput true` in
`rc.conf` discards the queued second key, so ranger sits in the `d` submenu
waiting. Send each key separately with a short gap. This affects scripted input
only; typed keystrokes are naturally spaced.

## Known divergences from dragon-drop

- A cancelled drag leaves the window open rather than exiting, so a fumbled
  grab does not force a relaunch. `dragon-drop -x` exits either way. The
  watchdog still bounds the window's lifetime.
- No `-a` flag equivalent: every selection is always one combined drag, since
  that is the only behaviour `dn` ever asked for.
