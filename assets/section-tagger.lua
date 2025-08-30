-- assets/section-tagger.lua
-- What it does:
--  1) In ANNEXES, wrap the “modèle de page titre” lines in <div class="title-mock">.
--  2) In 2.4.2 “Bibliographie”, tag actual reference paragraphs as <div class="ref-entry"><p>…</p></div>
--     so CSS can give them hanging indents, regardless of missing Word style classes.

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

-- Heuristic: recognize the 2.4.2 Bibliographie heading text
local function is_biblio_heading(txt) return norm(txt):match("^bibliographie$") end

function Pandoc(doc)
  local src, out = doc.blocks, {}
  local i = 1
  local in_annexes = false
  local in_biblio  = false
  local biblio_lvl = nil
  local sub_lvl    = nil
  local seen_first_para = false
  local after_list = false

  while i <= #src do
    local b = src[i]

    if b.t == "Header" then
      local txt = pandoc.utils.stringify(b.content)
      local n   = norm(txt)

      -- Track “Annexes”
      if n == "annexes" then in_annexes = true end

      -- Enter/leave 2.4.2 Bibliographie
      if is_biblio_heading(txt) then
        in_biblio  = true
        biblio_lvl = b.level
        sub_lvl, seen_first_para, after_list = nil, false, false
      elseif in_biblio and b.level <= biblio_lvl then
        in_biblio  = false
        biblio_lvl = nil
      end

      -- Starting a new subsection inside Bibliographie?
      if in_biblio and b.level > biblio_lvl then
        sub_lvl = b.level
        seen_first_para, after_list = false, false
      end

      table.insert(out, b)
      i = i + 1

    elseif in_annexes and (b.t == "Para" or b.t == "Plain") then
      -- Find the annex title-page mock: it begins with “Université du Québec à Montréal”
      local first = norm(pandoc.utils.stringify(b))
      if first:match("universite du quebec a montreal") then
        local j, collected, count = i + 1, { b }, 1
        while j <= #src do
          local nb = src[j]
          if nb.t == "Header" then break end
          local ntext = norm(pandoc.utils.stringify(nb))
          if ntext:match("modele de table") or ntext:match("exemple de texte") then break end
          table.insert(collected, nb)
          count = count + 1
          if count > 30 then break end -- safety
          j = j + 1
        end
        table.insert(out, pandoc.Div(collected, pandoc.Attr("", {"title-mock"})))
        i = j
      else
        table.insert(out, b); i = i + 1
      end

    elseif in_biblio then
      -- Inside Bibliographie: tag reference paragraphs structurally
      if b.t == "BulletList" or b.t == "OrderedList" then
        table.insert(out, b)
        after_list = true
        i = i + 1

      elseif b.t == "Para" or b.t == "Plain" then
        local wrap = false
        if after_list then
          -- First paragraph after a list is a reference entry
          wrap = true
          after_list = false
          seen_first_para = true
        elseif not seen_first_para then
          -- First explanatory paragraph in a subsection: do not wrap
          wrap = false
          seen_first_para = true
        else
          -- Subsequent paragraphs: wrap as references
          wrap = true
        end

        if wrap then
          table.insert(out, pandoc.Div({ b }, pandoc.Attr("", {"ref-entry"})))
        else
          table.insert(out, b)
        end
        i = i + 1

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
