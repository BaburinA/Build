#Считываем конфигурационный json
$json = Get-Content config.JSON | ConvertFrom-Json 

$deploy_path = $json.OT.Settings.Build_Path
$LogPath = $json.OT.Settings.LogPath
$Source_code_Path = $json.OT.Settings.Source_code_Path
$Build_Configs_Path = $json.OT.Settings.Configs_Path
$Build_Services_Path = $json.OT.Settings.Services_Path
$MSBuild_exe_Path = $json.OT.Settings.MSBuild_Path

$prefix = "LogStream.Magnit."

$dir = (${env:ProgramFiles(x86)}, ${env:ProgramFiles} -ne $null)[0]
$MSBuild_File="$dir\$MSBuild_exe_Path"

$number = Read-Host 'Введите номер релиза'

#Чистим директорию для релиза
if(Test-Path -Path $deploy_path\$number) {
	Write-Output "deploy exists, remove it"
	#Remove-Item $deploy_path\$number\1.txt #-ErrorAction Stop # для тестирования ошибки удаления
	if(Test-Path -Path $deploy_path\$number\$Build_Configs_Path) {
		Remove-Item -Recurse -Force $deploy_path\$number\$Build_Configs_Path -ErrorAction Stop
	}
	if(Test-Path -Path $deploy_path\$number\$Build_Services_Path) {
		Remove-Item -Recurse -Force $deploy_path\$number\$Build_Services_Path -ErrorAction Stop
	}
}

	
#Начинаем цикл по конфиг-файлу
ForEach ($line in $json.OT.Services.PSObject.Properties.Name ) {
	$PROJECT_NAME = $prefix+$line
	#Если необходимо билдить службу, то Enable = true в конфиге config.json
	If ($json.OT.Services.($line).Enable -eq "true" ) 
		{ 
		
		#Чистим bin в каждой службе
		if(Test-Path -Path $Source_code_Path\$PROJECT_NAME\bin\){
			Write-Host "Start Clean Build Directory" -ForegroundColor yellow
			Remove-Item -Recurse -Force $Source_code_Path\$PROJECT_NAME\bin\ -ErrorAction Stop
			Write-Host "End Clean Build Directory" -ForegroundColor yellow
		}
		
		ForEach ($Zone in $json.OT.Zones ) {
			#Получаем зону из массива из конфига, для который необходим Билд
			$Zone_array = $Zone.replace(' ','') -split ","	
			
			ForEach ($val_Zone in $Zone_array ) {
			
				#Готовим аргументы для Билда
				$arg1 = "$Source_code_Path\$PROJECT_NAME\$PROJECT_NAME.csproj"
				$arg2 = "/p:Configuration=$val_Zone"
				$arg3 = '/p:Platform="AnyCPU"'
				$arg4 = '/t:Rebuild'
				$arg5 = [string]::Concat('/flp:logfile=',$LogPath,'\',$PROJECT_NAME,'_',$val_Zone,'.log;errorsOnly')				
				
				#Билд проекта
				Write-Host Start build $PROJECT_NAME $val_Zone -ForegroundColor green
				& $MSBuild_File $arg1 $arg2 $arg3 $arg4 $arg5
				Write-Host End build $PROJECT_NAME $val_Zone -ForegroundColor green
			
				Write-Host  Check build -ForegroundColor yellow
				#Если создались DLL значит билд успешный
				if(Test-Path -Path "$Source_code_Path\$PROJECT_NAME\bin\$val_Zone\*" -Include *.dll) {
					Write-Host  Build success -ForegroundColor green 
				}
				else {
					Write-Host  ERROR: Build unsuccessful -ForegroundColor red
					exit
				}	
				#Копируем конфиги в папку релиза
				$source = "$Source_code_Path\$PROJECT_NAME\bin\$val_Zone\*"
				Write-Host Copy to Deploy Configs -ForegroundColor green
				$dist = (new-item -type directory -force ("$deploy_path\$number\$Build_Configs_Path\$PROJECT_NAME\$val_Zone\"))
				copy-item  $source $dist -Include "*.config" -force -recurse -ErrorAction Stop
				Write-Host End of Copy Configs -ForegroundColor green
				
				#Копируем билд в папку релиза только из зоны MagnitProd все кроме конфигов
				Write-Host Copy to Deploy Services -ForegroundColor green
				If ($val_Zone -like "MagnitProd" ) {
					If ($json.OT.Services.($line).Type -like "IIS" ) {
						$dist = (new-item -type directory -force ("$deploy_path\$number\$Build_Services_Path\$PROJECT_NAME\bin\")) 
					}
					elseif($json.OT.Services.($line).Type -like "Services" ){
						$dist = (new-item -type directory -force ("$deploy_path\$number\$Build_Services_Path\$PROJECT_NAME\")) 
					}
				copy-item  $source $dist -Exclude "*.config" -force -recurse -ErrorAction Stop
				}
				Write-Host End of Copy Services -ForegroundColor green
			}	
		}
    }
}
Write-Host End of Build Number: $number success -ForegroundColor green
