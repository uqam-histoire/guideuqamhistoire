-- assets/section-tagger.lua
-- Tags 3 things:
--  1) ANNEXES: wraps the "Modèle de page titre" sample as <div class="title-mock">…</div>
--  2) ANNEXES: wraps the "Modèle de table des matières" sample as <div class="toc-mock">…</div>
--  3) 2.4.2 Bibliographie: tags real reference paragraphs as <div class="ref-entry">…</div>

local function norm(s)
  if not s then return "" end
  s = s:lower()
  s = s:gsub("é","e"):gsub("è","e"):gsub("ê","e"):gsub("ë","e")
  s = s:gsub("à","a"):gsub("â","a")
  s = s:gsub("î","i"):gsub("ï","i")
  s = s:gsub("ô","o"):gsub("ö","o")
  s = s:gsub("ù","u"):gsub("û","u"):gsub("ü","u")
  s = s:gsub("[’']", "'")
  s = s:gsub("%s+", " ")
  return s
end

-- ---------- Bibliographie helpers (unchanged core heuristic) ----------
local function has_yearish(text)
  return text:match("%f[%d]1[5-9]%d%d%f[%D]") or text:match("%f[%d]20%d%d%f[%D]") or
         text:match("1[5-9]%d%d[%-%–]") or text:match("20%d%d[%-%–]") or
         text:match("[%uXIVLCDM]+%s*[%^]?[eE]?%s*si[èe]cle") or text:match("[%uXIVLCDM]+e?%s*s%.")
end
local function has_ext_link(para)
  if para.t ~= "Para" and para.t ~= "Plain" then return false end
  for _, inl in ipairs(para.content or {}) do
    if inl.t == "Link" then
      local tgt = inl.target and inl.target[1] or ""
      if tgt:match("^https?://") or tgt:match("^doi%.org") or tgt:match("^dx%.doi%.org") then return true end
    end
  end
  return false
end
local function has_emph(para)
  if para.t ~= "Para" and para.t ~= "Plain" then return false end
  for _, inl in ipairs(para.content or {}) do if inl.t == "Emph" then return true end end
  return false
end
local function starts_with_caps_name(text, first_comma)
  if not first_comma then return false end
  local up = text:upper(); local before = up:sub(1, first_comma - 1)
  return before:match("^[%uÀ-ÖØ-Þ%s%-%.'']+$") ~= nil and #before:gsub("%s+","") >= 2
end
local function has_quoted_title(text) return text:find("«") or text:find("»") or text:find("“") or text:find("”") or text:find('"') end
local function is_biblio_heading(txt) return norm(txt):match("bibliographie") end

local function is_reference_para(para)
  if not para or not para.t then return false end
  local raw  = pandoc.utils.stringify(para) or ""
  local text = (raw:gsub("%s+", " "):match("^%s*(.-)%s*$") or "")
  local ntext = norm(text)

  local starters = { "^si ", "^voir ", "^de plus", "^par exemple", "^nota", "^remarque",
                     "^attention", "^on ", "^pour ", "^dans le cas", "^lorsqu", "^lorsque ",
                     "^nom du", "^nom des", "^auteur", "^autrice" }
  for _, pat in ipairs(starters) do if ntext:match(pat) then return false end end

  local first_comma = text:find(","); if not first_comma or first_comma > 120 then return false end
  local dateish = has_yearish(text) or has_ext_link(para); if not dateish then return false end
  local strong  = starts_with_caps_name(text, first_comma) or has_emph(para) or has_quoted_title(text)
  if not strong then return false end
  return #text >= 40
end
-- ---------------------------------------------------------------------

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
      if is_biblio_heading(txt) then in_biblio, biblio_lvl = true, b.level
      elseif in_biblio and b.level <= biblio_lvl then in_biblio, biblio_lvl = false, nil end
      table.insert(out, b); i = i + 1

    elseif in_annexes and (b.t == "Para" or b.t == "Plain") then
      local t = norm(pandoc.utils.stringify(b))

      -- (A) Wrap the "Modèle de page titre" sample by detecting its first line
      if t:match("^universite du quebec a montreal") then
        local j, collected, count = i + 1, { b }, 1
        while j <= #src do
          local nb = src[j]
          if nb.t == "Header" then break end
          local ntext = norm(pandoc.utils.stringify(nb))
          if ntext:match("^modele de table des matieres") or ntext:match("^exemple de texte") then break end
          table.insert(collected, nb); count = count + 1; if count > 40 then break end
          j = j + 1
        end
        table.insert(out, pandoc.Div(collected, pandoc.Attr("", {"title-mock"})))
        i = j

      -- (B) Wrap the "Modèle de table des matières" sample by detecting its first visible line
      elseif t:match("^table des matieres$") or t:match("^modele de table des matieres$") then
        local j, collected, count = i, {}, 1
        while j <= #src do
          local nb = src[j]
          if nb.t == "Header" then break end
          local ntext = norm(pandoc.utils.stringify(nb))
          if ntext:match("^exemple de texte") or ntext:match("^universite du quebec a montreal") then break end
          table.insert(collected, nb); count = count + 1; if count > 60 then break end
          j = j + 1
        end
        table.insert(out, pandoc.Div(collected, pandoc.Attr("", {"toc-mock"})))
        i = j

      -- (C) Wrap the "Exemple de texte avec appels de notes et citations"
      --     sample by detecting its first visible line
      elseif t:match("^exemple de texte") or t:match("^exemple de texte avec appels de notes") then
        local j, collected, count = i, {}, 1
        while j <= #src do
          local nb = src[j]
          if nb.t == "Header" then break end
          local ntext = norm(pandoc.utils.stringify(nb))
          -- stop if we hit the start of another annex sample
          if ntext:match("^modele de table des matieres")
            or ntext:match("^universite du quebec a montreal") then break end
          table.insert(collected, nb)
          count = count + 1; if count > 80 then break end
          j = j + 1
        end
        table.insert(out, pandoc.Div(collected, pandoc.Attr("", {"notes-mock"})))
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
