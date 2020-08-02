local ffi = require("ffi")
local Ref, ui_set, ui_get, ui_set_visible = ui.reference, ui.set, ui.get, ui.set_visible
local globals_realtime, globals_absoluteframetime, globals_tickinterval = globals.realtime, globals.absoluteframetime, globals.tickinterval
local table_insert, table_remove = table.insert, table.remove
local abs, sqrt, floor = math.abs, math.sqrt, math.floor
local HasRan, Val1, Val2, Val3, OldCfg = false, false, false, false, nil
local SSlider, Slider1, Slider2, Slider3, Slider4, Slider5 = false, false, false, false, false, false
local Stop1, Stop2, Stop3, Stop4, Stop5, Speed = false, false, false, false, false, nil
local R2, G2, B2, A2 = 0, 0, 0, 0

local Config      = Ref("CONFIG", "Presets", "Presets")						local FsBYaw	  = Ref("AA", "Anti-aimbot angles", "Freestanding body yaw")
local AAEnabled   = Ref("AA", "Anti-aimbot angles", "Enabled")				local LBYT		  = Ref("AA", "Anti-aimbot angles", "Lower body yaw target") 
local Pitch		  = Ref("AA", "Anti-aimbot angles", "Pitch")				local FYawLimit   = Ref("AA", "Anti-aimbot angles", "Fake yaw limit") 
local YawBase     = Ref("AA", "Anti-aimbot angles", "Yaw base")				local EdgeYaw	  = Ref("AA", "Anti-aimbot angles", "Edge yaw")
local Yaw         = Ref("AA", "Anti-aimbot angles", "Yaw")					local FStanding   = Ref("AA", "Anti-aimbot angles", "Freestanding")
local YawJitter   = Ref("AA", "Anti-aimbot angles", "Yaw jitter")			local LagEnable   = Ref("AA", "Fake lag", "Enabled") 
local BYaw, BYawS = Ref("AA", "Anti-aimbot angles", "Body yaw")				local LagLimit	  = Ref("AA", "Fake lag", "Limit") 

local function FpsTable()
	local Fps_Table = {}
	Fps_Table[59] = "Tickrate"
	for i = 1, 241 do
		Fps_Table[59+i] = 59+i .. "fps"
	end
	return Fps_Table
end

local Enabled     = ui.new_checkbox    ("AA", "Anti-aimbot angles", "Legit AA")
local Invert      = ui.new_hotkey      ("AA", "Anti-aimbot angles", "invert", true)
local Indicators  = ui.new_multiselect ("AA", "Anti-aimbot angles", "Indicators", "Status", "Arrow", "Text")
local Color       = ui.new_color_picker("AA", "Anti-aimbot angles", "Colorz", 76, 148, 255, 255)
local Arrow2      = ui.new_checkbox    ("AA", "Anti-aimbot angles", "Show both arrows")
local Color2 	  = ui.new_color_picker("AA", "Anti-aimbot angles", "Colorz2", 255, 255, 255, 255)
local LegitMode   = ui.new_combobox    ("AA", "Anti-aimbot angles", "Mode", "Safe", "Maximum")
local AutoOff	  = ui.new_multiselect ("AA", "Anti-aimbot angles", "Auto-Off [EXPERIMENTAL]", "Show Sliders", "Fps", "Ping", "Speed", "Loss", "Choke")
local FpsSlider	  = ui.new_slider      ("AA", "Anti-aimbot angles", "Fps Threshold", 59, 300, 59, true, "", 1, FpsTable())
local PingSlider  = ui.new_slider      ("AA", "Anti-aimbot angles", "Ping Threshold", 0, 150, 75, true, "ms")
local SpeedSlider =	ui.new_slider      ("AA", "Anti-aimbot angles", "Speed Threshold", 0, 250, 135, true, "u")
local LossSlider  =	ui.new_slider      ("AA", "Anti-aimbot angles", "Loss Threshold", 0, 10, 1, true, "%")
local ChokeSlider =	ui.new_slider      ("AA", "Anti-aimbot angles", "Choke Threshold", 0, 10, 1, true, "%")
ui_set(Invert, "toggle")

local frametimes = {}
local fps_prev = 0
local last_update_time = 0
local function AccumulateFps()
	local ft = globals_absoluteframetime()
	if ft > 0 then
		table_insert(frametimes, 1, ft)
	end
	local count = #frametimes
	if count == 0 then
		return 0
	end
	local i, accum = 0, 0
	while accum < 0.5 do
		i = i + 1
		accum = accum + frametimes[i]
		if i >= count then
			break
		end
	end
	accum = accum / i
	while i < count do
		i = i + 1
		table_remove(frametimes)
	end
	local fps = 1 / accum
	local rt = globals_realtime()
	if abs(fps - fps_prev) > 4 or rt - last_update_time > 2 then
		fps_prev = fps
		last_update_time = rt
	else
		fps = fps_prev
	end
	return floor(fps + 0.5)
end

local function SetFalse()
	Val1 = false
	Val2 = false
	Val3 = false
end

local function SetFalse2()
	SSlider = false
	Slider1 = false
	Slider2 = false
	Slider3 = false
	Slider4 = false
	Slider5 = false
end

local function TurnOffAA()
	ui_set(Pitch, "Off")
	ui_set(YawBase, "Local view")
	ui_set(Yaw, "Off")
	ui_set(YawJitter, "Off")
	ui_set(FsBYaw, false)
	ui_set(EdgeYaw, false)
	ui_set(FStanding, "-")
end

local function Sync()
	local Selected = ui_get(Indicators)
	for i=1, #Selected do
		if Selected[i] ~= "Status" then Val1 = false end
		if Selected[i] ~= "Arrow"  then Val2 = false end
		if Selected[i] ~= "Text"   then Val3 = false end
	end
	for i=1, #Selected do
		if Selected[i] == "Status" then Val1 = true end
		if Selected[i] == "Arrow"  then Val2 = true end
		if Selected[i] == "Text"   then Val3 = true end
	end
	if next(Selected) == nil then
        SetFalse()
	end
end

local function Sync2()
	local Selected = ui_get(AutoOff)
	for i=1, #Selected do
		if Selected[i] ~= "Show Sliders" then SSlider = false end
		if Selected[i] ~= "Fps"          then Slider1 = false end
		if Selected[i] ~= "Ping"         then Slider2 = false end
		if Selected[i] ~= "Speed"        then Slider3 = false end
		if Selected[i] ~= "Loss"         then Slider4 = false end
		if Selected[i] ~= "Choke"        then Slider5 = false end
	end
	for i=1, #Selected do
		if Selected[i] == "Show Sliders" then SSlider = true end
		if Selected[i] == "Fps"          then Slider1 = true end
		if Selected[i] == "Ping"         then Slider2 = true end
		if Selected[i] == "Speed"        then Slider3 = true end
		if Selected[i] == "Loss"         then Slider4 = true end
		if Selected[i] == "Choke"        then Slider5 = true end
	end
	if next(Selected) == nil then
        SetFalse2()
	end
end

local function SyncMenu()
	Sync()
	Sync2()
	if ui_get(Enabled) then
		if Val2 then
			ui_set_visible(Arrow2, true)
			ui_set_visible(Color2, true)
		else
			ui_set_visible(Arrow2, false)
			ui_set_visible(Color2, false)
		end

		if SSlider then
			if Slider1 then
				ui_set_visible(FpsSlider, true)
			else
				ui_set_visible(FpsSlider, false)
			end

			if Slider2 then
				ui_set_visible(PingSlider, true)
			else
				ui_set_visible(PingSlider, false)
			end

			if Slider3 then
				ui_set_visible(SpeedSlider, true)
			else
				ui_set_visible(SpeedSlider, false)
			end

			if Slider4 then
				ui_set_visible(LossSlider, true)
			else
				ui_set_visible(LossSlider, false)
			end

			if Slider5 then
				ui_set_visible(ChokeSlider, true)
			else
				ui_set_visible(ChokeSlider, false)
			end
		else
			ui_set_visible(FpsSlider  , false)
			ui_set_visible(PingSlider , false)
			ui_set_visible(SpeedSlider, false)
			ui_set_visible(LossSlider , false)
			ui_set_visible(ChokeSlider, false)
		end
	else
		ui_set_visible(FpsSlider  , false)
		ui_set_visible(PingSlider , false)
		ui_set_visible(SpeedSlider, false)
		ui_set_visible(LossSlider , false)
		ui_set_visible(ChokeSlider, false)
		ui_set_visible(Arrow2, false)
		ui_set_visible(Color2, false)
	end
end

local function HandleMenu()
	local BState = ui_get(Enabled)
	ui_set_visible(Indicators, BState)
	ui_set_visible(Color, BState)
	ui_set_visible(LegitMode, BState)
	ui_set_visible(AutoOff, BState)
	if BState then
		HasRan = true
		client.delay_call(0.1, function()
			OldCfg = ui_get(Config)
		end)
		ui_set(AAEnabled, true)
		ui_set(BYaw, "Static")
		ui_set(LagLimit, 14)
		ui_set(LagEnable, false)
		ui_set(FYawLimit, 60)
	else
		if HasRan then
			HasRan = false
			if OldCfg == ui_get(Config) then
				TurnOffAA()
				ui_set(AAEnabled, false)
				ui_set(BYaw, "Off")
				ui_set(LBYT, "Off")
			end
		end
	end
	Sync()
	Sync2()
	SyncMenu()
end

local function CallSyncMenu()
	SyncMenu()
end

local function CheckConditions()
	if Stop1 then ui_set(AAEnabled, false)
		elseif Stop2 then ui_set(AAEnabled, false)
		elseif Stop3 then ui_set(AAEnabled, false)
		elseif Stop4 then ui_set(AAEnabled, false)
		elseif Stop5 then ui_set(AAEnabled, false)
		else ui_set(AAEnabled, true)
	end
end

HandleMenu()
ui.set_callback(Enabled, HandleMenu)
ui.set_callback(Indicators, CallSyncMenu)
ui.set_callback(AutoOff, SyncMenu)


ffi.cdef[[
    typedef void*(__thiscall* get_net_channel_info_t)(void*);
    typedef const char*(__thiscall* get_name_t)(void*);
    typedef const char*(__thiscall* get_address_t)(void*);
    typedef float(__thiscall* get_local_time_t)(void*);
    typedef float(__thiscall* get_time_connected_t)(void*);
    typedef float(__thiscall* get_avg_latency_t)(void*, int);
    typedef float(__thiscall* get_avg_loss_t)(void*, int);
    typedef float(__thiscall* get_avg_choke_t)(void*, int);
]]
local interface_ptr = ffi.typeof('void***')
local rawivengineclient = client.create_interface("engine.dll", "VEngineClient014") or error("VEngineClient014 wasnt found", 2)
local ivengineclient = ffi.cast(interface_ptr, rawivengineclient) or error("rawivengineclient is nil", 2)
local get_net_channel_info = ffi.cast("get_net_channel_info_t", ivengineclient[0][78]) or error("ivengineclient is nil")
local FLOW_OUTGOING = 0
local FLOW_INCOMING	= 1
local MAX_FLOWS		= 2

client.set_event_callback("paint", function()
	if not ui_get(Enabled) then return end

	local netchaninfo    = ffi.cast("void***", get_net_channel_info(ivengineclient))
	local get_avg_loss   = ffi.cast("get_avg_loss_t", netchaninfo[0][11])
	local get_avg_choke  = ffi.cast("get_avg_choke_t", netchaninfo[0][12])
	local Tickrate       = 1 / globals_tickinterval()
	local vx, vy         = entity.get_prop(entity.get_local_player(), "m_vecVelocity")
	local R, G, B, A 	 = ui_get(Color)
	local R3, G3, B3, A3 = ui_get(Color2)

	local X, Y 			 = client.screen_size()
	local Ping  = floor(client.latency()*1000)
	local Loss  = get_avg_loss(netchaninfo, FLOW_INCOMING)
	local Choke = get_avg_choke(netchaninfo, FLOW_INCOMING)

	if vx ~= nil then
		Speed = floor(sqrt(vx*vx + vy*vy + 0.5))
	end

	if ui_get(LegitMode) == "Safe" then
		ui_set(LBYT, "Eye yaw")
	elseif ui_get(LegitMode) == "Maximum" then
		ui_set(LBYT, "Opposite")
	end

	if ui_get(AAEnabled) then
		R2, G2, B2, A2 = 124, 195, 13, 255
	else
		R2, G2, B2, A2 = 255, 0, 0, 255
	end

	if Val1 then
		renderer.indicator(R2, G2, B2, A2, "LEGIT-AA")
	end

	if Val2 then
		if ui_get(Invert) then
			renderer.text(X/2-60, Y/2, R, G, B, A, "+c", 0, "⮜")
			if ui_get(Arrow2) then
				renderer.text(X/2+60, Y/2, R3, G3, B3, A3, "+c", 0, "⮞")
			end
		else
			renderer.text(X/2+60, Y/2, R, G, B, A, "+c", 0, "⮞")
			if ui_get(Arrow2) then
				renderer.text(X/2-60, Y/2, R3, G3, B3, A3, "+c", 0, "⮜")
			end
		end
	end

	if Val3 then
		if ui_get(Invert) then
			renderer.indicator(R, G, B, A, "LEFT")
		else
			renderer.indicator(R, G, B, A, "RIGHT")
		end
	end

	if ui_get(Invert) then
		ui_set(BYawS, 60)
		TurnOffAA()
		ui_set(BYaw, "Static")
	else
		ui_set(BYawS, -60)
		TurnOffAA()
		ui_set(BYaw, "Static")
	end

	if Slider1 then
		if ui_get(FpsSlider) == 59 then
			if(AccumulateFps() < Tickrate) then
				Stop1 = true
			else
				Stop1 = false
			end
		else
			if(AccumulateFps() < ui_get(FpsSlider)) then
				Stop1 = true
			else
				Stop1 = false
			end
		end
	else
		Stop1 = false
	end

	if Slider2 then
		if (Ping > ui_get(PingSlider)) then
			Stop2 = true
		else
			Stop2 = false
		end
	else
		Stop2 = false
	end

	if Slider3 then
		if (Speed > ui_get(SpeedSlider)) then
			Stop3 = true
		else
			Stop3 = false
		end
	else
		Stop3 = false
	end

	if Slider4 then
		if (Loss > ui_get(LossSlider)) then
			Stop4 = true
		else
			Stop4 = false
		end
	else
		Stop4 = false
	end

	if Slider5 then
		if (Choke > ui_get(ChokeSlider)) then
			Stop5 = true
		else
			Stop5 = false
		end
	else
		Stop5 = false
	end
	CheckConditions()
end)