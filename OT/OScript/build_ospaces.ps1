#��������� ���������������� json
$json = Get-Content config.JSON | ConvertFrom-Json 

$LogPath = $json.Settings.LogPath
$Build_Path=$json.Settings.Source_code_Path
$OT_Path=$json.Settings.OT_Path
$Deploy_path = $json.Settings.Build_Path
$Build_module_Path = $json.Settings.module_Path
$Build_support_Path = $json.Settings.support_Path

$JAVA_OPTS="-Dfile.encoding=UTF-8"
$JAVA_OPTS=$JAVA_OPTS + " -Djava.library.path=$OT_Path\bin\"
$JAVA_OPTS=$JAVA_OPTS + " -Doclipse.rmiPort=1099"
$JAVA_OPTS=$JAVA_OPTS + " -Doclipse.startupScript=$OT_Path\ide_startup.lxe"
$JAVA_OPTS=$JAVA_OPTS + " -Doclipse.configFile=$OT_Path\config\opentext.ini"
$JAVA_OPTS=$JAVA_OPTS + " -Doclipse.remoteObject=otbuilderprocess"
$JAVA_OPTS=$JAVA_OPTS + " -Doclipse.startByEclipse=false"
$JAVA_OPTS=$JAVA_OPTS + " -Dru.ospaceBuilder.removeSources=false"
Write-Output JAVA_OPTS=$JAVA_OPTS

$Number = Read-Host '������� ����� ������'
#�������� ������ ���
Start-Transcript -path $LogPath\$Number"_output.log"

Write-Host Start of Build Number: $Number -ForegroundColor green
#������ ���������� ��� ������
if(Test-Path -Path $Deploy_path\$Number) {
	Write-Output "Deploy folder exists, remove it"
	if(Test-Path -Path $Deploy_path\$Number\$Build_module_Path) {
		Remove-Item -Recurse -Force $Deploy_path\$Number\$Build_module_Path -ErrorAction Stop
	}
	if(Test-Path -Path $Deploy_path\$Number\$Build_support_Path) {
		Remove-Item -Recurse -Force $Deploy_path\$Number\$Build_support_Path -ErrorAction Stop
	}
}

#�������� ���� �� ������-����� ��� ������������ *.jar � ������� *.oll 
ForEach ($Line in $json.Module.PSObject.Properties.Name ) {
	$Module_name=$Line -split "_"
	$Short_module_name = $Module_name[0]
	#���� ���������� ������� ������, �� Enable = true � ������� config.json
	If ($json.Module.($Line).Enable -eq "true" ) {
		#������ oll � ������ ������
		if(Test-Path -Path $Build_Path\$Short_module_name\ospace\) {
			Write-Host "Start Clean Build Directory for $Short_module_name" -ForegroundColor yellow
			Remove-Item -Recurse -Force $Build_Path\$Short_module_name\ospace\* -Include *.oll -ErrorAction Stop
			Write-Host "End Clean Build Directory" -ForegroundColor yellow
		}
		#��������� *.jar ������ � ���� 
		if(Test-Path -Path $OT_Path\module\$Line\ojlib\*) {
			foreach ( $i in Get-ChildItem -Path $OT_Path\module\$Line\ojlib\* -Include *.jar -Name ) {
				$CP=$CP + "$OT_Path\module\$Line\ojlib\$i;"
			}
		}

	}
}
#��������� ��������� ���������� � ���� �� ojlib
foreach ( $i in Get-ChildItem -Path $OT_Path\ojlib\* -Include *.jar -Name ) {
	$CP=$CP + "$OT_Path\ojlib\$i;"
}
#��������� ��������� ���������� � ���� �� core\module
foreach ( $i in Get-ChildItem -Path $OT_Path\core\module\* -Name ) {
	if(Test-Path -Path E:\app\OPENTEXT\core\module\$i\ojlib\* -Include *.jar) {	
		foreach ( $ii in Get-ChildItem -Path $OT_Path\core\module\$i\ojlib\* -Include *.jar -Name ) {
			$CP=$CP + "$OT_Path\core\module\$i\ojlib\$ii;"
		}
	}
}

#��������� � ���� Oclipse_212.jar
foreach ( $i in Get-ChildItem -Include *.jar -Name ) {
	$CP=$CP + "$PSScriptRoot\$i;"
}

#��������� �������
$old_location=Get-Location
cd $OT_Path

#������ ���������� ���������
$path = [Environment]::GetEnvironmentVariable('path')
$newpath = $path + ";$OT_Path\bin"
[Environment]::SetEnvironmentVariable("path", $newpath)

#��������� ���� � ���� ������ 
$build_log = [string]::Concat($old_location, '\',$LogPath.Substring(2),'\',$Number,'_build_output.log')

#��������� BUILD
Start-Process -FilePath $OT_Path\jre\bin\java.exe "$JAVA_OPTS -classpath $CP ru.tl.oscript.OSpaceBuilder $Build_Path" -NoNewWindow -Wait -RedirectStandardOutput $build_log

#������������ � ��������� ����������
cd $old_location

#�������� ���� �� ������-����� ��� ���������� ������
ForEach ($Line in $json.Module.PSObject.Properties.Name ) {
	$Module_name=$Line -split "_"
	$Short_module_name = $Module_name[0]
	#���� ���������� ������� ������, �� Enable = true � ������� config.json
	If ($json.Module.($Line).Enable -eq "true" ) {
		#���� ��������� OLL ������ ���� ��������
		if(Test-Path -Path "$Build_Path\$Short_module_name\ospace\*" -Include *.oll) {
			Write-Host  Build module $Short_module_name success -ForegroundColor green 
		}
		else {
			Write-Host  ERROR: Build module $Short_module_name unsuccessful -ForegroundColor red
			exit
		}
		#�������� � ����� ������ ������
		$source = "$Build_Path\$Short_module_name\*"
		Write-Host Copy to Deploy module $Short_module_name -ForegroundColor green
		$dist = (new-item -type directory -force ("$Deploy_path\$Number\$Build_module_Path\$Line\"))
		copy-item  $source $dist -Exclude $Short_module_name.ToUpper() -force -recurse -ErrorAction Stop
		
		Write-Host End of Copy module $Short_module_name -ForegroundColor green
		#�������� � ����� ������ support
		if(Test-Path -Path "$Build_Path\$Short_module_name\support" ) {
			$source = "$Build_Path\$Short_module_name\support\*"
			Write-Host Copy to Deploy support $Short_module_name -ForegroundColor green
			$dist = (new-item -type directory -force ("$Deploy_path\$Number\$Build_support_Path\$Short_module_name\"))
			copy-item  $source $dist -force -recurse -ErrorAction Stop
			Write-Host End of Copy to Deploy support $Short_module_name -ForegroundColor green
		}
	}
}
Write-Host End of Build Number: $Number success -ForegroundColor green
Stop-Transcript