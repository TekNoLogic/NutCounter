
----------------------
--      Locals      --
----------------------

local L = setmetatable({}, {__index=function(t,i) return i end})
local defaults, db = {}


------------------------------
--      Util Functions      --
------------------------------

local function Print(...) ChatFrame1:AddMessage(string.join(" ", "|cFF33FF99Addon Template|r:", ...)) end

local debugf = tekDebug and tekDebug:GetFrame("NutCounter")
local function Debug(...) if debugf then debugf:AddMessage(string.join(", ", tostringall(...))) end end


-----------------------------
--      Event Handler      --
-----------------------------

local f = CreateFrame("frame")
f:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)
f:RegisterEvent("ADDON_LOADED")


function f:ADDON_LOADED(event, addon)
	if addon ~= "NutCounter" then return end

	NutCounterDB = setmetatable(NutCounterDB or {min = {}, max = {}, last = {}}, {__index = defaults})
	db = NutCounterDB

	-- Do anything you need to do after addon has loaded

	LibStub("tekKonfig-AboutPanel").new("NutCounter", "NutCounter") -- Remove first arg if no parent config panel

	self:UnregisterEvent("ADDON_LOADED")
	self.ADDON_LOADED = nil

	if IsLoggedIn() then self:PLAYER_LOGIN() else self:RegisterEvent("PLAYER_LOGIN") end
end


function f:PLAYER_LOGIN()
	self:RegisterEvent("PLAYER_LOGOUT")

	-- Do anything you need to do after the player has entered the world

	self:UnregisterEvent("PLAYER_LOGIN")
	self.PLAYER_LOGIN = nil
end


function f:PLAYER_LOGOUT()
	for i,v in pairs(defaults) do if db[i] == v then db[i] = nil end end

	-- Do anything you need to do as the player logs out
end
