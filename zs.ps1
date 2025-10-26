if (-not $global:ZS_EXE_PATH) {
    $global:ZS_EXE_PATH = "C:\zs\zs.exe"
}

$global:ZS_LastPath = $null

if (-not $global:OriginalPrompt) {
    $global:OriginalPrompt = $function:prompt
}

function z {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Arg
    )

    $result = & $global:ZS_EXE_PATH $Arg

    if ([string]::IsNullOrWhiteSpace($result)) {
        Write-Host "No match for '$Arg'"
        return
    }

    $result = $result.Trim()

    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $result)) {
        Set-Location -LiteralPath $result
    }
    else {
        Write-Host "No match for '$Arg'"
    }
}

function global:prompt {
    if ($global:OriginalPrompt) {
        & $global:OriginalPrompt
    }

    $current = (Get-Location).ProviderPath
    if ($global:ZS_LastPath -ne $current) {
        $global:ZS_LastPath = $current
        try {
            & $global:ZS_EXE_PATH --add $current | Out-Null
        }
        catch {
            Write-Debug "Failed to add path to ZS: $_"
        }
    }

    return "$(Get-Location)> "
}