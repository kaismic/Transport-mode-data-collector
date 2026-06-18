$api = "https://pmegv0abk8.execute-api.ap-southeast-2.amazonaws.com/Prod"

$body = @{
  invite_code = "KAIS-7F3Q-22"
  session_id = "11111111-1111-4111-8111-111111111113"
  device_uuid = "22222222-2222-4222-8222-222222222222"
  vehicle_type = "car"
  phone_position = "pocket"
  started_at_ms = 1710000000000
  stopped_at_ms = 1710000060000
  trimmed_start_ms = 1710000000000
  trimmed_end_ms = 1710000060000
  uploaded_at_ms = 1710000070000
  sensor_manifest = @{
    accelerometer = @{ available = $true; observed_hz = 50 }
    gyroscope = @{ available = $true; observed_hz = 50 }
    magnetometer = @{ available = $true; observed_hz = 25 }
    barometer = @{ available = $false }
  }
  sample_count = 1
} | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod `
  -Method Post `
  -Uri "$api/sessions/request-upload" `
  -ContentType "application/json" `
  -Body $body

$response

$payload = @{
  session_id = "11111111-1111-4111-8111-111111111111"
  vehicle_type = "car"
  phone_position = "pocket"
  samples = @(
    @{
      ts = 1710000000000
      ax = 0.1
      ay = 0.2
      az = 9.8
      gx = 0.01
      gy = 0.02
      gz = 0.03
    }
  )
} | ConvertTo-Json -Depth 10

[System.IO.File]::WriteAllText("$PWD\test_payload.json", $payload)
$bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
$out = [System.IO.File]::Create("$PWD\test_payload.json.gz")
$gzip = New-Object System.IO.Compression.GzipStream($out, [System.IO.Compression.CompressionMode]::Compress)
$gzip.Write($bytes, 0, $bytes.Length)
$gzip.Close()
$out.Close()

curl.exe -X PUT "$($response.presigned_url)" `
  -H "Content-Type: application/json" `
  -H "Content-Encoding: gzip" `
  --data-binary "@test_payload.json.gz"
