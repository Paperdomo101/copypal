function init(plugin)
    local colorFormats = {
        "CSV Bytes (0-255)",
        "CSV Floats (0-1.0)",
        "Hexadecimal (0-FF)",
        "BGR555 (0-1F)",
        "Decimal (0-16777215)"
    }

    if plugin.preferences.bgr555_endian == nil then
        plugin.preferences.bgr555_endian = "Big Endian"
    end

    if plugin.preferences.copy_alpha == nil then
        plugin.preferences.copy_alpha = false
    end

    if plugin.preferences.float_alpha == nil then
        plugin.preferences.float_alpha = false
    end

    plugin.preferences.prefix = ""
    plugin.preferences.suffix = ""

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

        local hex = (b << 10) + (g << 5) + r
        if plugin.preferences.bgr555_endian == "Little Endian" then
            local lo = hex & 0xFF
            local hi = (hex >> 8) & 0xFF
            hex = (lo << 8) | hi
        end

        return string.format("%04X", hex)
    end

    local function toARGBDecimal(color, alpha)
        local decimal = ((color.alpha << 24) * alpha) | (color.red << 16) | (color.green << 8) | color.blue
        return string.format("%d", decimal)
    end

    local function copyToClipboard(text)
        local cmd
        if app.os.name == 'Windows' then
            cmd = 'clip'
        elseif app.os.name == 'macOS' then
            cmd = 'pbcopy'
        elseif app.os.name == 'Linux' then
            cmd = 'xsel --clipboard'
        else
            app.alert("Unsupported OS: " .. app.os.name)
            return
        end

        local handle = io.popen(cmd, 'w')
        if handle then
            handle:write(text)
            handle:close()
        else
            app.alert("Failed to run clipboard command: " .. cmd)
        end
    end

    local function readFromClipboard()
        local cmd
        if app.os.name == 'Windows' then
            cmd = 'powershell Get-Clipboard'
        elseif app.os.name == 'macOS' then
            cmd = 'pbpaste'
        elseif app.os.name == 'Linux' then
            cmd = 'xsel --clipboard --output'
        else
            app.alert("Unsupported OS: " .. app.os.name)
            return nil
        end

        local handle = io.popen(cmd, 'r')
        if handle then
            local result = handle:read("*a")
            handle:close()
            return result
        else
            app.alert("Failed to read clipboard")
            return nil
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


    local function parseColorString(str, formatType)
        local function clamp(v) return math.max(0, math.min(255, v)) end

        if formatType == 1 then -- CSV Bytes
            local r, g, b, a = str:match("(%d+),%s*(%d+),%s*(%d+),?%s*(%d*)")
            if not r or not g or not b then return end
            return Color {
                red = clamp(tonumber(r) or 0),
                green = clamp(tonumber(g) or 0),
                blue = clamp(tonumber(b) or 0),
                alpha = a ~= "" and clamp(tonumber(a)) or 255
            }
        elseif formatType == 2 then -- CSV Floats
            local r, g, b, a = str:match("([0-9%.]+),%s*([0-9%.]+),%s*([0-9%.]+),?%s*([0-9%.]*)")
            if not r or not g or not b then return end
            return Color {
                red = clamp(math.floor((tonumber(r) or 0) * 255)),
                green = clamp(math.floor((tonumber(g) or 0) * 255)),
                blue = clamp(math.floor((tonumber(b) or 0) * 255)),
                alpha = a ~= "" and clamp(math.floor((tonumber(a)) * 255)) or 255
            }
        elseif formatType == 3 then -- Hexadecimal
            str = str:gsub("%s", ""):gsub("#", "")
            local r, g, b, a
            if #str == 6 then
                r, g, b = tonumber(str:sub(1, 2), 16), tonumber(str:sub(3, 4), 16), tonumber(str:sub(5, 6), 16)
                a = 255
            elseif #str == 8 then
                r, g, b, a = tonumber(str:sub(1, 2), 16), tonumber(str:sub(3, 4), 16), tonumber(str:sub(5, 6), 16),
                    tonumber(str:sub(7, 8), 16)
            else
                return nil
            end
            return Color { red = clamp(r), green = clamp(g), blue = clamp(b), alpha = clamp(a) }
        elseif formatType == 4 then -- BGR555
            local clean = str:gsub("%s", "")
            local hex = tonumber(clean, 16)
            if not hex then return nil end

            if plugin.preferences.bgr555_endian == "Little Endian" then
                local lo = hex & 0xFF
                local hi = (hex >> 8) & 0xFF
                hex = (lo << 8) | hi
            end

            local b = ((hex >> 10) & 0x1F) * 8
            local g = ((hex >> 5) & 0x1F) * 8
            local r = (hex & 0x1F) * 8
            return Color { red = r, green = g, blue = b, alpha = 255 }
        elseif formatType == 5 then -- Decimal
            local value = tonumber(str)
            if not value then return nil end
            local a = (value >> 24) & 0xFF
            local r = (value >> 16) & 0xFF
            local g = (value >> 8) & 0xFF
            local b = value & 0xFF
            return Color { red = clamp(r), green = clamp(g), blue = clamp(b), alpha = a }
        end
    end

    local function pasteFromClipboard()
        local formatType = indexOf(colorFormats, plugin.preferences.color_format)
        local text = readFromClipboard()
        if not text then return end

        local match = (formatType == 3 or formatType == 4) and "[^\r\n ,-]+" or "[^\r\n]+"
        local lines = {}
        for line in text:gmatch(match) do
            table.insert(lines, line)
        end

        local colors = {}
        for _, line in ipairs(lines) do
            local clean = line:match("^%s*(.-)%s*$")
            local col = parseColorString(clean, formatType)
            if col then table.insert(colors, col) end
        end

        if #colors == 0 then return end

        local palette = app.sprite.palettes[1]

        app.transaction("Paste Colors", function()
            if #app.range.colors > 0 then
                local startIndex = app.range.colors[1]

                -- Expand palette if needed
                local neededSize = startIndex + #colors
                if neededSize > #palette then
                    palette:resize(neededSize)
                end

                for i, col in ipairs(colors) do
                    local idx = startIndex + (i - 1)
                    palette:setColor(idx, col)
                end
            else
                -- No selection: update only foreground color
                app.fgColor = colors[1]
            end
        end)
    end



    -- plugin:newMenuSeparator {
    --     group = "palette_generation"
    -- }

    local dlg = Dialog("CopyPal")

    plugin:newMenuGroup {
        id = "copypal",
        title = "Copypal",
        group = "palette_generation"
    }

    plugin:newCommand {
        id = "copypal_options",
        title = "Options...",
        group = "copypal",
        onclick = function()
            dlg:show {
                wait = false,
                autoscrollbars = false,
            }
        end
    }

    plugin:newCommand {
        id = "copypal_copy",
        title = "Copy Colors",
        group = "copypal",
        onclick = function()
            copyToClipboard(generateColorText(indexOf(colorFormats, plugin.preferences.color_format)))
        end
    }

    plugin:newCommand {
        id = "copypal_paste",
        title = "Paste Colors",
        group = "copypal",
        onclick = pasteFromClipboard
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
            dlg:modify {
                id = "copypal_bgr555_big_endian",
                visible = data.color_format == colorFormats[4],
            }
            dlg:modify {
                id = "copypal_bgr555_little_endian",
                visible = data.color_format == colorFormats[4],
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

    dlg:radio {
        id = "copypal_bgr555_little_endian",
        text = "Little Endian",
        selected = plugin.preferences.bgr555_endian == "Little Endian",
        visible = plugin.preferences.color_format == colorFormats[4],
        onclick = function()
            plugin.preferences.bgr555_endian = "Little Endian"
        end
    }

    dlg:radio {
        id = "copypal_bgr555_big_endian",
        text = "Big Endian",
        selected = plugin.preferences.bgr555_endian == "Big Endian",
        visible = plugin.preferences.color_format == colorFormats[4],
        onclick = function()
            plugin.preferences.bgr555_endian = "Big Endian"
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
            copyToClipboard(generateColorText(indexOf(colorFormats, plugin.preferences.color_format)))
        end
    }

    dlg:button {
        text = "Paste",
        onclick = pasteFromClipboard
    }

    dlg:button {
        text = "Close",
        onclick = function()
            dlg:close()
        end
    }
end
