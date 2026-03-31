local M = {}
WowPoker.Menu = M

local G = WowPoker.Game
local L = WowPoker.L

function M.Init()
    -- Add "Invite to Poker" to right-click unit popup menus
    -- Using hooksecurefunc to avoid taint issues

    -- Try to hook into the dropdown menu system
    if UnitPopupButtons then
        UnitPopupButtons["WOWPOKER_INVITE"] = {
            text = L["INVITE_CONTEXT_MENU"],
            dist = 0,
        }

        -- Insert into PLAYER menu
        if UnitPopupMenus and UnitPopupMenus["PLAYER"] then
            table.insert(UnitPopupMenus["PLAYER"], #UnitPopupMenus["PLAYER"], "WOWPOKER_INVITE")
        end

        -- Insert into PARTY menu
        if UnitPopupMenus and UnitPopupMenus["PARTY"] then
            table.insert(UnitPopupMenus["PARTY"], #UnitPopupMenus["PARTY"], "WOWPOKER_INVITE")
        end

        -- Insert into FRIEND menu
        if UnitPopupMenus and UnitPopupMenus["FRIEND"] then
            table.insert(UnitPopupMenus["FRIEND"], #UnitPopupMenus["FRIEND"], "WOWPOKER_INVITE")
        end
    end

    -- Hook OnClick to detect our button
    if UnitPopup_OnClick then
        hooksecurefunc("UnitPopup_OnClick", function(self)
            local button = self.value or self:GetID()
            if not button then return end

            -- Get the button info
            local dropdownFrame = UIDROPDOWNMENU_OPEN_MENU or UIDROPDOWNMENU_INIT_MENU
            if not dropdownFrame then return end

            -- Check if our button was clicked
            local name = nil
            if self.value == "WOWPOKER_INVITE" then
                -- Get target name from the dropdown
                if dropdownFrame.name then
                    name = dropdownFrame.name
                elseif dropdownFrame.unit then
                    name = UnitName(dropdownFrame.unit)
                end
            end

            if name then
                G.SendInvite(name)
            end
        end)
    end

end
