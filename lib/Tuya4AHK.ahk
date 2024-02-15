#Include CNG.ahk
#Include cJSON.ahk

class TuyaApi {
    ; Initialize the class
	__New() {
        this.loadConfig()
		this.loadDevices()
		this.retryNum := 0
    }

    ; Load configuration from common_data.json file
    loadConfig() {
        FileRead, cfg, ./conf/common_data.json
        this.cfg := JSON.Load(cfg)
		this.clientId := this.cfg.client_id
        this.clientSecret := this.cfg.secret
        this.apiUrl := this.cfg.url
    }

    ; Load devices from devices.json file
    loadDevices() {
        FileRead, devices, ./conf/devices.json
        this.devices := JSON.Load(devices)
    }

    ; Get Tuya API token
    getToken() {
		outData := this.tuyaApiCall("/v1.0/token?grant_type=1", "", "GET", true)
		if(outData.status == 200){
			result_obj := JSON.Load(outData.result)
			if(result_obj.success){
				this.accessToken := result_obj.result.access_token
				if(FileExist("./conf/access_token")){
					FileRead, prvious_token, ./conf/access_token
				}
				if(this.accessToken != prvious_token){
					FileDelete, ./conf/access_token
					FileAppend, % this.accessToken, ./conf/access_token
					if(this.cfg.debug)
						MsgBox % "Access Token generated: " this.accessToken
				}
			}else{
				if(this.cfg.debug)
					MsgBox % "Error in tuya_api_call() response:" result_obj.msg
			}
		}else{
			if(this.cfg.debug)
				MsgBox % "Error in tuya_api_call(): " outData.status
		}
    }

    ; Refresh Tuya API token
    refreshToken(refreshToken) {
        return this.tuyaApiCall("/v1.0/token/" refreshToken, "", "GET", true)
    }

    ; Run action on a specific Tuya device
    runAction(deviceId, body := "") {
		if(body != ""){
			urlCmd := "/v1.0/devices/" deviceId "/commands"
			return this.tuyaApiCall(urlCmd, this.body)
		}
    }

	; Toggle On
	toggleOn(deviceId, valueOn){
		this.body :=
		(
		"{
			""commands"": [
				{
					""code"": ""switch_led"",
					""value"": " valueOn "
				}
			]
		}"
		)
		return this.runAction(deviceId, this.body)
	}

	; Set Light Status, Luminosity and Warmth
	setNormalLightStatus(deviceId, lightStatus, luminosity, warmth){
		if(luminosity >= 10 && luminosity <= 1000 && warmth >= 0 && warmth <= 1000){
			this.body :=
			(
			"{
				""commands"": [
					{
						""code"": ""switch_led"",
						""value"": " lightStatus "
					},
					{
						""code"": ""bright_value_v2"",
						""value"": " luminosity "
					},
					{
						""code"": ""temp_value_v2"",
						""value"": " warmth "
					}
				]
			}"
			)
			return this.runAction(deviceId, this.body)
		}else if(this.cfg.debug){
			MsgBox, Parameters not in range
		}
	}

	; Set Light HSV Status
	setHSVLightStatus(deviceId, lightStatus, h, s, v){
		if(h >= 0 && h <= 360 && s >= 0 && s <= 1000 && v >= 0 && v <= 1000){
			this.body :=
			(
			"{
				""commands"": [
					{
						""code"": ""switch_led"",
						""value"": " lightStatus "
					},
					{
						""code"": ""colour_data_v2"",
						""value"": ""{\""h\"":" h ",\""s\"":" s ",\""v\"":" v "}""
					}
				]
			}"
			)
			return this.runAction(deviceId, this.body)
		}else if(this.cfg.debug){
			MsgBox, Parameters not in range
		}
	}

    ; Get information about a specific Tuya device
    getDeviceInfo(deviceId) {
        urlCmd := "/v1.0/devices/" deviceId
        return this.tuyaApiCall(urlCmd, "", "GET")
    }

    ; Get information about multiple Tuya devices
    getDevicesInfo(deviceIdList) {
        deviceIds := ""
        Loop % deviceIdList.length()
        {
            if (A_Index != deviceIdList.length())
                deviceIds .= deviceIdList[A_Index].id ","
            else
                deviceIds .= deviceIdList[A_Index].id
        }
        urlCmd := "/v1.0/devices/?device_ids=" deviceIds "&page_no=1&page_size=20"
        return this.tuyaApiCall(urlCmd, "", "GET")
    }

    ; Get status of a specific Tuya device
    getDeviceStats(deviceId) {
        urlCmd := "/v1.0/devices/" deviceId "/status"
        return this.tuyaApiCall(urlCmd, "", "GET")
    }

    ; Get status of multiple Tuya devices
    getDevicesStats(deviceIdList) {
        deviceIds := ""
        Loop % deviceIdList.length()
        {
            if (A_Index != deviceIdList.length())
                deviceIds .= deviceIdList[A_Index].id ","
            else
                deviceIds .= deviceIdList[A_Index].id
        }
        urlCmd := "/v1.0/devices/status?device_ids=" deviceIds
        return this.tuyaApiCall(urlCmd, "", "GET")
    }

    ; Make a Tuya API call
    tuyaApiCall(urlCmd, body := "", httpMethod := "POST", getToken := false) {
        if (!getToken) {
            FileRead, access_token, ./conf/access_token
            this.accessToken := access_token
        }else{
			this.accessToken := ""
		}
        this.signStr := this.stringToSign(httpMethod, urlCmd, body)
		this.timestamp := this.oauthTimestamp()

        HttpObj := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        HttpObj.Open(httpMethod, this.apiUrl urlCmd, 0)
        HttpObj.SetRequestHeader("Content-Type", "application/json")
        HttpObj.SetRequestHeader("client_id", this.clientId)
        HttpObj.SetRequestHeader("sign", this.calcSign(this.clientId, this.accessToken, this.timestamp, this.signStr, this.clientSecret))
        HttpObj.SetRequestHeader("t", this.timestamp)
        if (!getToken && this.accessToken != "")
            HttpObj.SetRequestHeader("access_token", this.accessToken)
        HttpObj.SetRequestHeader("sign_method", "HMAC-SHA256")
        HttpObj.Send(body)
		if(HttpObj.Status == 200 && JSON.Load(HttpObj.ResponseText).code == "1010" && this.retryNum = 0){
			this.retryNum := 1
			this.retry := {"urlCmd": urlCmd, "body": body, "httpMethod": httpMethod, "getToken": getToken}
			this.getToken()
			this.tuyaApiCall(this.retry.urlCmd, this.retry.body, this.retry.httpMethod, this.retry.getToken)
		}else{
			this.retryNum := 0
			if(this.cfg.debug){
				if(HttpObj.Status == 200){
					response := JSON.Load(HttpObj.ResponseText)
					if(!response.success){
						MsgBox, % "Call error`nCode: " response.code "`nMsg: " response.msg
					}
				}else{
					MsgBox, % "HTTP Status: " HttpObj.Status "`nResponse: " HttpObj.ResponseText
				}
			}
		}
        return {"result": HttpObj.ResponseText, "status": HttpObj.Status}
    }

    ; Convert method, urlCmd, and body into signature string
    stringToSign(method, urlCmd, body) {
        sha256 := bcrypt_sha256(body)
        return method "`n" sha256 "`n`n" urlCmd
    }

    ; Calculate signature
    calcSign(clientId, accessToken, timestamp, signStr, secret) {
        str := clientId accessToken timestamp signStr
        hash := bcrypt_sha256_hmac(str, secret)
        StringUpper, hash, % hash
        return hash
    }

    ; Generate OAuth timestamp
    oauthTimestamp(serverTime := "") {
        static offset := 0
        if (serverTime != "" && "19700101000000" < (serverTime := RegexReplace(serverTime, "\D")))
        {
            offset := serverTime
            offset -= A_NowUTC, s
        }
        timestamp := A_NowUTC
        timestamp -= 19700101000000, s
        return SubStr(0.0 + timestamp + offset, 1, 1 + Floor(Log(timestamp + offset)))*1000
    }
}

bcrypt_sha256(string, encoding := "utf-8")
{
    static BCRYPT_SHA256_ALGORITHM := "SHA256"
    static BCRYPT_OBJECT_LENGTH    := "ObjectLength"
    static BCRYPT_HASH_LENGTH      := "HashDigestLength"

	try
	{
		; loads the specified module into the address space of the calling process
		if !(hBCRYPT := DllCall("LoadLibrary", "str", "bcrypt.dll", "ptr"))
			throw Exception("Failed to load bcrypt.dll", -1)

		; open an algorithm handle
		if (NT_STATUS := DllCall("bcrypt\BCryptOpenAlgorithmProvider", "ptr*", hAlg, "ptr", &BCRYPT_SHA256_ALGORITHM, "ptr", 0, "uint", 0) != 0)
			throw Exception("BCryptOpenAlgorithmProvider: " NT_STATUS, -1)

		; calculate the size of the buffer to hold the hash object
		if (NT_STATUS := DllCall("bcrypt\BCryptGetProperty", "ptr", hAlg, "ptr", &BCRYPT_OBJECT_LENGTH, "uint*", cbHashObject, "uint", 4, "uint*", cbData, "uint", 0) != 0)
			throw Exception("BCryptGetProperty: " NT_STATUS, -1)

		; allocate the hash object
		VarSetCapacity(pbHashObject, cbHashObject, 0)
		;	throw Exception("Memory allocation failed", -1)

		; calculate the length of the hash
		if (NT_STATUS := DllCall("bcrypt\BCryptGetProperty", "ptr", hAlg, "ptr", &BCRYPT_HASH_LENGTH, "uint*", cbHash, "uint", 4, "uint*", cbData, "uint", 0) != 0)
			throw Exception("BCryptGetProperty: " NT_STATUS, -1)

		; allocate the hash buffer
		VarSetCapacity(pbHash, cbHash, 0)
		;	throw Exception("Memory allocation failed", -1)

		; create a hash
		if (NT_STATUS := DllCall("bcrypt\BCryptCreateHash", "ptr", hAlg, "ptr*", hHash, "ptr", &pbHashObject, "uint", cbHashObject, "ptr", 0, "uint", 0, "uint", 0) != 0)
			throw Exception("BCryptCreateHash: " NT_STATUS, -1)

		; hash some data
		VarSetCapacity(pbInput, (StrPut(string, encoding) - 1) * ((encoding = "utf-16" || encoding = "cp1200") ? 2 : 1), 0)
		cbInput := (StrPut(string, &pbInput, encoding) - 1) * ((encoding = "utf-16" || encoding = "cp1200") ? 2 : 1)
		if (NT_STATUS := DllCall("bcrypt\BCryptHashData", "ptr", hHash, "ptr", &pbInput, "uint", cbInput, "uint", 0) != 0)
			throw Exception("BCryptHashData: " NT_STATUS, -1)

		; close the hash
		if (NT_STATUS := DllCall("bcrypt\BCryptFinishHash", "ptr", hHash, "ptr", &pbHash, "uint", cbHash, "uint", 0) != 0)
			throw Exception("BCryptFinishHash: " NT_STATUS, -1)

		loop % cbHash
			hash .= Format("{:02x}", NumGet(pbHash, A_Index - 1, "uchar"))
	}
	catch exception
	{
		; represents errors that occur during application execution
		throw Exception
	}
	finally
	{
		; cleaning up resources
		if (pbInput)
			VarSetCapacity(pbInput, 0)
		if (hHash)
			DllCall("bcrypt\BCryptDestroyHash", "ptr", hHash)
		if (pbHash)
			VarSetCapacity(pbHash, 0)
		if (pbHashObject)
			VarSetCapacity(pbHashObject, 0)
		if (hAlg)
			DllCall("bcrypt\BCryptCloseAlgorithmProvider", "ptr", hAlg, "uint", 0)
		if (hBCRYPT)
			DllCall("FreeLibrary", "ptr", hBCRYPT)
	}
	return hash
}

bcrypt_sha256_hmac(string, hmac, encoding := "utf-8")
{
    static BCRYPT_SHA256_ALGORITHM     := "SHA256"
    static BCRYPT_ALG_HANDLE_HMAC_FLAG := 0x00000008
    static BCRYPT_OBJECT_LENGTH        := "ObjectLength"
    static BCRYPT_HASH_LENGTH          := "HashDigestLength"

	try
	{
		; loads the specified module into the address space of the calling process
		if !(hBCRYPT := DllCall("LoadLibrary", "str", "bcrypt.dll", "ptr"))
			throw Exception("Failed to load bcrypt.dll", -1)

		; open an algorithm handle
		if (NT_STATUS := DllCall("bcrypt\BCryptOpenAlgorithmProvider", "ptr*", hAlg, "ptr", &BCRYPT_SHA256_ALGORITHM, "ptr", 0, "uint", BCRYPT_ALG_HANDLE_HMAC_FLAG) != 0)
			throw Exception("BCryptOpenAlgorithmProvider: " NT_STATUS, -1)

		; calculate the size of the buffer to hold the hash object
		if (NT_STATUS := DllCall("bcrypt\BCryptGetProperty", "ptr", hAlg, "ptr", &BCRYPT_OBJECT_LENGTH, "uint*", cbHashObject, "uint", 4, "uint*", cbData, "uint", 0) != 0)
			throw Exception("BCryptGetProperty: " NT_STATUS, -1)

		; allocate the hash object
		VarSetCapacity(pbHashObject, cbHashObject, 0)
		;	throw Exception("Memory allocation failed", -1)

		; calculate the length of the hash
		if (NT_STATUS := DllCall("bcrypt\BCryptGetProperty", "ptr", hAlg, "ptr", &BCRYPT_HASH_LENGTH, "uint*", cbHash, "uint", 4, "uint*", cbData, "uint", 0) != 0)
			throw Exception("BCryptGetProperty: " NT_STATUS, -1)

		; allocate the hash buffer
		VarSetCapacity(pbHash, cbHash, 0)
		;	throw Exception("Memory allocation failed", -1)

		; create a hash
		VarSetCapacity(pbSecret, (StrPut(hmac, encoding) - 1) * ((encoding = "utf-16" || encoding = "cp1200") ? 2 : 1), 0)
		cbSecret := (StrPut(hmac, &pbSecret, encoding) - 1) * ((encoding = "utf-16" || encoding = "cp1200") ? 2 : 1)
		if (NT_STATUS := DllCall("bcrypt\BCryptCreateHash", "ptr", hAlg, "ptr*", hHash, "ptr", &pbHashObject, "uint", cbHashObject, "ptr", &pbSecret, "uint", cbSecret, "uint", 0) != 0)
			throw Exception("BCryptCreateHash: " NT_STATUS, -1)

		; hash some data
		VarSetCapacity(pbInput, (StrPut(string, encoding) - 1) * ((encoding = "utf-16" || encoding = "cp1200") ? 2 : 1), 0)
		cbInput := (StrPut(string, &pbInput, encoding) - 1) * ((encoding = "utf-16" || encoding = "cp1200") ? 2 : 1)
		if (NT_STATUS := DllCall("bcrypt\BCryptHashData", "ptr", hHash, "ptr", &pbInput, "uint", cbInput, "uint", 0) != 0)
			throw Exception("BCryptHashData: " NT_STATUS, -1)

		; close the hash
		if (NT_STATUS := DllCall("bcrypt\BCryptFinishHash", "ptr", hHash, "ptr", &pbHash, "uint", cbHash, "uint", 0) != 0)
			throw Exception("BCryptFinishHash: " NT_STATUS, -1)

		loop % cbHash
			hash .= Format("{:02x}", NumGet(pbHash, A_Index - 1, "uchar"))
	}
	catch exception
	{
		; represents errors that occur during application execution
		throw Exception
	}
	finally
	{
		; cleaning up resources
		if (pbInput)
			VarSetCapacity(pbInput, 0)
		if (hHash)
			DllCall("bcrypt\BCryptDestroyHash", "ptr", hHash)
		if (pbHash)
			VarSetCapacity(pbHash, 0)
		if (pbHashObject)
			VarSetCapacity(pbHashObject, 0)
		if (hAlg)
			DllCall("bcrypt\BCryptCloseAlgorithmProvider", "ptr", hAlg, "uint", 0)
		if (hBCRYPT)
			DllCall("FreeLibrary", "ptr", hBCRYPT)
	}
	return hash
}