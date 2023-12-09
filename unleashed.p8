pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
function _init()
 dog.x, dog.y=63,63
end

function _update60()
 dog._update()
end

function _draw()
 cls(6)
	dog._draw()
end
-->8
local function update()
 -- apply gravity to jump,
 -- unless the jump button is
 -- clicked and the dog is
 -- neither too high nor
 -- slowing down the climb.
 -- this is so the user can
 -- click longer for a higher
 -- jump.
 if dog.z<0 then
  if not (btn(❎) or btn(🅾️))
  or dog.z<-13 -- too high
  or dog.dz>=-1.5 -- too slow
  then
   dog.dz+=0.3
  end
 end
 
 -- apply velocity deltas
 dog.x += dog.dx
	dog.y += dog.dy
	dog.z += dog.dz
	
	-- dog doesn't enter the floor
	if dog.z>0 then
	 dog.z=0
	 dog.dz=0
	end
 
 -- jump if needed and on floor
 if (btnp(❎) or btnp(🅾️))
 and dog.z==0
 then
  dog.dz=-2.4
 end
 
 -- move up and down if needed,
 -- using acceleration and
 -- deceleration for effect
 if btn(⬆️) then
	 dog.dy-=0.35
	elseif btn(⬇️) then
	 dog.dy+=0.35
	else
	 dog.dy/=1.5
	end	
	
	-- limit vertical acceleration
	-- to limit movement speed
	if dog.dy<0 then
	 dog.dy=max(-1.4,dog.dy)
	elseif dog.dy>0 then
	 dog.dy=min(1.4,dog.dy)
	end
end

local function draw()
 -- draw dog shadow
 rectfill(
  dog.x+1,
  dog.y+5,
  dog.x+4,
  dog.y+6,
  5
 )
 -- draw dog sprite
 spr(1, dog.x, dog.y + dog.z)
end

dog={
 x=0,
 y=0,
 z=0,
 dx=0,
 dy=0,
 dz=0,
 _update=update,
 _draw=draw,
}
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000400001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700400004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000044481410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000044481440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700004448000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000040040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
