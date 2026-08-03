local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local SETTING_NAME = "paragraph_spacing"
local PUBLISHER_DEFAULT = "publisher"
local BLOCK_START = "/* paragraph-spacing.koplugin:start */"
local BLOCK_END = "/* paragraph-spacing.koplugin:end */"
local BLOCK_PATTERN = "\n?/%* paragraph%-spacing%.koplugin:start %*/.-/%* paragraph%-spacing%.koplugin:end %*/"

local SPACING_OPTIONS = {
    { text = _("Publisher default"), value = PUBLISHER_DEFAULT },
    { text = _("None"), value = "none" },
    { text = _("0.125 em"), value = "0.125" },
    { text = _("0.25 em"), value = "0.25" },
    { text = _("0.375 em"), value = "0.375" },
    { text = _("0.5 em"), value = "0.5" },
    { text = _("0.75 em"), value = "0.75" },
    { text = _("1.0 em"), value = "1.0" },
}

local ParagraphSpacing = WidgetContainer:extend{
    name = "paragraph_spacing",
    is_doc_only = true,
}

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
    if value == "none" then
        rule = [[p {
    margin-top: 0 !important;
    margin-bottom: 0 !important;
}]]
    else
        rule = string.format([[p + p {
    margin-top: %sem !important;
}]], value)
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

function ParagraphSpacing:init()
    -- ReaderStyleTweak and CSS reflow are available only on ReaderUI's rolling
    -- document path. Not registering here keeps this out of PDF/fixed-layout UI.
    if not self.ui.rolling or not self.ui.styletweak then
        return
    end

    self.value = self.ui.doc_settings:readSetting(SETTING_NAME) or PUBLISHER_DEFAULT
    self.ui.menu:registerToMainMenu(self)
end

function ParagraphSpacing:setSpacing(value)
    local style_tweak = self.ui.styletweak
    local css = removeManagedBlock(style_tweak.book_style_tweak)

    if value ~= PUBLISHER_DEFAULT then
        css = appendManagedBlock(css, makeManagedBlock(value))
        style_tweak.book_style_tweak_enabled = true
    elseif not css then
        style_tweak.book_style_tweak_enabled = false
    end

    self.value = value
    style_tweak.book_style_tweak = css

    self.ui.doc_settings:saveSetting(SETTING_NAME, value)
    self.ui.doc_settings:saveSetting("book_style_tweak", css)
    self.ui.doc_settings:saveSetting("book_style_tweak_enabled", style_tweak.book_style_tweak_enabled)

    -- updateCssText() is an internal ReaderStyleTweak API, not a stable plugin
    -- interface. Passing true rebuilds its aggregate CSS and immediately sends
    -- ApplyStyleSheet to ReaderTypeset, avoiding a document reopen.
    style_tweak:updateCssText(true)
end

function ParagraphSpacing:addToMainMenu(menu_items)
    local sub_item_table = {}
    for _, option in ipairs(SPACING_OPTIONS) do
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
