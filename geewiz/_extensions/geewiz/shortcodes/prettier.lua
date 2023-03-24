local function isEmpty(s)
  return s == nil or s == ''
end

local function ensureHtmlDeps()
  quarto.doc.add_html_dependency({
    name = 'binaryben/gcode-prettier',
    version = '0.1.0',
    stylesheets = {'../assets/prettier.css'},
    scripts = {'../assets/prettier.js'}
  })
end

-- Obtain g-code definitions and metadata
local current_path = string.sub(debug.getinfo(1).source, 2, string.len("/prettier.lua") * -1)

local function read_file(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local content = file:read "*a"
  file:close()
  return content
end

local gcode = {}

local rawJson = read_file(current_path .. "../assets/gcode.json")
if rawJson ~= nil then
  gcode = quarto.json.decode(rawJson)
else
  quarto.log.error("G-Code data file not found")
end

-- Pretty gcode should have leading 0's and be uppercase
-- Write your raw gcode however you like of course!
local function normaliseWord(raw)
  local result = raw:upper()
  local address = result:sub(1,1)

  if result:len() == 2 and result:find('[GMT]%d') ~= nil then
    result = result:sub(1,1) .. "0" .. result:sub(2,2)
  end

  -- TODO: Add 0 before decimal numbers (account for negative numbers)

  -- Watch out for comments
  if address == '(' or address == ';' then
    result = raw
  end

  return result
end

local function getMetadata(raw, machine)
  local word = normaliseWord(raw)
  local address = word:sub(1,1)
  local type = (address == 'G' or address == 'M') and 'command' or 'address'
  local result = {
    raw = raw,
    word = word,
    type = type,
    description = 'Unrecognised ' .. type,
    class = {},
    machine = { -- currently unused
      mill = machine == 'mill',
      lathe = machine == 'lathe',
      print = machine == 'print',
      plasma = machine == 'plasma',
      laser = machine == 'laser'
    },
    comment = 'Not all ' .. (type == 'command' and 'commands' or 'addresses') .. ' are as universal as the ones highlighted elsewhere. This ' .. type .. ' may be valid for the machine you are using but you should check your controllers manual for more information.'
  }

  local meta = gcode[type][type == 'command' and word or address]

  -- Return the above defaults if we get nothing
  if meta == nil then return result end

  -- Grab the inherited data instead if needed
  if meta['inherit'] ~= nil then meta = gcode[type][meta['inherit']] end

  -- TODO: Let alternative options be used for different machine types
  result['description'] = meta['description']
  result['class'] = meta['class']
  result['comment'] = meta['comment']

  -- Be mindful of comments
  result['type'] = ((address == ';' or address == '(') or (word == 'MSG')) and 'note' or type

  return result
end

local function generateWord(meta)
  local classes = "gcode-word"
  local data = "data-gcode-raw='" .. meta['raw'] .. "'"

  -- Generate tooltip data
  data =
    meta['description'] and
    (data .. " data-gcode-description='" .. meta['description'] .."'") or
    data
  data =
    meta['comment'] and
    (data .. " data-gcode-comment='" .. meta['comment'] .."'") or
    data

  -- Generate classes for styling command types
  if meta['class'] then
    for _, class in ipairs(meta['class']) do
      classes = classes .. " is-" .. class
    end
  end
  if meta['type'] == 'command' then classes = classes .. " is-command" end

  -- Don't close the span if it's the start of a comment
  if (meta['type'] == 'note') then
    return pandoc.utils.stringify("<span " .. data .. " class='" .. classes .. "'>" .. meta['raw'])
  else
    return pandoc.utils.stringify("<span " .. data .. " class='" .. classes .. "'>" .. meta['word'] .. "</span>")
  end
end

return {
  ['gcode'] = function(args, kwargs, meta)
    ensureHtmlDeps()

    local note = pandoc.utils.stringify(kwargs["note"])
    local line = pandoc.utils.stringify(kwargs["line"])

    local output = ""

    if (not isEmpty(line)) then
      output = "<div class='sourceCode'><pre class='sourceCode numberSource default number-lines code-with-copy'>"
    end

    -- generate word list
    local command = pandoc.utils.stringify(kwargs["command"])
    words = {}
    for word in string.gmatch(command, '([^, *]+)') do
      words[#words+1] = word
    end

    -- account for continuing comment blocks
    local annotationMode = false
    for k, word in pairs(words) do
      local meta = getMetadata(word)
      if (annotationMode) then
        output = output .. " " .. meta['raw']
        if (meta['raw']:sub(-1,-1) == ')') then
          output = output .. "</span>"
          annotationMode = false
        end
      elseif (meta['type'] == 'note') then
        output = output .. generateWord(meta)
        if (word:sub(-1,-1) == ')') then
          output = output .. "</span>"
        else
          annotationMode = true
        end
      else
        output = output .. generateWord(meta)
      end
    end

    -- Close the tag if at end of word list and still in comment
    if (annotationMode) then output = output .. "</span>" end


    if (not isEmpty(line)) then
      output = output .. "</pre></div>"
    end

    return pandoc.RawInline(
      'html',
      output
    )
  end
}
