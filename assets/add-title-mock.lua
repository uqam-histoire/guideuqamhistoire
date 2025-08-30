-- assets/add-title-mock.lua
-- Tag the Annex section whose heading matches “Modèle de page titre”
-- (accept both “Modèle de page titre” and “Modèle de page de titre”,
-- with or without accents) by adding the class "title-mock".
-- Requires pandoc run with --section-divs so sections are wrapped in <section> (Div) blocks.

local function matches_title_mock(s)
  if not s then return false end
  -- normalize to lowercase and treat é as e for matching
  s = s:lower():gsub("é", "e")
  return s:match("modele de page titre") or s:match("modele de page de titre")
end

function Div(el)
  -- Only consider section divs produced by --section-divs
  if not el.classes or not el.classes:includes("section") then
    return nil
  end

  -- Common case: the first child is a Header; read its text
  if #el.content > 0 and el.content[1].t == "Header" then
    local heading_text = pandoc.utils.stringify(el.content[1].content)
    if matches_title_mock(heading_text) then
      el.classes:insert("title-mock")
      return el
    end
  end

  -- Fallback: sometimes the id of the section reflects the heading
  if el.identifier and matches_title_mock((el.identifier:gsub("%-", " "))) then
    el.classes:insert("title-mock")
    return el
  end

  return nil -- no change
end
