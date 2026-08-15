import os
import subprocess

from ranger.api.commands import Command
from ranger.core.loader import CommandLoader


def _x_env():
    """Return an env dict with DISPLAY/XAUTHORITY/WAYLAND_DISPLAY populated.

    Inside tmux the pane often lacks DISPLAY because the shell predates the
    graphical session. tmux's server-global env usually has it though, so
    pull from there when our own env is missing the bits xclip/dragon need.
    """
    env = os.environ.copy()
    needed = ("DISPLAY", "XAUTHORITY", "WAYLAND_DISPLAY")
    if all(env.get(k) for k in needed if k != "WAYLAND_DISPLAY") or env.get("WAYLAND_DISPLAY"):
        return env
    if not env.get("TMUX"):
        return env
    try:
        out = subprocess.check_output(["tmux", "show-environment", "-g"],
                                      stderr=subprocess.DEVNULL, text=True)
    except (OSError, subprocess.CalledProcessError):
        return env
    for line in out.splitlines():
        if "=" not in line or line.startswith("-"):
            continue
        k, v = line.split("=", 1)
        if k in needed and not env.get(k):
            env[k] = v
    return env


class yank(Command):
    """:yank [name|dir|path|name_without_extension]

    Copy file info to the system clipboard (PRIMARY + CLIPBOARD on X11,
    or wl-copy on Wayland) and show a notification. Overrides the stock
    yank, which is silent and leaves you wondering whether it worked.
    """

    modes = {
        "": "basename",
        "name": "basename",
        "name_without_extension": "basename_without_extension",
        "dir": "dirname",
        "path": "path",
    }

    def execute(self):
        from ranger.ext.get_executables import get_executables

        attr = self.modes.get(self.arg(1), "basename")
        selection = [getattr(f, attr) for f in self.fm.thistab.get_selection()]
        if not selection:
            return
        text = "\n".join(selection)

        execs = get_executables()
        if "wl-copy" in execs:
            cmds = [["wl-copy"]]
        elif "xclip" in execs:
            cmds = [["xclip", "-selection", "primary"],
                    ["xclip", "-selection", "clipboard"]]
        elif "xsel" in execs:
            cmds = [["xsel", "-pi"], ["xsel", "-bi"]]
        elif "pbcopy" in execs:
            cmds = [["pbcopy"]]
        else:
            self.fm.notify("yank: no clipboard tool (install xclip/xsel/wl-copy)", bad=True)
            return

        env = _x_env()
        for cmd in cmds:
            p = subprocess.Popen(cmd, stdin=subprocess.PIPE,
                                 stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL,
                                 env=env)
            p.communicate(input=text.encode())

        preview = text if len(text) <= 60 else text[:57] + "..."
        self.fm.notify("yanked {}: {}".format(attr, preview))

    def tab(self, tabnum):
        return ["yank " + m for m in sorted(self.modes) if m]


class drag(Command):
    """:drag

    Drag-and-drop the current selection out of ranger using dragon-drop.
    Detached via setsid -f so ranger isn't blocked.
    """

    def execute(self):
        from ranger.ext.get_executables import get_executables

        if "dragon-drop" in get_executables():
            tool = "dragon-drop"
        elif "dragon" in get_executables():
            tool = "dragon"
        else:
            self.fm.notify("drag: dragon-drop not installed (paru -S dragon-drop)", bad=True)
            return

        paths = [f.path for f in self.fm.thistab.get_selection()]
        if not paths:
            return

        subprocess.Popen(["setsid", "-f", tool, "-a", "-x", "--"] + paths,
                         stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL,
                         stdin=subprocess.DEVNULL,
                         env=_x_env())
        self.fm.notify("dragging {} file(s)".format(len(paths)))


class extract_here(Command):
    def execute(self):
        """Extract selected .zip files to the current directory using 'unzip'."""
        cwd = self.fm.thisdir
        marked_files = tuple(cwd.get_selection())

        def refresh(_):
            cwd = self.fm.get_directory(original_path)
            cwd.load_content()

        if not marked_files:
            return

        one_file = marked_files[0]
        original_path = cwd.path

        self.fm.copy_buffer.clear()
        self.fm.cut_buffer = False

        for f in marked_files:
            if not f.path.lower().endswith(".zip"):
                self.fm.notify(f"Skipping non-zip file: {f.basename}", bad=True)
                continue

            descr = f"Extracting: {os.path.basename(f.path)}"
            obj = CommandLoader(
                args=["unzip", "-o", f.path, "-d", original_path],
                descr=descr,
                read=True,
            )
            obj.signal_bind("after", refresh)
            self.fm.loader.add(obj)


class sudorename(Command):
    """
    :sudorename <newname>
    Rename the current file using sudo (mv), prompting for your sudo password.
    """

    def execute(self):
        new = self.rest(1)
        if not new:
            # open console pre-filled so you can type the new name
            self.fm.open_console("sudorename ")
            return

        src = self.fm.thisfile.path
        dst = os.path.join(self.fm.thisdir.path, new)

        # run sudo mv and wait so ranger refreshes afterwards
        self.fm.run(["sudo", "mv", "-v", "--", src, dst], flags="w")
        # refresh directory view
        self.fm.thisdir.load_content()


# class compress(Command):
#     def execute(self):
#         """ Compress marked files into a zip archive using the 'zip' command. """
#         cwd = self.fm.thisdir
#         marked_files = cwd.get_selection()
#
#         if not marked_files:
#             self.fm.notify("No files selected for compression", bad=True)
#             return
#
#         # Get output archive name from the command line, default to 'archive.zip'
#         parts = self.line.strip().split()
#         if len(parts) < 2:
#             self.fm.notify("Usage: :compress <output.zip>", bad=True)
#             return
#
#         archive_name = parts[1]
#         if not archive_name.lower().endswith(".zip"):
#             archive_name += ".zip"
#
#         rel_paths = [os.path.relpath(f.path, cwd.path) for f in marked_files]
#
#         descr = f"Compressing to: {archive_name}"
#         obj = CommandLoader(
#             args=["zip", "-r", archive_name] + rel_paths,
#             descr=descr,
#             read=True
#         )
#
#         def refresh(_):
#             cwd = self.fm.get_directory(cwd.path)
#             cwd.load_content()
#
#         obj.signal_bind("after", refresh)
#         self.fm.loader.add(obj)
#
#     def tab(self, tabnum):
#         """ Auto-complete with current folder name + .zip """
#         return [f"compress {os.path.basename(self.fm.thisdir.path)}.zip"]
