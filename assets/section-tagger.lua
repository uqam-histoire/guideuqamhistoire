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
-- Heuristic: return true only for paragraphs that look like references
-- Heuristic: return true for paragraphs that look like bibliography entries
-- Heuristic: identify real bibliography entries, avoid explanatory lines
local function has_year(text)
  -- 1500–2099 (word boundaries so we don't match page numbers)
  return text:match("%f[%d]1[5-9]%d%d%f[%D]") or text:match("%f[%d]20%d%d%f[%D]")
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
  local before = up:sub(1, first_comma - 1)            -- e.g., "POLLARD" or "PRDH"
  -- allow letters (incl. diacritics), spaces, hyphen, apostrophe, dot
  return before:match("^[%uÀ-ÖØ-Þ%s%-%.'']+$") ~= nil and #before:gsub("%s+", "") >= 2
end

local function has_quoted_title(text)
  return text:find("«") or text:find("»") or text:find("“") or text:find("”") or text:find("\"")
end

local function is_reference_para(para)
  if not para or not para.t then return false end
  local raw  = pandoc.utils.stringify(para) or ""
  local text = (raw:gsub("%s+", " "):match("^%s*(.-)%s*$") or "")
  local ntext = norm(text)

  -- Obvious non-reference openers (expandable)
  local starters = {
    "^si ", "^voir ", "^de plus", "^par exemple", "^nota", "^remarque",
    "^attention", "^on ", "^pour ", "^dans le cas", "^lorsqu", "^lorsque "
  }
  for _, pat in ipairs(starters) do
    if ntext:match(pat) then return false end
  end

  -- Must have an early comma (author/acronym, then comma)
  local first_comma = text:find(",")
  if not first_comma or first_comma > 80 then return false end

  -- Must have a year or a DOI/URL somewhere (exclude plain explanations)
  local has_dateish = has_year(text) or has_ext_link(para)
  if not has_dateish then return false end

  -- Require one strong "title/author" signal
  local strong_signal =
      starts_with_caps_name(text, first_comma) or  -- SURNAME/ACRONYM before comma
      has_emph(para) or                            -- italicised title
      has_quoted_title(text)                       -- quoted title
  if not strong_signal then return false end

  -- Avoid very short fragments
  if #text < 40 then return false end

  return true
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
