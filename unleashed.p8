pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
function _init()
 scroll_speed=1.3
 dog=create_dog(50,115)
 scenario={
  create_pub(-15,4),
  create_pub(-15+7*8,4),
  create_pub(-15+14*8,4),
 }
end

function _update60()
 if dog.x+78>128*8 then
  scroll_speed=0
 end
 dog._update()
end

function _draw()
 -- yellow for transparencies
 palt(0, false)
 palt(10, true)

 -- light gray background
 cls(6)
 
 -- draw the different elements
 camera(dog.x-50, 13) 
 map()
 for _,element in ipairs(scenario) do
   element._draw()
 end
	dog._draw()
end
-->8
-- dog info --

local jump_acc=2.4
local jump_reduction=0.35

local function spr_duration()
 if scroll_speed!=0 then
  return 5/scroll_speed
 end
 return -1
end

local function update()
 -- apply gravity to jump,
 -- unless the jump button is
 -- clicked and the dog is
 -- neither too high nor
 -- slowing down the climb.
 -- this is so the user can
 -- click longer for a higher
 -- jump.
 local current_dz=dog.dz
 if dog.z<0 then
  if not (btn(❎) or btn(🅾️))
  or dog.z<-13 -- too high
  or dog.dz>=-1.5 -- too slow
  then
   dog.dz+=jump_reduction
  end
 end
 
 -- apply velocity deltas
 if dog.dx!=0 and dog.dy!=0 then
  -- ensure diagonal movements
  -- aren't faster than non
  -- diagonal ones
  local acc=abs(dog.dx)+abs(dog.dy)
  local acc_v=sqrt(dog.dx*dog.dx+dog.dy*dog.dy)
  local reduction=acc_v/acc
  dog.x+=dog.dx*reduction
	 dog.y+=dog.dy*reduction
 else
  dog.x+=dog.dx 
	 dog.y+=dog.dy
 end
 dog.x+=scroll_speed
	dog.z+=dog.dz
	
	-- dog doesn't enter the floor
	if dog.z>0 then
	 dog.z=0
	 dog.dz=0
	end
 
 -- jump if needed and on floor
 if (btnp(❎) or btnp(🅾️))
 and dog.z==0
 then
  dog.dz=-jump_acc
 end
 
 -- move up and down if needed,
 -- using acceleration and
 -- deceleration for better
 -- feeling when moving
 if btn(⬆️) then
	 dog.dy-=0.35
	elseif btn(⬇️) then
	 dog.dy+=0.35
	else
	 dog.dy/=1.6
	end	
	
	-- limit vertical speed
	if dog.dy<0 then
	 dog.dy=max(-1.4,dog.dy)
	elseif dog.dy>0 then
	 dog.dy=min(1.4,dog.dy)
	end
	
	-- update the dog sprite
	if current_dz==0 then
	 -- not jumping: running sprite
		-- (6 sprites)
		dog.spr_aux+=1
		local frames_per_sprite=spr_duration()
		if frames_per_sprite>0 then
			if dog.spr_aux>6*frames_per_sprite then
			 dog.spr_aux=frames_per_sprite
			end
			dog.sprite=dog.spr_aux/frames_per_sprite
		else
		 dog.sprite=2 -- sitting down
		end
	else
	 -- jumping: take the right
	 -- sprite depending on the
	 -- progress of the jump
	 -- (10 sprites)
	 dog.sprite=32+9*((current_dz+jump_acc)/(2*jump_acc))
	 dog.sprite=max(32,min(41,dog.sprite))
	end
	
	-- update leash
	dog.leash._update()
end

local function draw()
 -- draw dog shadow
 local shadow=5
 if (dog.y+8<121) shadow=0
 ovalfill(
  dog.x+1,
  dog.y+6,
  dog.x+6,
  dog.y+8,
  shadow
 )

 -- draw dog sprite
 local dog_y=dog.y+dog.z
 spr(dog.sprite, dog.x, dog_y)
 
 -- draw leash
 dog.leash._draw()
end

function create_dog(x,y)
	return {
	 x=x,
	 y=y,
	 z=0,
	 dx=0,
	 dy=0,
	 dz=0,
	 spr_aux=spr_duration(),
	 sprite=1,
	 leash=create_leash(0),
	 _update=update,
	 _draw=draw,
	}
end
-->8
-- pub info --

local function draw(sprts,offset)
 -- create zero offset if needed
 if (offset==nil) offset={}
 if (offset.x==nil) offset.x=0
 if (offset.y==nil) offset.y=0
 
 -- draw element
 local x,y=0,0
 while y<#sprts do
  while x<#sprts[y+1] do
   local sprite=sprts[y+1][x+1]
   if sprite!=0 then
    local flip=sprite<0
    spr(
     abs(sprite),
     x*8+offset.x,
     y*8+offset.y,
     1,1,
     flip)
   end
   x+=1
  end
  y+=1
  x=0
 end
 
 return {x=x*8+offset.x,y=y*8+offset.y}
end

function create_pub(x,y)
	local roof={
	 {0,65,66,67,-66,-65,0},
	 {80,81,82,83,-82,-81,-80},
	 {97,82,82,83,-82,-82,-97},
	 {97,82,82,83,-82,-82,-97},
	 {97,82,98,99,-98,-82,-97},
	 {112,113,114,115,-114,-113,-112},
	}
	local windows={
	 {68,69,70,87,-70,-69,-68},
	 {84,85,86,87,-86,-85,-84},
	 {100,101,102,103,-102,-101,-100},
	}
	local pub={
	 {116,117,118,119,120,117,-116},
	 {72,73,74,75,76,77,-72},
	 {88,89,90,91,92,93,-88},
	 {104,105,106,106,106,-105,-104}
	}
 return {
	 x=x,
	 y=y,
  _draw=function()
   local offset={x=x,y=y}
   offset=draw(roof,offset)
   offset=draw(windows,offset)
   offset=draw(pub,offset)
  end,
 }
end
-->8
-- leash info --

local leash={
 leash={},
}

-- leash position relative
-- to the start of the dog
-- sprite for each of the
-- dog sprites. used for the
-- leash origin point to
-- move along with the dog's
-- neck. as usual, the z
-- coordinate is a little bit
-- odd and inaccurate because
-- this isn't real 3d at all.
local leash_positions={
 [1]={x=12,y=7,z=-1},
 [2]={x=12,y=7,z=-1},
 [3]={x=12,y=7,z=-2},
 [4]={x=12,y=7,z=-2},
 [5]={x=12,y=7,z=-1},
 [6]={x=12,y=7,z=-1},
 [32]={x=12,y=7,z=-1},
 [33]={x=12,y=7,z=-2},
 [34]={x=12,y=7,z=-3},
 [35]={x=12,y=7,z=-3},
 [36]={x=12,y=7,z=-3},
 [37]={x=12,y=7,z=-2},
 [38]={x=12,y=7,z=-2},
 [39]={x=12,y=7,z=-2},
 [40]={x=12,y=7,z=-2},
 [41]={x=12,y=7,z=-1},
}

local function leash_rel_origin()
 local p=leash_positions[1]
 if dog!=nil then
  p=leash_positions[flr(dog.sprite)]
 end
 return {x=p.x,y=p.y,z=p.z}
end

-- todo: make the least also
-- move up and down with the
-- dog
function leash._update()
	-- update leash point by point
	local o=leash_rel_origin()
	local new_leash={
  {
   x=o.x,
   y=o.y,
   z=o.z+dog.z,
   dz=0,
  },
 }
	for i=2,#leash.leash do
	 local lp=new_leash[i-1]
	 local p=leash.leash[i]
	 
	 -- update point position,
	 -- avoiding entering the
	 -- floor
	 p.z+=p.dz 
	 if p.z>0 then
	  p.z=0
	  p.dz=0
	 end
	 
	 -- update movement deltas
	 local diff=p.z-lp.z
	 local dist=abs(diff)
	 if dist>1 then
	  -- move the point to catch
	  -- up with its predecessor,
	  -- which is now far
	  if diff>0 then
	   -- point must move up
	   p.z-=diff-1
	   p.dz=-dist/2
	  else
	   -- point must move down
	   p.z-=diff+1
	   p.dz=dist/2
	  end
	 else
	  -- apply gravity
		 if p.z<0 then
		  p.dz+=jump_reduction
		 else
		  p.dz=0
		 end
	 end
	 new_leash[#new_leash+1]=p
	end
	dog.leash.leash=new_leash
end

function leash._draw()
 for i=1,#leash.leash do
  local p=leash.leash[i]
  if i<#leash.leash then
	  rectfill(
	  dog.x-8+p.x,
	  dog.y+p.y+p.z,
	  dog.x-8+p.x,
	  dog.y+p.y+p.z,
	  2
	 )
	 else
	  rectfill(
	  dog.x-8+p.x-1,
	  dog.y+p.y+p.z-1,
	  dog.x-8+p.x,
	  dog.y+p.y+p.z,
	  0
	 )
	 end
 end
end

function create_leash(dog_z)
	local o=leash_rel_origin()
 leash.leash={
  {
   x=o.x,
   y=o.y,
   z=o.z+dog_z,
   dz=0,
  },
 }
 for _=1,10 do
  local lp=leash.leash[#leash.leash]
  leash.leash[#leash.leash+1]={
   x=lp.x-1,
   y=lp.y,
   z=min(0,lp.z+1),
   dz=0,
  }
 end

 return leash
end
__gfx__
00000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000
00000000aaaaaaaaaaaaaaaaaaaaa0aaaaaaa0aaaaaaaaaaaaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000
007007004aaaa0aaaaaaa0aaaaaaa44aaaaaa44aaaaaa0aa4aaaa0aa000000000000000000000000000000000000000000000000000000000000000000000000
000770004aaaa44a4aaaa44a4aaa80404aaa80404aaaa44a4aaaa44a000000000000000000000000000000000000000000000000000000000000000000000000
00077000a44480404a4480404a4480444a4480444a448040a4448040000000000000000000000000000000000000000000000000000000000000000000000000
00700700a4448044a4448044a444484aa44448aaa4448044a4448044000000000000000000000000000000000000000000000000000000000000000000000000
00000000aa4448aaa44448aaa444aaaa444444aaa44448aaa44448aa000000000000000000000000000000000000000000000000000000000000000000000000
00000000aa44aaaaaa4a4aaaa4aaaaaaaaaaaa4a4aaaa4aaaaaa4aaa000000000000000000000000000000000000000000000000000000000000000000000000
66666666565555555655555555555555666666666666666600000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666555556555555565555555655666666666666666600000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666555555555555555555555555666666666666666600000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666555555555555555555555555666666666666666600000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666556555555565555555655555666666666666666600000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666555555655555555555555565666666666666666600000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666555555555050505055555555677777777766666600000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666555555550505050555555555677777777766666600000000000000000000000000000000000000000000000000000000000000000000000000000000
aaaaaaaaaaaaaaaaaaaaa0aaaaaaa0aaaaaaa0aaaaaaaaaa4aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000000000000000000000000000000000000000000000000
aaaaaaaaaaaaa0aaaaaaa44aaaaaa44a4aaaa44a4aaaa0aa4aaaa0aa4aaaa0aaaaaaa0aaaaaaaaaa000000000000000000000000000000000000000000000000
aaaaa0aaaaaaa44aaaaa80404aaa80404aaa80404aaaa44aa4aaa44a4aaaa44a4aaaa44a4aaaa0aa000000000000000000000000000000000000000000000000
4aaaa44a4aaa80404aa480444a448044a4448044a4aa8040444a8040a44a80404aaa80404aaaa44a000000000000000000000000000000000000000000000000
4a4480404a4480444a4448aaa44448aa444448aa444480444444804444448044a4448044a4448040000000000000000000000000000000000000000000000000
a4448044a44448aaa44444aa444444aa444444aa444448aa444448aa444448aaa44448aaa4448044000000000000000000000000000000000000000000000000
a44448aa444444aa444aaaaa44aaaaaa44aaa4aa444444aaa4a444aa44a444aaa4a44aaaa4a448aa000000000000000000000000000000000000000000000000
aaa44aaa44aaaaaa44aaaaaaaaaaaaaaaaaaaaaaaaaaa4aaaaaaa4aaa4aa4aaaa4aa4aaaaa4a4aaa000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000aaaaaaaaaaaaaaaaaaa11aaaaaa666655454454444444444000000005050000000000000000000000000000000000000000000000000000000000000
00000000aaaaaaaaaaaaaaaaa111d11aaaa666655445444444444444000000005500655560f01050501010101040101010101010101010060000000000000000
00000000aaaaaaaaaaaaaaa11dd11dd1aaaa655545444444444444440000000050506666600f0105010101010202010101010101010102060000000000000000
00000000aaaaaaaaaaaaa11dd11d111daaaa666544444444444444440000000055006555601011555111111122226111611111117111f0060000000000000000
00000000aaaaaaaaaaa11dd11dd11dd1aaaa666454444444444444440000000050506666600411555555555f4556665666555eee9ef502060000000000000000
00000000aaaaaaaaa11dd11dd111d11daaaa655545444444444444440000000055006555601011555555555ff556665666555eeeee2220060000000000000000
00000000aaaaaaa11dd11dd11dd11dd1aaaa666544444466666666640000000050506666600111ddddddddddddddddddddddddddddd202060000000000000000
00000000aaaaa11dd11dd11dd11d111daaaa666454444655555555560000000055006555601011ddddddddd4dddddddddddddddddddcc0060000000000000000
aaaaaaaaaaa11dd11dd11dd11dd11dd1aaaa655545444600006000064444444450506666600111fddddddd343ddddddddddddd7ddddc0c060000000000000000
aaaaaaaaa11dd11dd11dd11dd111d11daaaa66654444460dd060dd064444444455006555601017f6111111333311111111747474411c10060000000000000000
aaaaaaa11dd11dd11dd11dd11dd11dd1555066645444460110601106444444445050666660017776474444334311111114747444441000060000000000000000
aaaaa11dd11dd11dd11dd11dd11d111d550065554544460000600006444444445500655560107f6649447444c411111114444444441110060000000000000000
aaa11dd11dd11dd11dd11dd11dd11dd150506665444446666666666644444444505066666001fdd444449444c111111111144444111101060000000000000000
aa1dd11dd11dd11dd11dd11dd111d11d550066645444460000600006444444445500655560101010104040000010101010101010101010060000000000000000
aa111dd11dd11dd11dd11dd11dd11dd1505065554544460dd060dd06444444445050666660010202010001010101010101010001010101060000000000000000
aa1dd11dd11dd11dd11dd11dd11d111d550066654444460110601106444444445500655560000000000000000000000000000000000000060000000000000000
00000000aa111dd11dd11dd11dd11dd1505066644444460000600006444444445050666677777777777777770000000000000000000000000000000000000000
00000000aa1dd11dd11dd11dd111d11d550065554544466666666666444444445500655566666666666666660000000000000000000000000000000000000000
00000000aa111dd11dd11dd11dd11dd1505066654444555555555555544444455056666666666666666666660000000000000000000000000000000000000000
00000000aa1dd11dd11dd11dd110011d550066645444444444444444444444445506555556666666666666660000000000000000000000000000000000000000
00000000aa111dd11dd11dd11056650150506555454444444444444444444444aaa5555555555555555555550000000000000000000000000000000000000000
00000000aa1dd11dd11dd1105666666555006666544444444444444444444444aaaaaaaaaaaaaaaaaaaaaaaa0000000000000000000000000000000000000000
00000000aa111dd11dd110566665566650506666654545454545454545454545aaaaaaaaaaaaaaaaaaaaaaaa0000000000000000000000000000000000000000
00000000aa1dd11dd11056666555555655006666645454545454545454545454aaaaaaaaaaaaaaaaaaaaaaaa0000000000000000000000000000000000000000
aa111dd11dd11dd11056666554544545505066666555555555555555555555555555555500000000000000000000000000000000000000000000000000000000
aa1dd11dd11dd1105666655454444445550666666666666666666666666666666666666600000000000000000000000000000000000000000000000000000000
aa111dd11dd110566665545445466454505555555555555555555555555555555555555500000000000000000000000000000000000000000000000000000000
aa1dd11dd11056666554544544600644550888888888888888888888888888888888888800000000000000000000000000000000000000000000000000000000
aa111dd11056666554544544460dd06450588f8f8f8f8f8f8f8f8f8777878787778f8f8f00000000000000000000000000000000000000000000000000000000
aa1dd1105666655454454444460110645508f8f8f8f8f8f8f8f8f887778787877788f8f800000000000000000000000000000000000000000000000000000000
aa11105666655454454444444460064450588f8f8f8f8f8f8f8f8f8788877787778f8f8f00000000000000000000000000000000000000000000000000000000
aa155666655454454444444444466444550888888888888888888888888888888888888800000000000000000000000000000000000000000000000000000000
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
74747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474747474
__map__
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
