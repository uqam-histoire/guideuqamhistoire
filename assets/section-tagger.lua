-- assets/section-tagger.lua
-- Wrap the content of selected sections in a <div class="..."> so CSS can target it.

local function norm(s)
  if not s then return "" end
  s = s:lower()
  s = s:gsub("é", "e"):gsub("è", "e"):gsub("ê", "e"):gsub("ë", "e")
  s = s:gsub("à", "a"):gsub("â", "a")
  s = s:gsub("î", "i"):gsub("ï", "i")
  s = s:gsub("ô", "o"):gsub("ö", "o")
  s = s:gsub("ù", "u"):gsub("û", "u"):gsub("ü", "u")
  return s
end

-- returns true if the heading text matches the "title page model" section
local function is_title_mock(txt)
  txt = norm(txt)
  return txt:match("modele de page titre") or txt:match("modele de page de titre")
end

-- returns true if the heading text looks like bibliography example(s)
local function is_biblio_examples(txt)
  txt = norm(txt)
  local has_biblio = txt:match("biblio")
  local has_ref    = txt:match("reference")
  local has_ex     = txt:match("exemple")
  local has_modele = txt:match("modele")
  return (has_biblio and (has_ex or has_modele)) or (has_ref and has_ex)
end

function Pandoc(doc)
  local src = doc.blocks
  local out = {}
  local i = 1
  while i <= #src do
    local b = src[i]
    if b.t == "Header" then
      local lvl = b.level
      local txt = pandoc.utils.stringify(b.content)
      -- Decide whether to wrap the following blocks
      local wrap_class = nil
      if is_title_mock(txt) then
        wrap_class = "title-mock"
      elseif is_biblio_examples(txt) then
        wrap_class = "biblio-samples"
      end

      table.insert(out, b)

      if wrap_class then
        local j = i + 1
        local collected = {}
        while j <= #src do
          local nb = src[j]
          if nb.t == "Header" and nb.level <= lvl then
            break
          end
          table.insert(collected, nb)
          j = j + 1
        end
        -- Wrap collected blocks for this section in a div with our class
        table.insert(out, pandoc.Div(collected, pandoc.Attr("", {wrap_class})))
        i = j
      else
        i = i + 1
      end
    else
      table.insert(out, b)
      i = i + 1
    end
  end
  doc.blocks = out
  return doc
end
