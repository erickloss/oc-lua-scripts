local function item(label, name)
    return {
        label = label,
        name = name
    }
end

return {
    minecraft = {
        sand = item("Sand", "minecraft:sand"),
        redstone = item("Redstone", "minecraft:redstone"),
    },
    enderio = {
        silicon = item("Silicon", "enderio:item_material")
    },
    ae2 = {
        chargedCertusQuartzCrystal = item("Charged Certus Quartz Crystal", "appliedenergistics2:material"),
        certusQuartzCrystal = item("Certus Quartz Crystal", "appliedenergistics2:material"),
        calculationProcessor = item("Calculation Processo", "appliedenergistics2:material"),
    }
}
