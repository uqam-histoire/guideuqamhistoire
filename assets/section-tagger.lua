-- assets/section-tagger.lua
-- 1) Wrap the "mock title page" (from “Université du Québec à Montréal”
--    down to before “Table des matières”) in <div class="title-mock">.
-- 2) (Optional hook) If you later mark bibliography sample lines in Word
--    with a paragraph style named “Bibliographie”, Pandoc will emit
--    <p class="Bibliographie"> and the CSS below will give them a hanging indent.

local function norm(s)
  if not s then return "" end
  s = s:lower()
  s = s:gsub("é","e"):gsub("è","e"):gsub("ê","e"):gsub("ë","e")
  s = s:gsub("à","a"):gsub("â","a")
  s = s:gsub("î","i"):gsub("ï","i")
  s = s:gsub("ô","o"):gsub("ö","o")
  s = s:gsub("ù","u"):gsub("û","u"):gsub("ü","u")
  return s
end

function Pandoc(doc)
  local src = doc.blocks
  local out = {}
  local i = 1
  while i <= #src do
    local b = src[i]

    -- Detect the first line of the mock title page as a plain paragraph.
    if b.t == "Para" or b.t == "Plain" then
      local txt = norm(pandoc.utils.stringify(b))
      if txt:match("universite du quebec a montreal") then
        -- collect until we hit the start of the table of contents card
        local collected = { b }
        local j = i + 1
        while j <= #src do
          local nb = src[j]
          local kind = nb.t
          local ntext = norm(pandoc.utils.stringify(nb))

          -- Stop before “Table des matières” line or a blockquote ToC,
          -- or at the next real section header.
          if (kind == "Para" or kind == "Plain") and ntext:match("table des matieres") then
            break
          end
          if kind == "BlockQuote" or kind == "Header" then
            break
          end

          table.insert(collected, nb)
          j = j + 1
        end

        table.insert(out, pandoc.Div(collected, pandoc.Attr("", {"title-mock"})))
        i = j -- continue after what we wrapped
      else
        table.insert(out, b)
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
