# Paragraph spacing for KOReader

This plugin adds a per-book paragraph spacing control to KOReader's bottom
configuration menu; it is designed to look and behave like the built-in line
spacing control.

## Installation

Download `paragraph-spacing.koplugin-vX.Y.Z.zip` from the latest GitHub release
and extract it into KOReader's `plugins` directory. The resulting directory
must be named `paragraph-spacing.koplugin`. Restart KOReader, open a reflowable
book, and use the paragraph spacing row in the bottom configuration menu.

## Compatibility

The bottom-menu integration and immediate CSS refresh use internal KOReader
interfaces. The plugin falls back to a normal reader settings submenu if it
cannot extend the bottom menu. See [COMPATIBILITY.md](COMPATIBILITY.md) for the
technical details and compatibility history.
