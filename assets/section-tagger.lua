-- assets/section-tagger.lua
-- 1) In ANNEXES, wrap the “modèle de page titre” lines in <div class="title-mock">.
-- 2) In 2.4.2 “Bibliographie”, tag only true reference paragraphs as <div class="ref-entry">…</div>.

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
  return norm(txt):match("bibliographie")
end

-- Heuristic: does a paragraph "look like" a bibliographic reference?
-- Signals we use (any one is enough):
--   A) runs of ASCII caps before a comma early (e.g., "POLLARD, Richard …")
--   B) presence of emphasized (italic) text (the title) AND a comma early
-- We also exclude typical explanatory starters ("si ", "voir ", "de plus", etc.)
local function is_reference_para(para)
  if not para or not para.t then return false end

  local raw = pandoc.utils.stringify(para) or ""
  local raw_trim = raw:match("^%s*(.-)%s*$")

  -- Exclude obvious non-reference intros
  local lead = norm(raw_trim):sub(1, 8)
  if lead:match("^si ") or lead:match("^voir ") or lead:match("^de plus") or lead:match("^nota") then
    return false
  end

  -- Early comma?
  local first_comma = raw:find(",")
  local early_comma = first_comma and first_comma <= 80

  -- Caps run before comma (ASCII, good enough for most surnames)
  local before = first_comma and raw:sub(1, first_comma - 1) or ""
  local caps_run = before:match("%u%u+") ~= nil -- e.g., GAGNON, POLLARD

  -- Has emphasized (italic) inlines (book/article titles)
  local has_emph = false
  if para.t == "Para" or para.t == "Plain" then
    for _, inl in ipairs(para.content or {}) do
      if inl.t == "Emph" then
        has_emph = true
        break
      end
    end
  end

  if early_comma and (caps_run or has_emph) then
    -- Also avoid very short lines like "Voir la section Livres"
    if #raw_trim >= 40 then
      return true
    end
  end
  return false
end

function Pandoc(doc)
  local src, out = doc.blocks, {}
  local i = 1
  local in_annexes = false
  local in_biblio  = false
  local biblio_lvl = nil

  while i <= #src do
    local b = src[i]

    if b.t == "Header" then
      local txt = pandoc.utils.stringify(b.content)
      local n   = norm(txt)

      if n == "annexes" then in_annexes = true end
      if is_biblio_heading(txt) then
        in_biblio  = true
        biblio_lvl = b.level
      elseif in_biblio and b.level <= biblio_lvl then
        in_biblio  = false
        biblio_lvl = nil
      end

      table.insert(out, b)
      i = i + 1

    elseif in_annexes and (b.t == "Para" or b.t == "Plain") then
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
          if count > 30 then break end
          j = j + 1
        end
        table.insert(out, pandoc.Div(collected, pandoc.Attr("", {"title-mock"})))
        i = j
      else
        table.insert(out, b); i = i + 1
      end

    elseif in_biblio and (b.t == "Para" or b.t == "Plain") then
      if is_reference_para(b) then
        table.insert(out, pandoc.Div({ b }, pandoc.Attr("", {"ref-entry"})))
      else
        table.insert(out, b)
      end
      i = i + 1

    else
      table.insert(out, b); i = i + 1
    end
  end

  doc.blocks = out
  return doc
end
