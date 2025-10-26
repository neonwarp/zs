Describe "z function" {
    BeforeAll {
        $env:ZS_DISABLE_PROMPT = 1
        $global:ZS_EXE_PATH = Join-Path $PSScriptRoot "zs-test.cmd"

        function Set-ZSStub {
            param([string]$Body)
            $content = "@echo off`r`nif ""%1""==""--add"" exit /b 0`r`n$Body`r`n"
            $content | Set-Content -Path $global:ZS_EXE_PATH -Encoding ASCII
        }

        Set-ZSStub -Body 'echo C:\MockPath'
        . "$PSScriptRoot\zs.ps1"

        New-Item -ItemType Directory -Path "C:\MockPath" -Force | Out-Null
    }

    BeforeEach {
        $script:StartLocation = Get-Location
    }

    AfterEach {
        Set-Location $script:StartLocation
    }

    It "Changes location when zs.exe returns a valid path" {
        z test
        (Get-Location).Path | Should -Be "C:\MockPath"
    }

    It "Does not change location when returned path does not exist" {
        Set-ZSStub -Body 'echo C:\DoesNotExist'
        $orig = (Get-Location).Path
        z something
        (Get-Location).Path | Should -Be $orig
    }

    It "Does not change location when zs.exe exit code is non-zero" {
        Set-ZSStub -Body "echo C:\MockPath`r`nexit /b 1"
        $orig = (Get-Location).Path
        z test
        (Get-Location).Path | Should -Be $orig
    }

    It "Handles path containing spaces" {
        $pathWithSpace = "C:\Mock Path"
        New-Item -ItemType Directory -Path $pathWithSpace -Force | Out-Null
        Set-ZSStub -Body 'echo C:\Mock Path'
        z spaced
        (Get-Location).Path | Should -Be $pathWithSpace
    }

    It "Leaves location unchanged when zs.exe returns blank output" {
        Set-ZSStub -Body "echo."
        $orig = (Get-Location).Path
        z blank
        (Get-Location).Path | Should -Be $orig
    }

    It "Can be invoked multiple times consecutively" {
        Set-ZSStub -Body 'echo C:\MockPath'
        z first
        z second
        (Get-Location).Path | Should -Be "C:\MockPath"
    }

    AfterAll {
        Remove-Item -Path "C:\MockPath" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $global:ZS_EXE_PATH -Force -ErrorAction SilentlyContinue
        Remove-Item Env:ZS_DISABLE_PROMPT -ErrorAction SilentlyContinue
    }
}