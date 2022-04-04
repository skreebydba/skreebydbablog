Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-WebRequest https://community.chocolatey.org/install.ps1 -UseBasicParsing | Invoke-Expression; 
choco install zoomit -y; 
choco install notepadplusplus -y; 
choco install git -y; 
choco install azure-data-studio -y; 
choco install microsoft-edge -y; 
choco install powershell-core -y; 