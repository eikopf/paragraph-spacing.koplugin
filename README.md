# Paragraph spacing for KOReader

This plugin adds a per-book paragraph spacing control to KOReader's bottom
configuration menu. It is designed to look and behave like the built-in line
spacing control: a quantized slider provides quick presets, and its menu button
opens a precise unitless level selector.

The control is available only for reflowable documents such as EPUB and FB2.
Each book remembers its own setting. Changes are applied immediately, and the
plugin preserves unrelated book-specific CSS.

## Installation

Download `paragraph-spacing.koplugin.zip` from the latest GitHub release and
extract it into KOReader's `plugins` directory. The resulting directory must be
named `paragraph-spacing.koplugin`. Restart KOReader, open a reflowable book,
and use the paragraph spacing row in the bottom configuration menu.

## Compatibility

The bottom-menu integration and immediate CSS refresh use internal KOReader
interfaces. The plugin falls back to a normal reader settings submenu if it
cannot extend the bottom menu. See [COMPATIBILITY.md](COMPATIBILITY.md) for the
technical details and compatibility history.

## Versioning

Stable releases use the `MAJOR.MINOR.PATCH` form from
[Semantic Versioning](https://semver.org/) and do not currently publish
prerelease tags. The version in `_meta.lua` is mirrored by a `vX.Y.Z` Git tag.
KOReader does not use the metadata version itself; the Git tag and corresponding
release are the canonical distribution version.
