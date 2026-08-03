# KOReader compatibility

This plugin does not modify KOReader core, but two parts of its implementation
use internal KOReader APIs that are not covered by the stable plugin interface.

## Bottom configuration menu

To make paragraph spacing behave like line spacing, the plugin adds a
declarative option to `ReaderConfig.options`, immediately after the option whose
`name` is `line_spacing`. The inserted table uses the internal
`CreOptions`/`ConfigDialog` fields `name`, `name_text`, `buttonprogress`,
`values`, `labels`, `default_value`, `args`, `event`, `more_options`, and
`more_options_param.value_table`.

`ReaderConfig` then loads and saves the value through `document.configurable`
as `copt_paragraph_spacing`, giving it the same per-book and "set as default"
behavior as KOReader's built-in reflowable-document settings.

This structure has been stable since KOReader moved the UI option definitions
into `ReaderConfig` on 2018-10-26:

<https://github.com/koreader/koreader/commit/9e57e56f9>

The most recent incompatible behavioral change in this path was on 2021-05-12,
when `ConfigDialog` stopped updating `document.configurable` directly and began
broadcasting a `ConfigChange` event:

<https://github.com/koreader/koreader/commit/002b4d4be>

The plugin targets that newer event model and has been checked against KOReader
v2026.03. Because this remains an internal interface, a future bottom-menu
redesign may require changes. The injection therefore:

- locates `line_spacing` by name instead of relying on a panel index;
- avoids duplicate insertion into the `require()`-cached `CreOptions` table;
- contains no ReaderUI-instance closures in the injected option; and
- falls back to a normal reader settings submenu if the expected structure is
  unavailable.

## Immediate stylesheet application

The generated CSS is stored in the book's existing
`ReaderStyleTweak.book_style_tweak` value. After changing the managed block, the
plugin calls `ReaderStyleTweak:updateCssText(true)`. This internal method rebuilds
the aggregate tweak CSS and sends `ApplyStyleSheet`, so the open document is
rerendered immediately.

If KOReader changes `ReaderStyleTweak`, check that `book_style_tweak`,
`book_style_tweak_enabled`, and `updateCssText(true)` still have these semantics.

## Settings migration

Versions of this plugin before the bottom-menu integration stored the selected
value as `paragraph_spacing`. On first load, that value is migrated to
`copt_paragraph_spacing` and the legacy key is removed. The delimited CSS block
format is unchanged.

Early bottom-menu versions stored CSS `em` values as strings. These are migrated
to a numeric, unitless scale: `0` is Publisher default, `1` is None, and `2` to
`101` represent precise spacing levels 1 to 100. This lets the main bottom-menu
control expose 12 presets while KOReader's standard more-options picker exposes
all 100 positive levels without presenting document-relative CSS units.
