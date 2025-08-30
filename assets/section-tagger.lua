-- assets/section-tagger.lua
-- Wraps two regions for easier CSS styling:
--   1) In the "Annexes" part, the consecutive lines of the "Modèle de page titre"
--      (detected by the first line "Université du Québec à Montréal") are wrapped
--      in <div class="title-mock">.
--   2) Any section whose heading looks like "Références bibliographiques" or
--      "Exemples de références ..." is wrapped in <div class="biblio-samples">.

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

local function is_biblio_heading(txt)
  txt = norm(txt)
  return txt:match("references bibliographiques")
      or (txt:match("biblio") and (txt:match("exemple") or txt:match("modele")))
      or (txt:match("references") and txt:match("exemple"))
end

function Pandoc(doc)
  local src, out = doc.blocks, {}
  local i, in_annexes = 1, false

  while i <= #src do
    local b = src[i]

    if b.t == "Header" then
      local txt = pandoc.utils.stringify(b.content)
      -- Track when we enter the Annexes section
      in_annexes = in_annexes or norm(txt):match("^annexes$")
      table.insert(out, b)

      -- Wrap bibliography examples section
      if is_biblio_heading(txt) then
        local lvl, j, collected = b.level, i + 1, {}
        while j <= #src do
          local nb = src[j]
          if nb.t == "Header" and nb.level <= lvl then break end
          table.insert(collected, nb)
          j = j + 1
        end
        table.insert(out, pandoc.Div(collected, pandoc.Attr("", {"biblio-samples"})))
        i = j
      else
        i = i + 1
      end

    elseif in_annexes and (b.t == "Para" or b.t == "Plain") then
      -- Look for the *annex* title-page start line
      local first = norm(pandoc.utils.stringify(b))
      if first:match("universite du quebec a montreal") then
        local j, collected, count = i + 1, { b }, 1
        while j <= #src do
          local nb, kind = src[j], src[j].t
          if kind == "Header" then break end
          local ntext = norm(pandoc.utils.stringify(nb))
          -- stop before the next annex item such as "Modèle de table ..."
          if ntext:match("modele de table") or ntext:match("exemple de texte") then break end
          table.insert(collected, nb)
          count = count + 1
          if count > 30 then break end -- safety guard
          j = j + 1
        end
        table.insert(out, pandoc.Div(collected, pandoc.Attr("", {"title-mock"})))
        i = j
      else
        table.insert(out, b); i = i + 1
      end

    else
      table.insert(out, b); i = i + 1
    end
  end

  doc.blocks = out
  return doc
end
