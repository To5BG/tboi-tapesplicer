local TimeSplice = RegisterMod("KingCrimson",1.0)
local item = Isaac.GetItemIdByName("Tape splicer")

local moveX = {0,0,0,0} -- 1 for right, -1 for left
local moveY = {0,0,0,0} -- 1 for down, -1 for up
local shootX = {0,0,0,0} -- 1 for right, -1 for left
local shootY = {0,0,0,0} -- 1 for down, -1 for up
local rockstuckcooldown = {0,0,0,0}
local lastplayerpos = {Vector(0,0),Vector(0,0),Vector(0,0),Vector(0,0)}
local aroundrockdirection = {0,0,0,0}
local incorner = {-1,-1,-1,-1}

local avoidrange = 15
local firerange = 60
local pickupdistance = 0
local enemydistance = 0
local chaserange = 0
local shoottolerance = 25
local bossroom = false
local ignoreenemiesitems = false
local bombcooldown = 0
local highestshopprice = 0
local visitedcrawlspace = false
local greedmodecooldown = 0
local greedmodebuttonpos = Vector(320,400)
local greedexitopen = false
local rockavoidwarmup = 0
local rockavoidcooldowndefault = 35

local playerID = 0

local avoidDangers = true
local shootEnemies = true
local shootFires = true
local shootPoops = true
local avoidCorners = true
local goaroundrockspits = true
local avoidotherplayers = true
local followplayer1 = true
 --0 for off, 1 for player1 only, 2 for all ais
local getPickups = 2
local usePillsCards = 0
local getItems = 2
local getTrinkets = 0
local useItems = 0
local pressButtons = 2
local moveToDoors = 2
local bombThings = 2
local usebeggarsandmachines = 0
local goesshopping = 0
local takesdevildeals = 0
local multisettingmin = 0 --setting needs to be higher than this to be applied

local clone = nil
local cloneSig = Vector(0, 0)
local counter = 0
local effect = nil
local sfx = SFXManager()
local music = MusicManager()
local customSfx = {
	["WINDUP_1"] = Isaac.GetSoundIdByName("KCWindup1"),
	["WINDUP_2"] = Isaac.GetSoundIdByName("KCWindup2"),
	["START_SKIP_1"] = Isaac.GetSoundIdByName("KCIntro1"),
	["START_SKIP_2"] = Isaac.GetSoundIdByName("KCIntro2"),
	["END_SKIP"] = Isaac.GetSoundIdByName("KCOutro")
}
local bd = nil
local roomIndex = 0
local weaponType = {1, 1, 1, 1} -- 1 tear, 2 laser, 3 knife, 4 bomb, 5 rockets, 6 mlung
local canShootCharged = {false, false, false, false} -- lasers
local canShootChargedLong = {false, false, false, false} -- rockets, knives
local lastShotLaser = { }
local laserRange = {0, 0, 0, 0}
local updateLaserRange = {false, false, false, false}
local entColClass = nil
local gridColClass = nil
local closestEnemy = nil
local shotmultiplier = 1
local gridEntOnCol = { }
local correctionFactor = 20
local activeItemIds = {0, 0, 0, 0}
local activeItemCharges = {0, 0, 0, 0}
--local toggledTCS = false

function TimeSplice:tick()
	--[[if Input.IsActionPressed(26, 0) then
		toggledTCS = not toggledTCS
	end--]]
	if counter == 0 then return end
	if counter == 1 then
		effect:Remove()
		TimeSplice:resetVals(Isaac.GetPlayer(playerID))
		music:Resume()
		Isaac.GetPlayer(playerID):AddCacheFlags(CacheFlag.CACHE_DAMAGE)
		Isaac.GetPlayer(playerID):EvaluateItems()
		return
	end
	counter = counter - 1
	if counter == 15 then
		Game():ShowHallucination(0, bd)
		sfx:Stop(SoundEffect.SOUND_DEATH_CARD)

		-- restore grid entities
		local room = Game():GetRoom()
		for i = 0, room:GetGridSize() - 1 do
			local curr = room:GetGridEntity(i)
			if curr then
				local sprite = curr:GetSprite()
				sprite.Color = Color(1, 1, 1, 1, 0, 0, 0)
			end
		end
		return
	end
	if counter < 30 then return end

	-- remove effect if leaving the currnet room
	if roomIndex ~= Game():GetLevel():GetCurrentRoomIndex() and counter > 30 then
		counter = 30
	end
	local player = Isaac.GetPlayer(playerID)
	for i, v in pairs(gridEntOnCol) do
		if v == 0 then
			gridEntOnCol[i] = nil
			local ent = Game():GetRoom():GetGridEntity(i)
			ent:GetSprite().Color = Color(1, 1, 1, 0, 0, 0, 0)
		else gridEntOnCol[i] = v - 1 end
	end

	if counter == 399 then
		player:AnimateCollectible(item, "LiftItem", "PlayerPickup")
	elseif counter == 380 then
		player:AddControlsCooldown(110)
		cloneSig = player.Position
		clone.Position = cloneSig
		bd = Game():GetRoom():GetBackdropType()
		for _,v in pairs(Isaac.GetRoomEntities()) do
			-- freeze all enemies during windup
			if v.Index ~= effect.Index and
					v.Type ~= EntityType.ENTITY_TEAR and v.Type ~= EntityType.ENTITY_PROJECTILE then
				v:AddEntityFlags(EntityFlag.FLAG_FREEZE)
				v:AddEntityFlags(EntityFlag.FLAG_NO_KNOCKBACK)
				if v:IsBoss() then v:AddEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE) end
			elseif v.Type == EntityType.ENTITY_TEAR or v.Type == EntityType.ENTITY_PROJECTILE then
				local data = v:GetData()
				local tear = v:ToTear()
				if not tear then tear = v:ToProjectile() end
				data.StoredVel = tear.Velocity
				data.StoredFall = tear.FallingSpeed
				tear.Velocity = Vector(0, 0)
				tear.FallingSpeed = 0
				if v.Type == EntityType.ENTITY_TEAR then
					data.StoredAccel = tear.FallingAcceleration
					tear.FallingAcceleration = -0.1
				else
					data.StoredAccel = tear.FallingAccel
					tear.FallingAccel = -0.1
				end
			end
			if v:IsEnemy() and v.Type ~= EntityType.ENTITY_PLAYER and v.Type ~= EntityType.ENTITY_EFFECT then
				-- set to target clone
				--TimeSplice:SetTarget(v, clone)
				v.Target = clone

				-- brighten color
				v:SetColor(Color(1, 1, 1, 1.75, 0, 0, 0), 0, 0, false, false)
			end
			if v.Type == EntityType.ENTITY_KNIFE then
				v.Visible = false
			end
		end
	elseif counter == 370 then
		sfx:Play(customSfx["START_SKIP_"..math.random(2)], 1, 0, false, 1, 0)
	elseif counter == 345 then
		player:AnimateCollectible(item, "HideItem", "PlayerPickup")
		-- change room backdrop for cosmo effect
		Game():ShowHallucination(0, 35)
		sfx:Stop(SoundEffect.SOUND_DEATH_CARD)

		-- unfreeze enemies
		for _,v in pairs(Isaac.GetRoomEntities()) do
			v:ClearEntityFlags(EntityFlag.FLAG_FREEZE)
			v:ClearEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE)
			v:ClearEntityFlags(EntityFlag.FLAG_NO_KNOCKBACK)
			if v.Type == EntityType.ENTITY_TEAR or v.Type == EntityType.ENTITY_PROJECTILE then
				local data = v:GetData()
				local tear = v:ToTear()
				if not tear then tear = v:ToProjectile() end
				tear.Velocity = data.StoredVel
				tear.FallingSpeed = data.StoredFall
				if v.Type == EntityType.ENTITY_TEAR then tear.FallingAcceleration = data.StoredAccel
				else tear.FallingAccel = data.StoredAccel end
			end
		end

		-- hide grid entities
		local room = Game():GetRoom()
		for i = 0, room:GetGridSize() - 1 do
			local curr = room:GetGridEntity(i)
			if curr then
				local sprite = curr:GetSprite()
				sprite.Color = Color(1, 1, 1, 0, 0, 0, 0)
			end
		end
	elseif counter == 30 then
		--(re-)loading or setting to frame 0 apparently doesn't work for me, so we create a new entity...
		effect:Remove()
		local w = Isaac.GetScreenWidth()
		local h = Isaac.GetScreenHeight()
		effect = Isaac.Spawn(1000, 1000, 100, Vector(
				math.min(430 - w, w - 530), math.min(260 - h, h - 280)), Vector(0,0), nil)
		local idx = Game():GetRoom():GetRoomShape()
		effect:GetSprite().Scale = Vector(
				((idx >= 6 and idx <= 12) and 2 or 1)*Isaac.GetScreenWidth()/480,
				((idx == 4 or idx == 5 or (idx >= 8 and idx <= 12)) and 2 or 1)*Isaac.GetScreenHeight()/270)
		sfx:Stop(customSfx["START_SKIP_1"])
		sfx:Stop(customSfx["START_SKIP_2"])
		sfx:Play(customSfx["END_SKIP"], 1, 0, false, 1, 0)

		-- restore color
		for _,v in pairs(Isaac.GetRoomEntities()) do
			v:SetColor(Color(1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0), 0, 0, false, false)
			if v.Type == EntityType.ENTITY_KNIFE then
				v.Visible = true
			end
			if v.Type == EntityType.ENTITY_FAMILIAR then
				--v:ToFamiliar().FireCooldown = 0
			end
		end
		player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
		player:EvaluateItems()
		return
	end

	-- play red flash effect
	if counter >= 359 and counter <= 370 then TimeSplice:redFlash() end
	-- dont conrol ai if still during windup
	if counter > 345 then return end

	-- get room
	local currentRoom = Game():GetLevel():GetCurrentRoom()

	-- make player intangible
	player.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYERONLY
	player.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS

	-- move clone to new pos
	local sData = Game():GetLevel():GetCurrentRoomDesc().Data
	local currPos = cloneSig
	local currVel = Vector(player.MoveSpeed * moveX[playerID + 1] * 6, player.MoveSpeed * moveY[playerID + 1] * 6)
	if goaroundrockspits and currentRoom:GetGridEntityFromPos(currPos + currVel) then
		cloneSig = currPos
	else cloneSig = currPos + currVel end

	-- position bound
	cloneSig = Vector(
			math.min(math.max(cloneSig.X, 70), 70 + sData.Width * 38.5),
			math.min(math.max(cloneSig.Y, 150), 150 + sData.Height * 38.5))
	clone.Position = cloneSig

	-- move laser
	local fc = Game():GetFrameCount()
	if fc % 2 == 0 and #lastShotLaser ~= 0 then
		for _,v in pairs(lastShotLaser) do
			v.Position = cloneSig
		end
	end

	-- shoot with clone
	local frate = player.MaxFireDelay
	if player:GetSubPlayer() then frate = math.min(player.MaxFireDelay, player:GetSubPlayer().MaxFireDelay) end
	if fc % math.floor(frate * 3) == 0 then canShootCharged[playerID + 1] = true end
	if fc % math.floor(frate * 6) == 0 then canShootChargedLong[playerID + 1] = true end

	local xShoot = shootX[playerID + 1]
	local yShoot = shootY[playerID + 1]
	if (xShoot ~= 0 or yShoot ~= 0) and (fc % math.floor(frate) == 0) and counter <= 345 then

		local chargeFlag = false
		local longChargeFlag = false
		local spread = player:HasCollectible(CollectibleType.COLLECTIBLE_20_20) and 5 or 10
		for i = 1, shotmultiplier do
			local projectile = nil

			if weaponType[playerID + 1] == 1 then -- regular tears
				local dir = Vector(0, 0)
				local spawnPos = currPos
				if xShoot ~= 0 then
					dir = Vector(xShoot * player.ShotSpeed * 10,
							(shotmultiplier % 2 == 0 and (i - shotmultiplier / 2 == 1 or i == shotmultiplier / 2)) and 0
									or TimeSplice:pow((i - math.floor((shotmultiplier + 1) / 2)) * player.ShotSpeed * 5,
									spread / (100 * shotmultiplier)))
					spawnPos = spawnPos + Vector(0, (i - (shotmultiplier + 1) / 2) * spread)
				else
					dir =  Vector((shotmultiplier % 2 == 0 and (i - shotmultiplier / 2 == 1 or i == shotmultiplier / 2)) and 0
							or  TimeSplice:pow((i - math.floor((shotmultiplier + 1) / 2)) * player.ShotSpeed * 5,
							spread / (100 * shotmultiplier)),
							yShoot * player.ShotSpeed * 10)
					spawnPos = spawnPos + Vector((i - (shotmultiplier + 1) / 2) * spread, 0)
				end
				projectile = Isaac.Spawn(EntityType.ENTITY_TEAR, 0, 0, spawnPos, dir, nil):ToTear()
				projectile.FallingAcceleration = player.TearFallingAcceleration
				projectile.FallingSpeed = player.TearFallingSpeed
				projectile.Height = player.TearHeight
				projectile.CollisionDamage = player.Damage

			elseif weaponType[playerID + 1] == 2 then -- lasers
				local laserType = TimeSplice:getLaserVariant(player)
				if canShootCharged[playerID + 1] or not TimeSplice:hasChargeWeapon(player) then
					projectile = Isaac.Spawn(EntityType.ENTITY_LASER, laserType,
							0, currPos, Vector(0, 0), nil):ToLaser()
					projectile.Angle = TimeSplice:rotate(xShoot, yShoot) + (i - (shotmultiplier + 1) / 2) * 8
					projectile:SetTimeout(laserType == 2 and 5 or 20)
					--projectile:SetColor(Color(1, 1, 1, 2, 100, 0, 0), 0, 0, false, false)
					projectile.CollisionDamage = player.Damage
					projectile:SetMaxDistance(laserRange[playerID + 1])
					lastShotLaser[i] = projectile
					chargeFlag = true
				end

			elseif weaponType[playerID + 1] == 3 then -- knives
				local f = false
				for _,v in pairs(Isaac.GetRoomEntities()) do
					if v:IsEnemy() then
						if canShootChargedLong[playerID + 1] then
							local entPos = v.Position
							if ((xShoot == 1 and entPos.X > currPos.X) or (xShoot == -1 and entPos.X < currPos.X)) and
									math.abs(entPos.Y - currPos.Y) < 20  then
								v:TakeDamage(player.Damage * 5, 0, EntityRef(player), 0)
								f = true
							elseif ((yShoot == 1 and entPos.Y > currPos.Y) or (yShoot == -1 and entPos.Y < currPos.Y)) and
									math.abs(entPos.X - currPos.X) < 20 then
								v:TakeDamage(player.Damage * 5, 0, EntityRef(player), 0)
								f = true
							end
						end
						if v.Position:Distance(currPos) < firerange then
							v:TakeDamage(player.Damage * 10, 0, EntityRef(player), 0)
						end
					end
				end
				if f then longChargeFlag = true end

			elseif weaponType[playerID + 1] == 4 then -- bombs
				if canShootCharged[playerID + 1] then
					projectile = Isaac.Spawn(EntityType.ENTITY_BOMB, 0, 0, currPos +
							Vector((i - (shotmultiplier + 1) / 2) * 5, (i - (shotmultiplier + 1) / 2) * 5),
							Vector(xShoot * player.ShotSpeed * 10, yShoot * player.ShotSpeed * 10), nil):ToBomb()
					projectile:SetExplosionCountdown(30)
					projectile.ExplosionDamage = player.Damage * 10
					chargeFlag = true
				end

			elseif weaponType[playerID + 1] == 5 then -- rockets (+epic fetus)
				if closestEnemy == nil then
					local temp = nil
					for _,v in pairs(Isaac.GetRoomEntities()) do
						local dist = v.Position:Distance(currPos)
						if v.Index ~= clone.Index and v:IsEnemy() and
								(not temp or dist < temp.Position:Distance(currPos)) then
							temp = v
						end
					end
					closestEnemy = temp
				end
				if canShootChargedLong[playerID + 1] then
					projectile = Isaac.Spawn(EntityType.ENTITY_BOMB, 0, 0, closestEnemy.Position,
							Vector(0, 0), nil):ToBomb()
					projectile.ExplosionDamage = player.Damage * 20
					projectile:SetExplosionCountdown(0)
					longChargeFlag = true
					if not closestEnemy:Exists() then closestEnemy = nil end
				end
			end

			if projectile then
				projectile:AddTearFlags(player.TearFlags)
				if correctionFactor > 60 then projectile:AddTearFlags(TearFlags.TEAR_SPECTRAL) end
			end
		end

		if chargeFlag then canShootCharged[playerID + 1] = false end
		if longChargeFlag then canShootChargedLong[playerID + 1] = false end
	end

---------------------------------------------
-----------------AI CODE---------------------
---------------------------------------------
	--check if the current player is set to AI enabled
	multisettingmin = 0

	--workaround for tainted soul/forgotten
	if REPENTANCE then
		if player:GetPlayerType() == 40 and playerID == 1 then
			moveX[playerID+1] = 0
			moveY[playerID+1] = 0
			shootX[playerID+1] = 0
			shootY[playerID+1] = 0
			return
		end
	end
	--prevent AI from trying to do stuff that isn't possible (co-op babies are limited)
	local activecharacter = true
	if not InfinityTrueCoopInterface and not REPENTANCE then
		activecharacter = false
	end
	if REPENTANCE and player.Variant == 1 then
		activecharacter = false
	end
	if playerID == 0 then
		activecharacter = true
	end
	if activecharacter == false then
		if getPickups > 1 then
			getPickups = 1
		end
		if usePillsCards > 1 then
			usePillsCards = 1
		end
		if getItems > 1 then
			getItems = 1
		end
		if getTrinkets > 1 then
			getTrinkets = 1
		end
		if useItems > 1 then
			useItems = 1
		end
		if moveToDoors > 1 then
			moveToDoors = 1
		end
		if bombThings > 1 then
			bombThings = 1
		end
		if usebeggarsandmachines > 1 then
			usebeggarsandmachines = 1
		end
		if goesshopping > 1 then
			goesshopping = 1
		end
		if takesdevildeals > 1 then
			takesdevildeals = 1
		end
	end
	--check for player1 only settings
	if playerID > 0 then
		multisettingmin = 1
	end

	--handle AI behaviour
	ignoreenemiesitems = false

	currentRoom:InvalidatePickupVision()
	--get entity positions and determine actions
	pickupdistance = 9999999999
	enemydistance = 9999999999
	highestshopprice = -1
	moveX[playerID+1] = 0
	moveY[playerID+1] = 0
	shootX[playerID+1] = 0
	shootY[playerID+1] = 0
	local topleft = currentRoom:GetTopLeftPos()
	local bottomright = currentRoom:GetBottomRightPos()
	local topright = Vector(bottomright.X,topleft.Y)
	local bottomleft = Vector(topleft.X,bottomright.Y)
	local tilecount = currentRoom:GetGridSize()
	local keycount = player:GetNumKeys()
	local bombcount = player:GetNumBombs()
	if keycount == 0 and player:HasGoldenKey() then
		keycount = 1
	end
	if player:HasCollectible(380) then
		keycount = player:GetNumCoins()
	end
	if bombcount == 0 and player:HasGoldenBomb() then
		bombcount = 1
	end
	--if in mega satan room move up to start the battle
	if Game():GetLevel():GetCurrentRoomDesc().GridIndex == -1 and currentRoom:GetType() == 5 and currPos.Y > currentRoom:GetCenterPos().Y then
		moveY[playerID+1] = -1
	end
	--go to another room when clear
	if moveToDoors > multisettingmin then
		if currentRoom:IsClear() and ignoreenemiesitems == false then
			--go through doors
			local angelroom = false
			local roomcheckcount = 9999999999
			for i = 0, 7 do
				local door = currentRoom:GetDoor(i)
				if not door then
					--no door at this position
				elseif door:IsRoomType(RoomType.ROOM_CURSE) and currentRoom:GetType() ~= RoomType.ROOM_CURSE and (Game():GetLevel():GetRoomByIdx(door.TargetRoomIndex).VisitedCount > 0 or player:GetHearts() + player:GetSoulHearts() < 6) then
					--dont waste health on curse doors
				elseif door:IsOpen() == false and (door:IsRoomType(RoomType.ROOM_SECRET) or door:IsRoomType(RoomType.ROOM_SUPERSECRET)) then
					--dont go for hidden secret room doors
				else
					if door:IsOpen() or ((door:IsRoomType(RoomType.ROOM_TREASURE) or door:IsRoomType(RoomType.ROOM_LIBRARY) or (goesshopping > multisettingmin and door:IsRoomType(RoomType.ROOM_SHOP))) and keycount > 0) or (door:IsRoomType(RoomType.ROOM_ARCADE) and player:GetNumCoins() > 0) then
						--get door to room visited the least times
						if Game():GetLevel():GetRoomByIdx(door.TargetRoomIndex).VisitedCount <= roomcheckcount or (Game():IsGreedMode() and Game():GetLevel():GetCurrentRoomDesc().GridIndex == 84 and door:IsOpen() and i == 3) or (Game():GetLevel():GetRoomByIdx(door.TargetRoomIndex).VisitedCount == 0 and (door:IsRoomType(RoomType.ROOM_DEVIL) or door:IsRoomType(RoomType.ROOM_ANGEL) or ((door:IsRoomType(RoomType.ROOM_TREASURE) or (goesshopping > multisettingmin and door:IsRoomType(RoomType.ROOM_SHOP))) and (door:IsOpen() or keycount > 0)) or (door:IsRoomType(RoomType.ROOM_ARCADE) and (door:IsOpen() or player:GetNumCoins() > 0)))) then
							roomcheckcount = Game():GetLevel():GetRoomByIdx(door.TargetRoomIndex).VisitedCount
							--go for angel rooms
							if roomcheckcount == 0 and (door:IsRoomType(RoomType.ROOM_ANGEL) or door:IsRoomType(RoomType.ROOM_DEVIL)) then
								roomcheckcount = -5
								angelroom = true
							end
							--go for treasure rooms
							if roomcheckcount == 0 and door:IsRoomType(RoomType.ROOM_TREASURE) and (door:IsOpen() or keycount > 0) then
								roomcheckcount = -5
							end
							--go for arcade rooms
							if roomcheckcount == 0 and door:IsRoomType(RoomType.ROOM_ARCADE) and (door:IsOpen() or player:GetNumCoins() > 0) then
								roomcheckcount = -5
							end
							--go for shops and libraries
							if roomcheckcount == 0 and ((door:IsRoomType(RoomType.ROOM_SHOP) and goesshopping > multisettingmin) or door:IsRoomType(RoomType.ROOM_LIBRARY)) and (door:IsOpen() or keycount > 0) then
								roomcheckcount = -5
							end
							--go for secret rooms
							if roomcheckcount == 0 and (door:IsRoomType(RoomType.ROOM_SECRET) or door:IsRoomType(RoomType.ROOM_SUPERSECRET)) and door:IsOpen() then
								roomcheckcount = -5
							end
							--go for mega satans room
							if roomcheckcount == 0 and Game():GetLevel():GetStage() == 11 and Game():GetLevel():GetCurrentRoomDesc().GridIndex == 84 and door:IsRoomType(RoomType.ROOM_BOSS) then
								roomcheckcount = -5
							end
							--go for greed mode floor exit
							if Game():IsGreedMode() and Game():GetLevel():GetCurrentRoomDesc().GridIndex == 84 and door:IsOpen() and i == 3 and greedmodecooldown < 1 then
								roomcheckcount = -5
								greedexitopen = true
							end
							--move towards chosen door
							local doorpos = door.Position
							local leeway = door.Position:Distance(currPos)*0.5
							if leeway > 40 then
								leeway = 40
							end
							moveX[playerID+1] = 0
							moveY[playerID+1] = 0
							TimeSplice:simplemovetowards(currPos, doorpos, leeway)
						end
					end
				end
			end
			--check for crawlspace exit
			if currentRoom:GetType() == 16 then
				visitedcrawlspace = true
				moveX[playerID+1] = -1
				moveY[playerID+1] = -1
			end
			--check for hush door
			if (Game():GetLevel():GetCurrentRoomDesc().VisitedCount > 3 or keycount < 1) and Game():GetLevel():GetStage() == 9 and currentRoom:GetType() ~= RoomType.ROOM_TREASURE then
				TimeSplice:simplemovetowards(currPos, currentRoom:GetCenterPos().X, 0)
				moveY[playerID+1] = -1
			end
			--go for trapdoor
			if (currentRoom:GetType() == RoomType.ROOM_BOSS and angelroom == false) or (Game():IsGreedMode() and Game():GetLevel():GetCurrentRoomDesc().GridIndex == 110) then
				local trapdooristhere = false
				for g = 1, tilecount do
					if currentRoom:GetGridEntity(g) ~= nil then
						local gridEntity = currentRoom:GetGridEntity(g)
						if gridEntity:GetType() == 17 then
							trapdooristhere = true
						end
					end
				end
				if trapdooristhere then
					local trapdoorpos = currentRoom:GetCenterPos()
					local leeway = trapdoorpos:Distance(currPos)*0.5
					if leeway > 40 then
						leeway = 40
					end
					moveX[playerID+1] = 0
					TimeSplice:simplemovetowards(currPos, trapdoorpos, leeway)
					moveY[playerID+1] = 1
					if trapdoorpos.Y < currPos.Y then
						bossroom = true
					end
					if trapdoorpos.Y > currPos.Y + 60 then
						bossroom = false
					end
					if bossroom then
						moveY[playerID+1] = -1
					end
				end
			else
				bossroom = false
			end
			--take trapdoor in black market
			if currentRoom:GetType() == RoomType.ROOM_BLACK_MARKET then
				for g = 1, tilecount do
					if currentRoom:GetGridEntity(g) ~= nil then
						local gridEntity = currentRoom:GetGridEntity(g)
						if gridEntity:GetType() == 17 then
							moveX[playerID+1] = 0
							moveY[playerID+1] = 0
							TimeSplice:simplemovetowards(currPos, gridEntity.Position, 0)
						end
					end
				end
			end
		end
	end
	--check room for poops, rocks and buttons
	if bombcooldown > 0 then
		bombcooldown = bombcooldown - 1
	end
	if (shootPoops and currentRoom:IsClear()) or (bombThings > multisettingmin and bombcount > 0 and currentRoom:IsClear()) or (pressButtons > multisettingmin and currentRoom:HasTriggerPressurePlates() and currentRoom:IsClear() == false) or (moveToDoors > multisettingmin and currentRoom:IsClear()) then
		for i = 1, tilecount do
			if currentRoom:GetGridEntity(i) ~= nil then
				local gridEntity = currentRoom:GetGridEntity(i)
				local gridReact = -1
				if currentRoom:IsClear() and shootPoops and gridEntity:GetType() == 14 and gridEntity.State ~= 4 and gridEntity.State ~= 1000 and gridEntity:GetVariant() ~= 1 then
					gridReact = 0
				elseif currentRoom:IsClear() and bombThings > multisettingmin and bombcount > 0 and (gridEntity:GetType() == 4 or gridEntity:GetType() == 22) and gridEntity:ToRock() ~= nil and gridEntity.State ~= 2 then
					gridReact = 1
				elseif currentRoom:IsClear() == false and pressButtons > multisettingmin and gridEntity:GetType() == 20 and gridEntity.State ~= 3 then
					gridReact = 2
				elseif currentRoom:IsClear() and moveToDoors > multisettingmin and gridEntity:GetType() == 18 and visitedcrawlspace == false then
					gridReact = 3
				end
				if gridReact > -1 then
					moveX[playerID+1] = 0
					moveY[playerID+1] = 0
					local xdiff = math.abs(gridEntity.Position.X - currPos.X)
					local ydiff = math.abs((gridEntity.Position.Y+5) - currPos.Y)
					if xdiff > 45 or ydiff > 45 or gridReact == 3 then
						local temppooppos = gridEntity.Position
						temppooppos.Y = temppooppos.Y+5
						TimeSplice:simplemovetowards(currPos, temppooppos, 5)
					elseif xdiff < 30 and ydiff < 30 then --dont stand right on top of it
						if xdiff > ydiff then
							if gridEntity.Position.X < currPos.X then
								moveX[playerID+1] = 1
							else
								moveX[playerID+1] = -1
							end
						else
							if gridEntity.Position.Y+5 < currPos.Y then
								moveY[playerID+1] = 1
							else
								moveY[playerID+1] = -1
							end
						end
					end
					if gridReact == 0 then --shoot at poops
						if ydiff < shoottolerance and ydiff < xdiff then
							if gridEntity.Position.X > currPos.X then
								shootX[playerID+1] = 1
							else
								shootX[playerID+1] = -1
							end
						end
						if xdiff < shoottolerance and xdiff < ydiff then
							if gridEntity.Position.Y > currPos.Y then
								shootY[playerID+1] = 1
							else
								shootY[playerID+1] = -1
							end
						end
						--aim ludovico
						if player:HasWeaponType(WeaponType.WEAPON_LUDOVICO_TECHNIQUE) and player:GetActiveWeaponEntity() ~= nil then
							local ludotear = player:GetActiveWeaponEntity()
							if gridEntity.Position.X > ludotear.Position.X then
								shootX[playerID+1] = 1
							else
								shootX[playerID+1] = -1
							end
							if gridEntity.Position.Y > ludotear.Position.Y then
								shootY[playerID+1] = 1
							else
								shootY[playerID+1] = -1
							end
						end
					--if at a tinted rock bomb it
					elseif gridReact == 1 and bombcooldown < 1 and bombcount > 3 and gridEntity:ToRock() ~= nil and gridEntity.State ~= 2 and gridEntity.Position:Distance(currPos) < 60 then
						TimeSplice:bomb(player)
					end
				end
			end
		end
	end
	--go for greed button
	if Game():IsGreedMode() and Game():GetLevel():GetCurrentRoomDesc().GridIndex == 84 then
		if currentRoom:GetAliveEnemiesCount() == 0 and currentRoom:GetAliveBossesCount() == 0 then
			greedmodecooldown = greedmodecooldown - 1
			if pressButtons > multisettingmin and greedmodecooldown < 1 and greedexitopen == false then
				TimeSplice:simplemovetowards(currPos, greedmodebuttonpos, 10)
			end
		end
	end
	--check room for relevant entities (enemies, projectiles and pickups)
	local entities = Isaac.GetRoomEntities()
	for ent = 1, #entities do
		local entity = entities[ent]
		------------------------------------------------
		if (entity.Type == EntityType.ENTITY_TEAR or entity.Type == EntityType.ENTITY_BOMB) then
			if currentRoom:GetGridCollisionAtPos(entity.Position) == GridCollisionClass.COLLISION_SOLID then
				local gridEnt = currentRoom:GetGridEntityFromPos(entity.Position)
				if gridEnt then
					local idx = gridEnt:GetGridIndex()
					local val = gridEntOnCol[idx]
					if not val then
						val = 10
						gridEntOnCol[idx] = 10
						local correction = (entity.Position - clone.Position)
						if correction:Length() < firerange then
							cloneSig = cloneSig + correction:Resized(correctionFactor)
							correctionFactor = correctionFactor + 10
						end
					end
				end
			end
		end
		-- set target to newly spawned enemies
		if entity:IsEnemy() and entity.Type ~= EntityType.ENTITY_FIREPLACE and entity.Target ~= clone then
			--TimeSplice:SetTarget(entity, clone)
			entity.Target = clone
		end
		if entity.Type == EntityType.ENTITY_FAMILIAR then
			--entity:ToFamiliar().FireCooldown = 1000
		end
		------------------------------------------------
		if (entity:IsDead() == false or entity.Type == 7) and (entity.Type == 231 and entity.Variant == 700 and entity.SubType == 700) == false then
			local xdiff = math.abs(entity.Position.X - currPos.X)
			local ydiff = math.abs(entity.Position.Y - currPos.Y)
			--shoot poops
			if shootPoops and entity.Type == 245 and entity.HitPoints > 1 then
				TimeSplice:simplemovetowards(currPos, entity.Position, 0)
				if ydiff < shoottolerance and ydiff < xdiff then
					if entity.Position.X > currPos.X then
						shootX[playerID+1] = 1
					else
						shootX[playerID+1] = -1
					end
				end
				if xdiff < shoottolerance and xdiff < ydiff then
					if entity.Position.Y > currPos.Y then
						shootY[playerID+1] = 1
					else
						shootY[playerID+1] = -1
					end
				end
				--aim ludovico
				if player:HasWeaponType(WeaponType.WEAPON_LUDOVICO_TECHNIQUE) and player:GetActiveWeaponEntity() ~= nil then
					local ludotear = player:GetActiveWeaponEntity()
					if entity.Position.X > ludotear.Position.X then
						shootX[playerID+1] = 1
					else
						shootX[playerID+1] = -1
					end
					if entity.Position.Y > ludotear.Position.Y then
						shootY[playerID+1] = 1
					else
						shootY[playerID+1] = -1
					end
				end
			end
			--pick up items
			if getPickups > multisettingmin and entity.Type == 5 and ignoreenemiesitems == false and (entity.Variant == 10 and (entity.SubType < 3 or entity.SubType == 5 or entity.SubType == 9) and player:GetHearts() == player:GetEffectiveMaxHearts()) == false and entity:ToPickup():IsShopItem() == false then
				if (entity.Variant == 100 and entity.SubType == 0) == false and (entity.Variant == 50 and entity.SubType == 0) == false and (entity.Variant ~= 51 or (bombThings > multisettingmin and entity.Variant == 51 and bombcount > 0 and entity.SubType == 1)) and entity.Variant ~= 52 and entity.Variant ~= 53 and entity.Variant ~= 54 and entity.Variant ~= 58 and (entity.Variant ~= 60 or (entity.Variant == 60 and player:GetNumKeys() > 0 and entity.SubType == 1)) and (entity.Variant == 360 and entity.SubType == 0) == false then
					if (usePillsCards <= multisettingmin or player:GetCard(0) > 0) and entity.Variant == 300 then
						--dont get cards or runes
						if entity.Position:Distance(currPos) < 70 then
							TimeSplice:goaround(currPos, entity.Position, 35)
						end
					elseif entity.Variant == 300 and entity.SubType == 46 then
						--dont pick up suicide king
						if entity.Position:Distance(currPos) < 70 then
							TimeSplice:goaround(currPos, entity.Position, 35)
						end
					elseif (usePillsCards <= multisettingmin or player:GetPill(0) > 0) and entity.Variant == 70 then
						--dont get pills
						if entity.Position:Distance(currPos) < 70 then
							TimeSplice:goaround(currPos, entity.Position, 35)
						end
					elseif getItems <= multisettingmin and entity.Variant == 100 then
						--dont get passive items
						if entity.Position:Distance(currPos) < 70 then
							TimeSplice:goaround(currPos, entity.Position, 35)
						end
					elseif entity.Variant == 90 and (entity.SubType == BatterySubType.BATTERY_GOLDEN or
							player:NeedsCharge() == false or player:GetActiveCharge() == activeItemCharges[playerID + 1]) then
						--dont get batteries
					elseif getItems > multisettingmin and (useItems <= multisettingmin or player:GetActiveItem() > 0) and entity.Variant == 100 and Isaac.GetItemConfig():GetCollectible(entity.SubType).Type == 3 then
						--dont get active items
						if entity.Position:Distance(currPos) < 70 then
							TimeSplice:goaround(currPos, entity.Position, 35)
						end
					elseif entity.Variant == 20 and entity.SubType == 6 and (bombcount < 1 or bombThings <= multisettingmin) then
						--dont get stuck on sticky nickels
					elseif entity.Variant == 350 and (player:GetTrinket(0) > 0 or getTrinkets <= multisettingmin) then
						--dont go for trinkets if already have one
						if entity.Position:Distance(currPos) < 70 then
							TimeSplice:goaround(currPos, entity.Position, 35)
						end
					elseif entity.Variant == 10 and player:CanPickSoulHearts() == false and (entity.SubType == 3 or entity.SubType == 6 or entity.SubType == 8) then
						--dont grab health if full
					elseif entity.Variant == 10 and player:CanPickBoneHearts() == false and entity.SubType == 11 then
						--dont grab health if full
					elseif entity.Variant == 380 and (entity:ToPickup().Touched or (player:CanPickRedHearts() == false and player:GetEffectiveMaxHearts() > 0) or (player:CanPickSoulHearts() == false and player:GetEffectiveMaxHearts() == 0)) then
						--dont go for beds if they cant be used
					elseif entity.Variant == 99 and (player:GetNumCoins() < 1 or entity.SubType == 0) then
						--dont go for paychests if not enough coins
					------------------------------------------------
					elseif entity.Variant >= 51 and entity.Variant <= 60 and entity.Variant ~= 56 then
						-- dont go for any chest but regular and wooden chest
					elseif entity.Variant == PickupVariant.PICKUP_THROWABLEBOMB then
						-- dont go for throwables
					elseif entity.Variant == PickupVariant.PICKUP_GRAB_BAG then
						-- dont go for sacks (unintended)
					------------------------------------------------
					else
						local distance = entity.Position:Distance(currPos)
						--get closest item
						if distance < pickupdistance then
							if currentRoom:IsClear() then
								moveX[playerID+1] = 0
								moveY[playerID+1] = 0
							end
							pickupdistance = distance
							if distance > 15 then
								TimeSplice:simplemovetowards(currPos, entity.Position, 10)
							else
								TimeSplice:takePickup(entity:ToPickup(), player)
							end
							--let ai move away from paychest to be able to pay more
							if entity.Variant == 99 and entity:GetSprite():IsPlaying("Pay") and entity.Position:Distance(currPos) < 70 then
								TimeSplice:simplemoveaway(currPos, entity.Position, 10)
							end
							--bomb stone chests and sticky nickels
							if bombThings > multisettingmin and ((entity.Variant == 51 and entity.SubType == 1) or (entity.Variant == 20 and entity.SubType == 6)) and bombcount > 3 and bombcooldown < 1 and distance < 40 then
								TimeSplice:bomb(player)
							end
						end
					end
				end
			end
			--buy stuff at shops
			if goesshopping > multisettingmin and entity.Type == 5 and entity:ToPickup():IsShopItem() and entity:ToPickup().Price > -1 then
				local itemprice = entity:ToPickup().Price
				--get most expensive item player can afford
				if entity.Variant == 100 and getItems <= multisettingmin then
					--dont buy items if take items is false
					if entity.Position:Distance(currPos) < 70 then
						TimeSplice:goaround(currPos, entity.Position, 35)
						break
					end
				elseif (getItems <= multisettingmin or useItems <= multisettingmin or player:GetActiveItem() > 0) and entity.Variant == 100 and Isaac.GetItemConfig():GetCollectible(entity.SubType).Type == 3 then
					--dont buy active items
					if entity.Position:Distance(currPos) < 70 then
						TimeSplice:goaround(currPos, entity.Position, 35)
						break
					end
				elseif entity.Variant == 10 and player:CanPickSoulHearts() == false and (entity.SubType == 3 or entity.SubType == 6 or entity.SubType == 8) then
					--dont buy soul hearts if no room
				elseif entity.Variant == 10 and player:CanPickRedHearts() == false and (entity.SubType < 3 or entity.SubType == 5 or entity.SubType == 9) then
					--dont buy red hearts if no room
				elseif entity.Variant == 90 and player:GetActiveCharge() == activeItemCharges[playerID + 1] then
					--dont buy batteries if no active or active fully charged
				elseif itemprice > highestshopprice and itemprice <= player:GetNumCoins() then
					if currentRoom:IsClear() then
						moveX[playerID+1] = 0
						moveY[playerID+1] = 0
					end
					highestshopprice = itemprice
					TimeSplice:simplemovetowards(currPos, entity.Position, 0)
				end
			end
			--take devil deals
			if entity.Type == 5 and entity:ToPickup().Price < 0 then
				--check for active items
				local takeactiveitem = true
				if entity.Variant == 100 and getItems <= multisettingmin then
					takeactiveitem = false --dont take items if disabled
				elseif entity.Variant == 100 and Isaac.GetItemConfig():GetCollectible(entity.SubType).Type == 3 and (useItems <= multisettingmin or player:GetActiveItem() > 0) then
					takeactiveitem = false --dont take actives if cant use them or already has one
				end
				local itemprice = 0-entity:ToPickup().Price
				if takesdevildeals > multisettingmin and itemprice == 3 and player:GetSoulHearts() > 20 and takeactiveitem then
					TimeSplice:simplemovetowards(currPos, entity.Position, 0)
					if pickupdistance == 9999999999 then
						pickupdistance = 999999
					end
				elseif takesdevildeals > multisettingmin and player:GetMaxHearts() > itemprice*4 + 2 and takeactiveitem then
					TimeSplice:simplemovetowards(currPos, entity.Position, 0)
					if pickupdistance == 9999999999 then
						pickupdistance = 999999
					end
				elseif entity.Position:Distance(currPos) < 70 then
					--avoid the item to not lose health accidentally
					TimeSplice:goaround(currPos, entity.Position, 35)
				end
			end
			--use beggars/machines
			if entity.Type == 6 and entity:GetSprite():IsPlaying("Broken") == false and entity:GetSprite():IsFinished("Broken") == false and entity:GetSprite():IsPlaying("CoinJam") == false and entity:GetSprite():IsFinished("CoinJam") == false and entity:GetSprite():IsPlaying("CoinJam2") == false and entity:GetSprite():IsFinished("CoinJam2") == false and entity:GetSprite():IsPlaying("CoinJam3") == false and entity:GetSprite():IsFinished("CoinJam3") == false and entity:GetSprite():IsPlaying("CoinJam4") == false and entity:GetSprite():IsFinished("CoinJam4") == false then
				if entity.Variant == 93 and (entity:GetSprite():IsPlaying("PayPrize") or entity:GetSprite():IsPlaying("PayNothing")) and entity:GetSprite():GetFrame() < 9 then
					--check for dead beggar
				else
					--machines/beggard to avoid
					if entity.Position:Distance(currPos) < 80 then
						if entity.Variant == 2 or entity.Variant == 5 or entity.Variant == 10 or entity.Variant == 94 then
							TimeSplice:goaround(currPos, entity.Position, 35)
						end
					end
					--machines/beggars to move towards
					if ((entity.Variant == 1 or entity.Variant == 4 or entity.Variant == 6 or entity.Variant == 8 or entity.Variant == 11) and usebeggarsandmachines > multisettingmin and player:GetNumCoins() > 0) or ((entity.Variant == 2 or entity.Variant == 3 or entity.Variant == 5 or entity.Variant == 12) and bombcount > 0 and bombThings > multisettingmin) or (usebeggarsandmachines > multisettingmin and entity.Variant == 7 and player:GetNumKeys() > 0) or (usebeggarsandmachines > multisettingmin and entity.Variant == 9 and player:GetNumBombs() > 0) or (usebeggarsandmachines > multisettingmin and entity.Variant == 93 and player:GetSoulHearts() > 0) then
						TimeSplice:simplemovetowards(currPos, entity.Position, 0)
						if pickupdistance == 9999999999 then
							pickupdistance = 999999
						end
					end
					--give shell game beggar space to spawn flies
					if entity.Position:Distance(currPos) < 70 then
						if entity:GetSprite():IsPlaying("Shell1Prize") or entity:GetSprite():IsPlaying("Shell2Prize") or entity:GetSprite():IsPlaying("Shell3Prize") then
							TimeSplice:simplemoveaway(currPos, entity.Position, 0)
						end
					end
				end
			end
			--shoot at fires and tnt barrels
			if shootFires and entity.Type == 33 and entity.HitPoints > 1 and entity.Variant < 2 then
				if currentRoom:IsClear() then
					moveX[playerID+1] = 0
					moveY[playerID+1] = 0
				end
				local distance = entity.Position:Distance(currPos)
				if currentRoom:IsClear() and distance > firerange then
					TimeSplice:simplemovetowards(currPos, entity.Position, 10)
				end
				if distance < firerange+10 then
					if ydiff < shoottolerance then
						if entity.Position.X > currPos.X then
							shootX[playerID+1] = 1
						else
							shootX[playerID+1] = -1
						end
					end
					if xdiff < shoottolerance then
						if entity.Position.Y > currPos.Y then
							shootY[playerID+1] = 1
						else
							shootY[playerID+1] = -1
						end
					end
				end
				--aim ludovico
				if enemydistance == 9999999999 and player:HasWeaponType(WeaponType.WEAPON_LUDOVICO_TECHNIQUE) and player:GetActiveWeaponEntity() ~= nil then
					local ludotear = player:GetActiveWeaponEntity()
					if entity.Position.X > ludotear.Position.X then
						shootX[playerID+1] = 1
					else
						shootX[playerID+1] = -1
					end
					if entity.Position.Y > ludotear.Position.Y then
						shootY[playerID+1] = 1
					else
						shootY[playerID+1] = -1
					end
				end
			end
			--bomb blue/purple fires
			if bombThings > multisettingmin and entity.Type == 33 and entity.HitPoints > 1 and entity.Variant > 1 and entity.Variant ~= 4 and bombcooldown < 1 and bombcount > 3 then
				if currentRoom:IsClear() then
					moveX[playerID+1] = 0
					moveY[playerID+1] = 0
				end
				local distance = entity.Position:Distance(currPos)
				if currentRoom:IsClear() and distance > firerange-20 then
					TimeSplice:simplemovetowards(currPos, entity.Position, 10)
				end
				if distance < firerange then
					TimeSplice:bomb(player)
				end
			end
			--dont run into fires
			if avoidDangers and entity.Type == 33 and entity.HitPoints > 1 then
				local distance = entity.Position:Distance(currPos)
				if distance < firerange then
					ignoreenemiesitems = true
					if math.abs(entity.Position.X - currPos.X) > math.abs(entity.Position.Y - currPos.Y) then
						moveY[playerID+1] = 0
						if entity.Position.X < currPos.X then
							moveX[playerID+1] = 1
						else
							moveX[playerID+1] = -1
						end
					else
						moveX[playerID+1] = 0
						if entity.Position.Y < currPos.Y then
							moveY[playerID+1] = 1
						else
							moveY[playerID+1] = -1
						end
					end
				end
			end
			--avoid dangers and shoot at enemies
			if entity.Type == 4 or (entity.Type > 8 and entity.Type < 1000 and entity.Type ~= 17 and entity.Type ~= 42 and entity.Type ~= 33 and entity.Type ~= 292 and entity.Type ~= 667 and entity.Type ~= 804) then
				if ignoreenemiesitems == false and (entity.Type == 4 or entity.HitPoints > 0.5) and entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) == false and (entity.Type == 231 and entity.Variant == 2 and entity.SubType == 1) == false then
					local distance = entity.Position:Distance(currPos)
					--get closest enemy
					if distance < enemydistance then
						if entity:IsVulnerableEnemy() or entity.Type == 27 or entity.Type == 204 then
							enemydistance = distance
						end
						if shootEnemies then
							chaserange = -player.TearHeight * 10.5
							if player:GetPlayerType() == PlayerType.PLAYER_THEFORGOTTEN or player:GetName() == "Moth" then
								chaserange = 60
							end
							if REPENTANCE and player:HasCollectible(579) then --spirit sword
								chaserange = 60
							end
							--try to stay in shooting range
							if distance > chaserange then
								TimeSplice:simplemovetowards(currPos, entity.Position, 0)
							end
							if distance > chaserange*0.66 and entity:IsVulnerableEnemy() == false and (entity.Type == 27 or entity.Type == 204) then
								TimeSplice:simplemovetowards(currPos, entity.Position, 0)
							end
							--move inline to shoot
							if xdiff > ydiff then
								if ydiff > 9 then
									if entity.Position.Y > currPos.Y then
										moveY[playerID+1] = 1
									else
										moveY[playerID+1] = -1
									end
								end
							else
								if xdiff > 9 then
									if entity.Position.X > currPos.X then
										moveX[playerID+1] = 1
									else
										moveX[playerID+1] = -1
									end
								end
							end
							--dont get stuck diagonally near enemy
							local directiontoenemy = Vector(xdiff,ydiff):Normalized()
							if math.abs(directiontoenemy.X - directiontoenemy.Y) < 0.45 and distance < avoidrange+20 then
								if xdiff > ydiff then
									moveX[playerID+1] = 0
								else
									moveY[playerID+1] = 0
								end
							end
							--shoot
							if entity:IsVulnerableEnemy() then
								if ydiff < shoottolerance and ydiff < xdiff then
									if entity.Position.X > currPos.X then
										shootX[playerID+1] = 1
									else
										shootX[playerID+1] = -1
									end
								end
								if xdiff < shoottolerance and xdiff < ydiff then
									if entity.Position.Y > currPos.Y then
										shootY[playerID+1] = 1
									else
										shootY[playerID+1] = -1
									end
								end
							end
							--aim ludovico
							if player:HasWeaponType(WeaponType.WEAPON_LUDOVICO_TECHNIQUE) and player:GetActiveWeaponEntity() ~= nil then
								local ludotear = player:GetActiveWeaponEntity()
								if entity.Position.X > ludotear.Position.X then
									shootX[playerID+1] = 1
								else
									shootX[playerID+1] = -1
								end
								if entity.Position.Y > ludotear.Position.Y then
									shootY[playerID+1] = 1
								else
									shootY[playerID+1] = -1
								end
							end
						end
						--try not to get hit
						if avoidDangers and entity.Type ~= 245 and (currentRoom:IsClear() == false or (entity.Type ~= 42 and (entity.Type == 44 and entity.Variant == 0) == false and entity.Type ~= 202 and entity.Type ~= 203)) then
							local temprange = avoidrange
							if player:GetPlayerType() == PlayerType.PLAYER_THEFORGOTTEN or player:GetName() == "Moth" then
								avoidrange = 30
							end
							if player:GetPlayerType() == PlayerType.PLAYER_AZAZEL and player:HasCollectible(118) == false then
								avoidrange = -player.TearHeight*1.5
							end
							--try to dodge charging enemies
							if distance < avoidrange*2 and (math.abs(entity.Velocity.X)>6 or math.abs(entity.Velocity.Y)>6) then
								if math.abs(entity.Velocity.X) > math.abs(entity.Velocity.Y) then
									--vertical dodge
									if (entity.Velocity.X > 0 and entity.Position.X < currPos.X) or (entity.Velocity.X < 0 and entity.Position.X > currPos.X) then
										if entity.Position.Y < currPos.Y then
											moveY[playerID+1] = 1
										else
											moveY[playerID+1] = -1
										end
									end
								else
									--horizontal dodge
									if (entity.Velocity.Y > 0 and entity.Position.Y < currPos.Y) or (entity.Velocity.Y < 0 and entity.Position.Y > currPos.Y) then
										if entity.Position.X < currPos.X then
											moveX[playerID+1] = 1
										else
											moveX[playerID+1] = -1
										end
									end
								end
							end
							--dodge close enemies
							if distance < avoidrange then
								local direction = entity.Velocity:Normalized()
								--check for diagonally moving enemies
								local diagonaldodge = false
								if math.abs(math.abs(direction.X) - math.abs(direction.Y)) < 0.3 then
									if direction.X > 0 then
										if direction.Y > 0 then
											if currPos.X > entity.Position.X and currPos.Y > entity.Position.Y then
												diagonaldodge = true
												if xdiff > ydiff then
													moveY[playerID+1] = -1
												else
													moveX[playerID+1] = -1
												end
											end
										else
											if currPos.X > entity.Position.X and currPos.Y < entity.Position.Y then
												diagonaldodge = true
												if xdiff > ydiff then
													moveY[playerID+1] = 1
												else
													moveX[playerID+1] = -1
												end
											end
										end
									else
										if direction.Y > 0 then
											if currPos.X < entity.Position.X and currPos.Y > entity.Position.Y then
												diagonaldodge = true
												if xdiff > ydiff then
													moveY[playerID+1] = -1
												else
													moveX[playerID+1] = 1
												end
											end
										else
											if currPos.X < entity.Position.X and currPos.Y < entity.Position.Y then
												diagonaldodge = true
												if xdiff > ydiff then
													moveY[playerID+1] = 1
												else
													moveX[playerID+1] = 1
												end
											end
										end
									end
								end
								if diagonaldodge == false then
									if entity.Type ~= 9 or xdiff < ydiff then
										if entity.Position.X < currPos.X then
											moveX[playerID+1] = 1
										else
											moveX[playerID+1] = -1
										end
									end
									if entity.Type ~= 9 or xdiff > ydiff then
										if entity.Position.Y < currPos.Y then
											moveY[playerID+1] = 1
										else
											moveY[playerID+1] = -1
										end
									end
								end
							end
							if player:GetPlayerType() == PlayerType.PLAYER_THEFORGOTTEN or player:GetName() == "Moth" or player:GetPlayerType() == PlayerType.PLAYER_AZAZEL then
								avoidrange = temprange
							end
						end
					end
				end
			end
			--avoid lasers
			if avoidDangers and entity.Type == 7 then
				if entity.Parent == nil or entity.Parent.Index ~= player.Index then
					local startpoint = entity.Position
					local endpoint = entity:ToLaser():GetEndPoint()
					local midpoint = Vector((startpoint.X+endpoint.X)*0.5, (startpoint.Y+endpoint.Y)*0.5)
					local earlypoint = Vector((startpoint.X+midpoint.X)*0.5, (startpoint.Y+midpoint.Y)*0.5)
					local latepoint = Vector((midpoint.X+endpoint.X)*0.5, (midpoint.Y+endpoint.Y)*0.5)
					local closestpoint = Vector(0,0)
					if currPos:Distance(midpoint) < currPos:Distance(earlypoint) and currPos:Distance(midpoint) < currPos:Distance(latepoint) then
						closestpoint = midpoint
					elseif currPos:Distance(earlypoint) < currPos:Distance(latepoint) then
						closestpoint = earlypoint
						if currPos:Distance(startpoint) < currPos:Distance(earlypoint) then
							closestpoint = startpoint
						end
					else
						closestpoint = latepoint
						if currPos:Distance(endpoint) < currPos:Distance(latepoint) then
							closestpoint = endpoint
						end
					end
					if currPos:Distance(closestpoint) < 75 then
						TimeSplice:simplemoveaway(currPos, entity.Position, 0)
					end
				end
			end
		end
	end
	--go around rocks if doesnt have flying
	if goaroundrockspits and enemydistance > 1000 then
		rockavoidwarmup = rockavoidwarmup + 1
		if rockavoidwarmup > 100 then goaroundrockspits = false
		elseif rockavoidwarmup > 20 and (moveX[playerID+1] ~= 0 or moveY[playerID+1] ~= 0) then
			if math.abs(clone.Position.X - lastplayerpos[playerID+1].X) < 0.05 and math.abs(clone.Position.Y -  lastplayerpos[playerID+1].Y) < 0.05 then
				--once its determined that the current path is blocked select a new direction to move
				--check if it already tried one of the directions and got stuck in the same spot, try different direction
				if (moveX[playerID+1] == 1 and moveY[playerID+1] == 1) then
					if aroundrockdirection[playerID+1] == 1 then
						aroundrockdirection[playerID+1] = 4
					else
						aroundrockdirection[playerID+1] = 1
					end
				elseif moveX[playerID+1] == 1 and moveY[playerID+1] == -1 then
					if aroundrockdirection[playerID+1] == 2 then
						aroundrockdirection[playerID+1] = 3
					else
						aroundrockdirection[playerID+1] = 2
					end
				elseif moveX[playerID+1] == -1 and moveY[playerID+1] == 1 then
					if aroundrockdirection[playerID+1] == 3 then
						aroundrockdirection[playerID+1] = 2
					else
						aroundrockdirection[playerID+1] = 3
					end
				elseif moveX[playerID+1] == -1 and moveY[playerID+1] == -1 then
					if aroundrockdirection[playerID+1] == 4 then
						aroundrockdirection[playerID+1] = 1
					else
						aroundrockdirection[playerID+1] = 4
					end
				elseif moveX[playerID+1] == 1 then
					if aroundrockdirection[playerID+1] == 4 and rockstuckcooldown[playerID+1] < rockavoidcooldowndefault-1 then
						aroundrockdirection[playerID+1] = 2
					elseif aroundrockdirection[playerID+1] == 3 then
						aroundrockdirection[playerID+1] = 4
					else
						aroundrockdirection[playerID+1] = 3
					end
				elseif moveX[playerID+1] == -1 then
					if aroundrockdirection[playerID+1] == 1 and rockstuckcooldown[playerID+1] < rockavoidcooldowndefault-1 then
						aroundrockdirection[playerID+1] = 3
					elseif aroundrockdirection[playerID+1] == 2 then
						aroundrockdirection[playerID+1] = 1
					else
						aroundrockdirection[playerID+1] = 2
					end
				elseif moveY[playerID+1] == 1 then
					if aroundrockdirection[playerID+1] == 3 and rockstuckcooldown[playerID+1] < rockavoidcooldowndefault-1 then
						aroundrockdirection[playerID+1] = 4
					elseif aroundrockdirection[playerID+1] == 1 then
						aroundrockdirection[playerID+1] = 3
					else
						aroundrockdirection[playerID+1] = 1
					end
				elseif moveY[playerID+1] == -1 then
					if aroundrockdirection[playerID+1] == 2 and rockstuckcooldown[playerID+1] < rockavoidcooldowndefault-1 then
						aroundrockdirection[playerID+1] = 1
					elseif aroundrockdirection[playerID+1] == 4 then
						aroundrockdirection[playerID+1] = 2
					else
						aroundrockdirection[playerID+1] = 4
					end
				end
				rockstuckcooldown[playerID+1] = rockavoidcooldowndefault
			end
			--move in the chosen direction get out of stuck position
			--but try not to accidentally leave the room while finding a new path
			if rockstuckcooldown[playerID+1] > 0 then
				if aroundrockdirection[playerID+1] == 1 then
					if clone.Position.X - topleft.X > 30 then
						moveX[playerID+1] = -1
					end
					if bottomright.Y - clone.Position.Y > 30 then
						moveY[playerID+1] = 1
					end
				elseif aroundrockdirection[playerID+1] == 2 then
					if clone.Position.X - topleft.X > 30 then
						moveX[playerID+1] = -1
					end
					if clone.Position.Y - topleft.Y > 30 then
						moveY[playerID+1] = -1
					end
				elseif aroundrockdirection[playerID+1] == 3 then
					if bottomright.X - clone.Position.X > 30 then
						moveX[playerID+1] = 1
					end
					if bottomright.Y - clone.Position.Y > 30 then
						moveY[playerID+1] = 1
					end
				elseif aroundrockdirection[playerID+1] == 4 then
					if bottomright.X - clone.Position.X > 30 then
						moveX[playerID+1] = 1
					end
					if clone.Position.Y - topleft.Y > 30 then
						moveY[playerID+1] = -1
					end
				end
			end
		end
	else
		rockavoidwarmup = 0
	end
	rockstuckcooldown[playerID+1] = rockstuckcooldown[playerID+1] - 1
	if rockstuckcooldown[playerID+1] < -35 then
		aroundrockdirection[playerID+1] = 0
	end
	if currentRoom:GetFrameCount() < 2 then
		aroundrockdirection[playerID+1] = 0
		rockavoidwarmup = 0
	end
	lastplayerpos[playerID+1] = currPos
	--dont get stuck in crawlspace
	if currentRoom:GetType() == 16 then
		--BEAST fight
		if REPENTANCE and Game():GetLevel():GetStage() == 13 then
			if currPos.Y > 400 then
				moveY[playerID+1] = -1
			end
		elseif pickupdistance > 9999999 then --no items in room
			if Game():GetLevel():GetCurrentRoomDesc().Data.Variant == 1 then --go to black market
				if currPos.X < 150 and currPos.Y < 360 then
					moveY[playerID+1] = 1
				end
				if currPos.X < 480 and currPos.Y > 340 then
					moveX[playerID+1] = 1
				end
				if currPos.X > 480 then
					moveY[playerID+1] = -1
				end
				if currPos.X > 480 and currPos.Y < 320  then
					moveX[playerID+1] = 1
				end
			else --go back up ladder
				if currPos.X > 220 and currPos.Y < 340 then
					moveX[playerID+1] = 1
					moveY[playerID+1] = 1
				end
				if currPos.X > 220 and currPos.Y > 340 then
					moveX[playerID+1] = -1
					moveY[playerID+1] = 1
				end
			end
		else --room still has items
			if currPos.X < 140 then
				moveY[playerID+1] = 1
			end
			if currPos.Y > 340 and currPos.X < 490 then
				moveX[playerID+1] = 1
			end
		end
	end
	--avoid black market trapdoor if still going for items
	if currentRoom:GetType() == RoomType.ROOM_BLACK_MARKET and pickupdistance < 9999999999 then
		for g = 1, tilecount do
			if currentRoom:GetGridEntity(g) ~= nil then
				local gridEntity = currentRoom:GetGridEntity(g)
				if gridEntity:GetType() == 17 and currPos:Distance(gridEntity.Position) < 150 then
					moveY[playerID+1] = 1
				end
			end
		end
	end
	--dont overlap with other players
	if avoidotherplayers and Game():GetNumPlayers() > 1 then
		for i = 0, Game():GetNumPlayers()-1 do
			local otherplayerpos = Isaac.GetPlayer(i).Position
			if i ~= playerID and currPos:Distance(otherplayerpos) < 40 then
				if currPos.X > otherplayerpos.X and bottomright.X - currPos.X > 20 then
					moveX[playerID+1] = 1
				elseif currPos.X - topleft.X > 20 then
					moveX[playerID+1] = -1
				end
				if currPos.Y > otherplayerpos.Y and bottomright.Y - currPos.Y > 20 then
					moveY[playerID+1] = 1
				elseif currPos.Y - topleft.Y > 20 then
					moveY[playerID+1] = -1
				end
			end
		end
	end
	--avoid spikes and red poops
	if avoidDangers then
		for i = 1, tilecount do
			if currentRoom:GetGridEntity(i) ~= nil then
				local gridEntity = currentRoom:GetGridEntity(i)
				------------------------------------------------
				if gridEntOnCol[i] then
					local redOffset = gridEntOnCol[i]
					gridEntity:GetSprite().Color = Color(1, 1, 1, 1, 1 - math.abs(redOffset - 5)/5, 0, 0)
				end
				------------------------------------------------
				if (gridEntity:GetType() == 14 and gridEntity:GetVariant() == 1 and gridEntity.State < 4) and gridEntity.Position:Distance(currPos) < 70 then
					if math.abs(gridEntity.Position.X - currPos.X) > math.abs(gridEntity.Position.Y - currPos.Y) then
						if gridEntity.Position.X > currPos.X then
							moveX[playerID+1] = -1
							if gridEntity:GetType() == 14 and gridEntity:GetVariant() == 1 and gridEntity.State < 4 and currentRoom:IsClear() then
								shootX[playerID+1] = 1
							end
						else
							moveX[playerID+1] = 1
							if gridEntity:GetType() == 14 and gridEntity:GetVariant() == 1 and gridEntity.State < 4 and currentRoom:IsClear() then
								shootX[playerID+1] = -1
							end
						end
					else
						if gridEntity.Position.Y > currPos.Y then
							moveY[playerID+1] = -1
							if gridEntity:GetType() == 14 and gridEntity:GetVariant() == 1 and gridEntity.State < 4 and currentRoom:IsClear() then
								shootY[playerID+1] = 1
							end
						else
							moveY[playerID+1] = 1
							if gridEntity:GetType() == 14 and gridEntity:GetVariant() == 1 and gridEntity.State < 4 and currentRoom:IsClear() then
								shootY[playerID+1] = -1
							end
						end
					end
				end
			end
		end
	end
	--avoid greed mode spiked button
	if Game():IsGreedMode() and Game():GetLevel():GetCurrentRoomDesc().GridIndex == 84 then
		if currentRoom:GetAliveEnemiesCount() > 0 or currentRoom:GetAliveBossesCount() > 0 then
			greedmodecooldown = 150
			if currPos:Distance(greedmodebuttonpos) < 120 then
				TimeSplice:goaround(currPos, greedmodebuttonpos, 60)
			end
		end
	end
	--dont get stuck in room corners
	if avoidCorners and pickupdistance > 75 and currentRoom:IsClear() == false then
		if currPos:Distance(topleft) < 60 then
			if incorner[playerID+1] < 0 then
				if math.abs(currPos.X-topleft.X) > math.abs(currPos.Y-topleft.Y) then
					incorner[playerID+1] = 1
				else
					incorner[playerID+1] = 3
				end
			end
		elseif currPos:Distance(topright) < 60 then
			if incorner[playerID+1] < 0 then
				if math.abs(currPos.X-topleft.X) > math.abs(currPos.Y-topleft.Y) then
					incorner[playerID+1] = 0
				else
					incorner[playerID+1] = 2
				end
			end
		elseif currPos:Distance(bottomleft) < 60 then
			if incorner[playerID+1] < 0 then
				if math.abs(currPos.X-topleft.X) > math.abs(currPos.Y-topleft.Y) then
					incorner[playerID+1] = 2
				else
					incorner[playerID+1] = 0
				end
			end
		elseif currPos:Distance(bottomright) < 60 then
			if incorner[playerID+1] < 0 then
				if math.abs(currPos.X-topleft.X) > math.abs(currPos.Y-topleft.Y) then
					incorner[playerID+1] = 3
				else
					incorner[playerID+1] = 1
				end
			end
		else
			incorner[playerID+1] = -1
		end
		if incorner[playerID+1] == 0 then
			moveX[playerID+1] = 1
			moveY[playerID+1] = 1
		elseif incorner[playerID+1] == 1 then
			moveX[playerID+1] = -1
			moveY[playerID+1] = 1
		elseif incorner[playerID+1] == 2 then
			moveX[playerID+1] = -1
			moveY[playerID+1] = -1
		elseif incorner[playerID+1] == 3 then
			moveX[playerID+1] = 1
			moveY[playerID+1] = -1
		end
	end
	--if in cleared room and is not player 1 and does not enter new rooms
	--and there is no other move target then follow player1
	if followplayer1 and currentRoom:IsClear() and playerID > 0 and moveX[playerID+1] == 0 and moveY[playerID+1] == 0 then
		local player1pos = Isaac.GetPlayer(0).Position
		if player1pos:Distance(currPos) > 120 then
			if player1pos.X > currPos.X + 40 then
				moveX[playerID+1] = 1
			elseif player1pos.X < currPos.X - 40 then
				moveX[playerID+1] = -1
			end
			if player1pos.Y > currPos.Y + 40 then
				moveY[playerID+1] = 1
			elseif player1pos.Y < currPos.Y - 40 then
				moveY[playerID+1] = -1
			end
		end
	end
	--check for mirrored world
	if currentRoom:IsMirrorWorld() then
		moveX[playerID+1] = -1*moveX[playerID+1]
		shootX[playerID+1] = -1*shootX[playerID+1]
	end
end

--use when ai should avoid touching something but still keep going in the same general direction
--if player is less than mindistance away from the target forget about general direction and just move away
function TimeSplice:goaround(playerpos, avoidposition, mindistance)
	local Xcheck = math.abs(playerpos.X - avoidposition.X)
	local Ycheck = math.abs(playerpos.Y - avoidposition.Y)
	if playerpos:Distance(avoidposition) < mindistance then
		TimeSplice:simplemoveaway(playerpos, avoidposition, 10)
	else
		if moveX[playerID+1] == -1 and moveY[playerID+1] == -1 then
			if Xcheck > Ycheck then
				moveX[playerID+1] = 1
			else
				moveY[playerID+1] = 1
			end
		elseif moveX[playerID+1] == 1 and moveY[playerID+1] == -1 then
			if Xcheck < Ycheck then
				moveY[playerID+1] = 1
			else
				moveX[playerID+1] = -1
			end
		elseif moveX[playerID+1] == 1 and moveY[playerID+1] == 1 then
			if Xcheck > Ycheck then
				moveX[playerID+1] = -1
			else
				moveY[playerID+1] = -1
			end
		elseif moveX[playerID+1] == -1 and moveY[playerID+1] == 1 then
			if Xcheck < Ycheck then
				moveY[playerID+1] = -1
			else
				moveX[playerID+1] = 1
			end
		elseif moveX[playerID+1] == -1 then
			if playerpos.Y < avoidposition.Y then
				moveY[playerID+1] = -1
			else
				moveY[playerID+1] = 1
			end
		elseif moveY[playerID+1] == -1 then
			if playerpos.X < avoidposition.X then
				moveX[playerID+1] = -1
			else
				moveX[playerID+1] = 1
			end
		elseif moveX[playerID+1] == 1 then
			if playerpos.Y < avoidposition.Y then
				moveY[playerID+1] = -1
			else
				moveY[playerID+1] = 1
			end
		elseif moveY[playerID+1] == 1 then
			if playerpos.X < avoidposition.X then
				moveX[playerID+1] = -1
			else
				moveX[playerID+1] = 1
			end
		end
	end
end

--have ai drop a bomb
function TimeSplice:bomb(player)
	Isaac.Spawn(4, 0, 0, cloneSig, player.Velocity*0.33, nil)
	player:AddBombs(-1)
	bombcooldown = 60
end

--take pickups
function TimeSplice:takePickup(ent, playerEnt)
	local var = ent.Variant
	local sub = ent.SubType
	local bow = playerEnt:HasCollectible(CollectibleType.COLLECTIBLE_MAGGYS_BOW)
	if var == PickupVariant.PICKUP_HEART then
		if sub == HeartSubType.HEART_FULL or sub == HeartSubType.HEART_SCARED then playerEnt:AddHearts(bow and 4 or 2)
		elseif sub == HeartSubType.HEART_HALF then playerEnt:AddHearts(bow and 2 or 1)
		elseif sub == HeartSubType.HEART_SOUL then playerEnt:AddSoulHearts(2)
		elseif sub == HeartSubType.HEART_ETERNAL then playerEnt:AddEternalHearts(1)
		elseif sub == HeartSubType.HEART_DOUBLEPACK then playerEnt:AddHearts(bow and 8 or 4)
		elseif sub == HeartSubType.HEART_BLACK then playerEnt:AddBlackHearts(2)
		elseif sub == HeartSubType.HEART_GOLDEN then playerEnt:AddGoldenHearts(1)
		elseif sub == HeartSubType.HEART_HALF_SOUL then playerEnt:AddSoulHearts(1)
		elseif sub == HeartSubType.HEART_BLENDED then
			if playerEnt:CanPickRedHearts() then
				playerEnt:AddHearts(bow and 2 or 1)
				if playerEnt:CanPickRedHearts() then
					playerEnt:AddHearts(bow and 2 or 1)
				else playerEnt:AddSoulHearts(1) end
			else playerEnt:AddSoulHearts(2) end
		elseif sub == HeartSubType.HEART_BONE then playerEnt:AddBoneHearts(1)
		elseif sub == HeartSubType.HEART_ROTTEN then playerEnt:AddRottenHearts(1) end

	elseif var == PickupVariant.PICKUP_COIN then
		playerEnt:AddCoins(ent:GetCoinValue())

	elseif var == PickupVariant.PICKUP_KEY then
		if sub == KeySubType.KEY_NORMAL then playerEnt:AddKeys(1)
		elseif sub == KeySubType.KEY_GOLDEN then playerEnt:AddGoldenKey()
		elseif sub == KeySubType.KEY_DOUBLEPACK then playerEnt:AddKeys(2)
		elseif sub == KeySubType.KEY_CHARGED then
			playerEnt:AddKeys(1)
			if not playerEnt:HasCollectible(CollectibleType.COLLECTIBLE_BATTERY) then
				playerEnt:SetActiveCharge(math.min(playerEnt:GetActiveCharge() + 6, activeItemCharges[playerID + 1]))
			else playerEnt:SetActiveCharge(playerEnt:GetActiveCharge() + 6) end
		end

	elseif var == PickupVariant.PICKUP_BOMB then
		if sub == BombSubType.BOMB_NORMAL then playerEnt:AddBombs(1)
		elseif sub == BombSubType.BOMB_DOUBLEPACK then playerEnt:AddBombs(2)
		elseif sub == BombSubType.BOMB_GOLDEN then playerEnt:AddGoldenBomb() end

	elseif var == PickupVariant.PICKUP_CHEST or var == PickupVariant.PICKUP_WOODENCHEST then
		ent:TryOpenChest(playerEnt)

	elseif var == PickupVariant.PICKUP_LIL_BATTERY then
		local charge = 0
		if sub == BatterySubType.BATTERY_NORMAL then charge = 6
		elseif sub == BatterySubType.BATTERY_MICRO then charge = 2
		elseif sub == BatterySubType.BATTERY_MEGA then charge = 100 end

		if not playerEnt:HasCollectible(CollectibleType.COLLECTIBLE_BATTERY) and charge ~= 100 then
			playerEnt:SetActiveCharge(math.min(playerEnt:GetActiveCharge() + charge, activeItemCharges[playerID + 1]))
		else playerEnt:SetActiveCharge(playerEnt:GetActiveCharge() + charge) end

		sfx:Play(SoundEffect.SOUND_BATTERYCHARGE)

	end

	ent:PlayPickupSound()
	if var ~= PickupVariant.PICKUP_CHEST and var ~= PickupVariant.PICKUP_WOODENCHEST then ent:Remove() end
end

--make ai move towards something, diagonally first then straight line
--the lower the tolerance the more accurate the player tries to be
function TimeSplice:simplemovetowards(playerpos, targetposition, tolerance)
	if targetposition.X > playerpos.X + tolerance then
		moveX[playerID+1] = 1
	elseif targetposition.X < playerpos.X - tolerance then
		moveX[playerID+1] = -1
	end
	if targetposition.Y > playerpos.Y + tolerance then
		moveY[playerID+1] = 1
	elseif targetposition.Y < playerpos.Y - tolerance then
		moveY[playerID+1] = -1
	end
end

--make ai move away from something, diagonally first then straight line
--the lower the tolerance the more accurate the player tries to be
function TimeSplice:simplemoveaway(playerpos, avoidposition, tolerance)
	if avoidposition.X > playerpos.X + tolerance then
		moveX[playerID+1] = -1
	elseif avoidposition.X < playerpos.X - tolerance then
		moveX[playerID+1] = 1
	end
	if avoidposition.Y > playerpos.Y + tolerance then
		moveY[playerID+1] = -1
	elseif avoidposition.Y < playerpos.Y - tolerance then
		moveY[playerID+1] = 1
	end
end

---------------------------------------------
--------------END OF AI CODE-----------------
---------------------------------------------

-- Lua moment
function TimeSplice:pow(m, n)
	-- assume proper pre-conditions
	if m > 0 then return m ^ n else return - (math.abs(m) ^ n) end
end

-- sets target (mostly to set enemies' target to clone)
function TimeSplice:SetTarget(ent, target)
	if not ent:IsBoss() and ent.Type ~= EntityType.ENTITY_ROUND_WORM and
			ent.Type ~= EntityType.ENTITY_ULCER and ent.Type ~= EntityType.ENTITY_BOIL and
			ent.Type ~= EntityType.ENTITY_POOTER and ent.Type ~= EntityType.ENTITY_HOPPER and
			ent.Type ~= EntityType.ENTITY_LEAPER and ent.Type ~= EntityType.ENTITY_SPIDER and
			ent.Type ~= EntityType.ENTITY_BIGSPIDER and ent.Type ~= EntityType.ENTITY_WALL_CREEP and
			ent.Type ~= EntityType.ENTITY_BLIND_CREEP and ent.Type ~= EntityType.ENTITY_RAGE_CREEP and
			ent.Type ~= EntityType.ENTITY_NIGHT_CRAWLER and ent.Type ~= EntityType.ENTITY_ROUNDY and
			ent.Type ~= EntityType.ENTITY_MINISTRO and ent.Type ~= EntityType.ENTITY_FLAMINGHOPPER and
			ent.Type ~= EntityType.ENTITY_ATTACKFLY and ent.Type ~= EntityType.ENTITY_MOTER and
			ent.Type ~= EntityType.ENTITY_RING_OF_FLIES and ent.Type ~= EntityType.ENTITY_DART_FLY and
			ent.Type ~= EntityType.ENTITY_SPIDER_L2 then
		ent.TargetPosition = target.Position
	end
	ent.Target = target
end

--check if a player is a charge type weapon
function TimeSplice:hasChargeWeapon(player)
	if player:HasWeaponType(WeaponType.WEAPON_BRIMSTONE) or
			player:HasWeaponType(WeaponType.WEAPON_KNIFE) or
			player:HasWeaponType(WeaponType.WEAPON_MONSTROS_LUNGS) or
			player:HasWeaponType(WeaponType.WEAPON_TECH_X) then
		return true
	elseif player:HasCollectible(CollectibleType.COLLECTIBLE_CHOCOLATE_MILK) or
			player:HasCollectible(CollectibleType.COLLECTIBLE_CURSED_EYE) then
		return true
	end
	return false
end

-- return laser variant of the player
function TimeSplice:getLaserVariant(player)
	if player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) then
		if player:HasCollectible(CollectibleType.COLLECTIBLE_TECHNOLOGY) then return 9
		else return 1 end
	end
	if player:HasCollectible(CollectibleType.COLLECTIBLE_TECHNOLOGY) then return 2 end
	return 1
end

-- return shot multiplier
function TimeSplice:getShotMultiplier(player)
	local res = ((player:GetPlayerType() == PlayerType.PLAYER_KEEPER) and 3 or
			(player:GetPlayerType() == PlayerType.PLAYER_KEEPER_B and 4 or 1))
	if player:HasCollectible(CollectibleType.COLLECTIBLE_INNER_EYE) then
		res = ((res == 1) and 3 or res + 1) end
	if player:HasCollectible(CollectibleType.COLLECTIBLE_MUTANT_SPIDER) then
		res = ((res == 1) and 4 or res + 2) end
	if player:HasCollectible(CollectibleType.COLLECTIBLE_20_20) then
		res = ((res == 1) and 2 or res) end
	return res
end

-- return rot degrees given shootX and shootY, avoids trig func for performance sake
function TimeSplice:rotate(x, y)
	if x == 1 then return 0
	elseif x == -1 then return 180
	else
		if y == 1 then return 90
		else return -90 end
	end
end

function TimeSplice:redFlash()
	local room = Game():GetLevel():GetCurrentRoom()
	if counter <= 370 and counter >= 365 then
		room:SetFloorColor(Color(1, 1, 1, 0.99, (371 - counter) * 0.03, 0, 0))
	end
	if counter == 364 then room:SetFloorColor(Color(1, 1, 1, 1, 0, 0, 0)) end

	if counter <= 365 and counter >= 360 then
		room:SetWallColor(Color(1, 1, 1, 0.99, (counter - 359) * 0.03, 0, 0))
	end
	if counter == 359 then room:SetWallColor(Color(1, 1, 1, 1, 0, 0, 0)) end
end

function TimeSplice:onUse(_, _, player, flags)
	if counter ~= 0 or (flags & UseFlag.USE_CARBATTERY ~= 0) then return {
		Discharge = false,
		Remove = false,
		ShowAnim = false
	} end

	-- store index in clone pos signature
	cloneSig = player.Position
	clone = Isaac.Spawn(EntityType.ENTITY_SHOPKEEPER, 0, 0, cloneSig, Vector(0, 0), nil)
	-- persist between rooms so it can be removed once leaving rooms during onset
	clone:AddEntityFlags(EntityFlag.FLAG_PERSISTENT)
	-- disable drops
	clone:AddEntityFlags(EntityFlag.FLAG_NO_REWARD)
	clone.Visible = false
	counter = 400
	roomIndex = Game():GetLevel():GetCurrentRoomIndex()
	playerID = TimeSplice:getPlayerId(player)

	-- handle collision classes
	entColClass = player.EntityCollisionClass
	gridColClass = player.GridCollisionClass

	-- handle visual effect
	local idx = Game():GetRoom():GetRoomShape()
	local w = Isaac.GetScreenWidth()
	local h = Isaac.GetScreenHeight()
	effect = Isaac.Spawn(1000, 1000, 100, Vector(
			math.min(430 - w, w - 530), math.min(260 - h, h - 280)), Vector(0, 0), nil)
	effect:GetSprite().Scale = Vector(
			((idx >= 6 and idx <= 12) and 2 or 1)*Isaac.GetScreenWidth()/480,
			((idx == 4 or idx == 5 or (idx >= 8 and idx <= 12)) and 2 or 1)*Isaac.GetScreenHeight()/270)

	-- handle sfx
	music:Pause()
	sfx:Play(customSfx["WINDUP_"..math.random(2)], 1, 0, false, 1, 0)

	return true
end

function TimeSplice:getPlayerId(player)
	if player.Index == Isaac.GetPlayer(0).Index then return 0
	elseif player.Index == Isaac.GetPlayer(1).Index then return 1
	elseif player.Index == Isaac.GetPlayer(2).Index then return 2
	elseif player.Index == Isaac.GetPlayer(3).Index then return 3
	end
	return 0
end

function TimeSplice:onSpawn(type,var,_,_,_,spawner,_)
	if counter > 30 and (type == EntityType.ENTITY_TEAR or
			type == EntityType.ENTITY_BOMB or type == EntityType.ENTITY_LASER)
			and spawner and spawner.Type == EntityType.ENTITY_PLAYER then
		counter = 31
	end
	if counter > 30 and type == EntityType.ENTITY_EFFECT and var == EffectVariant.ROCKET then
		counter = 35
	end
	return nil
end

function TimeSplice:onDamage(ent)
	if counter > 30 and counter < 370 and ent.Type == EntityType.ENTITY_PLAYER then
		return false
	end
	if counter ~= 0 and clone and ent.Index == clone.Index then
		return false
	end
	if #lastShotLaser ~= 0 and ent.Type == EntityType.ENTITY_PLAYER then
		for _, v in pairs(lastShotLaser) do
			if ent.Index == v.Index then return false end
		end
		return true
	end
end

function TimeSplice:onStart(isContinued)
	TimeSplice:resetVals(nil)
	if not isContinued then
		local player = Isaac.GetPlayer(playerID)
		if player:GetPlayerType() == PlayerType.PLAYER_AZAZEL then
			weaponType[playerID + 1] = 2
			laserRange[playerID + 1] = 97
			firerange = 30
		else
			weaponType[playerID + 1] = 1
		end
	end
end

function TimeSplice:onExit()
	TimeSplice:resetVals(nil)
end

function TimeSplice:newfloor()
	TimeSplice:resetVals(nil)
	visitedcrawlspace = false
	greedexitopen = false
end

function TimeSplice:resetVals(player)
	if player then
		player.EntityCollisionClass = entColClass
		player.GridCollisionClass = gridColClass
	end
	sfx:Stop(customSfx["START_SKIP_1"])
	sfx:Stop(customSfx["START_SKIP_2"])
	effect = nil
	bd = nil
	closestEnemy = nil
	lastShotLaser = {}
	gridEntOnCol = {}
	roomIndex = 0
	counter = 0
	cloneSig = Vector(0, 0)
	if clone then
		clone:Remove()
		clone = nil
	end
	canShootCharged = {false, false, false, false}
	updateLaserRange = {false, false, false, false}
	if not goaroundrockspits and not Isaac.GetPlayer(playerID).CanFly then
		goaroundrockspits = true
	end
end

local glowLookup = {0.9, 0.7, 0.7, 0.5, 0.1, 0.7, 0.9, 0.9}
function TimeSplice:onShaders(s)
	if s == "Cosmos" then
		local offset = 1
		if Options then offset = Options.HUDOffset end
		return {
			Time = Isaac.GetFrameCount(),
			Enabled = (counter >= 15 and counter <= 385) and 1 or 0,
			HUDOffset = offset,
			--,Toggle = toggledTCS and 1 or 0
		}
	elseif s == "Flash" then
		local pos = Isaac.WorldToScreen(Isaac.GetPlayer(playerID).Position)
		return {
			Time = Isaac.GetFrameCount(),
			Enabled = (counter >= 345 and counter <= 352) and 1 or 0,
			PlayerPos = { pos.X / Isaac.GetScreenWidth(), pos.Y / Isaac.GetScreenHeight() },
			GlowStrength = glowLookup[353 - counter]
		}
	end

end

function TimeSplice:onCacheEval(ent, flag)
	local id = TimeSplice:getPlayerId(ent)
	if flag == CacheFlag.CACHE_WEAPON then
		--if ent:HasWeaponType(WeaponType.WEAPON_MONSTROS_LUNGS) then
		--weaponType[id + 1] = 6
		if ent:HasWeaponType(WeaponType.WEAPON_ROCKETS) then
			weaponType[id + 1] = 5
		elseif ent:HasWeaponType(WeaponType.WEAPON_KNIFE) then
			weaponType[id + 1] = 3
		elseif ent:HasWeaponType(WeaponType.WEAPON_BOMBS) then
			weaponType[id + 1] = 4
		elseif ent:HasWeaponType(WeaponType.WEAPON_BRIMSTONE) or ent:HasWeaponType(WeaponType.WEAPON_LASER) then
			weaponType[id + 1] = 2
		end
	elseif flag == CacheFlag.CACHE_RANGE and ent:GetPlayerType() == PlayerType.PLAYER_AZAZEL then
		updateLaserRange[id + 1] = true
	elseif flag == CacheFlag.CACHE_DAMAGE and counter == 30 then
		ent.Damage = ent.Damage * 2
	elseif flag == CacheFlag.CACHE_DAMAGE and counter == 1 then
		ent.Damage = ent.Damage / 2
	elseif flag == CacheFlag.CACHE_FIREDELAY then
		shotmultiplier = TimeSplice:getShotMultiplier(ent)
	elseif flag == CacheFlag.CACHE_FLYING and goaroundrockspits then
		goaroundrockspits = not ent.CanFly
	end
end

function TimeSplice:onLaserUpdate(ent)
	if updateLaserRange[playerID + 1] then
		local newVal = ((ent.MaxDistance ~= 0) and ent.MaxDistance + 20 or 0)
		laserRange[playerID + 1] = newVal
		firerange = ((newVal == 0) and 60 or 30)
		updateLaserRange[playerID + 1] = false
	end
end

function TimeSplice:onLaserInit(ent)
	if counter > 30 then
		ent:SetColor(Color(1, 1, 1, 2, 100, 0, 0), 0, 0, false, false)
	end
end

function TimeSplice:onKnifeCollision()
	if counter > 30 then return true end
end

function TimeSplice:onFamiliarCollision(ent)
	if counter > 30 then return true end
end

function TimeSplice:onKnifeUpdate(ent)
	if counter > 30 and ent:GetKnifeDistance() ~= 0 then
		counter = 31
	end
end

function TimeSplice:onEntityKill()
	correctionFactor = 20
end

function TimeSplice:onPreUse(type, _, player)
	local idx = TimeSplice:getPlayerId(player)
	if type == activeItemIds[idx + 1] then return nil end
	activeItemIds[idx + 1] = type
	activeItemCharges[idx + 1] = Isaac.GetItemConfig():GetCollectible(type).MaxCharges
end

TimeSplice:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, TimeSplice.onEntityKill)
TimeSplice:AddCallback(ModCallbacks.MC_POST_KNIFE_UPDATE, TimeSplice.onKnifeUpdate)
TimeSplice:AddCallback(ModCallbacks.MC_PRE_KNIFE_COLLISION, TimeSplice.onKnifeCollision)
TimeSplice:AddCallback(ModCallbacks.MC_PRE_FAMILIAR_COLLISION, TimeSplice.onFamiliarCollision)
TimeSplice:AddCallback(ModCallbacks.MC_POST_LASER_UPDATE, TimeSplice.onLaserUpdate)
TimeSplice:AddCallback(ModCallbacks.MC_POST_LASER_INIT, TimeSplice.onLaserInit)
TimeSplice:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, TimeSplice.onCacheEval)
TimeSplice:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, TimeSplice.onShaders)
TimeSplice:AddCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN, TimeSplice.onSpawn)
TimeSplice:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, TimeSplice.onDamage)
TimeSplice:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, TimeSplice.onStart)
TimeSplice:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, TimeSplice.onExit)
TimeSplice:AddCallback(ModCallbacks.MC_POST_UPDATE, TimeSplice.tick)
TimeSplice:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, TimeSplice.newfloor)
TimeSplice:AddCallback(ModCallbacks.MC_USE_ITEM, TimeSplice.onUse, item)
TimeSplice:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, TimeSplice.onPreUse)