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
        goldIngot = item("Gold Ingot", "minecraft:gold_ingot"),
        diamond = item("Diamond", "minecraft:diamond"),
        netherQuartz = item("Nether Quartz", "minecraft:quartz"),
    },
    enderio = {
        silicon = item("Silicon", "enderio:item_material"),
    },
    ae2 = {
        chargedCertusQuartzCrystal = item("Charged Certus Quartz Crystal", "appliedenergistics2:material"),
        certusQuartzCrystal = item("Certus Quartz Crystal", "appliedenergistics2:material"),
        fluixCrystal = item("Fluix Crystal", "appliedenergistics2:material"),
        pureFluixCrystal = item("Pure Fluix Crystal", "appliedenergistics2:material"),
        pureNetherQuartzCrystal = item("Pure Nether Quartz Crystal", "appliedenergistics2:material"),
        pureCertusQuartzCrystal = item("Pure Certus Quartz Crystal", "appliedenergistics2:material"),
        calculationProcessor = item("Calculation Processor", "appliedenergistics2:material"),
        logicProcessor = item("Logic Processor", "appliedenergistics2:material"),
        engineeringProcessor = item("Engineering Processor", "appliedenergistics2:material"),
    }
}
