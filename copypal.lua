function init(plugin)
    local colorFormats = {
        "CSV Bytes (0-255)",
        "CSV Floats (0-1.0)",
        "Hexadecimal (0-FF)",
        "BGR555 (0-1F)",
        "Decimal (0-16777215)"
    }

    if plugin.preferences.copy_alpha == nil then
        plugin.preferences.copy_alpha = false
    end

    if plugin.preferences.float_alpha == nil then
        plugin.preferences.float_alpha = false
    end

    if plugin.preferences.prefix == nil then
        plugin.preferences.prefix = "";
    end

    if plugin.preferences.suffix == nil then
        plugin.preferences.suffix = "";
    end

    if plugin.preferences.newline == nil then
        plugin.preferences.newline = false
    end

    if plugin.preferences.lowercase == nil then
        plugin.preferences.lowercase = false
    end

    if plugin.preferences.color_format == nil then
        plugin.preferences.color_format = colorFormats[1]
    end

    local function indexOf(array, value)
        for i, v in ipairs(array) do
            if v == value then
                return i
            end
        end
        return nil
    end

    local function areColorsSelected()
        return #app.range.colors > 0
    end

    local function toBGR555Hex(color)
        local r = math.floor(color.red / 8.0)
        local g = math.floor(color.green / 8.0)
        local b = math.floor(color.blue / 8.0)

        local decimal = (b << 10) + (g << 5) + r
        return string.format("%04X", decimal)
    end

    local function toARGBDecimal(color, alpha)
        local decimal = ((color.alpha << 24) * alpha) | (color.red << 16) | (color.green << 8) | color.blue
        return string.format("%d", decimal)
    end

    local function copyToClipboard(text)
        if (app.os.name == 'Windows') then
            return io.popen('clip', 'w'):write(text):close()
        elseif (app.os.name == 'macOS') then
            return io.popen('pbcopy', 'w'):write(text):close()
        elseif (app.os.name == 'Linux') then
            return io.popen('xsel --clipboard', 'w'):write(text):close()
        end
    end

    local function getColors()
        if areColorsSelected() then
            local colors = {}
            for _, idx in ipairs(app.range.colors) do
                table.insert(colors, app.sprite.palettes[1]:getColor(idx))
            end
            return colors
        else
            return { app.fgColor }
        end
    end

    local function formatColor(col, formatType)
        local alpha = plugin.preferences.copy_alpha
        local floatAlpha = plugin.preferences.float_alpha
        local prefix = plugin.preferences.prefix
        local suffix = plugin.preferences.suffix

        if formatType == 1 then
            if alpha then
                if floatAlpha then
                    return prefix ..
                        string.format("%d, %d, %d, %.2g", col.red, col.green, col.blue, col.alpha / 255) .. suffix
                else
                    return prefix .. string.format("%d, %d, %d, %d", col.red, col.green, col.blue, col.alpha) .. suffix
                end
            else
                return prefix .. string.format("%d, %d, %d", col.red, col.green, col.blue) .. suffix
            end
        elseif formatType == 2 then
            if alpha then
                return prefix ..
                    string.format("%.2g, %.2g, %.2g, %.2g", col.red / 255, col.green / 255, col.blue / 255,
                        col.alpha / 255) ..
                    suffix
            else
                return prefix ..
                    string.format("%.2g, %.2g, %.2g", col.red / 255, col.green / 255, col.blue / 255) .. suffix
            end
        elseif formatType == 3 then
            if alpha then
                return prefix .. string.format("%02X%02X%02X%02X", col.red, col.green, col.blue, col.alpha) .. suffix
            else
                return prefix .. string.format("%02X%02X%02X", col.red, col.green, col.blue) .. suffix
            end
        elseif formatType == 4 then
            return prefix .. toBGR555Hex(col) .. suffix
        elseif formatType == 5 then
            local alphaFlag = plugin.preferences.copy_alpha and 1 or 0
            return prefix .. toARGBDecimal(col, alphaFlag) .. suffix
        end
    end

    local function generateColorText(formatType)
        local newline = plugin.preferences.newline and "\n" or ""
        local lowercase = plugin.preferences.lowercase
        local text = {}

        for _, col in ipairs(getColors()) do
            table.insert(text, formatColor(col, formatType))
        end

        local result = table.concat(text, newline)
        if lowercase then result = result:lower() end
        return result
    end

    local function_table = {
        [1] = function() return generateColorText(1) end,
        [2] = function() return generateColorText(2) end,
        [3] = function() return generateColorText(3) end,
        [4] = function() return generateColorText(4) end,
        [5] = function() return generateColorText(5) end
    }


    plugin:newMenuSeparator {
        group = "palette_generation"
    }

    local dlg = Dialog("CopyPal")

    plugin:newCommand {
        id = "copypal_options",
        title = "CopyPal Options...",
        group = "palette_generation",
        onclick = function()
            dlg:show {
                wait = false,
                autoscrollbars = false,
            }
        end
    }

    plugin:newCommand {
        id = "copypal",
        title = "Copy Colors",
        group = "palette_generation",
        -- onenabled = areColorsSelected,
        onclick = function()
            copyToClipboard(function_table[indexOf(colorFormats, plugin.preferences.color_format)]())
        end
    }

    dlg:separator {
        id = "fmt_sep",
        text = "Color Format",
    }

    dlg:combobox {
        id = "color_format",
        option = plugin.preferences.color_format,
        options = colorFormats,
        onchange = function()
            local data = dlg.data
            dlg:modify {
                id = "copypal_copy_alpha",
                visible = data.color_format ~= colorFormats[4],
            }
            dlg:modify {
                id = "copypal_float_alpha",
                visible = data.color_format == colorFormats[1],
            }
            dlg:modify {
                id = "copypal_lowercase",
                visible = data.color_format == colorFormats[3] or data.color_format == colorFormats[4],
            }
            plugin.preferences.color_format = data.color_format
        end
    }

    dlg:entry {
        id = "copypal_prefix",
        label = "Prefix",
        text = "",
        onchange = function()
            local data = dlg.data
            plugin.preferences.prefix = data.copypal_prefix
        end
    }

    dlg:entry {
        id = "copypal_suffix",
        label = "Suffix",
        text = "",
        onchange = function()
            local data = dlg.data
            plugin.preferences.suffix = data.copypal_suffix
        end
    }

    dlg:check {
        id = "copypal_copy_alpha",
        text = "Copy Alpha",
        selected = plugin.preferences.copy_alpha,
        visible = plugin.preferences.color_format ~= colorFormats[4],
        onclick = function()
            plugin.preferences.copy_alpha = not plugin.preferences.copy_alpha
            dlg:modify {
                id = "copypal_float_alpha",
                visible = plugin.preferences.color_format == colorFormats[1] and plugin.preferences.copy_alpha,
            }
        end
    }

    dlg:check {
        id = "copypal_float_alpha",
        text = "Float Alpha",
        visible = plugin.preferences.color_format == colorFormats[1],
        selected = plugin.preferences.float_alpha,
        onclick = function()
            plugin.preferences.float_alpha = not plugin.preferences.float_alpha
        end
    }

    dlg:check {
        id = "copypal_lowercase",
        text = "Lowercase",
        visible = plugin.preferences.color_format == colorFormats[3] or plugin.preferences.color_format == colorFormats[4],
        selected = plugin.preferences.lowercase,
        onclick = function()
            plugin.preferences.lowercase = not plugin.preferences.lowercase
        end
    }

    dlg:check {
        id = "copypal_newline",
        text = "Newline",
        selected = plugin.preferences.newline,
        onclick = function()
            plugin.preferences.newline = not plugin.preferences.newline
        end
    }

    dlg:separator {
        id = "copy_sep",
    }


    dlg:button {
        text = "Copy",
        onclick = function()
            copyToClipboard(function_table[indexOf(colorFormats, plugin.preferences.color_format)]())
        end
    }

    dlg:button {
        text = "Close",
        onclick = function()
            dlg:close()
        end
    }
end
