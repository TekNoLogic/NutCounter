
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


function f:ADDON_LOADED(event, addon)
	if addon ~= "NutCounter" then return end

	local dbkey = GetRealmName().. " ".. UnitFactionGroup("player")

	NutCounterDB = NutCounterDB or {}
	NutCounterDB[dbkey] = NutCounterDB[dbkey] or {min = {}, max = {}, last = {}, sold = {}, failed = {}}
	db = NutCounterDB[dbkey]

	LibStub("tekKonfig-AboutPanel").new(nil, "NutCounter")

	self:RegisterEvent("MAIL_INBOX_UPDATE")

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


local PADDING = 4
local bgFrame = {bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", insets = {left = PADDING, right = PADDING, top = PADDING, bottom = PADDING},
	tile = true, tileSize = 16, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16}

local f = CreateFrame("Frame", nil, InboxFrame)
f:SetPoint("TOP", 0, -32)
f:SetPoint("RIGHT", 19, 0)
f:SetWidth(58)
f:SetHeight(47)
f:SetFrameLevel(MailFrame:GetFrameLevel()-1)

f:SetBackdrop(bgFrame)
f:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
f:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)

local nutterbutter = LibStub("tekKonfig-Button").new_small(f, "TOPLEFT", 8, -5)
nutterbutter:SetWidth(45) nutterbutter:SetHeight(18)
nutterbutter:SetText("Nuts")
nutterbutter.tiptext = "Collect failed auctions"
nutterbutter:SetScript("OnClick", CollectNuts)

local shinybutt = LibStub("tekKonfig-Button").new_small(nutterbutter, "TOPLEFT", nutterbutter, "BOTTOMLEFT")
shinybutt:SetWidth(45) shinybutt:SetHeight(18)
shinybutt:SetText("Shinies")
shinybutt.tiptext = "Collect successful auctions"
shinybutt:SetScript("OnClick", GatherShinies)


-----------------------
--      Tracker      --
-----------------------

local lastcount, lastitem, lastprice, cashingout, lastexpire

local orig = AutoLootMailItem
function AutoLootMailItem(i, ...)
	Debug("AutoLootMailItem", i, ...)

	local _, _, _, subject = GetInboxHeaderInfo(i)
	if subject:match("^Auction expired:") then lastexpire = GetInboxItem(i, 1)
	else cashingout = i end
	return orig(i, ...)
end


function f:MAIL_INBOX_UPDATE()
	local grabnextshiney, grabnextnut
	local count = GetInboxNumItems()
	Debug("MAIL_INBOX_UPDATE", count)

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
