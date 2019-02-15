-- sample configs
-- https://github.com/Hammerspoon/hammerspoon/wiki/Sample-Configurations



-- Set base key combo
metaKey      = {'cmd', 'alt'}
superMetaKey = {'cmd', 'alt', 'ctrl'}
launchKey      = {'cmd', 'alt', 'shift'}


---------------------------------------------------------
-- loading spoons
---------------------------------------------------------

-- load spoon of auto-reload config when saving config
-- http://www.hammerspoon.org/Spoons/ReloadConfiguration.html
hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

-- hotkey to reload config
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "R", function()
    hs.reload()
end)
hs.alert.show("Config loaded")


hs.loadSpoon("Caffeine")
spoon.Caffeine:start()

-- hs.loadSpoon("HSKeybindings")
-- -- spoon.HSKeybindings:start()
-- hs.hotkey.bind(superMetaKey, "K", spoon.HSKeybindings:show())


hs.loadSpoon("ClipboardTool")
spoon.ClipboardTool.show_in_menubar = false
-- spoon.ClipboardTool.show_alert = true
spoon.ClipboardTool:start()
spoon.ClipboardTool:bindHotkeys({
    -- show_clipboard = {metaKey, "C"},
    toggle_clipboard = {metaKey, "C"}
})

---------------------------------------------------------
-- double quit app
-- from https://github.com/raulchen/dotfiles
---------------------------------------------------------
local quitModal = hs.hotkey.modal.new('cmd','q')

function quitModal:entered()
  hs.alert.show("Press Cmd+Q again to quit", 1)
  hs.timer.doAfter(1, function() quitModal:exit() end)
end

local function doQuit()
  local app = hs.application.frontmostApplication()
  app:kill()
end

quitModal:bind('cmd', 'q', doQuit)
quitModal:bind('', 'escape', function() quitModal:exit() end)


---------------------------------------------------------
-- find the mouse point - from hammperspoon getting started
---------------------------------------------------------
mouseCircle = nil
mouseCircleTimer = nil

function mouseHighlight()
  -- Delete an existing highlight if it exists
  if mouseCircle then
    mouseCircle:delete()
    if mouseCircleTimer then
      mouseCircleTimer:stop()
    end
  end
  -- Get the current co-ordinates of the mouse pointer
  mousepoint = hs.mouse.getAbsolutePosition()
  -- Prepare a big red circle around the mouse pointer
  mouseCircle = hs.drawing.circle(hs.geometry.rect(mousepoint.x-40, mousepoint.y-40, 80, 80))
  mouseCircle:setStrokeColor({["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1})
  mouseCircle:setFill(false)
  mouseCircle:setStrokeWidth(9)
  mouseCircle:show()

  -- Set a timer to delete the circle after 3 seconds
  mouseCircleTimer = hs.timer.doAfter(3, function() mouseCircle:delete() end)
end
hs.hotkey.bind(superMetaKey, "M", mouseHighlight)

---------------------------------------------------------


---------------------------------------------------------
-- app launching
---------------------------------------------------------
function bindAppKey(key,appID)
  hs.hotkey.bind(launchKey,
                 key,
                 function()
                   hs.application.launchOrFocusByBundleID(appID)
                 end
  )
end

bindAppKey('f', 'org.mozilla.firefox')
bindAppKey('e', 'org.gnu.Emacs')
bindAppKey('t', 'com.googlecode.iterm2')
-- bindAppKey('v', 'com.microsoft.VSCode')
bindAppKey('v', 'com.coppertino.Vox')
bindAppKey('c', 'com.apple.iCal')
-- bindAppKey('m', 'com.apple.mail.mailbox')
---------------------------------------------------------


---------------------------------------------------------
-- window management
---------------------------------------------------------
-- https://github.com/miromannino/miro-windows-manager
-- local hyper = {"ctrl", "alt", "cmd"}
local hyper = {"alt", "cmd"}

hs.loadSpoon("MiroWindowsManager")

-- hs.window.animationDuration = 0.01
hs.window.animationDuration = 0
spoon.MiroWindowsManager:bindHotkeys({
    up = {hyper, "up"},
    right = {hyper, "right"},
    down = {hyper, "down"},
    left = {hyper, "left"},
    fullscreen = {hyper, "f"}
})


-- move window to the next screen in the cycle
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "N", function()
    local win = hs.window.focusedWindow()
    local curScr = win:screen()

    function getNextScreen(scr)
      local nextIndex = 1
      local screens = hs.screen.allScreens()
      for i = 1, #screens do
        if scr == screens[i] then
          if i ~= #screens then
            nextIndex = i + 1
          end
        end
      end
      return screens[nextIndex]
    end

    local nextScr = getNextScreen(curScr)
    win:moveToScreen(nextScr)
end)

-- move window to screen
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "up", function()
    local win = hs.window.focusedWindow()
    win:moveOneScreenNorth()
end)
-- move window to screen
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "down", function()
    local win = hs.window.focusedWindow()
    win:moveOneScreenSouth()
end)
-- move window to screen
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "left", function()
    local win = hs.window.focusedWindow()
    win:moveOneScreenWest()
end)
-- move window to screen
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "right", function()
    local win = hs.window.focusedWindow()
    win:moveOneScreenEast()
end)


-- move window to left by 10px
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "H", function()
    local win = hs.window.focusedWindow()
    local f = win:frame()
    f.x = f.x - 10
    win:setFrame(f)
end)

-- move window to right by 10px
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "L", function()
    local win = hs.window.focusedWindow()
    local f = win:frame()
    f.x = f.x + 10
    win:setFrame(f)
end)


-- move and resize window to left, as 1/1.6 max size
hs.hotkey.bind({"cmd", "alt"}, "J", function()
    local win = hs.window.focusedWindow()
    local f = win:frame()
    local screen = win:screen()
    local max = screen:frame()

    f.x = max.x
    f.y = max.y
    f.w = max.w / 1.6
    f.h = max.h
    win:setFrame(f)
end)

-- move and resize window to right, as 1/1.6 max size
hs.hotkey.bind({"cmd", "alt"}, "K", function()
    local win = hs.window.focusedWindow()
    local f = win:frame()
    local screen = win:screen()
    local max = screen:frame()

    f.x = max.x + max.w - (max.w / 1.6) + 10
    f.y = max.y
    f.w = max.w / 1.6
    f.h = max.h
    win:setFrame(f)
end)

-- move and resize window to left, as 1/1.3 max size
hs.hotkey.bind({"cmd", "alt"}, "H", function()
    local win = hs.window.focusedWindow()
    local f = win:frame()
    local screen = win:screen()
    local max = screen:frame()

    f.x = max.x
    f.y = max.y
    f.w = max.w / 1.3
    f.h = max.h
    win:setFrame(f)
end)

-- move and resize window to right, as 1/1.3 max size
hs.hotkey.bind({"cmd", "alt"}, "L", function()
    local win = hs.window.focusedWindow()
    local f = win:frame()
    local screen = win:screen()
    local max = screen:frame()

    f.x = max.x + max.w - (max.w / 1.3) + 10
    f.y = max.y
    f.w = max.w / 1.3
    f.h = max.h
    win:setFrame(f)
end)


---------------------------------------------------------
-- wifi events
---------------------------------------------------------
wifiWatcher = nil
homeSSID = "sakura"
lastSSID = hs.wifi.currentNetwork()

function ssidChangedCallback()
  newSSID = hs.wifi.currentNetwork()

  if newSSID == homeSSID and lastSSID ~= homeSSID then
    -- We just joined our home WiFi network
    hs.audiodevice.defaultOutputDevice():setVolume(25)
  elseif newSSID ~= homeSSID and lastSSID == homeSSID then
    -- We just departed our home WiFi network
    hs.audiodevice.defaultOutputDevice():setVolume(0)
  end

  lastSSID = newSSID
end

wifiWatcher = hs.wifi.watcher.new(ssidChangedCallback)
wifiWatcher:start()
