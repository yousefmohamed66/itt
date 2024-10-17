param (
    [string]$OutputScript = "itt.ps1",
    [string]$readme = "README.md",
    [string]$Assets = ".\Resources",
    [string]$Controls = ".\UI\Controls",
    [string]$DatabaseDirectory = ".\Resources\Database",
    [string]$StartScript = ".\Initialize\start.ps1",
    [string]$MainScript = ".\Initialize\main.ps1",
    [string]$ScritsDirectory = ".\Scripts",
    [string]$windows = ".\UI\Views",
    [string]$LoadXamlScript = ".\Initialize\xaml.ps1",
    [string]$Themes = "Themes",
    [switch]$Debug,
    [switch]$code,
    [string]$ProjectDir = $PSScriptRoot,
    [string]$localNodePath = "releasenotes.md",
    [string]$NoteUrl = "https://raw.githubusercontent.com/emadadel4/ITT/refs/heads/main/Changelog.md"


)

# Initializeialize synchronized hashtable
$itt = [Hashtable]::Synchronized(@{})
$itt.database = @{}
$imageLinkMap = @{}
$global:extractedContent = ""


function Update-Progress {
    param (
        [Parameter(Mandatory, position=0)]
        [string]$Status,

        [Parameter(Mandatory, position=1)]
        [ValidateRange(0,100)]
        [int]$PercentComplete ,

        [Parameter(position=2)]
        [string]$Activity = "Building"
    )

    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete 

}

# write content to output script
function WriteToScript {
    param (
        [string]$Content
    )
    $streamWriter = $null
    try {
        $streamWriter = [System.IO.StreamWriter]::new($OutputScript, $true)
        $streamWriter.WriteLine($Content)
    }
    finally {
        if ($null -ne $streamWriter) {
            $streamWriter.Dispose()
        }
    }
}

# Replace placeholder function
function ReplaceTextInFile {
    param (
        [string]$FilePath,
        [string]$TextToReplace,
        [string]$ReplacementText
    )

    Write-Host "Replace Placeholder" -ForegroundColor Yellow
    Update-Progress "$($MyInvocation.MyCommand.Name)" 30
    
    # Read the content of the file
    $content = Get-Content $FilePath

    # Replace the text
    $newContent = $content -replace [regex]::Escape($TextToReplace), $ReplacementText

    # Write the modified content back to the file
    $newContent | Out-File -FilePath $FilePath -Encoding utf8
}

# handle file content generation
function AddFileContentToScript {
    param (
        [string]$FilePath
    )
    
    $Content = Get-Content -Path $FilePath -Raw
    WriteToScript -Content $Content
}

# process files in a directory
function ProcessDirectory {
    param (
        [string]$Directory
    )
    
    Get-ChildItem $Directory -Recurse -File | ForEach-Object {
        if ($_.DirectoryName -ne $Directory) {
            AddFileContentToScript -FilePath $_.FullName
        }
    }
}

# Generate Checkboxex apps/tewaks/settings
function GenerateCheckboxes {
    param (
        [array]$Items,
        [string]$ContentField,
        [string]$TagField = "",
        [string]$TipsField = "",
        [string]$IsCheckedField = "",
        [string]$ToggleField = "",
        [string]$NameField = ""
    )

    $Checkboxes = ""

    foreach ($Item in $Items) {
        # Clean description and category to remove special characters
        $CleanedDescription = $Item.Description -replace '[^\w\s.]', ''
        $CleanedCategory = $Item.Category -replace '[^\w\s]', ''

        # Get content from the specified content field
        $Content = $Item.$ContentField

        # Optional attributes for CheckBox based on fields
        $Tag = if ($TagField) { "Tag=`"$($Item.$TagField)`"" } else { "" }
        $Tips = if ($TipsField) { "ToolTip=`"Install it again to update. If there is an issue with the program, please report the problem on the GitHub repository.`"" } else { "" }
        $Name = if ($NameField) { "Name=`"$($Item.$NameField)`"" } else { "" }
        $Toggle = if ($ToggleField) { "Style=`"{StaticResource ToggleSwitchStyle}`"" } else { "" }
        $IsChecked = if ($IsCheckedField) { "IsChecked=`"$($Item.$IsCheckedField)`"" } else { "" }

        # Build the CheckBox and its container
        $Checkboxes += @"
        <StackPanel Orientation="Vertical" Width="auto" Margin="10">
            <StackPanel Orientation="Horizontal">
                <CheckBox Content="$Content" $Tag $IsChecked $Toggle $Name $Tips FontWeight="SemiBold" FontSize="15" Foreground="{DynamicResource TextColorSecondaryColor}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                <Label HorizontalAlignment="Center" VerticalAlignment="Center" Margin="5,0,0,0" FontSize="13" Content="$CleanedCategory"/>
            </StackPanel>
            <TextBlock Width="555" Background="Transparent" Margin="8" Foreground="{DynamicResource TextColorSecondaryColor2}" FontSize="15" FontWeight="SemiBold" VerticalAlignment="Center" TextWrapping="Wrap" Text="$CleanedDescription."/>
        </StackPanel>
"@
    }
    return $Checkboxes
}

# Process each JSON file in the specified directory
function Sync-JsonFiles {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DatabaseDirectory,
        [Parameter(Mandatory = $true)]
        [string]$OutputScriptPath
    )

    Get-ChildItem $DatabaseDirectory | Where-Object {$_.extension -eq ".json"} | ForEach-Object {
        $json = (Get-Content $_.FullName -Raw).replace("'", "''")
        $itt.database.$($_.BaseName) = $json | ConvertFrom-Json
        Write-Output "`$itt.database.$($_.BaseName) = '$json' | ConvertFrom-Json" | Out-File $OutputScriptPath -Append -Encoding default
    }
}

# Update app tweaks etc count.. from README.MD
function Update-Readme {
    param (
        [string]$OriginalReadmePath = "Templates\README.md",
        [string]$NewReadmePath = "README.md",
        [string]$Apps,
        [string]$Tewaks,
        [string]$Quote,
        [string]$Track,
        [string]$Settings,
        [string]$Localization

    )

    # Read the content of the original README.md file
    $readmeContent = Get-Content -Path $OriginalReadmePath -Raw

    # Replace multiple placeholders with the new content
    $updatedContent = $readmeContent -replace "#{a}", $Apps `
    -replace "#{t}", $Tewaks `
    -replace "#{q}", $Quote `
    -replace "#{OST}", $Track `
    -replace "#{s}", $Settings `
    -replace "#{loc}", $Localization

    # Write the updated content to the new README.md file
    Set-Content -Path $NewReadmePath -Value $updatedContent
}

# Add New Contributor to Contributor.md and show his name in about window
function NewCONTRIBUTOR {
  
    # Define paths
    $gitFolder = ".git"
    $contribFile = "CONTRIBUTORS.md"
    $xamlFile = "Templates\about.xaml"
    $updatedXamlFile = "UI\Views\AboutWindow.xaml" 


    Update-Progress "Check for new contributor " 40


    # Function to get GitHub username from .git folder
    function Get-GitHubUsername {
        $configFile = Join-Path $gitFolder "config"
        
        if (Test-Path $configFile) {
            $configContent = Get-Content $configFile -Raw
            if ($configContent -match 'url\s*=\s*https?://github.com/([^/]+)/') {
                return $matches[1]
            }
        }
        return $null
    }

    # Get GitHub username
    $username = Get-GitHubUsername

    if (-not $username) {
        Write-Error "GitHub username not found in .git/config."
        exit 1
    }

    # Read CONTRIBUTORS.md content and ensure username is unique
    if (Test-Path $contribFile) {
        $contribLines = Get-Content $contribFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" } | Sort-Object -Unique
        if ($contribLines -notcontains $username) {
            Add-Content $contribFile $username
            $contribLines += $username
        }
    } else {
        # Create CONTRIBUTORS.md if it doesn't exist and add the username
        Set-Content $contribFile $username
        $contribLines = @($username)
    }

    # Read the existing XAML file content
    $MainXamlContent = Get-Content $xamlFile -Raw

    # Generate unique TextBlock elements for each name in CONTRIBUTORS.md
    $textBlockElements = $contribLines | ForEach-Object {
        "<TextBlock Text='$($_)' Margin='1' Foreground='{DynamicResource TextColorSecondaryColor2}' />"
    }

    # Join TextBlock elements with newline characters
    $textBlockContent = $textBlockElements -join "`r`n"

    # Replace #{names} in the XAML file with the TextBlock elements
    $newXamlContent = $MainXamlContent -replace '#{names}', $textBlockContent

    # Write the updated content to the new XAML file
    Set-Content -Path $updatedXamlFile -Value $newXamlContent -Encoding UTF8
}

# Display the number of items in json files
function CountItems {
    # Store the counts in variables for reuse
    $appsCount = $itt.database.Applications.Count
    $tweaksCount = $itt.database.Tweaks.Count
    $quotesCount = $itt.database.Quotes.Quotes.Count
    $tracksCount = $itt.database.OST.Tracks.Count
    $settingsCount = $itt.database.Settings.Count
    $localizationCount = ($itt.database.locales.Controls.PSObject.Properties | Measure-Object).Count

    # Output all the counts in one call
    Write-Host "`n$appsCount Apps`n$tweaksCount Tweaks`n$quotesCount Quotes`n$tracksCount Tracks`n$settingsCount Settings`n$localizationCount Localization" -ForegroundColor Yellow

    # Update the readme with the new counts
    Update-Readme -Apps $appsCount -Tweaks $tweaksCount -Quote $quotesCount -Track $tracksCount -Settings $settingsCount -Localization $localizationCount
}

function ConvertTo-Xaml {
    param (
        [string]$text,
        [string]$HeadlineFontSize = 20,
        [string]$DescriptionFontSize = 15

    )

    Write-Host "Generate Events Window Content...." -ForegroundColor Yellow

    # Initialize XAML as an empty string
    $xaml = ""

    # Process each line of the input text
    foreach ($line in $text -split "`n") {
        switch -Regex ($line) {
            "!\[itt\.xName:(.+?)\s*\[(.+?)\]\]\((.+?)\)" {
                $xaml += "<Image x:Name=''$($matches[1].Trim())'' Source=''$($matches[3].Trim())'' Cursor=''Hand'' Margin=''0,0,0,0'' Height=''Auto'' Width=''400''/>`n"
                $link = $matches[2].Trim()   # Extract the link from inside the brackets
                $name = $matches[1].Trim()   # Extract the xName after 'tt.xName:'
                $imageLinkMap[$name] = $link
            }
            "^## (.+)" { # Event title
                $global:extractedContent += $matches[1].Trim() + "`n"
            }
            "^### (.+)" { # Headline 
                $text = $matches[1].Trim()
                $xaml += "<TextBlock Text=''$text'' FontSize=''$HeadlineFontSize'' Margin=''0,18,0,18'' FontWeight=''Bold'' Foreground=''{DynamicResource PrimaryButtonForeground}'' TextWrapping=''Wrap''/>`n"
            }
            "^##### (.+)" { ##### Headline
                $text = $matches[1].Trim()  
                $xaml += "<TextBlock Text='' • $text'' FontSize=''$HeadlineFontSize'' Margin=''0,18,0,18'' Foreground=''{DynamicResource PrimaryButtonForeground}'' FontWeight=''bold'' TextWrapping=''Wrap''/>`n" 
            }
            "^#### (.+)" { #### Description
                $text = $matches[1].Trim()  
                $xaml += "<TextBlock Text=''$text'' FontSize=''$DescriptionFontSize'' Margin=''8''  Foreground=''{DynamicResource TextColorSecondaryColor2}''  TextWrapping=''Wrap''/>`n" 
            }
            "^- (.+)" { # - Lists
                $text = $matches[1].Trim()  
                $xaml += "
                
                <StackPanel Orientation=''Vertical''>
                    <TextBlock Text=''• $text'' Margin=''15,0,0,0'' FontSize=''$DescriptionFontSize'' Foreground=''{DynamicResource TextColorSecondaryColor2}'' TextWrapping=''Wrap''/>
                </StackPanel>
                
                `n" 
            }
        }
    }

    return $xaml
}

function GenerateThemesInvoke   {
    param (
        [string]$ThemesPath = "Themes", # Path to the themes directory
        [string]$ITTFilePath = "itt.ps1" # Path to the ITT file
    )

    Update-Progress "$($MyInvocation.MyCommand.Name)" 50

    try {
        # Get menu items from files in the specified Themes directory
        $menuItems = Get-ChildItem -Path $ThemesPath -File | ForEach-Object {
            $filename = [System.IO.Path]::GetFileNameWithoutExtension($_.Name) # Get filename without extension
            $Key = $filename -replace '[^\w]', '' # Remove non-word characters

            # Create the MenuItem block
            @"
            "$Key" {
                Set-Theme -Theme `$action
                Debug-Message
            }
"@
        }

        # Read content from the ITT file
        $itta = Get-Content -Path $ITTFilePath -Raw

        # Join the menu items with newlines and replace placeholder in the file content
        $menuItemsOutput = $menuItems -join "`n"
        $itta = $itta -replace '#{themes}', $menuItemsOutput

        # Write updated content back to the ITT file
        Set-Content -Path $ITTFilePath -Value $itta
        Write-Host "Generate themes click events...." -ForegroundColor Yellow

    } catch {
        Write-Error "An error occurred: $($_.Exception.Message)"
    }
}

# Generate themes menu items
function GenerateThemesKeys {
    param (
        [string]$ThemesPath = "Themes"
    )

    # Validate the path
    if (-Not (Test-Path $ThemesPath)) {
        Write-Host "The specified path does not exist: $ThemesPath"
        return
    }

    # Generate MenuItem entries for each file in the themes folder
    $menuItems = Get-ChildItem -Path $ThemesPath -File | ForEach-Object {
        # Read the content of each file
        $content = Get-Content $_.FullName -Raw  # Read the entire file content

        # Use regex to extract content inside curly braces for Header
        if ($content -match '\{(.*?)\}') {
            $header = $matches[1]  # Extracted content inside {}
        } else {
            $header = "Unknown"  # Fallback if no match is found
        }

        # Use regex to extract x:Key value for Header2
        if ($content -match 'x:Key="(.*?)"') {
            $name = $matches[1]  # Extracted x:Key value
        } else {
            $header2 = "No Key"  # Fallback if no x:Key is found
        }

        # Create MenuItem entry with the extracted headers
        "<MenuItem Name=`"$name`" Header=`"$header`"/>"
    }

    # Join the MenuItems into a single string
    $menuItemsOutput = $menuItems -join "`n"
    return $menuItemsOutput
}

function GenerateClickEventHandlers {
    param (
        [string]$ITTFilePath = "itt.ps1"
    )

    Write-Host "Generate Click Event Handlers" -ForegroundColor Yellow
    Update-Progress "$($MyInvocation.MyCommand.Name)" 90

    foreach ($name  in $imageLinkMap.Keys) {

        $url = $imageLinkMap[$name]
        
        $EventHandler += "
        `$itt.event.FindName('$name').add_MouseLeftButtonDown({
                Start-Process('$url')
            })`
        "
    }

    $EventTitle = @"
        `$itt.event.FindName('title').text = '$global:extractedContent'`.Trim()
"@

    $itta = Get-Content -Path $ITTFilePath -Raw
    $menuItemsOutput = $menuItems -join "`n"
    $itta = $itta -replace '#{contorlshandler}', $EventHandler

    $itta = $itta -replace '#{title}', $EventTitle

    Set-Content -Path $ITTFilePath -Value $itta
}

# Write script header
function WriteHeader {

    WriteToScript -Content @"
######################################################################################
#      ___ _____ _____   _____ __  __    _    ____       _    ____  _____ _          #
#     |_ _|_   _|_   _| | ____|  \/  |  / \  |  _ \     / \  |  _ \| ____| |         #
#      | |  | |   | |   |  _| | |\/| | / _ \ | | | |   / _ \ | | | |  _| | |         #
#      | |  | |   | |   | |___| |  | |/ ___ \| |_| |  / ___ \| |_| | |___| |___      #
#     |___| |_|   |_|   |_____|_|  |_/_/   \_\____/  /_/   \_\____/|_____|_____|     #
#                Automatically generated from build don't play here :)               # 
#                              #StandWithPalestine                                   #
# https://github.com/emadadel4                                                       #
# https://t.me/emadadel4                                                             #
# https://emadadel4.github.io/posts/itt                                              #
######################################################################################
"@
}

# Main script generation
try {

    if (Test-Path -Path $OutputScript) {
        Remove-Item -Path $OutputScript -Force
    }

    WriteHeader
    WriteToScript -Content @"
#===========================================================================
#region Begin Start
#===========================================================================
"@

    AddFileContentToScript -FilePath $StartScript
    ReplaceTextInFile -FilePath $OutputScript -TextToReplace '#{replaceme}' -ReplacementText "$(Get-Date -Format 'MM/dd/yyy')"
    WriteToScript -Content @"
#===========================================================================
#endregion End Start
#===========================================================================
"@

    WriteToScript -Content @"
#===========================================================================
#region Begin Database /APPS/TWEEAKS/Quotes/OST/Settings
#===========================================================================
"@

    Sync-JsonFiles -DatabaseDirectory $DatabaseDirectory -OutputScriptPath $OutputScript

    WriteToScript -Content @"
#===========================================================================
#endregion End Database /APPS/TWEEAKS/Quotes/OST/Settings
#===========================================================================
"@

    # Write Main section
    WriteToScript -Content @"
#===========================================================================
#region Begin Main Functions
#===========================================================================
"@
    ProcessDirectory -Directory $ScritsDirectory

    GenerateThemesInvoke

    WriteToScript -Content @"
#===========================================================================
#endregion End Main Functions
#===========================================================================
"@

WriteToScript -Content @"
#===========================================================================
#region Begin WPF Main Window
#===========================================================================
"@

    # Define file paths
    $FilePaths = @{
        "MainWindow"    = Join-Path -Path $windows -ChildPath "MainWindow.xaml"
        "taps" = Join-Path -Path $Controls -ChildPath "taps.xaml"
        "menu" = Join-Path -Path $Controls -ChildPath "menu.xaml"
        "catagory" = Join-Path -Path $Controls -ChildPath "catagory.xaml"
        "search" = Join-Path -Path $Controls -ChildPath "search.xaml"
        "buttons" = Join-Path -Path $Controls -ChildPath "buttons.xaml"
        "Style"   = Join-Path -Path $Assets -ChildPath "Themes/Styles.xaml"
        "Colors"  = Join-Path -Path $Assets -ChildPath "Themes/Colors.xaml"
    }

    # Read and replace placeholders in XAML content
    try {
        # Read content from files
        $MainXamlContent     = (Get-Content -Path $FilePaths["MainWindow"] -Raw) -replace "'", "''"
        $AppXamlContent  = Get-Content -Path $FilePaths["taps"] -Raw
        $StyleXamlContent    = Get-Content -Path $FilePaths["Style"] -Raw
        $ColorsXamlContent   = Get-Content -Path $FilePaths["Colors"] -Raw
        $MenuXamlContent     = Get-Content -Path $FilePaths["menu"] -Raw
        $ButtonsXamlContent  = Get-Content -Path $FilePaths["buttons"] -Raw
        $CatagoryXamlContent = Get-Content -Path $FilePaths["catagory"] -Raw
        $searchXamlContent   = Get-Content -Path $FilePaths["search"] -Raw

        # Replace placeholders with actual content
        $MainXamlContent = $MainXamlContent -replace "{{Taps}}", $AppXamlContent
        $MainXamlContent = $MainXamlContent -replace "{{Style}}", $StyleXamlContent
        $MainXamlContent = $MainXamlContent -replace "{{Colors}}", $ColorsXamlContent
        $MainXamlContent = $MainXamlContent -replace "{{menu}}", $MenuXamlContent
        $MainXamlContent = $MainXamlContent -replace "{{buttons}}", $ButtonsXamlContent
        $MainXamlContent = $MainXamlContent -replace "{{catagory}}", $CatagoryXamlContent
        $MainXamlContent = $MainXamlContent -replace "{{search}}", $searchXamlContent

    } catch {
        Write-Error "An error occurred while processing the XAML content: $($_.Exception.Message)"
    }
   
    $AppsCheckboxes = GenerateCheckboxes -Items $itt.database.Applications -ContentField "Name" -TagField "Category" -IsCheckedField "check" -TipsField "show"
    $TweaksCheckboxes = GenerateCheckboxes -Items $itt.database.Tweaks -ContentField "Name"
    $SettingsCheckboxes = GenerateCheckboxes -Items $itt.database.Settings -ContentField "Content" -NameField "Name" -ToggleField "Style="{StaticResource ToggleSwitchStyle}""

    $MainXamlContent = $MainXamlContent -replace "{{Apps}}", $AppsCheckboxes 
    $MainXamlContent = $MainXamlContent -replace "{{Tweaks}}", $TweaksCheckboxes 
    $MainXamlContent = $MainXamlContent -replace "{{Settings}}", $SettingsCheckboxes 
    $MainXamlContent = $MainXamlContent -replace "{{ThemesKeys}}", (GenerateThemesKeys)

    # Get xaml files from Themes and put it inside MainXamlContent
    $ThemeFilesContent = Get-ChildItem -Path "$Themes" -File | 
    ForEach-Object { Get-Content $_.FullName -Raw } | 
    Out-String

    $MainXamlContent = $MainXamlContent -replace "{{CustomThemes}}", $ThemeFilesContent 

    # Final output
    WriteToScript -Content "`$MainWindowXaml = '$MainXamlContent'"

    # Signup a new CONTRIBUTOR
    NewCONTRIBUTOR


    WriteToScript -Content @"
#===========================================================================
#endregion End WPF Main Window
#===========================================================================
"@

WriteToScript -Content @"
#===========================================================================
#region Begin WPF About Window
#===========================================================================

"@

    # Define file paths
    $FilePaths = @{
        "about" = Join-Path -Path $windows -ChildPath "AboutWindow.xaml"
    }

    # Read and replace placeholders in XAML content
    try {
        $AboutWindowXamlContent = (Get-Content -Path $FilePaths["about"] -Raw) -replace "'", "''"
    } catch {
        Write-Error "Error: $($_.Exception.Message)"
    }
   
    WriteToScript -Content "`$AboutWindowXaml = '$AboutWindowXamlContent'"

    WriteToScript -Content @"
#===========================================================================
#endregion End WPF About Window
#===========================================================================
"@

WriteToScript -Content @"
#===========================================================================
#region Begin WPF Event Window
#===========================================================================

"@

    # Define file paths
    $FilePaths = @{
        "event" = Join-Path -Path $windows -ChildPath "EventWindow.xaml"
    }

    # Read and replace placeholders in XAML content
    try {
        $EventWindowXamlContent = (Get-Content -Path $FilePaths["event"] -Raw) -replace "'", "''"

        # debug offline local file
        # $textContent = Get-Content -Path $textFilePath -Raw
        # $xamlContent = ConvertTo-Xaml -text $textContent
        # # Write-Host $xamlContent

        $response = Invoke-WebRequest -Uri $NoteUrl
        $textContent = $response.Content
        $xamlContent = ConvertTo-Xaml -text $textContent
        $EventWindowXamlContent = $EventWindowXamlContent -replace "UpdateContent", $xamlContent
        WriteToScript -Content "`$EventWindowXaml = '$EventWindowXamlContent'"
        
    } catch {
        Write-Error "Error: $($_.Exception.Message)"
    }


    WriteToScript -Content @"
#===========================================================================
#endregion End WPF Event Window
#===========================================================================
"@

    WriteToScript -Content @"
#===========================================================================
#region Begin loadXmal
#===========================================================================
"@

    AddFileContentToScript -FilePath $LoadXamlScript
    WriteToScript -Content @"
#===========================================================================
#endregion End loadXmal
#===========================================================================
"@

    # Write Main section
    WriteToScript -Content @"
#===========================================================================
#region Begin Main
#===========================================================================
"@
    #ProcessDirectory -Directory $ScritsDirectory
    AddFileContentToScript -FilePath $MainScript
    WriteToScript -Content @"
#===========================================================================
#endregion End Main
#===========================================================================
"@




GenerateClickEventHandlers



CountItems
Write-Host " `n`Build successfully" -ForegroundColor Green

if($Debug)
{
    Write-Host " `n`Debug mode..." -ForegroundColor Green
    $script = "& '$ProjectDir\$OutputScript'"
    $pwsh = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
    $wt = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "wt.exe" } else { $pwsh }
    Start-Process $wt -ArgumentList "$pwsh -NoProfile -Command $script -Debug"
}

}

catch {
    Write-Error "An error occurred: $_"
}

