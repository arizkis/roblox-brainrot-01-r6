-- Remotes: the server -> client event channels. Created once at require time.
-- Notify(message) goes to one player; CashPopup(position, amount) goes to everyone
-- so any client can float a "+$" over the earning pad.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "BazaarRemotes"
folder.Parent = ReplicatedStorage

local function makeEvent(name: string): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	return event
end

local function makeFunction(name: string): RemoteFunction
	local func = Instance.new("RemoteFunction")
	func.Name = name
	func.Parent = folder
	return func
end

return {
	Notify = makeEvent("Notify"),
	CashPopup = makeEvent("CashPopup"),
	Banner = makeEvent("Banner"), -- FireAllClients(text): big top banner (events, tsunami, countdown)
	Toast = makeEvent("Toast"), -- FireClient(player, text): small corner toast (quests, index)
	Celebrate = makeEvent("Celebrate"), -- FireClient(player, rebirths): rebirth celebration
	LockState = makeEvent("LockState"), -- FireClient(owner, {Active, TimeLeft, CooldownLeft})
	QuestUpdate = makeEvent("QuestUpdate"), -- FireClient(player, ActiveQuests snapshot)
	RequestLock = makeEvent("RequestLock"), -- client -> server
	RequestRebirth = makeEvent("RequestRebirth"), -- client -> server
	BuyUpgrade = makeEvent("BuyUpgrade"), -- client -> server(trackId)
	GetIndex = makeFunction("GetIndex"), -- client -> IndexBook.FoundSet
	GetQuests = makeFunction("GetQuests"), -- client -> Quests.ActiveQuests
	GetUpgrades = makeFunction("GetUpgrades"), -- client -> Upgrades.UpgradeState
}
