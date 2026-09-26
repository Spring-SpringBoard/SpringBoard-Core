function gadget:GetInfo()
	return {
		name = "Dev Scene (SB)",
		desc = "Places a debug subject and frames the camera on it, so a shader panel opens onto something",
		author = "SpringBoard",
		date = "2026",
		license = "MIT OR Apache-2.0",
		layer = 10,
		enabled = true,
	}
end

-- Opt-in only: `sb_dev_scene=<featureDef>` in modoptions, which `just run-asset`
-- writes into the boot script. Without it this gadget does nothing at all, so it
-- can never disturb a real editing session.
local OPTIONS = Spring.GetModOptions() or {}
local SCENE = OPTIONS.sb_dev_scene

if not SCENE then
	return false
end

-- Three of them, in a row: one object cannot show whether shading responds to
-- facing, and a lone silhouette hides tiling seams between neighbours.
local COPIES = 3
local SPACING = 130

if gadgetHandler:IsSyncedCode() then
	function gadget:Initialize()
		local defID = FeatureDefNames[SCENE] and FeatureDefNames[SCENE].id
		if not defID then
			-- A game mounted over the editor names its scenes the same way and places them
			-- itself; nothing is wrong when the name is not a feature here.
			Spring.Log("sb-dev-scene", LOG.INFO, ("no featureDef %q; not placing one"):format(SCENE))
			gadgetHandler:RemoveGadget(self)
			return
		end

		local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
		for i = 1, COPIES do
			local px = x + (i - (COPIES + 1) / 2) * SPACING
			Spring.CreateFeature(defID, px, Spring.GetGroundHeight(px, z), z, (i - 1) * 8192)
		end
		Spring.Log("sb-dev-scene", LOG.NOTICE, ("placed %d x %s"):format(COPIES, SCENE))
	end
else
	-- A material/LOD capture harness supplies and verifies its own camera.
	-- Keep feature placement available without competing with that camera.
	if OPTIONS.sb_dev_scene_camera == "0" then
		return false
	end
	-- Camera framing, both overridable per run so a sweep can capture the same asset
	-- at several distances and angles.
	local DISTANCE = tonumber(OPTIONS.sb_dev_scene_dist) or 320

	-- Downward tilt in radians. The overhead camera clamps to [0.01, pi/2], where
	-- pi/2 is horizontal, so the default is a shallow look slightly down. A
	-- near-overhead view of a vertical prop shows mostly the top of the arch band
	-- and is genuinely misleading about the rest of it.
	local TILT = tonumber(OPTIONS.sb_dev_scene_tilt) or 1.30

	-- Switch the camera to the overhead controller and place it there outright.
	--
	-- The editor boots in the *overview* camera, whose whole job is to show the
	-- entire map. It exposes a `height` key and ignores it, so mutating the live
	-- state set a value that read back correctly and changed nothing -- every
	-- capture came out as the same whole-map shot. The mode has to change too, and
	-- `name` in the state table is what changes it.
	--
	-- For the overhead camera `pos` is the ground point it orbits, not the eye, so
	-- the subject position goes there and the eye follows from height and angle.
	local function frameSubject()
		local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
		Spring.SetCameraState({
			name = "ta",
			px = x,
			py = Spring.GetGroundHeight(x, z),
			pz = z,
			height = DISTANCE,
			angle = TILT,
			flipped = false,
		}, 0)
	end

	-- Keep reapplying until it sticks, rather than setting it once.
	--
	-- The editor sets its own camera at more than one point while a project loads, so
	-- a single set on an early frame is silently overwritten and captures then
	-- photograph the default whole-map view. This holds the framing until the camera
	-- reads back correct several times running, then says so and stops. That log line
	-- is what automation waits on, so it never has to guess a duration.
	local SETTLE_CHECKS = 5
	local GIVE_UP_FRAMES = 600
	local TOLERANCE = 1.0
	local FIRST_FRAME = 30

	local frames = 0
	local settled = 0

	function gadget:Update()
		-- Not until the game is actually simulating.
		--
		-- `Update` runs throughout loading, where the camera controller is not yet
		-- stepping and the engine has not drawn a live frame -- the status bar reads
		-- 0 FPS and every log line is stamped frame -1. Framing there set state that
		-- never took effect, and automation waiting on the log line then captured
		-- that dead pre-game frame. Gating here makes the log line mean "the engine
		-- is live and pointed at the subject", which is what a capture needs.
		if Spring.GetGameFrame() < 1 then
			return
		end

		frames = frames + 1
		if frames < FIRST_FRAME then
			return
		end

		local state = Spring.GetCameraState()
		local actual = state.height or state.dist
		-- The mode is part of the check: the overview camera reports a plausible
		-- height while ignoring it, so height alone cannot say the framing took.
		if state.name == "ta" and actual and math.abs(actual - DISTANCE) <= TOLERANCE then
			settled = settled + 1
		else
			settled = 0
			frameSubject()
		end

		-- Success and giving up have to read differently. Both used to log "framed",
		-- so automation waiting on that word could not tell a framed camera from one
		-- still in the boot overview, and a run that never framed captured anyway.
		if settled >= SETTLE_CHECKS then
			Spring.Log(
				"sb-dev-scene",
				LOG.NOTICE,
				("framed at %d in %s after %d frames"):format(
					DISTANCE,
					tostring(Spring.GetCameraState().name),
					frames
				)
			)
			gadgetHandler:RemoveGadget(self)
		elseif frames > GIVE_UP_FRAMES then
			Spring.Log(
				"sb-dev-scene",
				LOG.WARNING,
				("gave up framing at %d after %d frames; camera is %s"):format(
					DISTANCE,
					frames,
					tostring(Spring.GetCameraState().name)
				)
			)
			gadgetHandler:RemoveGadget(self)
		end
	end
end
