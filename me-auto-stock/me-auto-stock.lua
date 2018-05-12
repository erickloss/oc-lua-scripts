local component = require("component")

local MeAutoStock = {}
local MeAutoStock_MT = {__index = MeAutoStock}

function MeAutoStock.new(targetItem, autoStockSizeModel, interfaceAddress, minSourceItems)
    local new = {
        targetItem = targetItem,
        autoStockSizeModel = autoStockSizeModel,
        interface = component.proxy(component.get(interfaceAddress)),
        minSourceItems = minSourceItems,
        currentJob = nil
    }
    return setmetatable(new, MeAutoStock_MT)
end

local function _itemEquals(i1, i2)
    if type(i1) == "table" and type(i2) == "table" then
        if i1.label ~= i2.label then
            return false
        end
        if i1.name ~= nil and i1.name ~= i2.name then
            return false
        end
        return true
    else
        return false
    end
end
local function _getCurrentItemsInNetwork(self, item)
    local currentItemStockInNetwork = self.interface.getItemsInNetwork(item)
    if currentItemStockInNetwork.n and currentItemStockInNetwork.n > 0 then
        return currentItemStockInNetwork[1].size
    end
    return 0
end
local function _getCraftable(self)
    for _, craftable in pairs(self.interface.getCraftables()) do
        if _itemEquals(self.targetItem, craftable.getItemStack()) then
            return craftable
        end
    end
    return nil
end

function MeAutoStock:autoStock()
    if self.currentJob ~= nil then
        if self.currentJob.job.isDone() or self.currentJob.job.isCanceled() then
            self.currentJob = nil
        else
            print(string.format(
                "already crafting '%s' for %d",
                self.targetItem.label,
                os.time() - self.currentJob.startTime
            ))
            return
        end
    end
    local currentSize = _getCurrentItemsInNetwork(self, self.targetItem)
    local stackThreshold = self.autoStockSizeModel.get()
    local amountToAutoCraft = stackThreshold - currentSize
    if amountToAutoCraft <= 0 then
        print(string.format(
            "enough of '%s' - no need for auto stock (got %d but threshold is %d)",
            self.targetItem.label,
            currentSize,
            stackThreshold
        ))
        return
    end

    for _, minSourceItem in pairs(self.minSourceItems) do
        local currentCount = _getCurrentItemsInNetwork(self, minSourceItem.item)
        local minSourceItemCount = minSourceItem.min.get()
        if currentCount < minSourceItemCount then
            print(string.format(
                "not enough source '%s' for auto stocking '%s' (required %d but was %d)",
                minSourceItem.item.label,
                self.targetItem.label,
                minSourceItemCount,
                currentCount
            ))
            return
        end
    end

    -- demand one new item
    local craftable = _getCraftable(self)
    if craftable == nil then
        print("no craftable found for '" .. self.targetItem.label .. "'")
        return
    end
    self.currentJob = {
        job = craftable.request(amountToAutoCraft),
        startTime = os.time()
    }
    print(string.format(
        "started auto stock for '%s' (%s items)",
        self.targetItem.label,
        amountToAutoCraft
    ))
end

return MeAutoStock
