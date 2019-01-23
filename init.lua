-- sample configs
-- https://github.com/Hammerspoon/hammerspoon/wiki/Sample-Configurations


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


-- move window to another screen in the cycle
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
