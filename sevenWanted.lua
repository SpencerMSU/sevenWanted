script_name('sevenWanted')
local imgui = require 'mimgui'
local ffi = require 'ffi'
local encoding = require 'encoding'
local se = require 'lib.samp.events'
local effil = require 'effil'
local requests = require 'requests'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local configFile = getWorkingDirectory() .. '\\config\\sevenWanted.json'
local new = imgui.new
local WinState = new.bool()
local settings = {
    token = '',
    chat_id = ''
}
local inputToken = new.char[128]()
local inputUser = new.char[128]()
function saveConfig()
    local file = io.open(configFile, "w")
    if file then
        file:write(encodeJson(settings))
        file:close()
    end
end
function loadConfig()
    if doesFileExist(configFile) then
        local file = io.open(configFile, "r")
        if file then
            local data = decodeJson(file:read("*a"))
            file:close()
            if data then
                settings = data
                if settings.token then imgui.StrCopy(inputToken, settings.token) end
                if settings.chat_id then imgui.StrCopy(inputUser, settings.chat_id) end
            end
        end
    else
        createDirectory(getWorkingDirectory() .. '\\config')
        saveConfig()
    end
end

function async_http_request(url)
    effil.thread(function(u)
        local requests = require 'requests'
        local ok, result = pcall(requests.get, u)
    end)(url)
end

function sendTelegramNotification(msg)
    if settings.token == '' or settings.chat_id == '' then return end
    
    local utf8Msg = u8(msg)

    utf8Msg = utf8Msg:gsub('\n', '%%0A')
    utf8Msg = utf8Msg:gsub('([^%w %-%_%.%~])', function(c) return string.format("%%%02X", string.byte(c)) end)
    utf8Msg = utf8Msg:gsub(' ', '+')
    
    local url = 'https://api.telegram.org/bot' .. settings.token .. '/sendMessage?chat_id=' .. settings.chat_id .. '&text=' .. utf8Msg
    async_http_request(url)
end

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    
    loadConfig()
    
    sampRegisterChatCommand('swanted', function() WinState[0] = not WinState[0] end)
    sampAddChatMessage('[sevenWanted] {FFFFFF}Загружен. Меню: {308ad9}/swanted', 0x308ad9)
    
    while true do
        wait(0)
    end
end

function se.onServerMessage(color, text)
    local cleanText = text:gsub('{......}', '')
    if cleanText:find("Внимание!") and cleanText:find("объявлен%(a%) в розыск!") and cleanText:find("Уровень розыска:%s*7") then
        sendTelegramNotification(cleanText)
        return
    end
    if cleanText:find("Внимание! В игру зашел особо опасный преступник") and cleanText:find("%(7 уровень розыска%)") then
        sendTelegramNotification(cleanText)
    end
end
imgui.OnInitialize(function()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    local io = imgui.GetIO()
    io.Fonts:Clear()
    local glyph_ranges = io.Fonts:GetGlyphRangesCyrillic()
    io.Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\trebucbd.ttf', 15.0, nil, glyph_ranges)
    io.Fonts:Build()
    colors[clr.WindowBg]             = ImVec4(0.14, 0.14, 0.14, 1.00)
    colors[clr.TitleBg]              = ImVec4(0.00, 0.39, 1.00, 1.00)
    colors[clr.TitleBgActive]        = ImVec4(0.00, 0.39, 1.00, 1.00)
    colors[clr.TitleBgCollapsed]     = ImVec4(0.00, 0.39, 1.00, 0.65)
    colors[clr.Button]               = ImVec4(0.00, 0.39, 1.00, 1.00)
    colors[clr.ButtonHovered]        = ImVec4(0.00, 0.49, 1.00, 1.00)
    colors[clr.ButtonActive]         = ImVec4(0.00, 0.29, 0.80, 1.00)
    colors[clr.FrameBg]              = ImVec4(0.00, 0.39, 1.00, 1.00)
    colors[clr.FrameBgHovered]       = ImVec4(0.00, 0.49, 1.00, 1.00)
    colors[clr.FrameBgActive]        = ImVec4(0.00, 0.29, 0.80, 1.00)
    colors[clr.Text]                 = ImVec4(1.00, 1.00, 1.00, 1.00)
    style.WindowRounding = 5.0
    style.FrameRounding = 5.0
end)

imgui.OnFrame(function() return WinState[0] end,
    function(player)
        imgui.SetNextWindowSize(imgui.ImVec2(350, 240), imgui.Cond.FirstUseEver)
        local resX, resY = getScreenResolution()
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.Begin(u8'Настройки Seven Wanted', WinState, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)
            local text = u8"Данные для бота:"
            local windowWidth = imgui.GetWindowWidth()
            local textWidth = imgui.CalcTextSize(text).x
            imgui.SetCursorPosX((windowWidth - textWidth) * 0.5)
            imgui.Text(text)
            imgui.Spacing()
            imgui.PushItemWidth(-1)
            if imgui.InputTextWithHint('##token', u8'Введите токен бота', inputToken, 128, imgui.InputTextFlags.Password) then
                settings.token = ffi.string(inputToken)
                saveConfig()
            end
            imgui.Spacing()
            if imgui.InputTextWithHint('##userid', u8'Введите ваш Chat ID', inputUser, 128, imgui.InputTextFlags.Password) then
                settings.chat_id = ffi.string(inputUser)
                saveConfig()
            end
            imgui.PopItemWidth()
            imgui.Spacing()
            imgui.Spacing()
            if imgui.Button(u8'Тестовое сообщение', imgui.ImVec2(-1, 40)) then
                sendTelegramNotification("Тестовое сообщение!.")
            end
        imgui.End()
    end
)
