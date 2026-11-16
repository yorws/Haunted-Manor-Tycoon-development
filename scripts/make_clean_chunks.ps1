$splits = @(
    @{ Name = "sync_part_combat_data_eco_drop_monet.luau"; Files = @(
        @{ F = "src/ServerScriptService/Services/CombatService.luau"; T = 'game:GetService("ServerScriptService").Services.CombatService' },
        @{ F = "src/ServerScriptService/Services/DataService.luau"; T = 'game:GetService("ServerScriptService").Services.DataService' },
        @{ F = "src/ServerScriptService/Services/EconomyService.luau"; T = 'game:GetService("ServerScriptService").Services.EconomyService' },
        @{ F = "src/ServerScriptService/Services/ItemDropService.luau"; T = 'game:GetService("ServerScriptService").Services.ItemDropService' },
        @{ F = "src/ServerScriptService/Services/MonetizationService.luau"; T = 'game:GetService("ServerScriptService").Services.MonetizationService' }
    )},
    @{ Name = "sync_part_monster.luau"; Files = @(
        @{ F = "src/ServerScriptService/Services/MonsterService.luau"; T = 'game:GetService("ServerScriptService").Services.MonsterService' }
    )},
    @{ Name = "sync_part_plot.luau"; Files = @(
        @{ F = "src/ServerScriptService/Services/PlotService.luau"; T = 'game:GetService("ServerScriptService").Services.PlotService' }
    )},
    @{ Name = "sync_part_shop_visitor_world_servermain.luau"; Files = @(
        @{ F = "src/ServerScriptService/Services/ShopService.luau"; T = 'game:GetService("ServerScriptService").Services.ShopService' },
        @{ F = "src/ServerScriptService/Services/VisitorService.luau"; T = 'game:GetService("ServerScriptService").Services.VisitorService' },
        @{ F = "src/ServerScriptService/Services/WorldService.luau"; T = 'game:GetService("ServerScriptService").Services.WorldService' },
        @{ F = "src/ServerScriptService/ServerMain.server.luau"; T = 'game:GetService("ServerScriptService").ServerMain' }
    )},
    @{ Name = "sync_part_client_combat_plot.luau"; Files = @(
        @{ F = "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau"; T = 'game:GetService("StarterPlayer").StarterPlayerScripts.ClientMain' },
        @{ F = "src/StarterPlayer/StarterPlayerScripts/Controllers/CombatController.luau"; T = 'game:GetService("StarterPlayer").StarterPlayerScripts.Controllers.CombatController' },
        @{ F = "src/StarterPlayer/StarterPlayerScripts/Controllers/PlotController.luau"; T = 'game:GetService("StarterPlayer").StarterPlayerScripts.Controllers.PlotController' }
    )},
    @{ Name = "sync_part_core_upgrade_ui.luau"; Files = @(
        @{ F = "src/StarterPlayer/StarterPlayerScripts/Controllers/CoreUpgradeController.luau"; T = 'game:GetService("StarterPlayer").StarterPlayerScripts.Controllers.CoreUpgradeController' },
        @{ F = "src/StarterPlayer/StarterPlayerScripts/Controllers/UIController.luau"; T = 'game:GetService("StarterPlayer").StarterPlayerScripts.Controllers.UIController' }
    )}
)

foreach ($entry in $splits) {
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("local updated = {}")
    foreach ($item in $entry.Files) {
        $filePath = Join-Path (Get-Location) $item.F
        $content = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
        [void]$sb.AppendLine("do")
        [void]$sb.AppendLine("    local target = $($item.T)")
        [void]$sb.AppendLine("    target.Source = [==[")
        [void]$sb.Append($content)
        [void]$sb.AppendLine("]==]")
        [void]$sb.AppendLine("    table.insert(updated, target:GetFullName())")
        [void]$sb.AppendLine("end")
    }
    [void]$sb.AppendLine("return 'Synced (' .. #updated .. ' scripts): ' .. table.concat(updated, ', ')")
    
    $out = Join-Path (Get-Location) "scripts\$($entry.Name)"
    [System.IO.File]::WriteAllText($out, $sb.ToString(), [System.Text.Encoding]::UTF8)
    Write-Output "Generated $($entry.Name) ($($sb.Length) chars)"
}

