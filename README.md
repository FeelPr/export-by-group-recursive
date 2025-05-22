# Export By Group (Recursive)

A powerful and flexible Aseprite script to export your layers and groups intelligently. Designed by **Feel** ([https://www.instagram.com/feel.pixels/](https://www.instagram.com/feel.pixels/)) & ChatGPT, this script enables professional export workflows for artists working with layered sprites, dioramas, or modular elements.

---

## ✨ Features

- **Recursive export** of layers and groups
- **Trimmed PNGs**: crops empty pixels from exports
- **Group fusion**: export a whole group as one image using `@GroupName`
- **Visibility aware**: respects the "eye" icon in Aseprite
- **Ignore filter**: use `#` in a group/layer name to skip it
- **Command-line silent**: minimizes terminal flickers during export (Windows)
- **Export logs**: saved in `/Export-Logs/export-log.txt` for every session

---

## 📁 Usage Rules

### 🔹 Export a group as a single image

Name the group with `@`:

```
@Tree_Maple
├── Trunk
├── Leafs
```

→ Will export as: `Tree_Maple.png`

### 🔹 Skip a group or layer entirely

Add a `#` in the name:

```
#WIP_Sketch
```

→ Completely ignored (even if visible)

### 🔹 Export visible layers individually

Any visible layer not inside a `@group` or containing `#` will be exported trimmed:

```
Layer: Sword_Blade → Sword_Blade.png
```

### 🔹 Folder structure

- Export root is defined in the script:

```lua
local exportRoot = "E:/.../"
```

- Each group name becomes a folder:

```
Items/
├── Shield.png
├── Sword_Blade.png
```

- Logs are saved in: `<ExportFolder>/Export-Logs/export-log.txt`

---

### 🔧 How to install

1. Download the script from GitHub:  
👉 <a href="https://github.com/FeelPr/export-by-group-recursive" target="_blank">GitHub – Export By Group (Recursive)</a>

2. Place the `export-by-group-recursive.lua` file in your Aseprite scripts folder:
C:\Users\YourName\AppData\Roaming\Aseprite\scripts\

3. **Edit** the `exportRoot` (**line 14**) variable at the top of the script to set your preferred export folder path.
> #### ⚠️ Important note about the export path
> When editing the `exportRoot` variable, 
> make sure to use **forward slashes `/`** or  **double backslashes `\\`** otherwise Lua will throw an error.

✅ Correct example:
```
local exportRoot = "E:/My/Export/Folder/"
-- or
local exportRoot = "E:\\My\\Export\\Folder\\"
```

❌ Incorrect (this will break the script):
```
local exportRoot = "E:\My\Export\Folder"
```

4. Run the script in Aseprite via:  
`File > Scripts > export-by-group-recursive.lua`

---

## 🔧 Requirements

- Aseprite (v1.3 or newer recommended)
- This version does **not** require `app.fs.fileDialog` (manual path)

---

## 📜 License

This script is licensed under **Custom License inspired by BY-SA**.

- ✅ Free to use, modify and share
- ❌ Resale are **not** allowed
- 👤 Attribution required: [@feel.pixels](https://www.instagram.com/feel.pixels/) and ChatGPT

---

## 🧰 Credits

Crafted with 💛 by:

- 🎨 [Feel](https://www.instagram.com/feel.pixels/) (concept, testing, structure)
- 🤖 ChatGPT (Lua integration)

Feel free to share improvements or fork it with attribution.
Keep crafting! 🚀
