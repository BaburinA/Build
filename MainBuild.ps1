# Конструктор конфигов сборки
#----------------------------
$Home_Ps = Get-Location
$TotalCount = 2
$Main_Config = Get-Content "Main.Conf" -TotalCount $TotalCount
$Main_Config = $Main_Config -replace '\s',''
foreach($Conf in $Main_Config)
{
	$Conf = $Conf -split '='
	Set-Variable -Name $Conf[0] -value $Conf[1]
}
Write-Host "Release:"$Release -ForegroundColor green
Write-Host "DestinationPath:"$DestinationPath -ForegroundColor green
Write-Host "--------------------------------------"
$Main_Config = Get-Content "Main.Conf" 
$Count_End = $($Main_Config.count)-$TotalCount-1
$Main_Config = Get-Content "Main.Conf" -Tail $Count_End
$Main_Config = $Main_Config -replace '\s',''
Write-Host "Идет обработка конфигов сборки!!!" -ForegroundColor green
$PointLevel = @()
foreach($Conf in $Main_Config)
{
	if($Conf)
		{
			$Conf = $Conf -split '='
			$MainLevel = ($Conf[0].substring(0,$Conf[0].IndexOf("|")))
			$MainLevel = $MainLevel	-replace "\.","\\"
			$Json = Get-Content .\\$MainLevel\\Config.JSON | ConvertFrom-Json	
			$EndLevel = $Conf[0].substring($Conf[0].IndexOf("|") + 1)
			$EndLevel = $EndLevel -split "\."
			$JS = $Json
			foreach($Level in $EndLevel)  
			{ 
				$JS = $JS.($Level) 
			}
			$JS.Enable = [bool]::Parse($Conf[1]) 
			if( !($PointLevel -match ($Conf[0].substring(0,$Conf[0].IndexOf(".")))) -and [bool]::Parse($Conf[1]))
			{
			$PointLevel += ($Conf[0].substring(0,$Conf[0].IndexOf(".")))
			}
			$Json |ConvertTo-Json -Depth 5 | Out-File .\\$MainLevel\\Config.JSON -Force
		}
}
$PointLevel = $PointLevel -join ","
Write-Host "Обработка конфигов завершена!!!" -ForegroundColor green
Set-Location $Home_Ps
if($PointLevel)
{
	& Powershell.exe -File GitPull.ps1 $PointLevel
	#$PointLevel #Передача параметра
}