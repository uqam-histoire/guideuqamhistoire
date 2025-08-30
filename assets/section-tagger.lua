-- assets/section-tagger.lua
-- 1) Tag the Annexes "Modèle de page titre" block as <div class="title-mock">.
-- 2) Wrap bibliography example sections as <div class="biblio-samples">.
-- 3) Normalize any block styled with the Word paragraph style “Référence”
--    so it also has class "ref-entry-block" (for hanging indents).

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

local function has_class_norm(classes, needle)
  if not classes then return false end
  local n = norm(needle)
  for _,c in ipairs(classes) do
    if norm(c) == n then return true end
  end
  return false
end

local function is_biblio_heading(txt)
  txt = norm(txt)
  -- We want precisely the section "Bibliographie" (2.4.2), not "Références bibliographiques"
  -- "bibliographie" does NOT occur inside "bibliographiques", so this is safe.
  return txt:match("bibliographie")
end

-- (A) Normalize custom style "Référence" on any Div wrapper produced by Pandoc
function Div(el)
  if has_class_norm(el.classes, "Référence") then
    table.insert(el.classes, "ref-entry-block")
    return el
  end
  return nil
end

-- (B) Main walker: title-mock and bibliography-samples
function Pandoc(doc)
  local src, out = doc.blocks, {}
  local i, in_annexes = 1, false

  while i <= #src do
    local b = src[i]

    if b.t == "Header" then
      local txt = pandoc.utils.stringify(b.content)
      in_annexes = in_annexes or norm(txt):match("^annexes$")
      table.insert(out, b)

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
      local first = norm(pandoc.utils.stringify(b))
      if first:match("universite du quebec a montreal") then
        local j, collected, count = i + 1, { b }, 1
        while j <= #src do
          local nb, kind = src[j], src[j].t
          if kind == "Header" then break end
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

    else
      table.insert(out, b); i = i + 1
    end
  end

  doc.blocks = out
  return doc
end
