local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local _ = require("gettext")
local T = require("ffi/util").template

local LEGACY_SETTING_NAME = "paragraph_spacing"
local SETTING_NAME = "copt_paragraph_spacing"
local CONFIGURABLE_NAME = "paragraph_spacing"
local PUBLISHER_DEFAULT = 0
local NO_SPACING = 1
local MAX_SPACING_LEVEL = 101
local BLOCK_START = "/* paragraph-spacing.koplugin:start */"
local BLOCK_END = "/* paragraph-spacing.koplugin:end */"
local BLOCK_PATTERN = "\n?/%* paragraph%-spacing%.koplugin:start %*/.-/%* paragraph%-spacing%.koplugin:end %*/"

local OPTION_VALUES = { PUBLISHER_DEFAULT, NO_SPACING }
local BOTTOM_MENU_LABELS = {
  { text = _("Publisher default"), value = PUBLISHER_DEFAULT },
  { text = _("None"),              value = NO_SPACING },
}
for level = 1, 10 do
  local value = level * 10 + 1
  table.insert(OPTION_VALUES, value)
  table.insert(BOTTOM_MENU_LABELS, {
    text = T(_("Level %1"), level),
    value = value,
  })
end

local PRECISE_VALUE_LABELS = {
  _("Publisher default"),
  _("None"),
}
for level = 1, 100 do
  table.insert(PRECISE_VALUE_LABELS, tostring(level))
end

local OPTION_LABELS = {}
for _, option in ipairs(BOTTOM_MENU_LABELS) do
  table.insert(OPTION_LABELS, option.text)
end

-- This declarative table follows the internal CreOptions/ConfigDialog schema.
-- It deliberately contains no plugin-instance closures: ui/data/creoptions is
-- cached by require(), so this table may outlive an individual ReaderUI.
local BOTTOM_MENU_OPTION = {
  name = CONFIGURABLE_NAME,
  name_text = _("Paragraph Spacing"),
  buttonprogress = true,
  values = OPTION_VALUES,
  labels = OPTION_LABELS,
  default_value = PUBLISHER_DEFAULT,
  args = OPTION_VALUES,
  event = "SetParagraphSpacing",
  more_options = true,
  more_options_param = {
    value_table = PRECISE_VALUE_LABELS,
    value_table_shift = 1,
  },
}

local ParagraphSpacing = WidgetContainer:extend {
  name = "paragraph_spacing",
  is_doc_only = true,
}

local function normalizeValue(value)
  -- Migrate values stored by older plugin versions.
  if value == "publisher" then
    return PUBLISHER_DEFAULT
  elseif value == "none" then
    return NO_SPACING
  end

  local number = tonumber(value)
  if type(value) == "string" and number and number >= 0 and number <= 1 then
    return math.floor(number * 100 + 0.5) + 1
  elseif number and number >= PUBLISHER_DEFAULT and number <= MAX_SPACING_LEVEL then
    return math.floor(number + 0.5)
  end
  return PUBLISHER_DEFAULT
end

local function removeManagedBlock(css)
  if not css then
    return nil
  end

  css = css:gsub(BLOCK_PATTERN, "")
  if css == "" then
    return nil
  end
  return css
end

local function makeManagedBlock(value)
  local rule
  if value == NO_SPACING then
    rule = [[p {
    margin-top: 0 !important;
    margin-bottom: 0 !important;
}]]
  else
    local em = string.format("%.2f", (value - 1) / 100)
    em = em:gsub("0+$", ""):gsub("%.$", "")
    rule = string.format([[p + p {
    margin-top: %sem !important;
}]], em)
  end
  return BLOCK_START .. "\n" .. rule .. "\n" .. BLOCK_END
end

local function appendManagedBlock(css, block)
  if not css then
    return block
  end
  -- This newline belongs to our block (even when css already ends in one),
  -- so removeManagedBlock can later restore unrelated CSS byte-for-byte.
  return css .. "\n" .. block
end

local function injectBottomMenuOption(config_options)
  if type(config_options) ~= "table" then
    return false
  end

  local line_spacing_options
  local line_spacing_index
  for _, panel in ipairs(config_options) do
    if type(panel.options) == "table" then
      for index, option in ipairs(panel.options) do
        if option.name == CONFIGURABLE_NAME then
          return true -- Already injected by an earlier ReaderUI.
        elseif option.name == "line_spacing" then
          line_spacing_options = panel.options
          line_spacing_index = index
        end
      end
    end
  end

  if not line_spacing_options then
    return false
  end
  table.insert(line_spacing_options, line_spacing_index + 1, BOTTOM_MENU_OPTION)
  return true
end

function ParagraphSpacing:init()
  -- ReaderStyleTweak and CSS reflow are available only on ReaderUI's rolling
  -- document path. Not registering here keeps this out of PDF/fixed-layout UI.
  if not self.ui.rolling or not self.ui.styletweak then
    return
  end

  local configurable = self.ui.document.configurable
  local stored_default = G_reader_settings:readSetting(SETTING_NAME)
  local default = normalizeValue(stored_default)
  if stored_default ~= nil and stored_default ~= default then
    G_reader_settings:saveSetting(SETTING_NAME, default)
  end
  configurable[CONFIGURABLE_NAME] = default
  self.value = default

  -- ReaderConfig.options is an internal API. Its CreOptions table has been
  -- stable for years, but it is not part of KOReader's plugin contract; see
  -- COMPATIBILITY.md. Fall back to the supported top-menu registration if its
  -- expected structure is unavailable.
  self.bottom_menu_injected = self.ui.config
      and injectBottomMenuOption(self.ui.config.options)
  if not self.bottom_menu_injected then
    logger.warn("paragraph-spacing: unable to extend ReaderConfig; using top-menu fallback")
    self.ui.menu:registerToMainMenu(self)
  end
end

function ParagraphSpacing:onReadSettings(config)
  if not self.ui.rolling or not self.ui.styletweak then
    return
  end

  local value = config:has(SETTING_NAME)
      and config:readSetting(SETTING_NAME)
      or self.ui.document.configurable[CONFIGURABLE_NAME]
  if not config:has(SETTING_NAME) and config:has(LEGACY_SETTING_NAME) then
    value = normalizeValue(config:readSetting(LEGACY_SETTING_NAME))
    self.ui.document.configurable[CONFIGURABLE_NAME] = value
    config:saveSetting(SETTING_NAME, value)
    config:delSetting(LEGACY_SETTING_NAME)
  end
  self.value = normalizeValue(value)
  self.ui.document.configurable[CONFIGURABLE_NAME] = self.value
  if value ~= self.value then
    config:saveSetting(SETTING_NAME, self.value)
  end
end

function ParagraphSpacing:setSpacing(value)
  value = normalizeValue(value)
  local style_tweak = self.ui.styletweak
  local css = removeManagedBlock(style_tweak.book_style_tweak)

  if value ~= PUBLISHER_DEFAULT then
    css = appendManagedBlock(css, makeManagedBlock(value))
    style_tweak.book_style_tweak_enabled = true
  elseif not css then
    style_tweak.book_style_tweak_enabled = false
  end

  self.value = value
  self.ui.document.configurable[CONFIGURABLE_NAME] = value
  style_tweak.book_style_tweak = css

  self.ui.doc_settings:saveSetting(SETTING_NAME, value)
  self.ui.doc_settings:delSetting(LEGACY_SETTING_NAME)
  self.ui.doc_settings:saveSetting("book_style_tweak", css)
  self.ui.doc_settings:saveSetting("book_style_tweak_enabled", style_tweak.book_style_tweak_enabled)

  -- updateCssText() is an internal ReaderStyleTweak API, not a stable plugin
  -- interface. Passing true rebuilds its aggregate CSS and immediately sends
  -- ApplyStyleSheet to ReaderTypeset, avoiding a document reopen.
  style_tweak:updateCssText(true)
end

function ParagraphSpacing:onSetParagraphSpacing(value)
  self:setSpacing(value)
  return true
end

-- Used only when the internal bottom-menu option injection is unavailable.
function ParagraphSpacing:addToMainMenu(menu_items)
  local sub_item_table = {}
  for _, option in ipairs(BOTTOM_MENU_LABELS) do
    local value = option.value
    table.insert(sub_item_table, {
      text = option.text,
      checked_func = function()
        return self.value == value
      end,
      callback = function(touchmenu_instance)
        self:setSpacing(value)
        if touchmenu_instance then
          touchmenu_instance:updateItems()
        end
      end,
    })
  end

  menu_items.paragraph_spacing = {
    text = _("Paragraph spacing"),
    sorting_hint = "setting",
    sub_item_table = sub_item_table,
  }
end

return ParagraphSpacing
