## This script will generate a Table of Contents in your Global KB and in each of your Customer's KBs
# Author: Luke Whitelock
# Date: 02-04-2022

$VaultName = "Your Key Vault"

#### Hudu Settings ####
$HuduAPIKey = Get-AzKeyVaultSecret -vaultName $VaultName -name "HuduAPIKey" -AsPlainText
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = Get-AzKeyVaultSecret -vaultName $VaultName -name "HuduBaseDomain" -AsPlainText

$TOCArticleName = 'Table of Contents'

import-module HuduAPI

New-HuduAPIKey $HuduAPIKey
New-HuduBaseUrl $HuduBaseDomain

function Get-ProcessedFolder{
    param (
        $FolderParentID,
        $FolderName,
        $FolderDepth,
        $Articles,
        $Folders,
        $HTML
    )
    if ($FolderDepth -gt 6) {
        $Depth = 6
    } else {
        $Depth = $FolderDepth
    }
    if ($Depth -ne 0){
    $HTML.add("<h$($Depth)>$FolderName</h$FolderDepth><ul>")
    } else {
        $HTML.add("<ul>")
    }
    foreach ($Article in ($Articles | where-object {$FolderParentID -eq $_.folder_id} | sort-object name)){
        $HTML.add("<li><a href='$($Article.url)'>$($Article.Name)</a></li>")
    }
    foreach ($Folder in ($Folders | where-object {$FolderParentID -eq $_.parent_folder_id} | sort-object name)){
        Get-ProcessedFolder -FolderParentID $folder.id -FolderName $Folder.name -FolderDepth ($FolderDepth + 1) -Articles $Articles -Folders $Folders -HTML $HTML
    }
    $HTML.add("</ul><br />")
}


$AllArticles = Get-HuduArticles | Where-Object {$_.archived -eq $false}

$Folders = Get-HuduFolders

$TableOfContentsArticles = Get-HuduArticles -Name $TOCArticleName

# Process the Global KB First
$GlobalKBs = $AllArticles | where-object { $_.company_id -eq $null }
$GlobalFolders = $Folders | where-object { $_.company_id -eq $null }

[System.Collections.Generic.List[PSCustomObject]]$GlobalHTML = @()
$GlobalHTML.add('<h1 class="align-center">' + $TOCArticleName + '</h1>')
Get-ProcessedFolder -FolderParentID $null -FolderName "Top Level Documents" -FolderDepth 0 -Articles $GlobalKBs -Folders $GlobalFolders -HTML $GlobalHTML

$KBArticle = $TableOfContentsArticles | where-object {$_.company_id -eq $null}
    $KBCount = ($KBArticle | measure-object).count
    if ( $KBCount -eq 0){
        $Null = New-HuduArticle -Name $TOCArticleName -Content ($GlobalHTML -join '')
    } elseif ($KBCount -eq 1){
        $Null = Set-HuduArticle -ArticleId $KBArticle.Id -Content ($GlobalHTML -join '') -Name $TOCArticleName
    } else {
        Write-Error "Multiple KB Articles found with the same name"
    }

# Generate it for each company
foreach ($CompanyID in ($AllArticles.company_id | select-object -unique)) {
    $CompanyArticles = $AllArticles | where-object { $_.company_id -eq $CompanyID }
    $CompanyFolders = $Folders | where-object { $_.company_id -eq $CompanyID }
    [System.Collections.Generic.List[PSCustomObject]]$CompanyHTML = @()
    $CompanyHTML.add('<h1 class="align-center">' + $TOCArticleName + '</h1>')
    Get-ProcessedFolder -FolderParentID $null -FolderName "Top Level Documents" -FolderDepth 0 -Articles $CompanyArticles -Folders $CompanyFolders -HTML $CompanyHTML

    $CompanyArticle = $TableOfContentsArticles | where-object {$_.company_id -eq $CompanyID}
    $CompanyCount = ($CompanyArticle | measure-object).count
    if ( $CompanyCount -eq 0){
        $Null = New-HuduArticle -Name $TOCArticleName -Content ($CompanyHTML -join '') -company_id $CompanyID
    } elseif ($CompanyCount -eq 1){
        $Null = Set-HuduArticle -ArticleId $CompanyArticle.Id -Content ($CompanyHTML -join '') -Name $TOCArticleName -company_id $CompanyID
    } else {
        Write-Error "Multiple KB Articles found with the same name - Company ID: $CompanyID"
    }
}
