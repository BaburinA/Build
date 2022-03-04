param($Task_String="")
$Home_Ps = Get-location
$Json = Get-Content $Home_Ps\\"GitConfig.JSON" | ConvertFrom-Json
$Git_Local_Path = $Json.GitLocalPath	

Start-Transcript -path $Home_Ps\$Json.GitLog | Out-Null 
if($Task_String -ne "") 
{
	$Conn = &  ssh -T $Json.GitUrl | Out-String -InformationVariable a 
	if( $Conn -match "come") 
	{
		Write-Host $Conn -ForegroundColor green
		$Task_Arr = $Task_String -split "," # Отработать
		Write-Host "Назначенные задания: $Task_arr"  -ForegroundColor green
	
		foreach( $Task in $Json.Groups )
		{   
			if( $Task_Arr -match $Task.Name ) 
			{
				$TaskIs = $Task.Name
				Write-Host
				Write-Host "Контроль репозитория: "$TaskIs -ForegroundColor yellow
			
				foreach( $Repos in $Task.Repositories )
				{	
					$Branch = $Repos.Branch
					$Name = $Repos.Name
					if(Test-Path -Path $Git_Local_Path\$TaskIs\$Name) 
					{
						Set-location -Path $Git_Local_Path\$TaskIs\$Name
						Write-Host "Работа с репозиторием:"$Name -ForegroundColor green
						$Current_Branch = & { git branch } 2>&1 | % ToString
						foreach( $Cur in $Current_Branch)
						{
							if($Cur.substring(0,1) -eq "*")
							{
								Write-Host "Текущая ветка: "$Cur -ForegroundColor green
								$Current = $Cur; $LightCur = $Cur.substring(2); break
							}
						}
						if( $LightCur -ne $Branch )  
						{ 
							Write-Host "Переключение на "$Branch -ForegroundColor yellow
							$Info = & { git checkout $Branch } 2>&1   | % ToString 
							if( $Info -match "error" )
							{
								Write-Host "Ветка $Branch отсутствует. Ошибка переключения!!!" -ForegroundColor red
								Write-Host "_____________________________________________________"

							}
						}
						else
						{
							$Info_Check = & { git checkout -- *  } 2>&1 | % ToString
							$Info_Pull = & { git pull  } 2>&1 | % ToString
							if( $Info_Pull -eq "Already up to date.")
							{
								Write-Host "Обновление прошло успешно из репозитория: "$Name  -ForegroundColor green
								Write-Host "_____________________________________________________"
							}
						}
						
					}
					else
					{
						Write-Host "Репозиторий не найден:"$Name" !!!" -ForegroundColor red
						Exit-PSSession 
					}
				}
			}
		}
		Write-Host "Задачи по контролю репозитория выполнены!!!" -ForegroundColor green
	}
	else 
	{ 	
		Write-Host "Не возможно подключиться к gitlab" -ForegroundColor red}
	}
else 
{
	Write-Host "Задание не определено !!!" -ForegroundColor red	
}


Set-location $Home_Ps
Stop-Transcript | Out-Null
