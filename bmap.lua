_addon.name = 'BMAP'
_addon.version = '1.0'

packets = require('packets')
require('logger')

--It checks on zone and whenever you /bmap, not bothering to auto-check. Exercise for the reader if you want to make a bmap annoucer bot.
--windower.register_event("time change", function(new, old)
	--if new % 60 == 0 then
		--print("1hr!")
		--get bmap data
	--end
--end)

--Taken from https://besiege.info/cgi-bin/stat.cgi
--it's 2mins per force gain from 100-200, then 1 minute per from 200+
--230 is assumed to be the required forces, level 12. It's not possible to see the level early, so have to assume this.
--These may vary quite a bit

statics = {}
--Original website numbers
statics["Mamool March Time"] = 15
statics["Troll March Time"] = 15
statics["Lamia March Time"] = 10
statics["Maximum Force Count"] = 230
statics["Force Gain <200"] = {}
statics["Force Gain >200"] = {}
--Perhaps confusing? 'min' is the slowest forces gain rate, resulting in a later arrival
statics["Force Gain <200"]['min'] = 0.4
statics["Force Gain <200"]['max'] = 0.5
statics["Force Gain >200"]['min'] = 0.7
statics["Force Gain >200"]['max'] = 1

--Rework with min/max gain estimates to give a window. This will gradually get closer as the bar fills, regardless of accuracy

function bmap_event(id,original,modified,is_injected,is_blocked)
	if id == 0x05E then
		local junk = nil --There's some padding/unknown bits on the data we want that don't need to be kept

		local bmap = {}
		bmap['Mamool'] = {}
		bmap['Troll'] = {}
		bmap['Lamia'] = {}

		local tribes = {}
		tribes[0] = "Mamool"
		tribes[1] = "Troll"
		tribes[2] = "Lamia"
		
		junk,bmap['Owner'],junk = original:unpack('b8b2b6', 0xA0)
		junk,bmap['Orders'],junk = original:unpack('b10b2b4', 0xA0)

		--These could be redundant? See if they match other source
		junk,bmap['Mamool']['Level'] = original:unpack('b12b4', 0xA0)
		junk,bmap['Troll']['Level'],junk = original:unpack('b8b4b4', 0xA1)
		junk,bmap['Lamia']['Level'] = original:unpack('b12b4', 0xA1)

		local tribes = {}
		tribes[0] = "Mamool"
		tribes[1] = "Troll"
		tribes[2] = "Lamia"

		for i = 0,2 do
			bmap[tribes[i]] = {}
			--This is ugly as hell but appears to be correct.
			--Level2 is the same as level above, just a second source
			junk,bmap[tribes[i]]['Status'],bmap[tribes[i]]['Force Count'],bmap[tribes[i]]['Level2'],bmap[tribes[i]]['Mirrors'],bmap[tribes[i]]['Prisoners'],junk = original:unpack('b8b3b8b4b4b4b1', 0xA4+4*i)
		end

		bmap = translate_mappings(bmap)

		for _,tribe in pairs(tribes) do
			if bmap[tribe]["Status"] == "Advancing" then
				local arrival = os.time() + statics[tribe.." March Time"]*60
				local str = tribe.." is Advancing, arriving before "..os.date("%I:%M %p",arrival)
				notice(str)
			elseif bmap[tribe]["Status"] == "Attacking" then
				local str = tribe.." is in combat now"
				notice(str)
			elseif bmap[tribe]["Status"] == "Preparing" then
				local arrival_early = nil
				local arrival_late = nil
				if bmap[tribe]["Force Count"] < 200 then
					arrival_early = os.time() + ((200-bmap[tribe]["Force Count"])/statics["Force Gain <200"]['max'] + (statics["Maximum Force Count"]-200)/statics["Force Gain >200"]['max'] + statics[tribe.." March Time"])*60
					arrival_late = os.time() + ((200-bmap[tribe]["Force Count"])/statics["Force Gain <200"]['min'] + (statics["Maximum Force Count"]-200)/statics["Force Gain >200"]['min'] + statics[tribe.." March Time"])*60
				else
					arrival_early = os.time() + ((statics["Maximum Force Count"]-bmap[tribe]["Force Count"])/statics["Force Gain >200"]['max'] + statics[tribe.." March Time"])*60
					arrival_late = os.time() + ((statics["Maximum Force Count"]-bmap[tribe]["Force Count"])/statics["Force Gain >200"]['min'] + statics[tribe.." March Time"])*60
				end
				local str = tribe.."@"..bmap[tribe]["Force Count"].." arriving between "..os.date("%I:%M %p",arrival_early).." and "..os.date("%I:%M %p",arrival_late)
				notice(str)
			end
		end
	end
end

--Little of this is currently used, but could be?
function translate_mappings(bmap)
	local owners = {}
	owners[0] = "Whitegate"
	owners[1] = "Mamool"
	owners[2] = "Troll"
	owners[3] = "Lamia"

	local orders = {}
	orders[0] = "Defend"
	orders[1] = "Intercept"
	orders[2] = "Invade"
	orders[3] = "Recover"

	local beast_status = {}
	beast_status[0] = "Training"
	beast_status[1] = "Advancing"
	beast_status[2] = "Attacking"
	beast_status[3] = "Retreating"
	beast_status[4] = "Defending"
	beast_status[5] = "Preparing"

	bmap['Owner'] = owners[bmap['Owner']]
	bmap['Orders'] = orders[bmap['Orders']]
	bmap['Mamool']['Status'] = beast_status[bmap['Mamool']['Status']]
	bmap['Troll']['Status']  = beast_status[bmap['Troll']['Status']]
	bmap['Lamia']['Status']  = beast_status[bmap['Lamia']['Status']]

	return bmap
end

windower.register_event('incoming chunk', bmap_event)