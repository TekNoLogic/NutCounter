
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
	elseif lastprice and count == lastcount - 1 then
		Debug("Detected mail removal", lastprice, lastitem)
		db.min[lastitem] = math.min(lastprice, db.min[lastitem] or math.huge)
		db.max[lastitem] = math.max(lastprice, db.max[lastitem] or 0)
		db.last[lastitem] = lastprice
		db.sold[lastitem] = (db.sold[lastitem] or 0) + 1
		lastprice, lastitem = nil
	end

	lastcount = count
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
