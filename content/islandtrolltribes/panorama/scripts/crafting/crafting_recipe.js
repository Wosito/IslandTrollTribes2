function InstantiateCraftingRecipe(panel) {
    var entity = panel.entity
    var ingredients = panel.ingredients
    var table = panel.table
    var section_name = panel.section_name
    var itemResult = panel.itemname
    var aliasTable = CustomNetTables.GetTableValue( "crafting", "Alias" )

    for (var i = 0; i < ingredients.length; i++) {
        MakeItemPanel(panel, ingredients[i], ingredients.length)
    };

    var equal = $.CreatePanel("Label", panel, "EqualSign")
    equal.text = "="

    // Resulting from craft
    var resultPanel = MakeItemPanel(panel, itemResult, 0)
    panel.entity = entity

    // Think glows and craft state
    //CheckInventory(panel, resultPanel)

    $.Msg("Instantiated Crafting Recipe: "+itemResult)
}

function MakeItemPanel(parent, name, elements) {
    var itemPanel = $.CreatePanel("Panel", parent, name)
    itemPanel.itemname = name
    itemPanel.elements = elements

    //itemPanel.BLoadLayout("file://{resources}/layout/custom_game/crafting/crafting_item.xml", false, false);
    itemPanel.BLoadLayoutSnippet("Crafting_Item")

    //Instantiate Item
    $.Msg("Instantiated Crafting Item: "+name)

    return itemPanel
}

function CheckInventory(panel)
{
    // Build an array of items in inventory 
    var itemsOnInventory = []

    for (var i = 0; i < 6; i++) {
        var item = Entities.GetItemInSlot(panel.entity, i)
        if (item)
        {
            var item_name = Abilities.GetAbilityName(item)
            if (item_name !== undefined && item_name != "item_slot_locked")
            {
                var charges = Items.GetCurrentCharges(item)
                if (charges > 1)
                {
                    for (var x = 0; x < charges; x++) {
                        itemsOnInventory.push(item_name)
                    };
                }
                else
                    itemsOnInventory.push(item_name)
            }
        }
    };

    if (panel.visible)
    {
        var meetsAllRequirements = true
        var childNum = panel.GetChildCount()
        for (var i = 0; i < childNum; i++) {
            var child = panel.GetChild(i)
            if (child.itemname !== undefined && child.itemname != itemResult)
            {
                var itemIndex = FindItemInArray(child.itemname, itemsOnInventory)
                if (itemIndex > -1)
                {
                    itemsOnInventory.splice(itemIndex, 1)
                    AddGlow(child)
                }
                else
                {
                    meetsAllRequirements = false
                    RemoveGlow(child)
                }
            }
        };
    }

    if (meetsAllRequirements)
        GlowCraft(resultPanel)
    else
        RemoveGlowCraft(resultPanel)

    $.Schedule(1, CheckInventory)
}

// Search for an item by name taking alias into account
function FindItemInArray(itemName, itemList) {
    for (var index in itemList)
    {
        if (itemList[index] == itemName)
        {
            return index
        }
        else if (MatchesAlias(itemName, itemList[index]))
        {
            return index
        }
    }
    return -1
}

function MatchesAlias( aliasName, targetItemName ) {
    if (aliasName.indexOf("any_") > -1)
    {
        for (var itemName in aliasTable[aliasName])
        {
            if (itemName==targetItemName)
            {
                return true
            }
        }
    }
    return false
}

function AddGlow(panel) {
    panel.AddClass("GlowGold");
}

function RemoveGlow(panel) {
    panel.RemoveClass("GlowGold");
}

function GlowCraft(panel) {
    panel.SetPanelEvent('onactivate', SendCraft)

    panel.AddClass("GlowGreen");
    panel.craft = true //Show a craft button when hovering
}

function SendCraft() {
    GameEvents.SendCustomGameEventToServer( "craft_item", {itemname: itemResult, section: section_name, entity: entity} );
}

function RemoveGlowCraft(panel) {  
    panel.ClearPanelEvent('onactivate')
    panel.craft = false
    panel.RemoveClass("GlowGreen");
}