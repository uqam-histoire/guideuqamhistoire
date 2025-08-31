-- Tagging for: Annex title mock, Bibliographie ref entries, and
-- special handling for "Documents d’archives manuscrits" listings.

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

local function is_biblio_heading(txt) return norm(txt):match("bibliographie") end

-- Robust reference detector used in most 2.4.2 subsections
-- Heuristic: identify real bibliography entries, avoid explanatory lines
local function has_year_or_century(text)
  -- 1500–2099 (standalone) or ranges like 1999–… / 2022-…
  if text:match("%f[%d]1[5-9]%d%d%f[%D]") or text:match("%f[%d]20%d%d%f[%D]") then
    return true
  end
  if text:match("1[5-9]%d%d[%-%–]") or text:match("20%d%d[%-%–]") then
    return true
  end
  -- French century mentions: Xe siècle / XVIIe siècle / XVIIe s.
  if text:match("[%uXIVLCDM]+%s*[%^]?[eE]?%s*si[èe]cle") or text:match("[%uXIVLCDM]+e?%s*s%.") then
    return true
  end
  return false
end

local function has_ext_link(para)
  if para.t ~= "Para" and para.t ~= "Plain" then return false end
  for _, inl in ipairs(para.content or {}) do
    if inl.t == "Link" then
      local tgt = inl.target and inl.target[1] or ""
      if tgt:match("^https?://") or tgt:match("^doi%.org") or tgt:match("^dx%.doi%.org") then
        return true
      end
    end
  end
  return false
end

local function has_emph(para)
  if para.t ~= "Para" and para.t ~= "Plain" then return false end
  for _, inl in ipairs(para.content or {}) do
    if inl.t == "Emph" then return true end
  end
  return false
end

local function starts_with_caps_name(text, first_comma)
  if not first_comma then return false end
  local up = text:upper()
  local before = up:sub(1, first_comma - 1)
  return before:match("^[%uÀ-ÖØ-Þ%s%-%.'']+$") ~= nil and #before:gsub("%s+","") >= 2
end

local function has_quoted_title(text)
  return text:find("«") or text:find("»") or text:find("“") or text:find("”") or text:find('"')
end

local function is_reference_para(para)
  if not para or not para.t then return false end
  local raw  = pandoc.utils.stringify(para) or ""
  local text = (raw:gsub("%s+", " "):match("^%s*(.-)%s*$") or "")
  local ntext = norm(text)

  -- Exclude obvious non-reference openers
  local starters = {
    "^si ", "^voir ", "^de plus", "^par exemple", "^nota", "^remarque",
    "^attention", "^on ", "^pour ", "^dans le cas", "^lorsqu", "^lorsque ",
    "^nom du", "^nom des", "^auteur", "^autrice"
  }
  for _, pat in ipairs(starters) do
    if ntext:match(pat) then return false end
  end

  -- Must have an early comma (author/org then comma)
  local first_comma = text:find(",")
  if not first_comma or first_comma > 120 then return false end

  -- Must also show some "dateish" proof (year/range/century OR URL/DOI)
  local dateish = has_year_or_century(text) or has_ext_link(para)
  if not dateish then return false end

  -- And one strong title/author signal
  local strong = starts_with_caps_name(text, first_comma) or has_emph(para) or has_quoted_title(text)
  if not strong then return false end

  return #text >= 40
end

function Pandoc(doc)
  local src, out = doc.blocks, {}
  local i = 1

  local in_annexes = false

  local in_biblio  = false
  local biblio_lvl = nil

  -- Special: within "Documents d’archives manuscrits"
  local in_archives_docs = false
  local archives_lvl = nil
  local archives_mode = nil -- "loc" | "name" | nil

  while i <= #src do
    local b = src[i]

    if b.t == "Header" then
      local txt = pandoc.utils.stringify(b.content)
      local n   = norm(txt)

      -- enter/exit Annexes
      if n == "annexes" then in_annexes = true end

      -- enter/exit 2.4.2 Bibliographie
      if is_biblio_heading(txt) then
        in_biblio  = true
        biblio_lvl = b.level
      elseif in_biblio and b.level <= biblio_lvl then
        in_biblio, biblio_lvl = false, nil
      end

      -- enter/exit Documents d’archives manuscrits (within Bibliographie)
      if in_biblio and n:match("^2?%.?4%.?2%.?15") or (in_biblio and n:match("documents d archives manuscrits")) then
        in_archives_docs, archives_lvl, archives_mode = true, b.level, nil
      elseif in_archives_docs and b.level <= archives_lvl then
        in_archives_docs, archives_lvl, archives_mode = false, nil, nil
      end

      table.insert(out, b)
      i = i + 1

    elseif in_annexes and (b.t == "Para" or b.t == "Plain") then
      -- Annexes: title page mock
      local first = norm(pandoc.utils.stringify(b))
      if first:match("universite du quebec a montreal") then
        local j, collected, count = i + 1, { b }, 1
        while j <= #src do
          local nb = src[j]; if nb.t == "Header" then break end
          local ntext = norm(pandoc.utils.stringify(nb))
          if ntext:match("modele de table") or ntext:match("exemple de texte") then break end
          table.insert(collected, nb); count = count + 1; if count > 30 then break end
          j = j + 1
        end
        table.insert(out, pandoc.Div(collected, pandoc.Attr("", {"title-mock"})))
        i = j
      else
        table.insert(out, b); i = i + 1
      end

    elseif in_biblio then
      -- Special handling for the archives listings
      if in_archives_docs and (b.t == "Para" or b.t == "Plain") then
        local t = norm(pandoc.utils.stringify(b))
        if t:match("^classement par lieu de conservation$") then
          archives_mode = "loc"
          table.insert(out, b); i = i + 1
        elseif t:match("^classement par nom d auteur") or t:match("^classement par nom d'auteur") or t:match("^classement par nom d auteur / autrice") then
          archives_mode = "name"
          table.insert(out, b); i = i + 1
        else
          if archives_mode then
            -- Every following paragraph is a reference entry until mode changes or section ends
            table.insert(out, pandoc.Div({ b }, pandoc.Attr("", {"ref-entry"})))
          else
            -- outside the two "Classement ..." blocks, fall back to generic detector
            if (b.t == "Para" or b.t == "Plain") and is_reference_para(b) then
              table.insert(out, pandoc.Div({ b }, pandoc.Attr("", {"ref-entry"})))
            else
              table.insert(out, b)
            end
          end
          i = i + 1
        end

      else
        -- Generic Bibliographie tagging elsewhere
        if (b.t == "Para" or b.t == "Plain") and is_reference_para(b) then
          table.insert(out, pandoc.Div({ b }, pandoc.Attr("", {"ref-entry"})))
        else
          table.insert(out, b)
        end
        i = i + 1
      end

    else
      table.insert(out, b); i = i + 1
    end
  end

  doc.blocks = out
  return doc
end
