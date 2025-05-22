--[[
Export By Group (Recursive) - final edition
Author: Feel (https://www.instagram.com/feel.pixels/) & ChatGPT
License: CC BY-NC-SA 4.0
You are free to use, share and modify this script for non-commercial purposes.
Commercial use and resale are strictly prohibited.
]]

local spr = app.activeSprite
if not spr then return app.alert("No active sprite") end
if spr.filename == "" then return app.alert("Please save your .aseprite file first") end

-- ✏️ Replace with your own export folder path
local exportRoot = "C:/Path/To/Your/Export/Folder/"
if exportRoot:find("C:/Path/To/Your/Export/Folder/") then
  return app.alert("⚠️ Please set your own export path in the script line14 (variable 'local exportRoot =')")
end

-- Ensure folder exists only once (cache to avoid multiple mkdir calls)
local function ensureDir(path, cache)
  if cache[path] then return end
  local sep = package.config:sub(1,1)
  if sep == "\\" then
    os.execute('if not exist "' .. path .. '" mkdir "' .. path .. '"')
  else
    os.execute('mkdir -p "' .. path .. '"')
  end
  cache[path] = true
end

-- Setup log file
local logPath = exportRoot .. "Export-Logs/"
local createdPaths = {}
ensureDir(logPath, createdPaths)
local logFile = io.open(logPath .. "export-log.txt", "a")
if not logFile then return app.alert("Cannot write export log") end

local date = os.date("[%Y-%m-%d %H:%M]")
logFile:write(date .. "\nExport from: " .. (spr.filename or "(unsaved)") .. "\n\n")

local exportCount, skippedCount = 0, 0

-- Check if a layer is a group
local function isGroup(layer)
  local ok, children = pcall(function() return layer.layers end)
  return ok and children ~= nil
end

-- Detect non-transparent area bounds
local function getTrimBounds(image)
  local r = image.bounds
  local left, top, right, bottom = r.x + r.width, r.y + r.height, r.x, r.y
  local found = false
  for y = r.y, r.y + r.height - 1 do
    for x = r.x, r.x + r.width - 1 do
      if image:getPixel(x, y) >> 24 > 0 then
        if x < left then left = x end
        if y < top then top = y end
        if x > right then right = x end
        if y > bottom then bottom = y end
        found = true
      end
    end
  end
  if not found then return nil end
  return {x=left, y=top, w=right-left+1, h=bottom-top+1}
end

-- Recursively collect visible, non-# image layers from a group
local function collectImageLayers(group, layers)
  for _, layer in ipairs(group.layers) do
    if isGroup(layer) then
      if layer.isVisible and not layer.name:find("#") then
        collectImageLayers(layer, layers)
      end
    elseif layer.isImage and layer.isVisible and not layer.name:find("#") then
      table.insert(layers, layer)
    end
  end
end

-- Merge a @group and export it as a single trimmed image
local function exportGroupImage(group, groupName, folderPath)
  logFile:write("\n→ Merging group: " .. group.name .. "\n")
  local tempImage = Image(spr.width, spr.height, spr.colorMode)
  local layersToDraw = {}
  collectImageLayers(group, layersToDraw)
  for _, layer in ipairs(layersToDraw) do
    for _, cel in ipairs(layer.cels) do
      tempImage:drawImage(cel.image, cel.position)
    end
  end
  local bounds = getTrimBounds(tempImage)
  if not bounds then
    logFile:write("→ Skipped: group is fully transparent\n")
    skippedCount = skippedCount + 1
    return
  end
  local trimmed = Image(bounds.w, bounds.h, spr.colorMode)
  trimmed:drawImage(tempImage, Point(-bounds.x, -bounds.y))
  local newSprite = Sprite(bounds.w, bounds.h)
  newSprite.filename = groupName
  newSprite:newCel(newSprite.layers[1], 1, trimmed, Point(0,0))
  local filename = folderPath .. groupName .. ".png"
  newSprite:saveCopyAs(filename)
  newSprite:close()
  logFile:write(string.format("→ Exported: %s (trimmed %dx%d)\n", filename, bounds.w, bounds.h))
  exportCount = exportCount + 1
end

-- Export individual layer as trimmed PNG
local function exportLayer(layer, groupName, folderPath)
  logFile:write("Checking layer: " .. (layer.name or "(unnamed)") .. "\n")
  if not layer.isVisible then
    logFile:write("→ Skipped: not visible\n")
    skippedCount = skippedCount + 1
    return
  end
  if layer.name:find("#") then
    logFile:write("→ Skipped: contains '#'\n")
    skippedCount = skippedCount + 1
    return
  end
  for _, cel in ipairs(layer.cels) do
    local image = cel.image
    local bounds = getTrimBounds(image)
    if not bounds then
      logFile:write("→ Skipped: fully transparent\n")
      skippedCount = skippedCount + 1
      return
    end
    ensureDir(folderPath, createdPaths)
    local trimmed = Image(bounds.w, bounds.h, image.colorMode)
    trimmed:drawImage(image, Point(-bounds.x, -bounds.y))
    local newSprite = Sprite(bounds.w, bounds.h)
    newSprite.filename = layer.name
    newSprite:newCel(newSprite.layers[1], cel.frameNumber, trimmed, Point(0, 0))
    local filename = folderPath .. layer.name .. ".png"
    newSprite:saveCopyAs(filename)
    newSprite:close()
    logFile:write(string.format("→ Exported: %s (trimmed %dx%d)\n", filename, bounds.w, bounds.h))
    exportCount = exportCount + 1
    return
  end
  logFile:write("→ Skipped: no cels found\n")
  skippedCount = skippedCount + 1
end

-- Recursive walker through layers and groups
local function walk(container, parentGroup, ignored)
  for _, layer in ipairs(container.layers) do
    local name = layer.name or "(unnamed)"
    local isIgnored = ignored or name:find("#")
    if isIgnored then
      logFile:write("→ Skipped (inherited or contains '#'): " .. name .. "\n")
      skippedCount = skippedCount + 1
    elseif not layer.isVisible then
      logFile:write("→ Skipped (not visible): " .. name .. "\n")
      skippedCount = skippedCount + 1
    elseif isGroup(layer) then
      if name:sub(1,1) == "@" then
        local cleanName = name:sub(2)
        local folderPath = exportRoot .. (parentGroup or "") .. "/"
        ensureDir(folderPath, createdPaths)
        exportGroupImage(layer, cleanName, folderPath)
      else
        logFile:write("→ Entering group: " .. name .. "\n")
        walk(layer, parentGroup or name, false)
      end
    elseif layer.isImage then
      local folderPath = exportRoot .. (parentGroup or "") .. "/"
      exportLayer(layer, parentGroup, folderPath)
    else
      logFile:write("→ Skipped (unknown type): " .. name .. "\n")
      skippedCount = skippedCount + 1
    end
  end
end

walk(spr, nil, false)

logFile:write("\nTotal exported : " .. exportCount .. " layer(s)\n")
logFile:write("Total skipped  : " .. skippedCount .. " layer(s)\n")
logFile:write("------------\n\n")
logFile:close()

app.alert("Export complete: " .. exportCount .. " exported, " .. skippedCount .. " skipped.")
