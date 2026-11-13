#requires -Version 5.1
[CmdletBinding()]
param(
    [int]$Port = 8080,

    [string]$Directory = (Join-Path $PSScriptRoot "Shared"),

    [string]$BindAddress = "0.0.0.0"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================
# Configuration
# ============================================================

if ($Port -lt 1 -or $Port -gt 65535) {
    throw "Port must be between 1 and 65535."
}

$ShareRoot = [System.IO.Path]::GetFullPath($Directory)

if (-not (Test-Path -LiteralPath $ShareRoot)) {
    New-Item -ItemType Directory -Path $ShareRoot -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $ShareRoot -PathType Container)) {
    throw "Not a directory: $ShareRoot"
}

# ============================================================
# MIME types
# ============================================================

$MimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".htm"  = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".txt"  = "text/plain; charset=utf-8"
    ".csv"  = "text/csv; charset=utf-8"
    ".xml"  = "application/xml; charset=utf-8"

    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".png"  = "image/png"
    ".gif"  = "image/gif"
    ".webp" = "image/webp"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"

    ".pdf"  = "application/pdf"

    ".zip"  = "application/zip"
    ".7z"   = "application/x-7z-compressed"
    ".gz"   = "application/gzip"

    ".mp3"  = "audio/mpeg"
    ".wav"  = "audio/wav"
    ".ogg"  = "audio/ogg"

    ".mp4"  = "video/mp4"
    ".webm" = "video/webm"
    ".mkv"  = "video/x-matroska"

    ".doc"  = "application/msword"
    ".docx" = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

    ".xls"  = "application/vnd.ms-excel"
    ".xlsx" = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

    ".ppt"  = "application/vnd.ms-powerpoint"
    ".pptx" = "application/vnd.openxmlformats-officedocument.presentationml.presentation"
}

# ============================================================
# Embedded HTML frontend
# ============================================================

$IndexHtml = @'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">

<title>LAN Share</title>

<style>
* {
    box-sizing: border-box;
}

body {
    margin: 0;
    font-family:
        system-ui,
        -apple-system,
        BlinkMacSystemFont,
        "Segoe UI",
        sans-serif;

    background: #f3f4f6;
    color: #111827;
}

header {
    background: #1f2937;
    color: white;
    padding: 24px;
}

header h1 {
    margin: 0 0 5px 0;
}

header p {
    margin: 0;
    opacity: .75;
}

main {
    max-width: 1100px;
    margin: 25px auto;
    padding: 0 16px;
}

.panel {
    background: white;
    border-radius: 12px;
    padding: 20px;
    margin-bottom: 20px;
    box-shadow: 0 2px 12px rgba(0,0,0,.08);
}

.upload {
    border: 2px dashed #9ca3af;
    border-radius: 10px;
    padding: 35px;
    text-align: center;
    cursor: pointer;
}

.upload.drag {
    border-color: #2563eb;
    background: #eff6ff;
}

button,
.button {
    display: inline-block;
    border: 0;
    border-radius: 7px;
    padding: 9px 14px;
    cursor: pointer;
    background: #2563eb;
    color: white;
    font-size: 14px;
}

button:hover,
.button:hover {
    background: #1d4ed8;
}

button.delete {
    background: #dc2626;
}

button.delete:hover {
    background: #b91c1c;
}

input[type=file] {
    display: none;
}

.progress {
    height: 8px;
    background: #d1d5db;
    border-radius: 5px;
    overflow: hidden;
    margin-top: 15px;
    display: none;
}

.progressBar {
    width: 0%;
    height: 100%;
    background: #2563eb;
}

.status {
    margin-top: 12px;
}

.toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
}

table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 15px;
}

th,
td {
    padding: 11px 8px;
    border-bottom: 1px solid #e5e7eb;
    text-align: left;
}

.actions {
    text-align: right;
}

a {
    color: #2563eb;
    text-decoration: none;
}

a:hover {
    text-decoration: underline;
}

.empty {
    text-align: center;
    padding: 30px;
    color: #6b7280;
}

@media(max-width:700px) {
    th:nth-child(3),
    td:nth-child(3) {
        display: none;
    }
}
</style>
</head>

<body>

<header>
    <h1>LAN Share</h1>
    <p>Simple workstation file sharing</p>
</header>

<main>

<div class="panel">

    <div id="dropZone" class="upload">

        <strong>Drop files here</strong>

        <div>or</div>

        <br>

        <label class="button">
            Choose files

            <input
                id="fileInput"
                type="file"
                multiple
            >
        </label>

        <div class="progress" id="progress">
            <div
                class="progressBar"
                id="progressBar"
            ></div>
        </div>

        <div
            class="status"
            id="status"
        ></div>

    </div>

</div>

<div class="panel">

    <div class="toolbar">

        <h2>Files</h2>

        <button onclick="loadFiles()">
            Refresh
        </button>

    </div>

    <div id="fileList">
        Loading...
    </div>

</div>

</main>

<script>

const fileInput =
    document.getElementById("fileInput");

const dropZone =
    document.getElementById("dropZone");

const progress =
    document.getElementById("progress");

const progressBar =
    document.getElementById("progressBar");

const status =
    document.getElementById("status");

const fileList =
    document.getElementById("fileList");


fileInput.addEventListener(
    "change",
    function() {

        uploadFiles(fileInput.files);

    }
);


dropZone.addEventListener(
    "dragover",
    function(event) {

        event.preventDefault();

        dropZone.classList.add("drag");

    }
);


dropZone.addEventListener(
    "dragleave",
    function() {

        dropZone.classList.remove("drag");

    }
);


dropZone.addEventListener(
    "drop",
    function(event) {

        event.preventDefault();

        dropZone.classList.remove("drag");

        if (event.dataTransfer.files.length > 0) {

            uploadFiles(
                event.dataTransfer.files
            );

        }

    }
);


async function loadFiles() {

    fileList.textContent = "Loading...";

    try {

        const response =
            await fetch(
                "/api/list",
                {
                    cache: "no-store"
                }
            );

        if (!response.ok) {
            throw new Error(
                "HTTP " + response.status
            );
        }

        const files =
            await response.json();

        if (files.length === 0) {

            fileList.innerHTML =
                '<div class="empty">No files shared yet.</div>';

            return;
        }

        const table =
            document.createElement("table");

        const header =
            document.createElement("tr");

        header.innerHTML =
            "<th>Name</th>" +
            "<th>Size</th>" +
            "<th>Modified</th>" +
            "<th></th>";

        table.appendChild(header);


        for (const file of files) {

            const row =
                document.createElement("tr");


            const nameCell =
                document.createElement("td");

            const link =
                document.createElement("a");

            link.href =
                "/files/" +
                encodeURIComponent(file.name);

            link.textContent =
                file.name;

            link.download =
                file.name;

            nameCell.appendChild(link);


            const sizeCell =
                document.createElement("td");

            sizeCell.textContent =
                formatBytes(file.size);


            const modifiedCell =
                document.createElement("td");

            modifiedCell.textContent =
                new Date(
                    file.modified
                ).toLocaleString();


            const actionCell =
                document.createElement("td");

            actionCell.className =
                "actions";


            const deleteButton =
                document.createElement("button");

            deleteButton.className =
                "delete";

            deleteButton.textContent =
                "Delete";

            deleteButton.onclick =
                function() {
                    deleteFile(file.name);
                };


            actionCell.appendChild(
                deleteButton
            );


            row.appendChild(nameCell);
            row.appendChild(sizeCell);
            row.appendChild(modifiedCell);
            row.appendChild(actionCell);

            table.appendChild(row);
        }


        fileList.innerHTML = "";

        fileList.appendChild(table);

    }
    catch (error) {

        fileList.textContent =
            "Unable to load files: " +
            error.message;

    }
}


async function uploadFiles(files) {

    if (!files || files.length === 0) {
        return;
    }

    progress.style.display =
        "block";


    for (const file of files) {

        status.textContent =
            "Uploading " +
            file.name +
            "...";

        try {

            await uploadFile(file);

            status.textContent =
                "Uploaded " +
                file.name;

        }
        catch (error) {

            status.textContent =
                "Upload failed: " +
                error.message;

        }
    }


    progressBar.style.width =
        "100%";


    await loadFiles();


    setTimeout(
        function() {

            progress.style.display =
                "none";

            progressBar.style.width =
                "0%";

        },
        800
    );
}


function uploadFile(file) {

    return new Promise(
        function(resolve, reject) {

            const xhr =
                new XMLHttpRequest();


            xhr.open(
                "PUT",
                "/upload/" +
                encodeURIComponent(file.name),
                true
            );


            xhr.setRequestHeader(
                "Content-Type",
                "application/octet-stream"
            );


            xhr.upload.onprogress =
                function(event) {

                    if (event.lengthComputable) {

                        const percent =
                            event.loaded /
                            event.total *
                            100;

                        progressBar.style.width =
                            percent.toFixed(1) +
                            "%";
                    }

                };


            xhr.onload =
                function() {

                    if (
                        xhr.status >= 200 &&
                        xhr.status < 300
                    ) {

                        resolve();

                    }
                    else {

                        reject(
                            new Error(
                                "HTTP " +
                                xhr.status +
                                ": " +
                                xhr.responseText
                            )
                        );

                    }

                };


            xhr.onerror =
                function() {

                    reject(
                        new Error(
                            "Network error"
                        )
                    );

                };


            xhr.send(file);

        }
    );
}


async function deleteFile(name) {

    if (
        !confirm(
            'Delete "' +
            name +
            '"?'
        )
    ) {
        return;
    }


    try {

        const response =
            await fetch(
                "/files/" +
                encodeURIComponent(name),
                {
                    method: "DELETE"
                }
            );


        if (!response.ok) {

            throw new Error(
                "HTTP " +
                response.status
            );

        }


        await loadFiles();

    }
    catch (error) {

        alert(
            "Delete failed: " +
            error.message
        );

    }
}


function formatBytes(bytes) {

    if (bytes === 0) {
        return "0 B";
    }


    const units = [
        "B",
        "KB",
        "MB",
        "GB",
        "TB"
    ];


    const index =
        Math.floor(
            Math.log(bytes) /
            Math.log(1024)
        );


    return (
        (
            bytes /
            Math.pow(1024, index)
        ).toFixed(
            index === 0 ? 0 : 1
        )
        +
        " " +
        units[index]
    );
}


loadFiles();

</script>

</body>
</html>
'@

# ============================================================
# Helper: MIME type
# ============================================================

function Get-MimeType {
    param(
        [string]$FileName
    )

    $extension =
        [System.IO.Path]::GetExtension(
            $FileName
        ).ToLowerInvariant()

    if ($MimeTypes.ContainsKey($extension)) {
        return $MimeTypes[$extension]
    }

    return "application/octet-stream"
}

# ============================================================
# Helper: send response
# ============================================================

function Send-Response {
    param(
        [System.Net.Sockets.NetworkStream]$Stream,

        [byte[]]$Body,

        [int]$StatusCode = 200,

        [string]$Reason = "OK",

        [string]$ContentType = "text/plain; charset=utf-8",

        [string]$ExtraHeaders = ""
    )

    $header =
        "HTTP/1.1 $StatusCode $Reason`r`n" +
        "Server: PowerShell-LAN-Share`r`n" +
        "Content-Type: $ContentType`r`n" +
        "Content-Length: $($Body.Length)`r`n" +
        "Connection: close`r`n" +
        "Cache-Control: no-store`r`n"

    if ($ExtraHeaders) {
        $header += $ExtraHeaders
    }

    $header += "`r`n"


    $headerBytes =
        [System.Text.Encoding]::ASCII.GetBytes(
            $header
        )


    $Stream.Write(
        $headerBytes,
        0,
        $headerBytes.Length
    )


    if ($Body.Length -gt 0) {

        $Stream.Write(
            $Body,
            0,
            $Body.Length
        )

    }


    $Stream.Flush()
}


function Send-TextResponse {
    param(
        [System.Net.Sockets.NetworkStream]$Stream,

        [string]$Text,

        [int]$StatusCode = 200,

        [string]$Reason = "OK",

        [string]$ContentType = "text/plain; charset=utf-8"
    )

    $bytes =
        [System.Text.Encoding]::UTF8.GetBytes(
            $Text
        )

    Send-Response `
        -Stream $Stream `
        -Body $bytes `
        -StatusCode $StatusCode `
        -Reason $Reason `
        -ContentType $ContentType
}


function Send-JsonResponse {
    param(
        [Parameter(Mandatory)]
        [System.IO.Stream]$Stream,

        [Parameter(Mandatory)]
        $Object,

        [int]$StatusCode = 200,

        [string]$Reason = "OK"
    )

    $json = ConvertTo-Json -InputObject $Object -Compress -Depth 10
    $body = [System.Text.Encoding]::UTF8.GetBytes($json)

    $header =
        "HTTP/1.1 $StatusCode $Reason`r`n" +
        "Server: PowerShell-LAN-Share`r`n" +
        "Content-Type: application/json; charset=utf-8`r`n" +
        "Content-Length: $($body.Length)`r`n" +
        "Connection: close`r`n" +
        "Cache-Control: no-store`r`n" +
        "`r`n"

    $headerBytes =
        [System.Text.Encoding]::ASCII.GetBytes($header)

    $Stream.Write(
        $headerBytes,
        0,
        $headerBytes.Length
    )

    if ($body.Length -gt 0) {
        $Stream.Write(
            $body,
            0,
            $body.Length
        )
    }

    $Stream.Flush()
}

function Send-ErrorResponse {
    param(
        [System.Net.Sockets.NetworkStream]$Stream,

        [int]$StatusCode,

        [string]$Reason,

        [string]$Message
    )

    $object = @{
        error = $Message
    }

    Send-JsonResponse `
        -Stream $Stream `
        -Object $object `
        -StatusCode $StatusCode `
        -Reason $Reason
}

# ============================================================
# Read HTTP headers
# ============================================================

function Read-HttpRequest {
    param(
        [System.Net.Sockets.NetworkStream]$Stream
    )

    $bytes =
        New-Object System.Collections.Generic.List[byte]

    $one =
        New-Object byte[] 1

    $maximum =
        65536


    while ($true) {

        $read =
            $Stream.Read(
                $one,
                0,
                1
            )

        if ($read -eq 0) {
            return $null
        }


        $bytes.Add(
            $one[0]
        )


        if ($bytes.Count -gt $maximum) {
            throw "HTTP headers too large."
        }


        if ($bytes.Count -ge 4) {

            $n =
                $bytes.Count

            if (
                $bytes[$n - 4] -eq 13 -and
                $bytes[$n - 3] -eq 10 -and
                $bytes[$n - 2] -eq 13 -and
                $bytes[$n - 1] -eq 10
            ) {
                break
            }
        }
    }


    $headerText =
        [System.Text.Encoding]::ASCII.GetString(
            $bytes.ToArray()
        )


    $lines =
        $headerText.Split(
            [string[]]@("`r`n"),
            [System.StringSplitOptions]::None
        )


    $parts =
        $lines[0].Split(
            " ",
            3
        )


    if ($parts.Count -ne 3) {
        throw "Invalid HTTP request line."
    }


    $headers =
        @{}

    for (
        $i = 1;
        $i -lt $lines.Count;
        $i++
    ) {

        $line =
            $lines[$i]

        if (
            [string]::IsNullOrWhiteSpace(
                $line
            )
        ) {
            continue
        }


        $colon =
            $line.IndexOf(":")


        if ($colon -le 0) {
            continue
        }


        $name =
            $line.Substring(
                0,
                $colon
            ).Trim().ToLowerInvariant()


        $value =
            $line.Substring(
                $colon + 1
            ).Trim()


        $headers[$name] =
            $value
    }


    $contentLength = 0


    if ($headers.ContainsKey("content-length")) {

        $parsed =
            [int64]0

        if (
            -not [int64]::TryParse(
                $headers["content-length"],
                [ref]$parsed
            )
        ) {
            throw "Invalid Content-Length."
        }

        $contentLength =
            $parsed
    }


    return [PSCustomObject]@{
        Method        = $parts[0].ToUpperInvariant()
        Target        = $parts[1]
        Version       = $parts[2]
        Headers       = $headers
        ContentLength = $contentLength
    }
}

# ============================================================
# Safe filename validation
# ============================================================

function Get-SafeFileName {
    param(
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $null
    }


    try {

        $Name =
            [System.Uri]::UnescapeDataString(
                $Name
            )

    }
    catch {

        return $null

    }


    # Files are intentionally restricted to the root of the share.
    if ($Name.Contains("/")) {
        return $null
    }

    if ($Name.Contains("\")) {
        return $null
    }

    if ($Name.Contains("..")) {
        return $null
    }

    if ($Name.Contains(":")) {
        return $null
    }


    if ($Name.Length -gt 255) {
        return $null
    }


    $invalid =
        [System.IO.Path]::GetInvalidFileNameChars()


    foreach ($character in $Name.ToCharArray()) {

        if ($invalid -contains $character) {
            return $null
        }

        if ([int][char]$character -lt 32) {
            return $null
        }
    }


    if (
        $Name.EndsWith(".") -or
        $Name.EndsWith(" ")
    ) {
        return $null
    }


    $baseName =
        [System.IO.Path]::GetFileNameWithoutExtension(
            $Name
        )


    $devices = @(
        "CON",
        "PRN",
        "AUX",
        "NUL",
        "COM1",
        "COM2",
        "COM3",
        "COM4",
        "COM5",
        "COM6",
        "COM7",
        "COM8",
        "COM9",
        "LPT1",
        "LPT2",
        "LPT3",
        "LPT4",
        "LPT5",
        "LPT6",
        "LPT7",
        "LPT8",
        "LPT9"
    )


    if (
        $devices -contains
        $baseName.ToUpperInvariant()
    ) {
        return $null
    }


    return $Name
}

# ============================================================
# Extract filename from endpoint
# ============================================================

function Get-EndpointFileName {
    param(
        [string]$Target,

        [string]$Prefix
    )

    if (-not $Target.StartsWith($Prefix)) {
        return $null
    }


    $name =
        $Target.Substring(
            $Prefix.Length
        )


    $question =
        $name.IndexOf("?")

    if ($question -ge 0) {

        $name =
            $name.Substring(
                0,
                $question
            )
    }


    return Get-SafeFileName $name
}

# ============================================================
# Upload body
# ============================================================

function Save-RequestBody {
    param(
        [System.Net.Sockets.NetworkStream]$Stream,

        [int64]$Length,

        [string]$Path
    )

    $file =
        $null

    try {

        $file =
            New-Object System.IO.FileStream(
                $Path,
                [System.IO.FileMode]::Create,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None,
                65536,
                [System.IO.FileOptions]::SequentialScan
            )


        $buffer =
            New-Object byte[] 65536


        $remaining =
            $Length


        while ($remaining -gt 0) {

            $wanted =
                [int][Math]::Min(
                    $buffer.Length,
                    $remaining
                )


            $read =
                $Stream.Read(
                    $buffer,
                    0,
                    $wanted
                )


            if ($read -le 0) {
                throw "Client disconnected during upload."
            }


            $file.Write(
                $buffer,
                0,
                $read
            )


            $remaining -= $read
        }


        $file.Flush()
    }
    finally {

        if ($null -ne $file) {
            $file.Dispose()
        }
    }
}

# ============================================================
# Client handler
# ============================================================

function Handle-Client {
    param(
        [System.Net.Sockets.TcpClient]$Client
    )

    $stream =
        $null

    try {

        $stream =
            $Client.GetStream()

        $stream.ReadTimeout =
            120000

        $stream.WriteTimeout =
            120000


        $request =
            Read-HttpRequest $stream


        if ($null -eq $request) {
            return
        }


        # --------------------------------------------------------
        # Front page
        # --------------------------------------------------------

        if (
            $request.Method -eq "GET" -and
            (
                $request.Target -eq "/" -or
                $request.Target.StartsWith("/?")
            )
        ) {

            $body =
                [System.Text.Encoding]::UTF8.GetBytes(
                    $IndexHtml
                )


            Send-Response `
                -Stream $stream `
                -Body $body `
                -ContentType "text/html; charset=utf-8"


            return
        }


       # --------------------------------------------------------
# File list
# --------------------------------------------------------

if (
    $request.Method -eq "GET" -and
    $request.Target -eq "/api/list"
) {

    try {

        $files =
            @(
                Get-ChildItem `
                    -LiteralPath $ShareRoot `
                    -File `
                    -Force `
                    -ErrorAction Stop |
                Where-Object {
                    -not $_.Name.StartsWith(
                        ".lan-upload-",
                        [System.StringComparison]::OrdinalIgnoreCase
                    )
                } |
                Sort-Object Name |
                ForEach-Object {

                    [PSCustomObject]@{
                        name     = $_.Name
                        size     = [int64]$_.Length
                        modified = $_.LastWriteTimeUtc.ToString("o")
                    }
                }
            )

        Send-JsonResponse `
            -Stream $stream `
            -Object $files `
            -StatusCode 200 `
            -Reason "OK"

    }
    catch {

        Write-Host `
            "FILE LIST ERROR: $($_.Exception.ToString())" `
            -ForegroundColor Red

        Send-JsonResponse `
            -Stream $stream `
            -Object @{
                error = "Unable to list files."
            } `
            -StatusCode 500 `
            -Reason "Internal Server Error"
    }

    return
}


# --------------------------------------------------------
# Download
# --------------------------------------------------------

if (
    $request.Method -eq "GET" -and
    $request.Target.StartsWith("/files/")
) {

    $name =
        Get-EndpointFileName `
            -Target $request.Target `
            -Prefix "/files/"


    if ($null -eq $name) {

        Send-ErrorResponse `
            -Stream $stream `
            -StatusCode 400 `
            -Reason "Bad Request" `
            -Message "Invalid filename."

        return
    }


    $path =
        Join-Path `
            $ShareRoot `
            $name


    if (
        -not (
            Test-Path `
                -LiteralPath $path `
                -PathType Leaf
        )
    ) {

        Send-ErrorResponse `
            -Stream $stream `
            -StatusCode 404 `
            -Reason "Not Found" `
            -Message "File not found."

        return
    }


    try {

        $info =
            Get-Item `
                -LiteralPath $path `
                -ErrorAction Stop


        $contentType =
            Get-MimeType $name


        $encodedName =
            [Uri]::EscapeDataString($name)


        $header =
            "HTTP/1.1 200 OK`r`n" +
            "Server: PowerShell-LAN-Share`r`n" +
            "Content-Type: $contentType`r`n" +
            "Content-Length: $($info.Length)`r`n" +
            "Content-Disposition: attachment; filename*=UTF-8''$encodedName`r`n" +
            "Connection: close`r`n" +
            "Cache-Control: no-store`r`n" +
            "`r`n"


        $headerBytes =
            [System.Text.Encoding]::ASCII.GetBytes($header)


        $stream.Write(
            $headerBytes,
            0,
            $headerBytes.Length
        )


        $file = $null

        try {

            $file =
                New-Object System.IO.FileStream(
                    $path,
                    [System.IO.FileMode]::Open,
                    [System.IO.FileAccess]::Read,
                    [System.IO.FileShare]::Read,
                    65536,
                    [System.IO.FileOptions]::SequentialScan
                )


            $buffer =
                New-Object byte[] 65536


            while ($true) {

                $read =
                    $file.Read(
                        $buffer,
                        0,
                        $buffer.Length
                    )


                if ($read -le 0) {
                    break
                }


                $stream.Write(
                    $buffer,
                    0,
                    $read
                )
            }


            $stream.Flush()

        }
        finally {

            if ($null -ne $file) {
                $file.Dispose()
            }
        }

    }
    catch {

        Write-Host `
            "DOWNLOAD ERROR: $($_.Exception.ToString())" `
            -ForegroundColor Red

        # The response may already have started, so don't
        # attempt to send another HTTP response here.
    }

    return
}


# --------------------------------------------------------
# Upload
# --------------------------------------------------------

if (
    $request.Method -eq "PUT" -and
    $request.Target.StartsWith("/upload/")
) {

    $name =
        Get-EndpointFileName `
            -Target $request.Target `
            -Prefix "/upload/"


    if ($null -eq $name) {

        Send-ErrorResponse `
            -Stream $stream `
            -StatusCode 400 `
            -Reason "Bad Request" `
            -Message "Invalid filename."

        return
    }


    if ($request.ContentLength -lt 0) {

        Send-ErrorResponse `
            -Stream $stream `
            -StatusCode 411 `
            -Reason "Length Required" `
            -Message "Content-Length required."

        return
    }


    $destination =
        Join-Path `
            $ShareRoot `
            $name


    $temporaryName =
        ".lan-upload-" +
        [Guid]::NewGuid().ToString("N") +
        ".tmp"


    $temporaryPath =
        Join-Path `
            $ShareRoot `
            $temporaryName


    try {

        Save-RequestBody `
            -Stream $stream `
            -Length $request.ContentLength `
            -Path $temporaryPath


        if (
            Test-Path `
                -LiteralPath $destination
        ) {

            Remove-Item `
                -LiteralPath $destination `
                -Force `
                -ErrorAction Stop
        }


        Move-Item `
            -LiteralPath $temporaryPath `
            -Destination $destination `
            -Force `
            -ErrorAction Stop


        Send-TextResponse `
            -Stream $stream `
            -Text "Upload complete.`r`n" `
            -StatusCode 201 `
            -Reason "Created"

    }
    catch {

        Write-Host `
            "UPLOAD ERROR: $($_.Exception.ToString())" `
            -ForegroundColor Red


        if (
            Test-Path `
                -LiteralPath $temporaryPath
        ) {

            Remove-Item `
                -LiteralPath $temporaryPath `
                -Force `
                -ErrorAction SilentlyContinue
        }


        Send-ErrorResponse `
            -Stream $stream `
            -StatusCode 500 `
            -Reason "Internal Server Error" `
            -Message "Upload failed."

    }

    return
}


        # --------------------------------------------------------
        # Delete
        # --------------------------------------------------------

        if (
            $request.Method -eq "DELETE" -and
            $request.Target.StartsWith("/files/")
        ) {

            $name =
                Get-EndpointFileName `
                    -Target $request.Target `
                    -Prefix "/files/"


            if ($null -eq $name) {

                Send-ErrorResponse `
                    -Stream $stream `
                    -StatusCode 400 `
                    -Reason "Bad Request" `
                    -Message "Invalid filename."

                return
            }


            $path =
                Join-Path `
                    $ShareRoot `
                    $name


            if (
                -not (
                    Test-Path `
                        -LiteralPath $path `
                        -PathType Leaf
                )
            ) {

                Send-ErrorResponse `
                    -Stream $stream `
                    -StatusCode 404 `
                    -Reason "Not Found" `
                    -Message "File not found."

                return
            }


            Remove-Item `
                -LiteralPath $path `
                -Force


            Send-Response `
                -Stream $stream `
                -Body ([byte[]]@()) `
                -StatusCode 204 `
                -Reason "No Content"


            return
        }


        # --------------------------------------------------------
        # Unknown endpoint
        # --------------------------------------------------------

        Send-ErrorResponse `
            -Stream $stream `
            -StatusCode 404 `
            -Reason "Not Found" `
            -Message "Endpoint not found."

    }
    catch {

        try {

            if ($null -ne $stream) {

                Send-ErrorResponse `
                    -Stream $stream `
                    -StatusCode 500 `
                    -Reason "Internal Server Error" `
                    -Message $_.Exception.Message
            }

        }
        catch {
            # Client may already have disconnected.
        }
    }
    finally {

        if ($null -ne $stream) {

            try {
                $stream.Dispose()
            }
            catch {}

        }


        if ($null -ne $Client) {

            try {
                $Client.Close()
            }
            catch {}

        }

    }
}

# ============================================================
# Start server
# ============================================================

$listener = $null

try {

    $ipAddress = [System.Net.IPAddress]::Parse($BindAddress)

    $listener = New-Object System.Net.Sockets.TcpListener(
        $ipAddress,
        $Port
    )

    $listener.Start()

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " PowerShell LAN Share"
    Write-Host "============================================================"
    Write-Host ""

    Write-Host "Shared directory:"
    Write-Host "  $ShareRoot"
    Write-Host ""

    Write-Host "Listening:"
    Write-Host "  $BindAddress`:$Port"
    Write-Host ""

    try {

        $addresses =
            [System.Net.Dns]::GetHostEntry(
                [System.Net.Dns]::GetHostName()
            ).AddressList |
            Where-Object {
                $_.AddressFamily -eq
                [System.Net.Sockets.AddressFamily]::InterNetwork
            }

        if ($addresses) {

            Write-Host "LAN URLs:"

            foreach ($address in $addresses) {

                Write-Host (
                    "  http://{0}:{1}/" -f
                    $address,
                    $Port
                )
            }

            Write-Host ""
        }

    }
    catch {
        Write-Host "Could not determine LAN address."
    }

    Write-Host "Local:"
    Write-Host "  http://localhost:$Port/"
    Write-Host ""

    Write-Host "Press Ctrl+C to stop."
    Write-Host ""

    # --------------------------------------------------------
    # Deliberately synchronous.
    #
    # This avoids PowerShell 5.1/.NET Thread execution-context
    # problems. One HTTP connection is processed at a time.
    # --------------------------------------------------------

    while ($true) {

        $client = $null

        try {

            Write-Host (
                "[{0}] Waiting for connection..." -f
                (Get-Date -Format "HH:mm:ss")
            )

            $client =
                $listener.AcceptTcpClient()

            Write-Host (
                "[{0}] Connection from {1}" -f
                (Get-Date -Format "HH:mm:ss"),
                $client.Client.RemoteEndPoint
            )

            Handle-Client -Client $client

            Write-Host (
                "[{0}] Connection closed." -f
                (Get-Date -Format "HH:mm:ss")
            )

        }
        catch {

            Write-Host ""
            Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
            Write-Host "CONNECTION ERROR"
            Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
            Write-Host $_.Exception.ToString()
            Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
            Write-Host ""

        }
        finally {

            if ($null -ne $client) {

                try {
                    $client.Close()
                }
                catch {}

            }
        }
    }
}
catch {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "SERVER ERROR"
    Write-Host "============================================================"
    Write-Host $_.Exception.ToString()
    Write-Host ""

    throw
}
finally {

    if ($null -ne $listener) {

        try {
            $listener.Stop()
        }
        catch {}

    }

    Write-Host ""
    Write-Host "LAN Share stopped."
}