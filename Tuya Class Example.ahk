; Version 0.1
#NoEnv
#SingleInstance, Force
SetWorkingDir %A_ScriptDir%
SetBatchLines, -1
#Include <Tuya4AHK>

; ****************************************
; INITIALIZE CLASS AND GET TOKEN
; ****************************************
tuyaApi := new TuyaApi()
tuyaApi.cfg.debug := 1 ; Since this is an example we set debug to true so that we get notified of errors
tuyaApi.getToken()  ; There really is no need to call this since by default it retries on Token emptry or invalid

; ****************************************
; PERFORM ACTION ON DEVICE
; ****************************************
; Turn on light
; tuyaApi.toggleOn(tuyaApi.devices[2].id, "true") ; Returns status 200 if successful

; Turn off light
; tuyaApi.toggleOn(tuyaApi.devices[2].id, "false")

; Turns on light, sets luminosity to 1000 (max [10-1000]) and warmness to 0 (warmest [0-1000])
; tuyaApi.setNormalLightStatus(tuyaApi.devices[2].id, "true", "1000", "0")

; Turns on light, sets HSV values to: h:240 -> blue, saturation -> 1000, value -> 1000
; tuyaApi.setHSVLightStatus(tuyaApi.devices[2].id, "true", "240", "1000", "1000")


; ****************************************
; GET DEVICE INFORMATION
; ****************************************
; a := tuyaApi.getDeviceInfo(tuyaApi.devices[2].id)
; b := tuyaApi.getDevicesInfo(tuyaApi.devices)
; c := tuyaApi.getDeviceStats(tuyaApi.devices[2].id)
; d := tuyaApi.getDevicesStats(tuyaApi.devices)



; ****************************************
; HOTKEYS EXAMPLE
; ****************************************
currentLightId := tuyaApi.devices[1].id
luminosity := 1000
warmth := 0

f1::
	Random, val, 0, 360 ; Random HSV Color
	tuyaApi.setHSVLightStatus(currentLightId, "true", val, "1000", "1000")
return

f2::
	tuyaApi.toggleOn(currentLightId, "true")
return

f3::
	if(luminosity > 100)
		luminosity -= 100
	tuyaApi.setNormalLightStatus(currentLightId, "true", luminosity, warmth)
return

f4::
	if(luminosity < 1000)
		luminosity += 100
	tuyaApi.setNormalLightStatus(currentLightId, "true", luminosity, warmth)
return

f5::
	if(warmth > 100)
		warmth -= 100
	tuyaApi.setNormalLightStatus(currentLightId, "true", luminosity, warmth)
return

f6::
	if(warmth < 1000)
		warmth += 100
	tuyaApi.setNormalLightStatus(currentLightId, "true", luminosity, warmth)
return

f7::
	tuyaApi.toggleOn(currentLightId, "false")
return