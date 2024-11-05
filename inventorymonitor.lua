addon.author = 'Fyayu'
addon.name = 'InventoryMonitor'
addon.version = '0.8'
addon.desc = 'Monitor your inventory and Wardrobes to make sure you never run out of supplies'

require('common')
local imgui = require('imgui')
local settings = require('settings')

local defaultConfig = T{
	items = {},
    charges = {},
    font_size = 1.0 -- Default font scale (1.0 means 100% scale)
}
local item_settings = settings.load(defaultConfig);

-- Variables for user input
local new_item_id = { "" }
local new_item_limit_red = { "" }
local new_item_limit_yellow = { "" }
local new_charge_id = { "" }
local item_to_remove = { "" }
local charge_to_remove = { "" }

local config_visible = false

local font_size = { item_settings.font_size or 1}  -- Default font size if not already set

-- Constants and pointers
local vanaOffset = 0x3C307D70
local timePointer = ashita.memory.find('FFXiMain.dll', 0, '8B0D????????8B410C8B49108D04808D04808D04808D04C1C3', 2, 0)

-- Define containers to search (main inventory, mog satchel, and mog wardrobes)
local containers = {0, 8, 10, 5, 16} -- 5 for Mog Satchel

-- Initialize item counts and charges
local item_counts = {}
local item_charges = {}

-- Time management variables
local last_update_time = os.time()
local update_interval = 5 -- Update every 5 seconds

-- Function to get the count of an item across containers
local function get_item_count(item_id)
    local total_count, mog_satchel_count = 0, 0

    for _, container in ipairs(containers) do
        for i = 0, 80 do
            local item = AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(container, i)
            if item and item.Id == item_id then
                if container == 5 then -- Mog Satchel
                    mog_satchel_count = mog_satchel_count + item.Count
                else
                    total_count = total_count + item.Count
                end
            end
        end
    end

    return total_count, mog_satchel_count
end

-- Function to get UTC time
local function GetTimeUTC()
    local ptr = ashita.memory.read_uint32(timePointer)
    ptr = ashita.memory.read_uint32(ptr)
    return ashita.memory.read_uint32(ptr + 0x0C)
end

-- Function to inspect item data (charges, ready status, and remaining time)
local function get_item_charges(item)
    if not item or not item.Extra then
        return nil, false, "No item or extra data available.", 0
    end

    local currentTime = GetTimeUTC()
    local charges = struct.unpack('B', item.Extra, 2) -- Charges at byte 2
    local flags = (struct.unpack('L', item.Extra, 5) + vanaOffset) - currentTime
    local ready = (flags < 0) -- Ready if flags < 0
    local timeRemainingOnCharge = ready and 0 or flags -- Time remaining in seconds until the charge is ready

    return charges, ready, timeRemainingOnCharge
end

-- Function to get total charges, check if any charge is ready, and return remaining time
local function get_item_total_charges(item_id)
    local total_charges, is_ready, min_time_remaining = 0, false, nil -- Store the minimum time remaining for any charge

    for _, container in ipairs(containers) do
        for i = 0, 80 do
            local item = AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(container, i)
            if item and item.Id == item_id then
                local charges, ready, time_remaining = get_item_charges(item)
                total_charges = total_charges + (tonumber(charges) or 0)

                if ready then
                    is_ready = true -- Set flag to true if any items are ready
                elseif not min_time_remaining or time_remaining < min_time_remaining then
                    min_time_remaining = time_remaining -- Track the smallest time remaining
                end
            end
        end
    end

    return total_charges, is_ready, min_time_remaining
end

-- Function to update the item counts and charges
local function update_item_counts()
    -- Update item counts from the settings
    for _, item in ipairs(item_settings.items) do
        local item_id = item.id
        local count, mog_satchel_count = get_item_count(item_id)

        -- Retrieve item name using the ID
        local item_data = AshitaCore:GetResourceManager():GetItemById(item_id)
        local item_name = item_data and item_data.Name[1] or "Unknown"

        item_counts[item_id] = {
            count = count,
            mog_satchel_count = mog_satchel_count,
            display_name = item_name,
            limits = item.limits
        }
    end

    -- Update charges based on the charge settings
    for _, charge_item in ipairs(item_settings.charges) do
        local charge_item_id = charge_item.id
        local total_charges, is_ready, time_remaining = get_item_total_charges(charge_item_id)

        -- Retrieve item name using the ID
        local item_data = AshitaCore:GetResourceManager():GetItemById(charge_item_id)
        local item_name = item_data and item_data.Name[1] or "Unknown"

        item_charges[charge_item_id] = {
            charges = total_charges,
            ready = is_ready,
            time_remaining = time_remaining,
            display_name = item_name
        }
    end
end

-- Event handlers
ashita.events.register('load', 'addon_load_cb', function()
    print("InventoryMonitor addon loaded.")
end)

local is_zoning = false

ashita.events.register('zone', 'zone_cb', function()
    is_zoning = true -- Set zoning state to true when zoning starts
    item_counts = {} -- Reset item counts
    item_charges = {} -- Reset charges
end)

ashita.events.register('zone_complete', 'zone_complete_cb', function()
    is_zoning = false -- Reset zoning state when zoning is complete
end)

-- Helper function to format time remaining as HH:MM:SS
local function format_time_remaining(seconds)
    if not seconds or seconds <= 0 then
        return ""
    end

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    seconds = math.floor(seconds % 60)

    return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

-- Rendering loop
ashita.events.register('d3d_present', 'd3d_present_cb', function()
    local current_time = os.time()


    -- Update item counts every 5 seconds if not zoning
    if not is_zoning and (current_time - last_update_time) >= update_interval then
        update_item_counts()
        last_update_time = current_time
    end
    -- Set window properties
    imgui.SetNextWindowBgAlpha(0.8)

    -- Begin ImGui window with auto-resize flag
    imgui.Begin("Inventory Monitor", false, ImGuiWindowFlags_AlwaysAutoResize)
    -- Set the font size for this window
    imgui.SetWindowFontScale(item_settings.font_size)
    -- Check if item_counts is empty and display loading message
    if next(item_counts) == nil then
        imgui.TextColored({1.0, 1.0, 0.0, 1.0}, "Loading...") -- Yellow loading message
         imgui.Text("                          ")
    else
        -- Consumables Table
        imgui.Text("---------------- Consumables ----------------")
        imgui.Separator()

        -- Set up columns for item display, including an optional "Remove" column when config_visible is true
        local num_columns = config_visible and 4 or 3
        imgui.Columns(num_columns, "ItemTable", true)
        --imgui.SetColumnWidth(0, 200) -- Item Name width
        --imgui.SetColumnWidth(1, 100) -- Inventory Count width
        --imgui.SetColumnWidth(2, 100) -- Satchel Count width

        -- Column Headers
        imgui.Text("Item Name")
        imgui.NextColumn()
        imgui.Text("Inventory")
        imgui.NextColumn()
        imgui.Text("Satchel")
        imgui.NextColumn()
        if config_visible then
            imgui.Text("")
            imgui.NextColumn()
        end
        imgui.Separator()

        -- Populate Consumables in the order defined in settings
        for i, item in ipairs(item_settings.items) do
            local item_id = item.id
            local data = item_counts[item_id]

            if data then
                local limits = data.limits
                local mog_satchel_display = data.mog_satchel_count > 0 and data.mog_satchel_count or ""
                local display_count = data.count

                -- Determine color based on item count and specified limits
                local color = {0.0, 1.0, 0.0, 1.0} -- Default to green
                if data.count + data.mog_satchel_count <= limits.red then
                    color = {1.0, 0.5, 0.0, 1.0} -- Orange
                elseif data.count + data.mog_satchel_count <= limits.yellow then
                    color = {1.0, 1.1, 0.0, 1.0} -- Yellow
                end

                imgui.TextColored(color, data.display_name) -- Item Name
                imgui.NextColumn()
                imgui.TextColored(color, tostring(display_count)) -- Count
                imgui.NextColumn()
                imgui.TextColored(color, tostring(mog_satchel_display)) -- Mog Satchel Count
                imgui.NextColumn()

                if config_visible then
                    -- Render "X" button to remove item
                    if imgui.Button("X##item_" .. tostring(i)) then
                        table.remove(item_settings.items, i)
                        settings.save() -- Save updated settings
                        print("Item removed: ID " .. item_id)
                    end
                    imgui.NextColumn()
                end
            end
        end

        imgui.Columns(1) -- End the columns for the item counts

        if config_visible then
            imgui.Text("                                                                  ")
            imgui.Text("---- Add New Item ----")
            imgui.InputText("Item ID", new_item_id, 32)
            imgui.InputText("Critical Limit", new_item_limit_red, 32)
            imgui.InputText("Warning Limit", new_item_limit_yellow, 32)

            if imgui.Button("Add Item") then
                local item_id = tonumber(new_item_id[1])
                local limit_red = tonumber(new_item_limit_red[1])
                local limit_yellow = tonumber(new_item_limit_yellow[1])

                if item_id and limit_red and limit_yellow then
                    table.insert(item_settings.items, {id = item_id, limits = {red = limit_red, yellow = limit_yellow}})
                    settings.save() -- Save updated settings
                    print("Item added and saved: ID " .. item_id)
                else
                    print("Invalid item ID or limits.")
                end
            end
        end

        imgui.Separator()
        imgui.Text("")
        -- Equipment Charges Table
        imgui.Text("------------- Equipment Charges -------------")
        imgui.Separator()
        -- Set up columns for charge display, including an optional "Remove" column when config_visible is true
        num_columns = config_visible and 4 or 3
        imgui.Columns(num_columns, "ChargeTable", true)
        --imgui.SetColumnWidth(0, 200) -- Charge Name width
        --imgui.SetColumnWidth(1, 100) -- Charges width
        --imgui.SetColumnWidth(2, 200) -- Status width

        -- Column Headers
        imgui.Text("Charge Name")
        imgui.NextColumn()
        imgui.Text("Charges")
        imgui.NextColumn()
        imgui.Text("Status")
        imgui.NextColumn()
        if config_visible then
            imgui.Text("")
            imgui.NextColumn()
        end
        imgui.Separator()

        -- Populate Charges in the order defined in settings
        for i, charge_item in ipairs(item_settings.charges) do
            local charge_item_id = charge_item.id
            local charge_data = item_charges[charge_item_id]

            if charge_data then
                local status_text
                local color

                -- If no charges, show "No Charges"
                if charge_data.charges == 0 then
                    status_text = "No Charges"
                    color = {1.0, 0.5, 0.0, 1.0} -- Orange for no charges
                elseif charge_data.ready then
                    status_text = "Ready"
                    color = {0.0, 1.0, 1.0, 1.0} -- Cyan if ready
                else
                    -- Display time remaining until next charge is ready
                    status_text = format_time_remaining(charge_data.time_remaining)
                    color = {0.0, 1.0, 0.0, 1.0} -- Green if not ready
                end

                imgui.TextColored(color, charge_data.display_name) -- Charge Name
                imgui.NextColumn()
                imgui.TextColored(color, tostring(charge_data.charges)) -- Charges
                imgui.NextColumn()
                imgui.TextColored(color, status_text) -- Status (or time remaining)
                imgui.NextColumn()

                if config_visible then
                    -- Render "X" button to remove charge
                    if imgui.Button("X##charge_" .. tostring(i)) then
                        table.remove(item_settings.charges, i)
                        settings.save() -- Save updated settings
                        print("Charge removed: ID " .. charge_item_id)
                    end
                    imgui.NextColumn()
                end
            end
        end
        imgui.Columns(1) -- End the columns for the charges



        -- If config_visible is true, show the configuration section
        if config_visible then
            -- Add new charge input section
            imgui.Text("---- Add New Charge ----")
            imgui.InputText("Charge ID", new_charge_id, 32)
            if imgui.Button("Add Charge") then
                local charge_id = tonumber(new_charge_id[1])
                if charge_id then
                    table.insert(item_settings.charges, {id = charge_id})
                    settings.save() -- Save updated settings
                    print("Charge added and saved: ID " .. charge_id)
                else
                    print("Invalid charge ID.")
                end
            end
            imgui.Separator()
            imgui.Text("")
            -- Define the font size setting in a table
            imgui.Text("Adjust Font Size")
            if imgui.SliderFloat("Font Size", font_size, 0.5, 1.5) then
                item_settings.font_size = font_size[1]
                settings.save() -- Save the updated font size in settings
            end
        end
        imgui.Separator()
        imgui.Text("")
        -- Display Config button

        if imgui.Button("Config") then
            config_visible = not config_visible -- Toggle the visibility of the config section
        end
    end


    imgui.End() -- End the ImGui window
end)

-- Called when the addon is unloaded
ashita.events.register('unload', 'addon_unload_cb', function()
    print("InventoryMonitor addon unloaded.")
end)

settings.register('settings', 'settings_update', function (s)
    if (s ~= nil) then
        item_settings = s;
    end
end);
