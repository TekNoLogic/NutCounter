
----------------------
--      Locals      --
----------------------

local db


------------------------------
--      Util Functions      --
------------------------------

local function Print(...) print("|cFF33FF99NutCounter|r:", ...) end

local debugf = tekDebug and tekDebug:GetFrame("NutCounter")
local function Debug(...) if debugf then debugf:AddMessage(string.join(", ", tostringall(...))) end end


-----------------------------
--      Event Handler      --
-----------------------------

local f = CreateFrame("frame")
f:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)
f:RegisterEvent("ADDON_LOADED")
f:Hide()


function f:ADDON_LOADED(event, addon)
	if addon ~= "NutCounter" then return end

	local dbkey = GetRealmName().. " ".. UnitFactionGroup("player")

	NutCounterDB = NutCounterDB or {}
	NutCounterDB[dbkey] = NutCounterDB[dbkey] or {min = {}, max = {}, last = {}, sold = {}, failed = {}}
	db = NutCounterDB[dbkey]

	LibStub("tekKonfig-AboutPanel").new(nil, "NutCounter")

	self:RegisterEvent("MAIL_INBOX_UPDATE")
	self:RegisterEvent("MAIL_CLOSED")
	self:RegisterEvent("PLAYER_LEAVING_WORLD")
	self:RegisterEvent("UI_ERROR_MESSAGE")

	self:UnregisterEvent("ADDON_LOADED")
	self.ADDON_LOADED = nil
end


-----------------------
--      Buttons      --
-----------------------

local function GrabItem(i)
	AutoLootMailItem(i)
	InboxFrame.openMailID = i
	OpenMailFrame.updateButtonPositions = true
	OpenMail_Update()
	ShowUIPanel(OpenMailFrame)
	InboxFrame_Update()
end


local nutting, shining
local function GatherShinies()
	shining = true
	for i=1,GetInboxNumItems() do
		local _, _, _, subject = GetInboxHeaderInfo(i)
		if subject:match("^Auction successful:") then
			Debug("Grabbing cash", i, subject)
			return GrabItem(i)
		end
	end
	shining = false
	Debug("Done gathering shinies")
end

local function CollectNuts()
	nutting = true
	local free = 0
	for i=0,4 do free = free + GetContainerNumFreeSlots(i) end
	if free > 1 then
		for i=1,GetInboxNumItems() do
			local _, _, _, subject = GetInboxHeaderInfo(i)
			if subject:match("^Auction expired:") then
				Debug("Grabbing nuts", i, subject)
				return GrabItem(i)
			end
		end
	end
	nutting = false
	Debug("Done collecting nuts")
end

local alling, mIndex, aIndex, inventoryFull
local function GrabAll()
	Debug("Grabbing everything")
	mIndex = GetInboxNumItems()
	alling, aIndex, inventoryFull = true
	f:MAIL_INBOX_UPDATE()
end


local PADDING = 4
local bgFrame = {bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", insets = {left = PADDING, right = PADDING, top = PADDING, bottom = PADDING},
	tile = true, tileSize = 16, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16}

local back = CreateFrame("Frame", nil, InboxFrame)
back:SetPoint("TOP", 0, -32)
back:SetPoint("RIGHT", 18, 0)
back:SetWidth(58)
back:SetHeight(75)
back:SetFrameLevel(MailFrame:GetFrameLevel()-1)

back:SetBackdrop(bgFrame)
back:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
back:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)

local nutterbutter = LibStub("tekKonfig-Button").new_small(back, "TOPRIGHT", -5, -5)
nutterbutter:SetWidth(45) nutterbutter:SetHeight(18)
nutterbutter:SetText("Nuts")
nutterbutter.tiptext = "Collect failed auctions"
nutterbutter:SetScript("OnClick", CollectNuts)

local shinybutt = LibStub("tekKonfig-Button").new_small(nutterbutter, "TOPLEFT", nutterbutter, "BOTTOMLEFT")
shinybutt:SetWidth(45) shinybutt:SetHeight(18)
shinybutt:SetText("Shinies")
shinybutt.tiptext = "Collect successful auctions"
shinybutt:SetScript("OnClick", GatherShinies)


local everybutt = LibStub("tekKonfig-Button").new_small(shinybutt, "TOPLEFT", shinybutt, "BOTTOMLEFT", 0, -8)
everybutt:SetWidth(45) shinybutt:SetHeight(18)
everybutt:SetText("All")
everybutt.tiptext = "Open all mail.  This will not count auction results!"
everybutt:SetScript("OnClick", GrabAll)


-----------------------
--      Tracker      --
-----------------------

local lastcount, lastitem, lastprice, cashingout, lastexpire

local orig = AutoLootMailItem
function AutoLootMailItem(i, ...)
	local _, _, _, subject = GetInboxHeaderInfo(i)
	Debug("AutoLootMailItem", subject, i, ...)

	if subject:match("^Auction expired:") then lastexpire = GetInboxItem(i, 1)
	else cashingout = i end
	return orig(i, ...)
end


function f:MAIL_INBOX_UPDATE()
	local grabnextshiney, grabnextnut
	local _, count = GetInboxNumItems()
	Debug("MAIL_INBOX_UPDATE", count, alling, shining, nutting, cashingout)

	if alling then return f:OpenAll() end
	if not (shining or nutting) then return end

	if cashingout then
		local invoiceType, itemName, _, bid, buyout = GetInboxInvoiceInfo(cashingout)
		Debug("Detected cashout", invoiceType, bid, buyout)
		if invoiceType then
			if invoiceType == "seller" then
				lastitem, lastprice = itemName, buyout or bid
			end
			cashingout = nil
		end
	elseif lastexpire and lastcount and count == lastcount - 1 then
		Debug("Detected expired mail removal", lastexpire)
		db.failed[lastexpire] = (db.failed[lastexpire] or 0) + 1
		lastexpire = nil
		grabnextnut = nutting
	elseif lastprice and count == lastcount - 1 then
		Debug("Detected mail removal", lastprice, lastitem)
		db.min[lastitem] = math.min(lastprice, db.min[lastitem] or math.huge)
		db.max[lastitem] = math.max(lastprice, db.max[lastitem] or 0)
		db.last[lastitem] = lastprice
		db.sold[lastitem] = (db.sold[lastitem] or 0) + 1
		lastprice, lastitem = nil
		grabnextshiney = shining
	end

	lastcount = count

	if grabnextnut then
		Debug("Still collecting nuts")
		return CollectNuts()
	end
	if grabnextshiney then
		Debug("Still gathering shinies")
		return GatherShinies()
	end
end


-----------------------------
--      Open all bits      --
-----------------------------

local elap
f:SetScript("OnShow", function(self) elap = 0 end)
f:SetScript("OnUpdate", function(self, e) elap = elap + e; if elap >= 0.1 then self:Hide() end end)
f:SetScript("OnHide", function(self) self:MAIL_INBOX_UPDATE() end)


function f:MAIL_CLOSED() alling = nil end
function f:UI_ERROR_MESSAGE(event, msg) if msg == ERR_INV_FULL then inventoryFull = true end end
f.PLAYER_LEAVING_WORLD = f.MAIL_CLOSED
-- ERR_MAIL_DATABASE_ERROR = "Internal mail database error.";
-- ERR_ITEM_NOT_FOUND = "The item was not found.";


function f:OpenAll()
	Debug("f:OpenAll()", mIndex, aIndex)
	local _, _, _, subject, money, cod, _, _, _, _, _, _, isGM = GetInboxHeaderInfo(mIndex)
	if not subject then alling = nil; return end
	if not aIndex then Debug("Resetting aIndex"); aIndex = ATTACHMENTS_MAX_RECEIVE end -- new mail, not tried aattachments yet... there can be gaps, so we can't rely on itemCount...
	while aIndex > 0 and not GetInboxItem(mIndex, aIndex) do aIndex = aIndex - 1 end -- no attachment here, next!

	if aIndex == 0 then -- all attachments passed, try and get the moneys
		if money > 0 then -- take money
			Debug("Taking money", mIndex, money)
			TakeInboxMoney(mIndex)
			return self:Show()
		else mIndex, aIndex = mIndex - 1 end -- done with this mail, next!
	elseif cod == 0 and not inventoryFull and not isGM then -- take item
		Debug("Taking item", mIndex, aIndex)
		TakeInboxItem(mIndex, aIndex)
		return self:Show()
	else mIndex, aIndex = mIndex - 1 end -- skip this mail

	return self:MAIL_INBOX_UPDATE()
end

-----------------------------
--      Tooltip stuff      --
-----------------------------

local function GS(cash)
	if not cash then return end
	cash = cash/100
	local s = floor(cash%100)
	local g = floor(cash/100)
	if g > 0 then return string.format("|cffffd700%d.|cffc7c7cf%02d", g, s)
	else return string.format("|cffc7c7cf%d", s) end
end


local origs = {}
local OnTooltipSetItem = function(frame, ...)
	assert(frame, "arg 1 is nil, someone isn't hooking correctly")

	local name = frame:GetItem()
	if name then
		local min, max, last, sold, failed = db.min[name], db.max[name], db.last[name], db.sold[name], db.failed[name]
		if min then frame:AddDoubleLine("Previous sales:", max and max ~= min and (GS(min).." - "..GS(max)) or GS(min)) end
		if last then frame:AddDoubleLine("Last sale:", GS(last)) end
		if sold or failed then frame:AddDoubleLine("Sellthrough:", string.format("(%d/%d) %d%%", sold or 0, (sold or 0) + (failed or 0), (sold or 0)/((sold or 0) + (failed or 0))*100)) end
	end

	if origs[frame] then return origs[frame](frame, ...) end
end

for i,frame in pairs{GameTooltip, ItemRefTooltip} do
	origs[frame] = frame:GetScript("OnTooltipSetItem")
	frame:SetScript("OnTooltipSetItem", OnTooltipSetItem)
end


--------------------------------
--      GetAuctionBuyout      --
--------------------------------

local ids = LibStub("tekIDmemo")
local orig = GetAuctionBuyout
function GetAuctionBuyout(item)
	local id = ids[item]
	return orig and orig(item) or id and db.last[GetItemInfo(id)]
end
