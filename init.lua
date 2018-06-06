-- load spoon of auto-reload config when saving config
hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

-- hotkey to reload config
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "R", function()
    hs.reload()
end)
hs.alert.show("Config loaded")


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

-- 
caffeine = hs.menubar.new()
function setCaffeineDisplay(state)
  if state then
    caffeine:setTitle("AWAKE")
  else
    caffeine:setTitle("SLEEPY")
  end
end

function caffeineClicked()
  setCaffeineDisplay(hs.caffeinate.toggle("displayIdle"))
end

if caffeine then
  caffeine:setClickCallback(caffeineClicked)
  setCaffeineDisplay(hs.caffeinate.get("displayIdle"))
end
