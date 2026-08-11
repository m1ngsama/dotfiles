-- RGB/HSL math adapted from Emmanuel Oga's columns project (CC BY 3.0).
-- Provenance and local modifications: third_party/hsl-color/UPSTREAM.toml

local M = {}

local function normalize_hex(hex)
	if type(hex) ~= "string" then
		return nil
	end

	local digits = hex:match("^#?([%da-fA-F]+)$")
	if not digits or (#digits ~= 3 and #digits ~= 6) then
		return nil
	end

	if #digits == 3 then
		digits = digits:gsub(".", "%0%0")
	end

	return digits:lower()
end

function M.hex_to_rgb(hex)
	local digits = assert(normalize_hex(hex), "expected a 3- or 6-digit hexadecimal color")

	return {
		tonumber(digits:sub(1, 2), 16) / 255,
		tonumber(digits:sub(3, 4), 16) / 255,
		tonumber(digits:sub(5, 6), 16) / 255,
	}
end

--[[
 * Converts an RGB color value to HSL. Conversion formula
 * adapted from http://en.wikipedia.org/wiki/HSL_color_space.
 * Assumes r, g, and b are contained in the set [0, 255] and
 * returns h, s, and l in the set [0, 1].
 *
 * @param   Number  r       The red color value
 * @param   Number  g       The green color value
 * @param   Number  b       The blue color value
 * @return  Array           The HSL representation
]]
function M.rgbToHsl(r, g, b)
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local h = 0
	local s = 0
	local l = 0

	l = (max + min) / 2

	if max == min then
		h, s = 0, 0 -- achromatic
	else
		local d = max - min
		if l > 0.5 then
			s = d / (2 - max - min)
		else
			s = d / (max + min)
		end
		if max == r then
			h = (g - b) / d
			if g < b then
				h = h + 6
			end
		elseif max == g then
			h = (b - r) / d + 2
		elseif max == b then
			h = (r - g) / d + 4
		end
		h = h / 6
	end

	return h * 360, s * 100, l * 100
end

--[[
 * Converts an HSL color value to RGB. Conversion formula
 * adapted from http://en.wikipedia.org/wiki/HSL_color_space.
 * Assumes h, s, and l are contained in the set [0, 1] and
 * returns r, g, and b in the set [0, 255].
 *
 * @param   Number  h       The hue
 * @param   Number  s       The saturation
 * @param   Number  l       The lightness
 * @return  Array           The RGB representation
]]
function M.hslToRgb(h, s, l)
	local r, g, b
	local function hue2rgb(p, q, t)
		if t < 0 then
			t = t + 1
		end
		if t > 1 then
			t = t - 1
		end
		if t < 1 / 6 then
			return p + (q - p) * 6 * t
		end
		if t < 1 / 2 then
			return q
		end
		if t < 2 / 3 then
			return p + (q - p) * (2 / 3 - t) * 6
		end
		return p
	end

	if s == 0 then
		r, g, b = l, l, l -- achromatic
	else
		local q
		if l < 0.5 then
			q = l * (1 + s)
		else
			q = l + s - l * s
		end
		local p = 2 * l - q

		r = hue2rgb(p, q, h + 1 / 3)
		g = hue2rgb(p, q, h)
		b = hue2rgb(p, q, h - 1 / 3)
	end

	return r * 255, g * 255, b * 255
end

function M.hexToHSL(hex)
	local rgb = M.hex_to_rgb(hex)
	local h, s, l = M.rgbToHsl(rgb[1], rgb[2], rgb[3])

	return string.format("hsl(%d, %d, %d)", math.floor(h + 0.5), math.floor(s + 0.5), math.floor(l + 0.5))
end

--[[
 * Converts an HSL color value to RGB in Hex representation.
 * @param   Number  h       The hue
 * @param   Number  s       The saturation
 * @param   Number  l       The lightness
 * @return  String           The hex representation
]]
function M.hslToHex(h, s, l)
	local r, g, b = M.hslToRgb(h / 360, s / 100, l / 100)
	local function byte(value)
		return math.max(0, math.min(255, math.floor(value + 0.5)))
	end

	return string.format("#%02x%02x%02x", byte(r), byte(g), byte(b))
end

function M.replace_hex_colors(line)
	assert(type(line) == "string", "expected a string")

	return (line:gsub("#([%da-fA-F]+)%f[^%w_]", function(digits)
		if #digits ~= 3 and #digits ~= 6 then
			return "#" .. digits
		end
		return M.hexToHSL("#" .. digits)
	end))
end

function M.replaceHexWithHSL()
	-- Get the current line number
	local line_number = vim.api.nvim_win_get_cursor(0)[1]

	-- Get the line content
	local line_content = vim.api.nvim_buf_get_lines(0, line_number - 1, line_number, false)[1]

	line_content = M.replace_hex_colors(line_content)

	-- Set the line content back
	vim.api.nvim_buf_set_lines(0, line_number - 1, line_number, false, { line_content })
end

return M
