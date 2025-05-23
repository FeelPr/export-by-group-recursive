app.transaction(function()
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

-- 🔍 Find all layers whose name starts with "%"
local exportRoot = nil
local percentLayers = {}

for _, layer in ipairs(spr.layers) do
  if layer.name:sub(1,1) == "%" then
    table.insert(percentLayers, layer)
  end
end

local exportMetaCount = #percentLayers

if exportMetaCount == 0 then
  return app.alert("No export path layer found. Create a layer named like = %D:/Your/Export/Path/")
elseif exportMetaCount > 1 then
  return app.alert("Multiple export path layers found. Only one layer starting with % (percent sign) is allowed = %D:/Your/Export/Path/")
end

exportRoot = percentLayers[1].name:sub(2)

-- Validate export path format
local lastChar = exportRoot:sub(-1)

if lastChar ~= "/" and lastChar ~= "\\" then
  return app.alert("Invalid export path: must end with slash or backslash = E:\\\\MyProject\\\\ -OR- E:/MyProject/")
end

if exportRoot:find("\\") and not exportRoot:find("\\\\") then
  return app.alert("Windows paths must use double backslashes = E:\\\\MyProject\\\\ -OR- E:/MyProject/")
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
local logPath = exportRoot .. "= Export-Logs/"
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
  logFile:write("→ Merging group: " .. group.name .. "")
  local originalGroupName = group.name

  -- Recursively find the group index and its parent container
  local function findLayerIndex(container, target)
    for i, layer in ipairs(container.layers) do
      if layer == target then return i, container end
      if layer.isGroup then
        local idx, parent = findLayerIndex(layer, target)
        if idx then return idx, parent end
      end
    end
  end

  local groupIndex, parent = findLayerIndex(spr, group)
  if not groupIndex or not parent then
    logFile:write("→ Error: group index not found")
    skippedCount = skippedCount + 1
    return
  end

  -- Flatten the group
  app.range.layers = { group }
  app.command.FlattenLayers()
  logFile:write("→ Flattened successfully at group index " .. groupIndex .. " in " .. (parent.name or "ROOT") .. "\n")

  -- After flattening, retrieve the new layer at the same index
  local flattenedLayer = parent.layers[groupIndex]
  if not flattenedLayer or not flattenedLayer.isImage then
    logFile:write("→ Error: could not locate flattened image layer")
    skippedCount = skippedCount + 1
    return
  end

  -- Rename the flattened layer to match the original group name
  flattenedLayer.name = originalGroupName

  -- Process like a normal image layer export
  for _, cel in ipairs(flattenedLayer.cels) do
    local image = cel.image
    local bounds = getTrimBounds(image)
    if not bounds then
      logFile:write("→ Skipped: group is fully transparent")
      skippedCount = skippedCount + 1
      return
    end
    ensureDir(folderPath, createdPaths)
    local trimmed = Image(bounds.w, bounds.h, image.colorMode)
    trimmed:drawImage(image, Point(-bounds.x, -bounds.y))
    local newSprite = Sprite(bounds.w, bounds.h)
    newSprite.filename = groupName
    newSprite:newCel(newSprite.layers[1], cel.frameNumber, trimmed, Point(0, 0))
	
	local filename = folderPath .. groupName .. ".png"
	logFile:write("→ Attempting to save: " .. filename .. "\n")

    newSprite:saveCopyAs(filename)
    newSprite:close()
    logFile:write(string.format("→ Exported: %s (trimmed %dx%d)", filename, bounds.w, bounds.h))
    exportCount = exportCount + 1
	
	logFile:write("→ Done processing group: " .. originalGroupName .. "\n")
	
	return
  end

  logFile:write("→ Skipped: no cels found")
  skippedCount = skippedCount + 1
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
	local isIgnored = ignored or name:find("#") or name:sub(1,1) == "%"
    if isIgnored then
      logFile:write("→ Skipped (inherited or contains '#'): " .. name .. "\n")
      skippedCount = skippedCount + 1
    elseif not layer.isVisible then
      logFile:write("→ Skipped (not visible): " .. name .. "\n")
      skippedCount = skippedCount + 1
	elseif isGroup(layer) then
	
	if name:sub(1,1) == "@" then
	  local cleanName = name:sub(2)
	  local folderPath = exportRoot .. (parentGroup and parentGroup .. "/" or "")
	  ensureDir(folderPath, createdPaths)
	  exportGroupImage(layer, cleanName, folderPath)
	else
	  logFile:write("→ Entering group: " .. name .. "\\n")
	  local newGroupPath = (parentGroup and (parentGroup .. "/" .. name) or name)
	  walk(layer, newGroupPath, ignored)
	end

    elseif layer.isImage then
      local folderPath = exportRoot .. (parentGroup and parentGroup .. "/" or "")
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
end)
app.undo()
