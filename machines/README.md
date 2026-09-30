# machines/

One file per machine, named for its LocalHostName (`scutil --get LocalHostName`).

Everything else in this repo is the same on every machine, which is the point
of it. A few things genuinely are not: the mouse jiggler makes sense on a work
laptop whose presence is being watched and makes no sense on a personal one.
This directory is where that difference is written down, so a machine's
behaviour is a committed fact rather than something remembered by hand.

Format is `feature = yes`, one per line, `#` for comments. It is read with
grep, never sourced, so a config file cannot run code during an install.

A feature not named in a file is OFF. A machine with no file here gets every
optional feature off, which is the right default for a machine nobody has
thought about yet.

Turning a feature off is not the same as deleting its line and forgetting it:
the install step for each feature also has to UNDO itself when the flag is
off, or the machine that already had it carries on regardless. See
`install.d/82-mouse-jiggle.sh` for the shape that takes.
