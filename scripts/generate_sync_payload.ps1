$groups = @{
    "batch1_replicated" = @(
        @{ File = "src/ReplicatedStorage/Config/BalanceConfig.luau"; Target = 'game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("BalanceConfig")' },
        @{ File = "src/ReplicatedStorage/Config/MonetizationConfig.luau"; Target = 'game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("MonetizationConfig")' },
        @{ File = "src/ReplicatedStorage/Modules/Network.luau"; Target = 'game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Network")' },
        @{ File = "src/ReplicatedStorage/Modules/Types.luau"; Target = 'game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Types")' }
    );
    "batch2_services1" = @(
        @{ File = "src/ServerScriptService/Services/CombatService.luau"; Target = 'game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("CombatService")' },
        @{ File = "src/ServerScriptService/Services/DataService.luau"; Target = 'game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("DataService")' },
        @{ File = "src/ServerScriptService/Services/EconomyService.luau"; Target = 'game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("EconomyService")' },
        @{ File = "src/ServerScriptService/Services/ItemDropService.luau"; Target = 'game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("ItemDropService")' },
        @{ File = "src/ServerScriptService/Services/MonetizationService.luau"; Target = 'game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("MonetizationService")' },
        @{ File = "src/ServerScriptService/Services/MonsterService.luau"; Target = 'game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("MonsterService")' }
    );
    "batch3_services2" = @(
        @{ File = "src/ServerScriptService/Services/PlotService.luau"; Target = 'game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("PlotService")' },
        @{ File = "src/ServerScriptService/Services/ShopService.luau"; Target = 'game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("ShopService")' },
        @{ File = "src/ServerScriptService/Services/VisitorService.luau"; Target = 'game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("VisitorService")' },
        @{ File = "src/ServerScriptService/Services/WorldService.luau"; Target = 'game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("WorldService")' },
        @{ File = "src/ServerScriptService/ServerMain.server.luau"; Target = 'game:GetService("ServerScriptService"):WaitForChild("ServerMain")' }
    );
    "batch4_starterplayer" = @(
        @{ File = "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau"; Target = 'game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("ClientMain")' },
        @{ File = "src/StarterPlayer/StarterPlayerScripts/Controllers/CombatController.luau"; Target = 'game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers"):WaitForChild("CombatController")' },
        @{ File = "src/StarterPlayer/StarterPlayerScripts/Controllers/CoreUpgradeController.luau"; Target = 'game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers"):WaitForChild("CoreUpgradeController")' },
        @{ File = "src/StarterPlayer/StarterPlayerScripts/Controllers/PlotController.luau"; Target = 'game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers"):WaitForChild("PlotController")' },
        @{ File = "src/StarterPlayer/StarterPlayerScripts/Controllers/UIController.luau"; Target = 'game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers"):WaitForChild("UIController")' }
    )
}

foreach ($name in $groups.Keys) {
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("-- Batch sync: $name")
    [void]$sb.AppendLine("local updated = {}")
    foreach ($item in $groups[$name]) {
        $filePath = Join-Path (Get-Location) $item.File
        $content = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
        [void]$sb.AppendLine("do")
        [void]$sb.AppendLine("    local target = $($item.Target)")
        [void]$sb.AppendLine("    target.Source = [==[")
        [void]$sb.Append($content)
        [void]$sb.AppendLine("]==]")
        [void]$sb.AppendLine("    table.insert(updated, target:GetFullName())")
        [void]$sb.AppendLine("end")
    }
    [void]$sb.AppendLine("return 'Synced batch $name (' .. #updated .. ' scripts): ' .. table.concat(updated, ', ')")
    
    $outPath = Join-Path (Get-Location) "scripts\${name}.luau"
    [System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::UTF8)
    Write-Output "Wrote $outPath ($($sb.Length) chars)"
}
