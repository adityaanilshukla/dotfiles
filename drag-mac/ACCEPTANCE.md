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
| 4 | Multi-file | `drag-mac /tmp/dragdemo/*.txt`, drag once | All 3 arrive together | TODO |
| 5 | Closes after the drop | any successful drop | Window disappears without being clicked | TODO |
| 6 | Cancelled drag | start a drag, release over dead space | Window stays; no crash | TODO |
| 7 | Escape | press Escape with the window focused | Window closes | TODO |
| 8 | Watchdog | launch, wait 2 minutes, touch nothing | Window closes on its own | TODO |
| 9 | From ranger | `alt-n`, select a file, press `dn` | Window appears above ranger; drag works | TODO |
| 10 | Multi-select from ranger | mark 3 files with space, press `dn` | Caption reads "3 items"; all 3 drop | TODO |
| 11 | ranger stays usable | after `dn`, type in ranger | ranger is not blocked | TODO |
| 12 | TCC-protected folder | `dn` on a file in ~/Documents | Drops, or prompts once and then drops | TODO |
| 13 | Filename with spaces | `dn` on a file named `with space.txt` | Correct file lands, name intact | TODO |
| 14 | Fresh machine | `rm -rf ~/.local/share/drag-mac && ./install.sh` | venv rebuilt, `dn` works again | TODO |

## Known divergences from dragon-drop

- A cancelled drag leaves the window open rather than exiting, so a fumbled
  grab does not force a relaunch. `dragon-drop -x` exits either way. The
  watchdog still bounds the window's lifetime.
- No `-a` flag equivalent: every selection is always one combined drag, since
  that is the only behaviour `dn` ever asked for.
