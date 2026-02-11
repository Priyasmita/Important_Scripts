# IIS Manager -> Application Pools ->  App Pool -> Advanced Settings -> Under Process Model, set Load User Profile = True -> Click OK and restart the App Pool

Get-ChildItem Cert:\LocalMachine\CA | Format-Table Subject, Thumbprint
Get-ChildItem Cert:\LocalMachine\Root | Format-Table Subject, Thumbprint

runas /user:DOMAIN\svc_weather powershell.exe
Get-ChildItem Cert:\LocalMachine\Root | Measure-Object
Invoke-WebRequest https://third-party/WeatherService/ #This will reveal the exact error the service account encounters.

#Set Load User Profile = True on the App Pool and ensure the third-party's intermediate certificates are in Cert:\LocalMachine\CA. Either one alone may not be sufficient — do both


$soapEnvelope = @"
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xmlns:xsd="http://www.w3.org/2001/XMLSchema"
               xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <Add xmlns="http://tempuri.org/">
      <intA>5</intA>
      <intB>3</intB>
    </Add>
  </soap:Body>
</soap:Envelope>
"@
$url = "http://www.dneonline.com/calculator.asmx"
$soapAction = "http://tempuri.org/Add"

$headers = @{
    "SOAPAction" = $soapAction
}

$response = Invoke-WebRequest `
    -Uri $url `
    -Method Post `
    -Headers $headers `
    -Body $soapEnvelope `
    -ContentType "text/xml; charset=utf-8"

$response.Content


#METHOD-2

$response = Invoke-RestMethod `
    -Uri $url `
    -Method Post `
    -Headers $headers `
    -Body $soapEnvelope `
    -ContentType "text/xml; charset=utf-8"

$response

#Windows Auth
Invoke-WebRequest `
    -Uri $url `
    -Method Post `
    -Headers $headers `
    -Body $soapEnvelope `
    -UseDefaultCredentials `
    -ContentType "text/xml; charset=utf-8"

#Baic Auth
$cred = Get-Credential

Invoke-WebRequest `
    -Uri $url `
    -Method Post `
    -Headers $headers `
    -Body $soapEnvelope `
    -ContentType "text/xml; charset=utf-8" `
    -Credential $cred

  #Parse Response
  [xml]$xml = $response.Content
$xml.Envelope.Body.AddResponse.AddResult


   <sources>
        <source name="System.Net" switchValue="Verbose">
            <listeners>
                <add name="net" type="System.Diagnostics.TextWriterTraceListener"
                     initializeData="C:\logs\network.log" />
            </listeners>
        </source>
    </sources>
