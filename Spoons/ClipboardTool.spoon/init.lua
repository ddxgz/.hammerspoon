--- === ClipboardTool ===
---
--- Keep a history of the clipboard for text entries and manage the entries with a context menu
---
--- Originally based on TextClipboardHistory.spoon by Diego Zamboni with additional functions provided by a context menu
--- and on [code by VFS](https://github.com/VFS/.hammerspoon/blob/master/tools/clipboard.lua), but with many changes and some contributions and inspiration from [asmagill](https://github.com/asmagill/hammerspoon-config/blob/master/utils/_menus/newClipper.lua).
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/ClipboardTool.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/ClipboardTool.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "ClipboardTool"
obj.version = "0.7"
obj.author = "Alfred Schilken <alfred@schilken.de>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

local getSetting = function(label, default) return hs.settings.get(obj.name.."."..label) or default end
local setSetting = function(label, value)   hs.settings.set(obj.name.."."..label, value); return value end

--- ClipboardTool.frequency
--- Variable
-----by pcx
obj.show_alert = false
------
--- Speed in seconds to check for clipboard changes. If you check too frequently, you will degrade performance, if you check sparsely you will loose copies. Defaults to 0.8.
obj.frequency = 0.8

--- ClipboardTool.hist_size
--- Variable
--- How many items to keep on history. Defaults to 100
obj.hist_size = 100

--- ClipboardTool.max_entry_size
--- Variable
--- maximum size of a text entry
obj.max_entry_size = 4990

--- ClipboardTool.max_size
--- Variable
--- Whether to check the maximum size of an entry. Defaults to `false`.
obj.max_size = getSetting('max_size', false)

--- ClipboardTool.honor_ignoredidentifiers
--- Variable
--- If `true`, check the data identifiers set in the pasteboard and ignore entries which match those listed in `ClipboardTool.ignoredIdentifiers`. The list of identifiers comes from http://nspasteboard.org. Defaults to `true`
obj.honor_ignoredidentifiers = true

--- ClipboardTool.paste_on_select
--- Variable
--- Whether to auto-type the item when selecting it from the menu. Can be toggled on the fly from the chooser. Defaults to `false`.
obj.paste_on_select = getSetting('paste_on_select', false)

--- ClipboardTool.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('ClipboardTool')

--- ClipboardTool.ignoredIdentifiers
--- Variable
--- Types of clipboard entries to ignore, see http://nspasteboard.org. Code from https://github.com/asmagill/hammerspoon-config/blob/master/utils/_menus/newClipper.lua. Default value (don't modify unless you know what you are doing):
--- ```
---  {
---     ["de.petermaurer.TransientPasteboardType"] = true, -- Transient : Textpander, TextExpander, Butler
---     ["com.typeit4me.clipping"]                 = true, -- Transient : TypeIt4Me
---     ["Pasteboard generator type"]              = true, -- Transient : Typinator
---     ["com.agilebits.onepassword"]              = true, -- Confidential : 1Password
---     ["org.nspasteboard.TransientType"]         = true, -- Universal, Transient
---     ["org.nspasteboard.ConcealedType"]         = true, -- Universal, Concealed
---     ["org.nspasteboard.AutoGeneratedType"]     = true, -- Universal, Automatic
---  }
--- ```
obj.ignoredIdentifiers = {
   ["de.petermaurer.TransientPasteboardType"] = true, -- Transient : Textpander, TextExpander, Butler
   ["com.typeit4me.clipping"]                 = true, -- Transient : TypeIt4Me
   ["Pasteboard generator type"]              = true, -- Transient : Typinator
   ["com.agilebits.onepassword"]              = true, -- Confidential : 1Password
   ["org.nspasteboard.TransientType"]         = true, -- Universal, Transient
   ["org.nspasteboard.ConcealedType"]         = true, -- Universal, Concealed
   ["org.nspasteboard.AutoGeneratedType"]     = true, -- Universal, Automatic
}

--- ClipboardTool.deduplicate
--- Variable
--- Whether to remove duplicates from the list, keeping only the latest one. Defaults to `true`.
obj.deduplicate = true

--- ClipboardTool.show_in_menubar
--- Variable
--- Whether to show a menubar item to open the clipboard history. Defaults to `true`
obj.show_in_menubar = true

--- ClipboardTool.menubar_title
--- Variable
--- String to show in the menubar if `ClipboardTool.show_in_menubar` is `true`. Defaults to `"\u{1f4ce}"`, which is the [Unicode paperclip character](https://codepoints.net/U+1F4CE)
obj.menubar_title   = "\u{1f4ce}"

----------------------------------------------------------------------

-- Internal variable - Chooser/menu object
obj.selectorobj = nil
-- Internal variable - Cache for focused window to work around the current window losing focus after the chooser comes up
obj.prevFocusedWindow = nil
-- Internal variable - Timer object to look for pasteboard changes
obj.timer = nil

local pasteboard = require("hs.pasteboard") -- http://www.hammerspoon.org/docs/hs.pasteboard.html
local hashfn   = require("hs.hash").MD5

-- Keep track of last change counter
local last_change = nil;
-- Array to store the clipboard history
local clipboard_history = nil

-- Internal function - persist the current history so it survives across restarts
function _persistHistory()
   setSetting("items",clipboard_history)
end

--- ClipboardTool:togglePasteOnSelect()
--- Method
--- Toggle the value of `ClipboardTool.paste_on_select`
function obj:togglePasteOnSelect()
   self.paste_on_select = setSetting("paste_on_select", not self.paste_on_select)
   hs.notify.show("ClipboardTool", "Paste-on-select is now " .. (self.paste_on_select and "enabled" or "disabled"), "")
end

function obj:toggleMaxSize()
   self.max_size = setSetting("max_size", not self.max_size)
   hs.notify.show("ClipboardTool", "Max Size is now " .. (self.max_size and "enabled" or "disabled"), "")
end

-- Internal method - process the selected item from the chooser. An item may invoke special actions, defined in the `actions` variable.
function obj:_processSelectedItem(value)
   local actions = {
      none = function() end,
      clear = hs.fnutils.partial(self.clearAll, self),
      toggle_paste_on_select = hs.fnutils.partial(self.togglePasteOnSelect, self),
      toggle_max_size = hs.fnutils.partial(self.toggleMaxSize, self),
   }
   if self.prevFocusedWindow ~= nil then
      self.prevFocusedWindow:focus()
   end
   if value and type(value) == "table" then
      if value.action and actions[value.action] then
         actions[value.action](value)
      elseif value.text then
         pasteboard.setContents(value.text)
--         self:pasteboardToClipboard(value.text)
         if (self.paste_on_select) then
            hs.eventtap.keyStroke({"cmd"}, "v")
         end
      end
      last_change = pasteboard.changeCount()
   end
end

--- ClipboardTool:clearAll()
--- Method
--- Clears the clipboard and history
function obj:clearAll()
   pasteboard.clearContents()
   clipboard_history = {}
   _persistHistory()
   last_change = pasteboard.changeCount()
end

--- ClipboardTool:clearLastItem()
--- Method
--- Clears the last added to the history
function obj:clearLastItem()
   table.remove(clipboard_history, 1)
   _persistHistory()
   last_change = pasteboard.changeCount()
end

-- Internal method: deduplicate the given list, and restrict it to the history size limit
function obj:dedupe_and_resize(list)
   local res={}
   local hashes={}
   for i,v in ipairs(list) do
      if #res < self.hist_size then
         local hash=hashfn(v)
         if (not self.deduplicate) or (not hashes[hash]) then
            table.insert(res, v)
            hashes[hash]=true
         end
      end
   end
   return res
end

--- ClipboardTool:pasteboardToClipboard(item)
--- Method
--- Add the given string to the history
---
--- Parameters:
---  * item - string to add to the clipboard history
---
--- Returns:
---  * None
function obj:pasteboardToClipboard(item)
   table.insert(clipboard_history, 1, item)
   clipboard_history = self:dedupe_and_resize(clipboard_history)
   _persistHistory() -- updates the saved history
end

-- Internal method: actions of the context menu, special paste
function obj:pasteAllWithDelimiter(row, delimiter)
  if self.prevFocusedWindow ~= nil then
      self.prevFocusedWindow:focus()
   end
   print("pasteAllWithTab row:" .. row)
   for ix = row, 1, -1 do
     local entry = clipboard_history[ix]
     print("pasteAllWithTab ix:" .. ix .. ":" .. entry)
--      pasteboard.setContents(entry)
--      os.execute("sleep 0.2")
--      hs.eventtap.keyStroke({"cmd"}, "v")
       hs.eventtap.keyStrokes(entry)
--      os.execute("sleep 0.2")
      hs.eventtap.keyStrokes(delimiter)
--      os.execute("sleep 0.2")
   end
end

-- Internal method: actions of the context menu, delete or rearrange of clips
function obj:manageClip(row, action)
    print("manageClip row:" .. row .. ",action:" .. action)
    if action == 0 then
      table.remove (clipboard_history, row)
    elseif action == 2 then
      	local i = 1
        local j = row
        while i < j do
          clipboard_history[i], clipboard_history[j] = clipboard_history[j], clipboard_history[i]
          i = i + 1
          j = j - 1
        end
    else
      local value = clipboard_history[row]
      local new = row + action
      if new < 1 then new = 1 end
      if new < row then
        table.move(clipboard_history, new, row - 1, new + 1)
      else
        table.move(clipboard_history, row + 1, new, row)
      end
      clipboard_history[new] = value
    end
    self.selectorobj:refreshChoicesCallback()
end

-- Internal method:
function obj:_showContextMenu(row)
  print("_showContextMenu row:" .. row)
  point = hs.mouse.getAbsolutePosition()
  local menu = hs.menubar.new(false)
  local menuTable = {
       { title = "Alle Schnipsel mit Tab einfügen", fn = hs.fnutils.partial(self.pasteAllWithDelimiter, self, row, "\t") },
       { title = "Alle Schnipsel mit Zeilenvorschub einfügen", fn = hs.fnutils.partial(self.pasteAllWithDelimiter, self, row, "\n") },
       { title = "-" },
       { title = "Eintrag entfernen",   fn = hs.fnutils.partial(self.manageClip, self, row, 0) },
       { title = "Eintrag an erste Stelle",   fn = hs.fnutils.partial(self.manageClip, self, row, -100)  },
       { title = "Eintrag nach oben",   fn = hs.fnutils.partial(self.manageClip, self, row, -1)  },
       { title = "Eintrag nach unten",   fn = hs.fnutils.partial(self.manageClip, self, row, 1) },
       { title = "Tabelle invertieren",   fn = hs.fnutils.partial(self.manageClip, self, row, 2) },
       { title = "-" },
       { title = "disabled item", disabled = true },
       { title = "checked item", checked = true },
   }
  menu:setMenu(menuTable)
  menu:popupMenu(point)
  print(hs.inspect(point))
end

-- Internal function - fill in the chooser options, including the control options
function obj:_populateChooser()
   menuData = {}
   for k,v in pairs(clipboard_history) do
      if (type(v) == "string") then
         table.insert(menuData, {text=v, subText=""})
      end
   end
   if #menuData == 0 then
      table.insert(menuData, { text="",
                               subText="《Clipboard is empty》",
                               action = 'none',
                               image = hs.image.imageFromName('NSCaution')})
   else
      table.insert(menuData, { text="《Clear Clipboard History》",
                               action = 'clear',
                               image = hs.image.imageFromName('NSTrashFull') })
   end
   table.insert(menuData, {
                   text="《" .. (self.paste_on_select and "Disable" or "Enable") .. " Paste-on-select》",
                   action = 'toggle_paste_on_select',
                   image = (self.paste_on_select and hs.image.imageFromName('NSSwitchEnabledOn') or hs.image.imageFromName('NSSwitchEnabledOff'))
   })
   table.insert(menuData, {
                   text="《" .. (self.max_size and "Disable" or "Enable") .. " max size " .. self.max_entry_size .. "》",
                   action = 'toggle_max_size',
                   image = (self.max_size and hs.image.imageFromName('NSSwitchEnabledOn') or hs.image.imageFromName('NSSwitchEnabledOff'))
   })
   self.logger.df("Returning menuData = %s", hs.inspect(menuData))
   return menuData
end

--- ClipboardTool:shouldBeStored()
--- Method
--- Verify whether the pasteboard contents matches one of the values in `ClipboardTool.ignoredIdentifiers`
function obj:shouldBeStored()
   -- Code from https://github.com/asmagill/hammerspoon-config/blob/master/utils/_menus/newClipper.lua
   local goAhead = true
   for i,v in ipairs(hs.pasteboard.pasteboardTypes()) do
      if self.ignoredIdentifiers[v] then
         goAhead = false
         break
      end
   end
   if goAhead then
      for i,v in ipairs(hs.pasteboard.contentTypes()) do
         if self.ignoredIdentifiers[v] then
            goAhead = false
            break
         end
      end
   end
   return goAhead
end

-- Internal method:
function obj:reduceSize(text)
  print(#text .. " ? " .. tostring(max_entry_size))
  local endingpos = 3000
  local lastLowerPos = 3000
  repeat
    lastLowerPos = endingpos
    _, endingpos = string.find(text, "\n\n", endingpos+1)
    print("endingpos:" .. endingpos)
  until endingpos > obj.max_entry_size
  return string.sub(text, 1, lastLowerPos)
end


--- ClipboardTool:checkAndStorePasteboard()
--- Method
--- If the pasteboard has changed, we add the current item to our history and update the counter
function obj:checkAndStorePasteboard()
   now = pasteboard.changeCount()
   if (now > last_change) then
      if (not self.honor_ignoredidentifiers) or self:shouldBeStored() then
         current_clipboard = pasteboard.getContents()
         self.logger.df("current_clipboard = %s", tostring(current_clipboard))
         if (current_clipboard == nil) and (pasteboard.readImage() ~= nil) then
            self.logger.df("Images not yet supported - ignoring image contents in clipboard")
         elseif current_clipboard ~= nil then
           local size = #current_clipboard
           if obj.max_size and size > obj.max_entry_size then
             local answer = hs.dialog.blockAlert("Clipboard", "The maximum size of " .. obj.max_entry_size .. " was exceeded.", "Copy partially", "Copy all", "NSCriticalAlertStyle")
              print("answer: " .. answer)
              if answer == "Copy partially" then
                current_clipboard = self:reduceSize(current_clipboard)
                size = #current_clipboard
                end
            end
            if obj.show_alert then
                hs.alert.show("Copied " .. size .. " chars")
            end
            self.logger.df("Adding %s to clipboard history", current_clipboard)
            self:pasteboardToClipboard(current_clipboard)
         else
            self.logger.df("Ignoring nil clipboard content")
         end
      else
         self.logger.df("Ignoring pasteboard entry because it matches ignoredIdentifiers")
      end
      last_change = now
   end
end

--- ClipboardTool:start()
--- Method
--- Start the clipboard history collector
function obj:start()
   obj.logger.level = 0
   clipboard_history = self:dedupe_and_resize(getSetting("items", {})) -- If no history is saved on the system, create an empty history
   last_change = pasteboard.changeCount() -- keeps track of how many times the pasteboard owner has changed // Indicates a new copy has been made
   self.selectorobj = hs.chooser.new(hs.fnutils.partial(self._processSelectedItem, self))
   self.selectorobj:choices(hs.fnutils.partial(self._populateChooser, self))
   self.selectorobj:rightClickCallback(hs.fnutils.partial(self._showContextMenu, self))
   --Checks for changes on the pasteboard. Is it possible to replace with eventtap?
   self.timer = hs.timer.new(self.frequency, hs.fnutils.partial(self.checkAndStorePasteboard, self))
   self.timer:start()
   if self.show_in_menubar then
      self.menubaritem = hs.menubar.new()
         :setTitle(obj.menubar_title)
         :setClickCallback(hs.fnutils.partial(self.toggleClipboard, self))
   end
end

--- ClipboardTool:showClipboard()
--- Method
--- Display the current clipboard list in a chooser
function obj:showClipboard()
   if self.selectorobj ~= nil then
      self.selectorobj:refreshChoicesCallback()
      self.prevFocusedWindow = hs.window.focusedWindow()
      self.selectorobj:show()
   else
      hs.notify.show("ClipboardTool not properly initialized", "Did you call ClipboardTool:start()?", "")
   end
end

--- ClipboardTool:toggleClipboard()
--- Method
--- Show/hide the clipboard list, depending on its current state
function obj:toggleClipboard()
   if self.selectorobj:isVisible() then
      self.selectorobj:hide()
   else
      self:showClipboard()
   end
end

--- ClipboardTool:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for ClipboardTool
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * show_clipboard - Display the clipboard history chooser
---   * toggle_clipboard - Show/hide the clipboard history chooser
function obj:bindHotkeys(mapping)
   local def = {
      show_clipboard = hs.fnutils.partial(self.showClipboard, self),
      toggle_clipboard = hs.fnutils.partial(self.toggleClipboard, self),
   }
   hs.spoons.bindHotkeysToSpec(def, mapping)
   obj.mapping = mapping
end

return obj

