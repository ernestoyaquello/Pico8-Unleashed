pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
function _init()
 state="play"
 scroll_speed=1.2
 dog_offset_x=56
 dog=create_dog(dog_offset_x,120)
 buildings={}
 cars={}
end

function _update60()
 local start_x=dog.x-dog_offset_x
 local end_x=dog.x-dog_offset_x+127
 
 -- if we have reached the end
 -- of the map, let's move
 -- everything to its start to
 -- make the horizontal
 -- scrolling infinite
 local map_end_x=(128*8)-1
 if end_x>=map_end_x then
  -- shift dog
  local offset=-map_end_x+127
  dog.x+=offset
  for _,p in ipairs(dog.leash.leash) do
   p.x+=offset
  end
  
  -- shift buildings
  for _,b in ipairs(buildings) do
   b.x+=offset
  end
  
  -- shift cars
  for _,c in ipairs(cars) do
   c.x+=offset
  end
  
  -- shift aux variables
  start_x=dog.x-dog_offset_x
  end_x=dog.x-dog_offset_x+127
 end 

 -- create a new list of
 -- buildings to update the
 -- scenario if needed
 local new_buildings={}
 
 -- add the existing buildings
 -- to the new list, but only
 -- if they are still within
 -- view
 local max_b_end_x=0
 for i=1,#buildings do
  local b=buildings[i]
  local b_end_x=b.x+b.width-1
  if b_end_x>=start_x then
   new_buildings[#new_buildings+1]=b
   max_b_end_x=max(max_b_end_x,b_end_x)
  end
 end
 
 -- add as many new buildings
 -- as needed to fill the gap
 while max_b_end_x<end_x do
  local nb=create_building(max_b_end_x+1,10)
  new_buildings[#new_buildings+1]=nb
  max_b_end_x+=nb.width
 end
 
 buildings=new_buildings
 
 -- create new car list
 local new_cars={}
 local new_car_ys={
  [18]=1.8,
  [40]=1.6,
  [116]=-1,
  [132]=-1.2,
 }
 
 -- add existing cars, but
 -- only if they are still
 -- within view
 for i=1,#cars do
  local c=cars[i]
  local c_end_x=c.x+c.width-1
  if c.x<=end_x and c_end_x>=start_x then
   new_cars[#new_cars+1]=c
   if
   (c.speed<0
    and c_end_x+c.width>=end_x)
   or
   (c.speed>0
    and c.x-c.width<=start_x)
   then
    -- this "y" isn't available
    -- for new cars, as a car
    -- is already on it
    new_car_ys[c.y]=nil
   end
  end
 end
 
 -- add new cars at random
 for cy,spd in pairs(new_car_ys) do
  if flr(rnd(50))==1 then
   local nc_x=end_x
   if spd>0 then
    nc_x=start_x-24
   end
   local nc=create_car(
    nc_x,
    cy,
    spd
   )
   new_cars[#new_cars+1]=nc
  end
 end
 
 cars=new_cars
 
 for _,c in ipairs(cars) do
  c._update()
 end

 dog._update()
end

function _draw()
 -- yellow for transparencies
 palt(0, false)
 palt(10, true)
 
 -- draw the different elements
 camera(dog.x-dog_offset_x, 12) 
 map()
 
 -- draw top cars
 for _,c in ipairs(cars) do
  if c.speed>0 then
   c._draw()
  end
 end
 
 -- draw buildings
 for _,b in ipairs(buildings) do
   b._draw()
 end
 
 -- todo: draw dog behind cars
 -- when needed
 
 -- draw bottom cars
 for _,c in ipairs(cars) do
  if c.speed<0 then
   c._draw()
  end
 end
 
 -- draw dog
	dog._draw()
end
-->8
-- dog info --

local jump_acc=2.4
local gravity=0.35

local jump_done=true

-- this will be a singleton,
-- so this object should never
-- be overriden
local dog={
 x=nil,
 y=nil,
 z=nil,
 floor_z=nil,
 dx=nil,
 dy=nil,
 dz=nil,
 spr_aux=nil,
 sprite=nil,
 leash=nil,
}

local function spr_duration()
 if scroll_speed!=0 then
  return 5/scroll_speed
 end
 return -1
end

function dog._update()
 local btn_click=btn(❎) or btn(🅾️)
 local last_dog_x=dog.x

 -- apply gravity to jump,
 -- unless the jump button is
 -- clicked and the dog is
 -- neither too high nor
 -- slowing down the climb.
 -- this is so the user can
 -- click longer for a higher
 -- jump.
 local current_dz=dog.dz
 if dog.z<dog.floor_z then
  if not btn_click
  or dog.floor_z-dog.z>13 -- too high
  or dog.dz>=-1.5 -- too slow
  then
   dog.dz+=gravity
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
	if dog.z>dog.floor_z then
	 dog.z=dog.floor_z
	 dog.dz=0
	end
 
 -- jump if needed and on floor
 if btn_click
 and dog.z==dog.floor_z
 and jump_done
 then
  dog.dz=-jump_acc
  jump_done=false
 else
  -- jump functionality
  -- available again after jump
  -- button is released
  jump_done=jump_done or not btn_click
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
	 if abs(dog.dy)<0.001 then
	  dog.dy=0
	 end
	end
	
	-- limit vertical speed
	if dog.dy<0 then
	 dog.dy=max(-1.4,dog.dy)
	elseif dog.dy>0 then
	 dog.dy=min(1.4,dog.dy)
	end
	
	-- reduce horizontal acc
	dog.dx/=1.2
	if abs(dog.dx)<0.001 then
	 dog.dx=0
	end
	
	-- avoid collisions
	local col_pts={
  {dog.x+6,dog.y+7,0},
 }
 -- check if any of the two dog
 -- points defined above are
 -- overlapping any of the map
 -- elements, and apply the
 -- necessary corrections if so
 dog.floor_z=0
 for _,c in ipairs(cars) do
  if c.speed<0 then
	  for _,cp in ipairs(col_pts) do
	   -- col returns the necessary
	   -- corrections to apply to
	   -- the dog when the point we
	   -- are checking is actually
	   -- colliding, if any
	   local col=c._collision(
		   cp[1],cp[2],cp[3]
		  )
		  if col!=nil then
		   if col[3]!=0
		   and (dog.z!=0 or dog.dz!=0)
		   then
		    -- dog is above the car
		    -- or even on top of it,
		    -- meaning that the car
		    -- roof is now the floor
		    -- for the dog
		    dog.floor_z=col[3]

		    if dog.z>=col[3] then
		     -- make sure that the
		     -- dog isn't inside the
		     -- car but on top of it
		     -- and moving with it
		     dog.z=col[3]
		     dog.dx=c.speed
		    end
		   elseif col[1]<0
		   and last_dog_x<=c.x
		   then
		    -- frontal car crash,
		    -- dog will be pushed
		    -- back
		    dog.dx=-8
		    c.dx=3
		   else
		    -- side car crash,
		    -- dog will be moved
		    -- to avoid getting
		    -- inside the car
		    dog.y+=col[2]
		    dog.dy=0
		   end

		   -- correct the table with
		   -- the collision points
		   -- for the next iteration
		   col_pts[1]={
		    dog.x+6,dog.y+7,0
		   }
		  end
	  end
  end
 end
 
 -- dog is within bounds
	if dog.y>132 then
	 dog.y=132
	 dog.dy=0
	elseif dog.y<104 then
	 dog.y=104
	 dog.dy=0
	end
	
	-- update the dog sprite
	if current_dz==0 then
	 -- not jumping: running sprite
		-- (6 sprites)
		dog.spr_aux+=1
		local frames_per_sprite=spr_duration()
		local pushback=dog.dx<0 and abs(dog.dx)-0.05>scroll_speed
		if pushback
		or frames_per_sprite<=0
		then
		 dog.sprite=2 -- sitting down
		else
		 if dog.spr_aux>6*frames_per_sprite then
			 dog.spr_aux=frames_per_sprite
			end
			dog.sprite=dog.spr_aux/frames_per_sprite
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

function dog._draw()
 local leash_behind=dog.leash.leash[#dog.leash.leash].y+2<dog.y

 -- draw leash behind dog
 if leash_behind then
  dog.leash._draw()
 end

 -- draw dog shadow
 local shadow=5
 if dog.y<113 and dog.y>40 then
  shadow=0
 elseif dog.floor_z!=0 then
  shadow=1
 end
 ovalfill(
  dog.x+1,
  dog.y+dog.floor_z+6,
  dog.x+6,
  dog.y+dog.floor_z+8,
  shadow
 )

 -- draw dog sprite
 local dog_y=dog.y+dog.z
 spr(dog.sprite, dog.x, dog_y)
 
 -- draw leash in front of dog
 if not leash_behind then
  dog.leash._draw()
 end
end

function create_dog(x,y)
	dog.x=x
	dog.y=y
	dog.z=0
	dog.floor_z=0
	dog.dx=0
	dog.dy=0
	dog.dz=0
	dog.spr_aux=spr_duration()
	dog.sprite=1
	dog.leash=create_leash(x,y,0)

	return dog
end
-->8
-- building info --

function create_building(x,y)
	local instance={
	 x=x,
	 y=y,
	 width=7*8,
	 height=13*8,
 }

 local roof={
	 {colswap=mil},
	 {0,65,66,67,-66,-65,0},
	 {80,81,82,83,-82,-81,-80},
	 {97,82,82,83,-82,-82,-97},
	 {97,82,82,83,-82,-82,-97},
	 {97,82,98,99,-98,-82,-97},
	}

 -- make chimneys appear
	local chimney=flr(rnd(3))
	if chimney==1 then
	 local off=flr(rnd(2))
	 local off2=flr(rnd(2))
	 if(off2==0) off=1
	 roof[3+off][2+off2]=107
	 roof[4+off][2+off2]=123
	elseif chimney==2 then
	 local off=flr(rnd(2))
	 local off2=flr(rnd(2))
	 if(off2==0) off=1
	 roof[3+off][6-off2]=-107
	 roof[4+off][6-off2]=-123
	end

 -- switch brick color
 local brick_cs=mil
 if flr(rnd(2))==0 then
  if flr(rnd(2))==0 then
   brick_cs={{4,3}}
  else
   brick_cs={{4,13}}
  end
 end

	local facade={
	 {colswap=brick_cs},
	 {112,113,114,115,-114,-113,-112},
	 {68,69,70,87,-70,-69,-68},
	 {84,85,86,87,-86,-85,-84},
	 {100,101,102,103,-102,-101,-100},
	}
	
	-- replace rose windows
	local rosew=flr(rnd(2))
	if rosew==1 then
	 facade[2][4]=121
	end
	
	local ground={
	 {colswap=brick_cs},
	 {64,-78,-79,122,79,78,-64},
  {71,85,86,87,95,94,-71},
  {71,101,102,96,111,110,-71},
  {124,106,106,106,127,126,-124},
	}
	
	-- use pub as ground floor
	local pub=flr(rnd(20))==10
	if pub then
	 -- switch pub sign bg color
	 local pub_bg_cs=mil
  local pub_bg_cs_rnd=flr(rnd(3))
  if pub_bg_cs_rnd==0 then
   pub_bg_cs={{8,1}}
  elseif pub_bg_cs_rnd==1 then
   pub_bg_cs={{8,2}}
  end
  -- make sure ground is a pub
	 ground={
		 {colswap=pub_bg_cs},
		 {116,117,118,119,120,117,-116},
		 {72,73,74,75,76,77,-72},
		 {88,89,90,91,92,93,-88},
		 {104,105,106,106,106,-105,-104},
		}
	end
	
	-- use alternative windows
	local altw=flr(rnd(2))
	if altw==1 then
	 facade[4][2]=108
	 facade[4][3]=109
	 facade[4][6]=-108
	 facade[4][5]=-109
	 facade[5][3]=125
	 facade[5][5]=-125
	 if not pub then
	  ground[3][2]=108
	  ground[3][3]=109
	  ground[4][3]=125
	 end
	end
	
	-- flip ground layout
	local flipg=flr(rnd(2))
	if not pub and flipg==1 then
	 for i=2,#ground do
	  local new_gr_row={}
	  for j=#ground[i],1,-1 do
	   new_gr_row[#new_gr_row+1]=-ground[i][j]
	  end
	  ground[i]=new_gr_row
	 end
	end

 instance._draw=function()
  local offset={x=instance.x,y=instance.y}
  offset=draw_sprts(roof,offset)
  offset=draw_sprts(facade,offset)
  offset=draw_sprts(ground,offset)
  return offset
 end
 
 return instance
end
-->8
-- leash info --

local leash_length=10

-- this will be a singleton,
-- so this object should never
-- be overriden
local leash={
 leash=nil,
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
 [1]={x=12,z=-1},
 [2]={x=12,z=-1},
 [3]={x=12,z=-2},
 [4]={x=12,z=-2},
 [5]={x=12,z=-1},
 [6]={x=12,z=-1},
 [32]={x=12,z=-1},
 [33]={x=12,z=-2},
 [34]={x=12,z=-3},
 [35]={x=12,z=-3},
 [36]={x=12,z=-3},
 [37]={x=12,z=-2},
 [38]={x=12,z=-2},
 [39]={x=12,z=-2},
 [40]={x=12,z=-2},
 [41]={x=12,z=-1},
}

-- returns the position of the
-- first point of the leash
-- (the one attached to the
-- dog's neck), which changes
-- depending on the current dog
-- sprite being used.
local function leash_rel_origin()
 local p=leash_positions[1]
 if dog!=nil then
  p=leash_positions[flr(dog.sprite)]
 end
 return {x=p.x,y=p.y,z=p.z}
end

function leash._update()
	-- update leash point by point
	local o=leash_rel_origin()
	local new_leash={
  {
   x=dog.x+o.x,
   y=dog.y,
   z=dog.z+o.z,
   dy=0,
   dz=0,
  },
 }
	for i=2,#leash.leash do
	 -- lp = last point
	 --  p = current point
	 local lp=new_leash[i-1]
	 local p=leash.leash[i]
	 
	 -- update point position
	 p.y+=p.dy
	 p.z+=p.dz
	 
	 -- avoid entering the floor
	 if p.z>0 then
	  p.z=0
	  p.dz=0
	 end
	 
	 -- update x movement deltas
	 local diff_x=p.x-lp.x
	 local dist_x=abs(diff_x)
	 if dist_x>0 then
	  -- move the point to catch
	  -- up with its predecessor,
	  -- which is now too far
	  if diff_x>0 then
	   p.x-=dist_x-1
	   p.dx=-dist_x/1.5
	  else
	   p.x-=diff_x+1
	   p.dx=dist_x/1.5
	  end
	 else
	  p.dx=0
	 end
	 
	 -- update y movement deltas
	 local diff_y=p.y-lp.y
	 local dist_y=abs(diff_y)
	 if dist_y>=1 then
	  -- move the point to catch
	  -- up with its predecessor,
	  -- which is now too far
	  if diff_y>0 then
	   p.y-=dist_y-1
	   p.dy=-dist_y/1.5
	  else
	   p.y-=diff_y+1
	   p.dy=dist_y/1.5
	  end
	 else
	  p.dy=0
	 end
	 
	 -- update z movement deltas
	 local diff_z=p.z-lp.z
	 local dist_z=abs(diff_z)
	 if dist_z>1 then
	  -- move the point to catch
	  -- up with its predecessor,
	  -- which is now too far
	  if diff_z>0 then
	   p.z-=diff_z-1
	   p.dz=-dist_z/2
	  else
	   p.z-=diff_z+1
	   p.dz=dist_z/2
	  end
	 else
	  -- apply gravity
		 if p.z<0 then
		  p.dz+=gravity
		 else
		  p.dz=0
		 end
	 end
	 
	 -- ensure there aren't gaps
	 -- between this point and the
	 -- previous one this one is
	 -- attached to. these gaps
	 -- could happen because we
	 -- calculate the y and z
	 -- independently above, which
	 -- could lead to a distance
	 -- of 2 between the points.
	 local v_diff=(lp.y+lp.z)-(p.y+p.z)
	 if v_diff>1 then
	  p.y+=v_diff-1
	 elseif v_diff<-1 then
	  p.y+=v_diff+1
	 end
	 
	 new_leash[#new_leash+1]=p
	end
	
	-- finally update the leash
	dog.leash.leash=new_leash
end

function leash._draw()
 for i=1,#leash.leash do
  local p=leash.leash[i]
  if i<#leash.leash then
   -- draw leash point
	 pset(
	  p.x-8,
	  p.y+7+p.z,
	  2
	 )
	 else
	  -- draw leash handle
	  rectfill(
	  p.x-9,
	  p.y+p.z+6,
	  p.x-8,
	  p.y+p.z+7,
	  0
	 )
	 end
 end
end

function create_leash(dog_x,dog_y,dog_z)
 leash.leash={}
 
 -- initialise leash points,
 -- starting with the one
 -- attached to the dog's neck
 local o=leash_rel_origin()
 leash.leash[1]={
  x=dog_x+o.x,
  y=dog_y,
  z=dog_z+o.z,
  dy=0,
  dz=0,
 }
 for i=2,leash_length do
  local lp=leash.leash[#leash.leash]
  leash.leash[i]={
   x=lp.x-1,
   y=lp.y,
   z=min(0,lp.z+1),
   dy=0,
   dz=0,
  }
 end

 return leash
end
-->8
-- collisions helper --

-- returns a table with the
-- {x,y,z} diffs needed to
-- correct the position of the
-- point defined by x,y,z in
-- order to stop its collision
-- with the 3d prism defined by
-- the other parameters, or nil
-- if there is no collision.
function collision(
 x,y,z,
 obs_x,obs_x2,
 obs_y,obs_y2,
 obs_z,obs_z2
)
 local fix={}

 -- correct the x, pushing the
 -- point left or right
 -- (whichever way the x move
 -- is shorter).
 x=flr(x)
 if x>=obs_x and x<=obs_x2 then
  if abs(x-obs_x)<abs(x-obs_x2) then
   -- push left
   fix[1]=obs_x-x-1
  else
   -- push right
   fix[1]=obs_x2-x+1
  end
 else
  -- no collision found
  return nil
 end

 -- correct the y, pushing the
 -- point up or down (whichever
 -- way the y move is shorter).
 y=flr(y)
 if y>=obs_y and y<=obs_y2 then
  if abs(y-obs_y)<abs(y-obs_y2) then
   -- push up
   fix[2]=obs_y-y-1
  else
   -- push down
   fix[2]=obs_y2-y+1
  end
 else
  -- no collision found
  return nil
 end

 -- correct the z, pushing the
 -- point upwards in the air
 -- when needed.
 z=flr(z)
 if z<=obs_z and z>=obs_z2 then
  fix[3]=obs_z2-z-1
 else
  -- no collision found
  return nil
 end
 
 -- choose the x correction if
 -- it has the shortest path
 --if abs(fix[1])<abs(fix[2])
 --and abs(fix[1])<abs(fix[3])
 --then
 -- fix[2],fix[3]=0,0
 --end

 -- choose the y correction if
 -- it has the shortest path
 --if abs(fix[2])<abs(fix[1])
 --and abs(fix[2])<abs(fix[3])
 --then
 -- fix[1],fix[3]=0,0
 --end
 
 -- choose the z correction if
 -- it has the shortest path
 --if abs(fix[3])<abs(fix[1])
 --and abs(fix[3])<abs(fix[2])
 --then
 -- fix[1],fix[2]=0,0
 --end

 return fix
end
-->8
-- car info --

-- todo: moving wheels

local function update(inst)
 inst.dx/=1.3
 if inst.dx<0.001 then
	 inst.dx=0
	end
 inst.x+=inst.speed+inst.dx
end

function create_car(x,y,speed)
	local instance={
	 x=x,
	 y=y,
	 y_rnd=flr(rnd(6))-2.5,
	 z=0,
	 speed=speed,
	 dx=0,
	 width=4*8,
	 height=2*8,
 }
 
 local cs=nil
 local cs_rnd=flr(rnd(7))
 if cs_rnd==0 then
  cs={{11,8},{3,2}}
 elseif cs_rnd==1 then
  cs={{11,12},{3,13}}
 elseif cs_rnd==2 then
  cs={{11,13},{3,5}}
 elseif cs_rnd==3 then
  cs={{11,14},{3,2}}
 elseif cs_rnd==4 then
  cs={{11,4},{3,5}}
 elseif cs_rnd==5 then
  cs={{11,7},{3,6}}
 end
	local car={
	 {colswap=cs},
	 {11,12,13,14},
	 {27,28,29,30},
	}
 
 instance._update=function()
  update(instance)
 end

 instance._draw=function()
  local offset={x=instance.x,y=instance.y+instance.y_rnd}
  offset=draw_sprts(car,offset)
  return offset
 end

 instance._collision=function(x,y,z)
  local col=collision(
   x,y,z,
   instance.x,
   instance.x+11,
   instance.y+instance.y_rnd+5,
   instance.y+instance.y_rnd+instance.height-1,
   0,
   -3
  )
  if col==nil then
   col=collision(
	   x,y,z,
	   instance.x+12,
	   instance.x+24,
	   instance.y+instance.y_rnd+5,
	   instance.y+instance.y_rnd+instance.height-1,
	   0,
	   -6
	  )
  end
  if col==nil then
   col=collision(
	   x,y,z,
	   instance.x+25,
	   instance.x+instance.width,
	   instance.y+instance.y_rnd+5,
	   instance.y+instance.y_rnd+instance.height-1,
	   0,
	   -3
	  )
  end
  
  return col
 end
 
 return instance
end
-->8
-- drawing helper --

function draw_sprts(sprts,offset)
 local colswap=sprts[1].colswap
 if colswap~=nil then
  for _,col in ipairs(colswap) do
   pal(col[1],col[2])
  end
 end
 local col,row=0,0
 while row<#sprts-1 do
  while col<#sprts[row+2] do
   local sprite=sprts[row+2][col+1]
   if sprite!=0 then
    local flip_h=sprite<0
    spr(
     abs(sprite),
     col*8+offset.x,
     row*8+offset.y,
     1,1,
     flip_h
    )
   end
   col+=1
  end
  row+=1
  col=0
 end
 if colswap~=nil then
  for _,col in ipairs(colswap) do
   pal(col[1],col[1])
  end
 end
 
 return {
  x=col*8+offset.x,
  y=row*8+offset.y,
 }
end
__gfx__
00000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9aaaa267daaaa267daaaddaaddaaaaaaaaaaaaabbbbbbbbbbbaaaaaaaaa00000000
00000000aaaaaaaaaaaaaaaaaaaaa0aaaaaaa0aaaaaaaaaaaaaaaaaaaaaa979aaa267daaaa267daa267dd76daaaaaaaaaaa3bbbbbbbbbbb3aaaaaaaa00000000
007007004aaaa0aaaaaaa0aaaaaaa44aaaaaa44aaaaaa0aa4aaaa0aaaaaa9774aa267daaaa267daa2677777daaaaaaaaa333bbbbbbbbbbb33aaaaaaa00000000
000770004aaaa44a4aaaa44a4aaa80404aaa80404aaaa44a4aaaa44aaaa9700aaa267daaaa267daaa26777daaabbbbb331d3bbbbbbbbbbb31333bbaa00000000
00077000a44480404a4480404a4480444a4480444a448040a4448040a9970aaaa26777daaa267daaaa267daaabbbbb3111d3bbbbbbbbbbb3103b3b1a00000000
00700700a4448044a4448044a444484aa44448aaa4448044a44480444770aaaa2677777daa267daaaa267daa6bbbbb3111d3bbbbbbbbbbb31133bb3000000000
00000000aa4448aaa44448aaa444aaaa444444aaa44448aaa44448aaa060aaaa267dd76daa267daaaa267daa3bbbbb3111d3bbbbbbbbbbb3103b3b1000000000
00000000aa44aaaaaa4a4aaaa4aaaaaaaaaaaa4a4aaaa4aaaaaa4aaaaa0aaaaaaddaaddaaa267daaaa267daa3bbbbb3111d33333333333331133bb3000000000
666666665655555556555555666666666666666666666666aaaaaaaaaaaaaaaaaaaaaaaa00000000000000003bbbbb311331111113111111303b3b1000000000
666666665555565555555655666666666666666666666666aaaaaaaaaaaaaaaaaaaaaaaa00000000000000003bbbbbb331111111131111111333bb3000000000
666666665555555555555555666666666666666666666666a5555555555555555555555a00000000000000003b3333333333333333333333333338e000000000
6666666655555555555555555555555566666666666666665aaa5aaa5aaa5aaa5aaa5aa500000000000000006333333333333333333333333333388500000000
66666666556555555565555555655555666666666666666655a5a5a5a5a5a5a5a5a5a5a500000000000000007633333311133333333333111333331500000000
6666666655555565555555555555556566666666666666665a5aaa5aaa5aaa5aaa5aaa5500000000000000005133333155513333333331555133331a00000000
66666666555555555050505055555555677777777766666655a5a5a5a5a5a5a5a5a5a5a50000000000000000a511111055501111111110555011115a00000000
6666666655555555050505055555555567777777776666665aaa5aaa5aaa5aaa5aaa5aa50000000000000000aa5555550005555555555500055555aa00000000
aaaaaaaaaaaaaaaaaaaaa0aaaaaaa0aaaaaaa0aaaaaaaaaa4aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa04aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa04aaa
aaaaaaaaaaaaa0aaaaaaa44aaaaaa44a4aaaa44a4aaaa0aa4aaaa0aa4aaaa0aaaaaaa0aaaaaaaaaaaaa44aaaaaa04aaaaaa04aaaaaa04aaaaaa04aaaaaa44aaa
aaaaa0aaaaaaa44aaaaa80404aaa80404aaa80404aaaa44aa4aaa44a4aaaa44a4aaaa44a4aaaa0aaaa222aaaaaa44aaaaaa44aaaaaa44aaaaaa44aaaaaa22aaa
4aaaa44a4aaa80404aa480444a448044a4448044a4aa8040444a8040a44a80404aaa80404aaaa44aa2a2224aaaa22aaaaaa22aaaaaa22aaaaaa22aaaaa2224aa
4a4480404a4480444a4448aaa44448aa444448aa444480444444804444448044a4448044a4448040a4accaaaaa222aaaaaa22aaaaaa22aaaaa222aaaaa4cccaa
a4448044a44448aaa44444aa444444aa444444aa444448aa444448aa444448aaa44448aaa4448044aaacacaaaa4cc4aaaaa4caaaaaac4aaaaa4c24aaaaaca0aa
a44448aa444444aa444aaaaa44aaaaaa44aaa4aa444444aaa4a444aa44a444aaa4a44aaaa4a448aaaa0aaa0aaaaccaaaaaa0caaaaaac0aaaaaaca0aaaaa0aaaa
aaa44aaa44aaaaaa44aaaaaaaaaaaaaaaaaaaaaaaaaaa4aaaaaaa4aaa4aa4aaaa4aa4aaaaa4a4aaaaaaaaaaaaa0aa0aaaaaa0aaaaaa0aaaaaaa0aaaaaaaaaaaa
555533333333333333335555555553333333333333355555aaaaaaaa505050505655555550505050aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaacccccccc00000000
565533333b333b3333335555555555555555555555555555aaadddaa050505055555565505050505aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaacccccccc00000000
5555333333331b3333335565565555555555556555555555aadd6dda5050505055555555505050504aaa656aaaaa656aaaaa656aaaaa656acccccccc00000000
555533b33333333333b35555555555555555555555555565a5ddddda0505050555555555050505054aa66ff64aa66ff64aa66ff64aa66ff6cccccccc00000000
555531b33333333331b35555555565555565555555555555a55d5d5a505050505050505050505050a44fe5f54a4fe5f54a4fe5f54a4fe5f5cccccccc00000000
5565333333b3333333335555555555555555555565555555a155555a050505050505050505050505a44fe5ffa44fe5ffa44fe5ffa44fe5ffcccccccc00000000
5555533331b333b333355655555555555555555555555555aa1111aa505050505050505055555555a444fe6aa4444e6aa444444aa4444e6acccccccc00000000
555555333333333333555555555555555555555555555555aaaaaaaa050505050505050555555555a4aa4aaaa4aaa4aaa4aaaaaa4aaaa4aacccccccc00000000
aaa06666aaaaaaaaaaaaaaaaaaa11aaaaa5666655454454444444444aaa06665aaa0000000000000000000000000000000000000000000004545454545454545
aaa06555aaaaaaaaaaaaaaaaa111d11aaa5666654545444444444444aaa06565aaa0655560f01050501010101040101010101010101010064444445544444444
aaa06665aaaaaaaaaaaaaaa11dd11dd1aaa566655444444444444444aaa06665aaa06666600f0105010101010202010101010101010102064444444544444444
aaa06565aaaaaaaaaaaaa11dd11d111daaa565554544444444444444aaa06565aaa06555601011555111111122226111611111117111f0064444445444444444
aaa06665aaaaaaaaaaa11dd11dd11dd1aaa566654444444444444444aaa06665aaa06666600411555555555f4556665666555eee9ef502064444444444444444
aaa06565aaaaaaaaa11dd11dd111d11daaa566655444444444444444aaa06565aaa06555601011555555555ff556665666555eeeee2220064444444544444444
aaa06665aaaaaaa11dd11dd11dd11dd1aaa565554544446666666664aaa06665aaa06666600111ddddddddddddddddddddddddddddd202066644445446666666
aaa06565aaaaa11dd11dd11dd11d111daaa566654444465555555556aaa06565aaa06555601011ddddddddd4dddddddddddddddddddcc0065564444465555555
aaaaaaaaaaa11dd11dd11dd11dd11dd1aaa56665544446000060000644444444aaa06666600111fddddddd343ddddddddddddd7ddddc0c060064444560000000
aaaaaaaaa11dd11dd11dd11dd111d11daaa565554544460dd060dd0644444444aaa06555601017f6111111333311111111747474411c10060064445460000000
aaaaaaa11dd11dd11dd11dd11dd11dd1aaa06665444446011060110644444444aaa06666600177764744443343111111147474444410000600644444600d0d0d
aaaaa11dd11dd11dd11dd11dd11d111daaa06665544446000060000644444444aaa0655560107f6649447444c411111114444444441110060064444560010101
aaa11dd11dd11dd11dd11dd11dd11dd1aaa06555454446666666666644444444aaa066666001fdd444449444c111111111144444111101060064445460000000
aa1dd11dd11dd11dd11dd11dd111d11daaa06665444446000060000644444444aaa06555601010101040400000101010101010101010100600644444600d0d0d
aa111dd11dd11dd11dd11dd11dd11dd1aaa066655444460dd060dd0644444444aaa0666660010202010001010101010101010001010101060064444560010101
aa1dd11dd11dd11dd11dd11dd11d111daaa06555454446011060110644444444aaa0655560000000000000000000000000000000000000060064445460000000
44444444aa111dd11dd11dd11dd11dd1aaa06665444446000060000644444444aaa0666667777777777777771dd00dd1544446000000000600644444600d0d0d
44444444aa1dd11dd11dd11dd111d11daaa06665544446666666666644444444aaa065556666666666666666d100601d4544460ddddddd060064444560010101
54444445aa111dd11dd11dd11dd11dd1aaa06555454455555555555554444445aa06666666666666666666665500005544444601111111060065445460000000
44444444aa1dd11dd11dd11dd110011daaa06665444444444444444444444444aa06555556666666666666665555555554444601111111060064444460050505
44444445aa111dd11dd11dd110566501aaa06665544444444444444444444444aa55555555555555555555555244444245444600000000060065444560005050
44444454aa1dd11dd11dd11056666665aaa06555554444444444444444444444aaaaaaaaaaaaaaaaaaaaaaaa2444442544444666666666660064545460050505
54545545aa111dd11dd1105666655666aaa06666545454545454545454555545aaaaaaaaaaaaaaaaaaaaaaaa5244444254444600000000060065454560000000
45454555aa1dd11dd110566665555556aaa06666554545454545454545566554aaaaaaaaaaaaaaaaaaaaaaaa2444442545444600000000060065545560000000
aa111dd11dd11dd11056666554544545aaa0666655555555555555555555555555555555545445455455554552444442aaa06667000000060367777763030303
aa1dd11dd11dd1105666655454455445aaa6666666666666666666666666666666666666544554454444444424444425aaa06566666666663d6666666d3d3d3d
aa111dd11dd110566665545445466454aaa5555555555555555555555555555555555555454444544444444452444442aa066666555555559366666663939393
aa1dd11dd11056666554544544600644aaa8888888888888888888888888888888888888444444444444444424444425aa065556444444443f6666666f3f3f3f
aa111dd11056666554544544460dd064aaa88f8f8f8f8f8f8f8f8f8777878787778f8f8f444444444444444452444220aa555555444444445555555555555555
aa1dd110566665545445444446011064aaa8f8f8f8f8f8f8f8f8f887778787877788f8f844444444444444442242200daaaaaaaa44444444aaaaaaaaaaaaaaaa
aa111056666554544544444444600644aaa88f8f8f8f8f8f8f8f8f8788877787778f8f8f444444444444444452200dd1aaaaaaaa54545454aaaaaaaaaaaaaaaa
aa155666655454454444444444466444aaa88888888888888888888888888888888888884444444444444444000dd11daaaaaaaa45454545aaaaaaaaaaaaaaaa
__gff__
0000000000000000010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313
3838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838
3737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737
3737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737
3737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737
3737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737
3939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939
1212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
