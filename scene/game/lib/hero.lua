
-- Module/class for platfomer hero

-- Use this as a template to build an in-game hero 
local fx = require( "com.ponywolf.ponyfx" )
local composer = require( "composer" )

-- Define module
local M = {}

function M.new( instance, options )
	-- Get the current scene
	local scene = composer.getScene( composer.getSceneName( "current" ) )
	local sounds = scene.sounds

	-- Default options for instance
	options = options or {}

	-- Store map placement and hide placeholder
	instance.isVisible = false
  local invincible = false
	local parent = instance.parent
	local x, y = instance.x, instance.y

	-- Load spritesheet
	local sheetData = { width = 192, height = 256, numFrames = 79, sheetContentWidth = 1920, sheetContentHeight = 2048 }
	local sheet = graphics.newImageSheet( "scene/game/img/sprites.png", sheetData )
	local sequenceData = {
		{ name = "idle", frames = { 1 } },
		{ name = "walk", frames = { 2, 3, 4, 5 }, time = 333, loopCount = 0 },
		{ name = "jump", frames = { 6 } },
		{ name = "ouch", frames = { 8, 8, 8, 8, 8 } },
		{ name = "swim", frames = { 11, 12, 13, 14 }, time = 666, loopCount = 0 },
	}
	instance = display.newSprite( parent, sheet, sequenceData )
	instance.x,instance.y = x, y
	instance:setSequence( "idle" )



	-- Add physics
	physics.addBody( instance, "dynamic", { radius = 58, density = 3, bounce = 0, friction =  1.0 } )
	instance.isFixedRotation = true
	instance.anchorY = 0.77

	-- Keyboard control
	local max, acceleration, left, right, flip = 375, 7000, 0, 0, 0
	local lastEvent = {}
	local function key( event )
		local phase = event.phase
		local name = event.keyName
		if ( phase == lastEvent.phase ) and ( name == lastEvent.keyName ) then return false end  -- Filter repeating keys
		if phase == "down" then
			if "left" == name or "a" == name then
				left = -acceleration
				flip = -0.333
			end
			if "right" == name or "d" == name then
				right = acceleration
				flip = 0.333
			elseif "space" == name or "buttonA" == name or "button1" == name then
				instance:jump()
			end
			if not ( left == 0 and right == 0 ) and not instance.jumping and not instance.swim then
				instance:setSequence( "walk" )
				instance:play()
			end
		elseif phase == "up" then
			if "left" == name or "a" == name then left = 0 end
			if "right" == name or "d" == name then right = 0 end
			if left == 0 and right == 0 and not instance.jumping and not instance.swim then
				instance:setSequence("idle")
			end
		end
		lastEvent = event
	end

	function instance:jump()
		if not self.jumping then
			audio.play( sounds.jump )
			self:applyLinearImpulse( 0, instance.jumpforce ) -- -760   -- -550
			instance:setSequence( "jump" )
			self.jumping = true
      if (instance.swim == true) then
        instance:setSequence( "swim" )
        instance:play()
        local jumpTimer = timer.performWithDelay(500,function()
              self.jumping = false
            end)
      end
		end
	end

  function instance:heal()
    print('am I healing?')
    self.shield:heal()
  end
  
	function instance:hurt()
		fx.flash( self, 30 )
		audio.play( sounds.hurt[math.random(2)] )
		instance:setSequence( "ouch" )
		self:applyLinearImpulse( -1600, 1600 )
    self.invincible = true
    system.vibrate()
    print("i'm invincible!")
    timer.performWithDelay(500,function()
        print('no longer invincible')
        self.invincible = false
      end)
		if self.shield:damage() <= 0 then
			-- We died
			fx.fadeOut( function()
				composer.gotoScene( "scene.death", { params = { map = self.filename } } )
			end, 1500, 2000 )
			instance.isDead = true
			instance.isSensor = true
--			self:applyLinearImpulse( 0, -500 )
			-- Death animation
			instance:setSequence( "ouch" )
			self.xScale = 1
      self:toFront()
      physics.pause()
      audio.play(sounds.died)
			transition.to( self, { xScale = 2.5, yScale = 2.5, time = 125, transition = easing.inQuad, onComplete = function()
            transition.to (self, {y = self.y+1500, time = 3000, delay=500, transition = easing.inQuint})
          end
          } )
			-- Remove all listeners
			self:finalize()
		end
	end

	function instance:collision( event )
		local phase = event.phase
		local other = event.other
		local y1, y2 = self.y + 50, other.y - ( other.type == "enemy" and 25 or other.height/2 )
		local vx, vy = self:getLinearVelocity()
		if phase == "began" then
			if not self.isDead and ( other.type == "blob" or other.type == "enemy" ) then
				if y1 < y2 then
					-- Hopped on top of an enemy
					other:die()
--          self:applyLinearImpulse(0,-800)
				elseif not other.isDead then
					-- They attacked us
          if not self.invincible then
            self:hurt()
          end
				end
			elseif self.jumping and vy > 0 and not self.isDead then
				-- Landed after jumping
				self.jumping = false
				if not ( left == 0 and right == 0 ) and not instance.jumping then
					instance:setSequence( "walk" )
					instance:play()
				else
					self:setSequence( "idle" )
				end
			end
		end
	end

	function instance:preCollision( event )
		local other = event.other
		local y1, y2 = self.y + 50, other.y - other.height/2
		if event.contact and ( y1 > y2 ) then
			-- Don't bump into one way platforms
			if other.floating then
				event.contact.isEnabled = false
			else
				event.contact.friction = 0.1
			end
		end
	end

	local function enterFrame()
		-- Do this every frame
		local vx, vy = instance:getLinearVelocity()
		local dx = left + right
		if instance.jumping then dx = dx / 4 end
		if ( dx < 0 and vx > -max ) or ( dx > 0 and vx < max ) then
			instance:applyForce( dx or 0, 0, instance.x, instance.y )
		end
		-- Turn around
		instance.xScale = math.min( 1, math.max( instance.xScale + flip, -1 ) )
	end

	function instance:finalize()
		-- On remove, cleanup instance, or call directly for non-visual
		instance:removeEventListener( "preCollision" )
		instance:removeEventListener( "collision" )
		Runtime:removeEventListener( "enterFrame", enterFrame )
		Runtime:removeEventListener( "key", key )
	end

	-- Add a finalize listener (for display objects only, comment out for non-visual)
	instance:addEventListener( "finalize" )

	-- Add our enterFrame listener
	Runtime:addEventListener( "enterFrame", enterFrame )

	-- Add our key/joystick listeners
	Runtime:addEventListener( "key", key )

	-- Add our collision listeners
	instance:addEventListener( "preCollision" )
	instance:addEventListener( "collision" )

	-- Return instance
	instance.name = "hero"
	instance.type = "hero"
	return instance
end

return M
