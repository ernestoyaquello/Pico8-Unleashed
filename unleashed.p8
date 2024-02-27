pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
function _init()
 state="play"
 scroll_speed_deft=1
 scroll_speed=scroll_speed_deft
 gravity=0.35
 jump_acc=2.4
 human_offset_x=6
 human=create_human(human_offset_x,114)
 dog_offset_x=48
 dog=create_dog(dog_offset_x,114)
 cam_shake=0
 cam_offset_x=0
 cam_offset_y=0
 buildings={}
 bones={}
 cars={}
 stopped_car_lane=nil
 bones_count=0
 meters_aux=0
 real_meters=0
 meters=0
 game_over_msg=nil
 clip_circle_radius=nil
 clip_circle_x=0
 clip_circle_y=0
 restart=false
end

function _update60()
 -- restart the game if needed
 if state=="game over"
 and game_over_msg!=nil
 and game_over_msg.finished
 and (btn(❎) or btn(🅾️))
 then
  -- schedule a restart for
  -- when the button is
  -- released, that way the
  -- game doesn't start with
  -- the dog immediately
  -- jumping
  restart=true
 end
 if restart
 and not btn(❎)
 and not btn(🅾️)
 then
  _init()
  return
 end

 local start_x=human.x-human_offset_x
 local end_x=human.x-human_offset_x+127
 
 -- if we have reached the end
 -- of the map, let's move
 -- everything to its start to
 -- make the horizontal
 -- scrolling infinite
 local offset=nil
 local map_end_x=(128*8)-1
 if end_x>=map_end_x then
  offset=-flr(map_end_x)+127
 elseif start_x<=0 then
  offset=-flr(start_x+0.5)+127
 end
 if offset!=nil then
  -- shift dog and human
  dog.x+=offset
  for _,p in ipairs(dog.leash.leash) do
   p.x+=offset
  end
  human.x+=offset
  
  -- shift buildings
  for _,b in ipairs(buildings) do
   b.x+=offset
  end
  
  -- shift cars
  for _,c in ipairs(cars) do
   c.x+=offset
  end
  
  -- shift bones
  for _,b in ipairs(bones) do
   b.x+=offset
  end
  
  -- shift aux variables
  start_x=human.x-human_offset_x
  end_x=human.x-human_offset_x+127
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
  -- using a 64 pixels margin
  -- in case the camera needs
  -- to go back, that way, the
  -- building will still be
  -- there
  if b_end_x+64>=start_x then
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
 
 -- todo: update buildings?
 
 -- create new bone list
 local new_bones={}
 
 -- add existing bones, but
 -- only if they are still
 -- within view
 for _,b in ipairs(bones) do
  if b.x+7>=start_x then
   new_bones[#new_bones+1]=b
  end
 end
 
 -- add bones at random on the
 -- sidewalk
 if state=="play"
 and flr(rnd(200/scroll_speed))==1
 and #new_bones==0
 then
  local bx=end_x+1
  local elev=flr(rnd(2))==0
  for _=1,1+flr(rnd(3)) do
   local nb=create_bone(bx,117,-3)
   if elev then
    nb.z=-15
   end
   new_bones[#new_bones+1]=nb
   bx+=12
  end
 end
 
 -- replace the bones table with
 -- the new bones
 bones=new_bones
 
 -- update bones
 for _,b in ipairs(bones) do
  b._update()
 end
 
 -- create new car list
 local new_cars={}
 local new_car_ys={
  [18]=1.2,
  [40]=1.3,
  [116]=-1.0,
  [131]=-0.9,
 }
 
 -- add existing cars, but
 -- only if they are still
 -- within view
 for i=1,#cars do
  local c=cars[i]
  local c_end_x=c.x+c.width-1
  if c.x<=end_x+1 and c_end_x>=start_x-1 then
   new_cars[#new_cars+1]=c
   -- make the lane unavailable
   -- for new cars in case
   -- this one is too close to
   -- where those new cars
   -- would spawn
   if (
    (c.speed<0 
     or c.speed<scroll_speed)
    and c_end_x+c.width+18>=end_x
   )
   or (c.speed>scroll_speed
    and c.x-c.width-18<=start_x)
   then
    new_car_ys[c.y]=nil
   end
  end
 end
 
 -- add new cars at random
 for cy,spd in pairs(new_car_ys) do
  -- avoid adding cars when
  -- their speed matches the
  -- scrolling, as they woulld
  -- not move
  local factor=abs(spd-scroll_speed)
  if factor!=0
  and flr(rnd(60/factor))==0
  then
   local nc_x=end_x+1
   if spd>scroll_speed then
    nc_x=start_x-32
   end
   local nc=create_car(nc_x,cy,spd)
   new_cars[#new_cars+1]=nc
  end
 end
 
 -- replace the cars table with
 -- the new cars, ensuring they
 -- are added to the table so
 -- that they can be rendered
 -- in the right order
 cars={}
 for _,cy in ipairs({18,40,116,131}) do
  local aux_new_cars={}
  for _,c in ipairs(new_cars) do
   if c.y==cy then
    cars[#cars+1]=c
   else
    aux_new_cars[#aux_new_cars+1]=c
   end
  end
  new_cars=aux_new_cars
 end
 
 -- update cars
 for _,c in ipairs(cars) do
  c._update()
 end

 human._update()
 
 local last_dog_x=dog.x
 dog._update()
 
 -- update meters counter
 meters_aux+=dog.x-last_dog_x
 local meter_size=15
 if abs(meters_aux)>=meter_size then
  real_meters+=flr(meters_aux/meter_size)
  meters=max(meters,real_meters)
  meters_aux=meters_aux%meter_size
 end
 
 -- increase scroll speed with
 -- each 100 meters
 scroll_speed=scroll_speed_deft
  +min(1,flr(meters/100)/20)
  
 -- shake the camera if needed
 -- to dramatize car crashes
 if cam_shake!=0 then
  cam_offset_x=4-rnd(8)
  cam_offset_y=4-rnd(8)
  cam_offset_x*=cam_shake
  cam_offset_y*=cam_shake
  
  cam_shake/=1.6
  if cam_shake<0.05 then
   cam_shake=0
   cam_offset_x=0
   cam_offset_y=0
  end
 end
 
 -- once the game is over, show
 -- a clipping circle that
 -- closes on the dog
 if state=="game over"
 then
  -- make the radius smaller
  -- over time, or suddenly if
  -- the user is pressing a
  -- button to skip animations
  if clip_circle_radius==nil then
   clip_circle_radius=350
  elseif clip_circle_radius>1 then
   clip_circle_radius-=max(1,(0.02*clip_circle_radius))
   if clip_circle_radius<1
   or (btn(❎) or btn(🅾️))
   then
    clip_circle_radius=0
    -- the dog and human are no
    -- longer visible, bring
    -- the game over message
    if game_over_msg==nil then
     game_over_msg=create_game_over_msg()
    end
   end
  end
  local half_radius=flr(clip_circle_radius/2)
  clip_circle_x=flr(dog.x)-half_radius
  clip_circle_y=flr(dog.y)-half_radius
 end
 
 if game_over_msg!=nil then
  game_over_msg._update()
 end
end

function _draw()
 local cam_x=human.x-human_offset_x+cam_offset_x
 local cam_y=20+cam_offset_y

 -- yellow for transparencies
 palt(0, false)
 palt(10, true)
 
 -- clip screen to the area
 -- that the clipping circle
 -- will cover if needed
 if clip_circle_radius!=nil then
  cls(0)
  if clip_circle_radius>0 then
   clip(
    clip_circle_x-flr(cam_x),
    clip_circle_y-flr(cam_y),
    clip_circle_radius,
    clip_circle_radius
   )
  else
   clip(0,0,0,0)
  end
 end

 -- draw the different elements
 camera(cam_x,cam_y)
 map()
 
 -- draw top cars
 local bottom_cars={}
 for _,c in ipairs(cars) do
  if c.speed>0 then
   c._draw()
  else
   bottom_cars[#bottom_cars+1]=c
  end
 end
 
 -- draw buildings
 for _,b in ipairs(buildings) do
  b._draw()
 end
 
 -- draw sidewalk bones behind
 -- dog
 local foregr_bones={}
 for _,b in ipairs(bones) do
  if dog.y+6>b.y+2 then
   b._draw()
  else
   foregr_bones[#foregr_bones+1]=b
  end
 end
 
 -- draw bottom cars behind dog
 local foregr_cars={}
 for _,c in ipairs(bottom_cars) do
  if dog.y+7>c.y+7
  then
   c._draw()
  else
   foregr_cars[#foregr_cars+1]=c
  end
 end
 
 -- draw dog and human
 dog._draw()
 human._draw()
 
 -- draw bottom bones that are
 -- on the foreground (i.e.,
 -- in front of the dog)
 for _,b in ipairs(foregr_bones) do
  b._draw()
 end
 
 -- draw bottom cars that are
 -- on the foreground
 for _,c in ipairs(foregr_cars) do
  c._draw()
 end
 
 -- draw the clipping circle
 -- if needed
 if clip_circle_radius!=nil then
  sspr(
   0,
   96,
   32,
   32,
   clip_circle_x,
   clip_circle_y,
   clip_circle_radius,
   clip_circle_radius
  )
  clip()
 end
 
 -- draw game over message
 if game_over_msg!=nil then
  game_over_msg._draw()
 end

 -- draw scores
 local m_str=tostr(meters)
 local bc_str=tostr(bones_count) 

 -- 1. draw meters
 if #m_str==1 then
  m_str="  "..m_str
 elseif #m_str==2 then
  m_str=" "..m_str
 end
 local m_end_x=cam_x+7+4*#m_str
 rect(
  cam_x+4,cam_y+3,
  m_end_x+1,cam_y+11,
  0
 )
 rectfill(
  cam_x+3,cam_y+2,
  m_end_x,cam_y+10,
  2
 )
 print(
  m_str,
  cam_x+6,
  cam_y+4,
  7
 )
 
 -- 2. draw bones count
 local bones_c_offset_x=0
 local bones_c_offset_y=0
 rect(
  m_end_x+4,
  cam_y+3,
  m_end_x+16+4*#bc_str,
  cam_y+11,
  0
 )
 rectfill(
  m_end_x+3,
  cam_y+2,
  m_end_x+15+4*#bc_str,
  cam_y+10,
  2
 )
 spr(
  29,
  m_end_x+5,
  cam_y+2
 )
 print(
  bc_str,
  m_end_x+14,
  cam_y+4,
  15
 )
end
-->8
-- dog info --

local jump_done=nil
local can_move_up=nil
local can_move_down=nil

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
 shadow_col=5,
}

local function spr_duration()
 if scroll_speed!=0 then
  if dog.dx>0 then
   return 5/(scroll_speed+dog.dx)
  else
   return 5/scroll_speed+dog.dx
  end
 end
 return -1
end

function dog._update()
 local last_dog_x=dog.x
 local last_dog_dx=dog.dx
 local last_dog_y=dog.y

 local btn_click=btn(❎) or btn(🅾️)

 -- jump functionality
 -- available again after jump
 -- button is released
 jump_done=jump_done
  or not btn_click

 -- jump if needed and able
 if btn_click
 and state=="play"
 and abs(dog.z-dog.floor_z)<1
 and abs(dog.dz)<0.1
 and dog.dx>=0
 and dog.dy==0
 and jump_done
 then
  dog.dz=-jump_acc
  jump_done=false
 end

 -- re-enable vertical move
 -- once the button is released
 can_move_up=can_move_up
  or not btn(⬆️)
 can_move_down=can_move_down
  or not btn(⬇️)

 -- move up and down if able
 if state=="play"
 and dog.dy==0
 and dog.z==dog.floor_z
 and dog.dz==0
 and dog.dx>=0
 then
  if btn(⬆️)
  and can_move_up
  and dog.y>107
  then
   dog.dy-=0.1
   can_move_up=false
  elseif btn(⬇️)
  and can_move_down
  and dog.y<134
  then
   dog.dy+=0.1
   can_move_down=false
  end
 end

 -- ensure dog reaches one of
 -- the valid lanes
 local function dy_speed(a,b)
  -- try to smooth out the
  -- vertical movement between
  -- point a and b by making
  -- the dog go faster in the
  -- middle and slower on the
  -- sides
  local diff=abs(a-b)/2
  local offst=min(a,b)+diff
  local div=diff*diff
  local spd=1-((dog.y-offst)^2)/div
  return 2.4*(0.25+spd)
 end
 if dog.dy<0 then
  if dog.y>119 then
   -- up from 134 to 119
   dog.dy=-dy_speed(134,119)
  elseif dog.y>107 then
   -- up from 119 to 107
   dog.dy=-dy_speed(119,107)
  end
 elseif dog.dy>0 then
  if dog.y<119 then
   -- down from 107 to 119
   dog.dy=dy_speed(107,119)
  elseif dog.y<134 then
   -- down from 119 to 134
   dog.dy=dy_speed(119,134)
  end
 end
 
 -- apply velocity deltas
 if state=="play" then
  dog.x+=scroll_speed
 end
 dog.x+=dog.dx
 dog.y+=dog.dy
 dog.z+=dog.dz
 
 -- apply gravity,unless the
 -- jump button is clicked and
 -- the dog is neither too high
 -- nor slowing down the climb.
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
 
 -- dog doesn't enter the floor
 if dog.z>=dog.floor_z then
  dog.z=dog.floor_z
  dog.dz=0
 end
 
 -- stabilise horizontal speed
 -- to ensure the dog
 -- eventually stops moving
 -- backwards
 if dog.dx<0 then
  dog.dx+=0.16*scroll_speed
  if dog.dx>=0 then
   dog.dx=0
   -- make the decimals of the
   -- dog's x and the human's x
   -- match to avoid flickering
   dog.x=flr(dog.x)
    +(human.x-flr(human.x))
  end
 end
 
 -- ensure the dog reaches one
 -- of the official lanes and
 -- stops moving vertically
 if dog.dy>0 then
  for _,lane_y in ipairs({119,134}) do
   if last_dog_y<lane_y
   and dog.y>=lane_y
   then
    dog.dy=0
    dog.y=lane_y
   end
  end
 elseif dog.dy<0 then
  for _,lane_y in ipairs({119,107}) do
   if last_dog_y>lane_y
   and dog.y<=lane_y
   then
    dog.dy=0
    dog.y=lane_y
   end
  end
 end
 
 -- detect collisions with cars
 dog.floor_z=0
 local cp={dog.x+6,dog.y+7,0}
 for _,c in ipairs(cars) do
  if c.speed<0 then
   -- col returns the necessary
   -- corrections to apply to
   -- the dog when the point we
   -- are checking is actually
   -- colliding
   local col=c._collision(
    cp[1],cp[2],cp[3]
   )
   if col!=nil then
    if col[3]!=0
    and dog.z<-1
    then
     -- dog is above the car
     -- or even on top of it,
     -- meaning that the car
     -- roof is now the floor
     -- for the dog
     dog.floor_z=col[3]

     -- ensure the dog is on
     -- top and not inside
     -- the car
     if dog.z>=col[3] then
      dog.z=col[3]
     end
    elseif col[1]<0
    and last_dog_x<=c.x
    then
     -- frontal car crash,
     -- dog will be pushed
     -- back
     dog.dx=min(
      -2,
      1.8*(c.speed-scroll_speed)
     )
     -- slow down the car too
     -- because of the crash
     c.dx=2.5*scroll_speed
     -- shake cam to add drama
     -- to the crash
     cam_shake=1
    elseif col[2]!=0 then
     -- side car crash,
     -- dog will be moved
     -- away from the car
     dog.y+=col[2]
     if col[2]>0 then
      dog.dy=0.1
     else
      dog.dy=-0.1
     end
     -- shake cam to add drama
     -- to the crash
     cam_shake=1
    end
    -- collision found, end
    -- the loop
    break
   end
  end
 end

 -- detect collisions with
 -- bones that aren't taken
 if state=="play" then
  local nt_bones={}
  for _,b in ipairs(bones) do
   if not b.taken then
    nt_bones[#nt_bones+1]=b
   end
  end
  for _,c in ipairs(cars) do
   if c.bone!=nil
   and not c.bone.taken
   then
    nt_bones[#nt_bones+1]=c.bone
   end
  end
  local cp={
   dog.x+6,
   dog.y+7,
   dog.z-2,
  }
  for _,b in ipairs(nt_bones) do
   local col=b._collision(
    cp[1],cp[2],cp[3]
   )
   if col!=nil then
    b.taken=true
    bones_count+=1
    break
   end
  end
 end
 
 -- check if it is game over
 if state=="play"
 and (dog.x<=human.x
  or dog.x-human.x<=8)
 then
  state="game over"
 end
 
 -- update the dog sprite
 if state=="play" then
  if current_dz==0 then
   -- not jumping: running sprite
   -- (6 sprites)
   dog.spr_aux+=1
   local frames_per_sprite=spr_duration()
   local pushback=last_dog_dx<0
   if pushback
   or frames_per_sprite<=0
   then
    dog.sprite=2 -- sitting down
    dog.spr_aux=spr_duration()*3
   else
    if dog.spr_aux>6*frames_per_sprite then
     dog.spr_aux=frames_per_sprite
    end
    dog.sprite=min(
     6,
     flr(dog.spr_aux/frames_per_sprite+0.5)
    )
   end
  else
   -- jumping: take the right
   -- sprite depending on the
   -- progress of the jump
   -- (10 sprites)
   dog.sprite=32+9*((current_dz+jump_acc)/(2*jump_acc))
   dog.sprite=max(32,min(41,dog.sprite))
  end
 elseif state=="game over" then
  -- sitting down for game over
  dog.sprite=11
 end
 
 -- update leash (needs updated
 -- after the dog sprite
 -- because it will be
 -- positioned according to it)
 dog.leash._update()
 
 -- update shadow color
 dog.shad_col=5
 if dog.y<113 and dog.y>40 then
  dog.shad_col=0
 elseif dog.floor_z!=0 then
  dog.shad_col=1
 end
end

function dog._draw()
 local leash_behind=state=="play"
  and dog.leash.leash[#dog.leash.leash].y+2<dog.y

 -- draw leash behind dog
 if leash_behind then
  dog.leash._draw()
 end

 -- draw dog shadow
 ovalfill(
  dog.x+1,
  dog.y+dog.floor_z+6,
  dog.x+6,
  dog.y+dog.floor_z+8,
  dog.shad_col
 )

 -- draw dog sprite
 local dog_y=dog.y+dog.z
 spr(
  dog.sprite,
  dog.x,
  dog_y
 )
 
 -- draw leash in front of dog
 if not leash_behind then
  dog.leash._draw()
 end
end

function create_dog(x,bottom_y)
 dog.x=x
 dog.y=bottom_y-7
 dog.z=0
 dog.floor_z=0
 dog.dx=0
 dog.dy=0
 dog.dz=0
 dog.spr_aux=spr_duration()
 dog.sprite=1
 dog.leash=create_leash(
  dog.x,
  dog.y,
  0
 )
 
 jump_done=true
 can_move_up=true
 can_move_down=true

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
  local offset={
   x=instance.x,
   y=instance.y,
   z=0,
  }
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
 if state=="play" then
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
end

function leash._draw()
 -- draw the leash normally
 -- while playing
 if state=="play" then
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

 -- draw the human holding the
 -- leash if the dog is caught
 elseif state=="game over" then
  -- draw leash handle
  rectfill(
   human.x+6,
   human.y+human.z+11,
   human.x+7,
   human.y+human.z+12,
   0
  )
  -- draw leash
  line(
   human.x+8,human.y+human.z+13,
   dog.x+4,dog.y+6,
   2
  )
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
-- car info --

-- todo: moving wheels

local function update(inst)
 -- reduce horizontal acc
 inst.dx/=1.3
 if abs(inst.dx)<0.001 then
  inst.dx=0
 end
 
 -- apply scroll speed to car,
 -- but only if the game is
 -- playing (or if the lane
 -- isn't occupied by the dog
 -- while the game is over)
 if stopped_car_lane!=inst.y
 and (state=="play"
  or inst.speed>0
  or inst.x<human.x
  or inst.x-24>dog.x
  or (inst.y==116 and dog.y!=119)
  or (inst.y==131 and dog.y!=134))
 then
  inst.x+=inst.speed
 else
  stopped_car_lane=inst.y
 end
 inst.x+=inst.dx
 
 -- update bone if needed
 if inst.bone!=nil then
  if not inst.bone.taken then
   inst.bone.x=inst.x+13
  end
  inst.bone._update()
 end
end

function create_car(x,y,speed)
 -- randomly place a bone on
 -- top of the car
 local bone=nil
 if speed<0
 and flr(rnd(4))<3
 then
  bone=create_bone(
   x+13,
   y+13,
   -13
  )
  bone.floor_z=-7
 end

 local instance={
  x=x,
  y=y,
  z=0,
  speed=speed,
  dx=0,
  width=4*8,
  height=2*8,
  bone=bone,
 }
 
 -- change the car colors to
 -- make each car look somewhat
 -- unique
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
  {7,8,9,10},
  {23,24,25,26},
 }
 if speed>0 then
  car[2]={-10,-9,-8,-7}
  car[3]={-26,-25,-24,-23}
 end
 
 instance._update=function()
  update(instance)
 end

 instance._draw=function()
  -- draw car
  local offset={
   x=instance.x,
   y=instance.y,
   z=0,
  }
  draw_sprts(car,offset)
  
  -- draw bone if needed
  if instance.bone!=nil then
   instance.bone._draw()
  end
 end

 instance._collision=function(x,y,z)
  local col=collision(
   x,y,z,
   instance.x,
   instance.x+11,
   instance.y+7,
   instance.y+instance.height-1,
   0,
   -4
  )
  if col==nil then
   col=collision(
    x,y,z,
    instance.x+11,
    instance.x+24,
    instance.y+7,
    instance.y+instance.height-1,
    0,
    -7
   )
  end
  if col==nil then
   col=collision(
    x,y,z,
    instance.x+24,
    instance.x+instance.width,
    instance.y+7,
    instance.y+instance.height-1,
    0,
    -4
   )
  end
  
  return col
 end
 
 return instance
end
-->8
-- helpers --

-- drawing helper to draw
-- multiple sprites as a single
-- element. each row will be
-- drawn as a row, starting
-- from the second one (the
-- first row indicates color
-- swaps). negative values
-- indicate horizontal flip.
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
     (row*8+offset.y)+offset.z,
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
  z=offset.z,
 }
end

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
 if x>=obs_x and x<=obs_x2 then
  if abs(x-obs_x)<abs(x-obs_x2) then
   -- push left
   fix[1]=obs_x-x
   if fix[1]>-0.5 then
    fix[1]=-0.5
   end
  else
   -- push right
   fix[1]=obs_x2-x
   if fix[1]<0.5 then
    fix[1]=0.5
   end
  end
 else
  -- no collision found
  return nil
 end

 -- correct the y, pushing the
 -- point up or down (whichever
 -- way the y move is shorter).
 if y>=obs_y and y<=obs_y2 then
  if abs(y-obs_y)<abs(y-obs_y2) then
   -- push up
   fix[2]=obs_y-y
   if fix[2]>-0.5 then
    fix[2]=-0.5
   end
  else
   -- push down
   fix[2]=obs_y2-y
   if fix[2]<0.5 then
    fix[2]=0.5
   end
  end
 else
  -- no collision found
  return nil
 end

 -- correct the z, pushing the
 -- point upwards in the air
 -- when needed.
 if z<=obs_z and z>=obs_z2 then
  fix[3]=obs_z2-z
  if fix[3]>-0.5 then
   fix[3]=-0.5
  end
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
-- human info --

local sprts={
 {{colswap=nil},{42},{58}},
 {{colswap=nil},{43},{59}},
 {{colswap=nil},{43},{60}},
 {{colswap=nil},{43},{61}},
 {{colswap=nil},{43},{62}},
 {{colswap=nil},{42},{63}},
}

local function spr_duration()
 if scroll_speed!=0 then
  return (#sprts-1)/scroll_speed
 end
 return -1
end

local function update(inst)
 -- apply velocity deltas
 if state=="play" then
  inst.x+=scroll_speed
 end
 inst.x+=inst.dx
 inst.y+=inst.dy
 inst.z+=inst.dz
 
 if state=="play" then
  -- follow the dog
  inst.dy=(dog.y-inst.y-8)/8
 elseif state=="game over" then
  -- get next to the dog to
  -- hold it by the leash
  inst.dx=(dog.x-inst.x-11)/5
  inst.dy=(dog.y-inst.y-8)/5
 end
 
 -- apply gravity
 inst.dz+=gravity
 if inst.z>=inst.floor_z then
  inst.z=inst.floor_z
  inst.dz=0
 end
 
 -- detect if the human is
 -- currently colliding with a
 -- car to make sure he is
 -- moved to be on top of it if
 -- needed
 local collided=false
 local cp={inst.x+4,inst.y+15,0}
 inst.floor_z=0
 for _,c in ipairs(cars) do
  if c.speed<0 then
   local col=c._collision(
    cp[1],cp[2],cp[3]
   )
   if col!=nil and col[3]!=0 then
    -- the car roof is now the
    -- floor for the human
    inst.floor_z=col[3]

    -- see if the human is
    -- or should be on top of
    -- the car, ensuring it is
    -- if needed
    if col[3]<=inst.z then
     inst.z=col[3]
     if inst.dz>0 then
      inst.dz=0
     end
    end
    -- collision found, end
    -- the loop
    collided=true
    break
   end
  end
 end
 
 -- detect if the human will
 -- collide with the car soon
 -- to make him jump if needed
 if not collided
 and state=="play"
 then
  local cp_future={
   cp[1]+(18*scroll_speed),
   cp[2]+(10*inst.dy),
   0,
  }
  for _,c in ipairs(cars) do
   if c.speed<0 then
    col=c._collision(
     cp_future[1],
     cp_future[2],
     cp_future[3]
    )
    if col!=nil
    and col[3]<0
    and inst.z==0
    and inst.dz==0
    then
     -- make the human jump
     inst.dz=-jump_acc*1.2
     -- collision found, end
     -- the loop
     break
    end
   end
  end
 end

 -- update sprites
 local running=state=="play" or
  (state=="game over"
  and (abs(dog.x-inst.x-11)>1
   or abs(dog.y-inst.y-8)>1))
 if running then
  inst.spr_aux+=1
  local frames_per_sprite=spr_duration()
  if frames_per_sprite<=0 then
   inst.sprites=sprts[2]
  else
   if inst.spr_aux>#sprts*frames_per_sprite then
    inst.spr_aux=frames_per_sprite
   end
   inst.spr_index=min(
    #sprts,
    flr(inst.spr_aux/frames_per_sprite+0.5)
   )
  end
 else
  -- not running, still pose
  inst.spr_index=nil
 end
 
 -- update the shadow color,
 -- which will depend on the
 -- surface the human is on top
 -- of
 inst.shad_col=5
 if inst.y+8<113 and inst.y+8>40 then
  inst.shad_col=0
 elseif inst.floor_z!=0 then
  inst.shad_col=1
 end
end

local function draw(inst)
 -- draw shadow
 ovalfill(
  inst.x+2,
  inst.y+14+inst.floor_z,
  inst.x+6,
  inst.y+16+inst.floor_z,
  inst.shad_col
 )
 
 -- draw sprites for the human
 local offset={
  x=inst.x,
  y=inst.y,
  z=inst.z,
 }
 local n_sprts={
  -- still pose by default
  {colswap=nil},{14},{30},
 }
 if inst.spr_index!=nil then
  n_sprts=sprts[inst.spr_index]
 end
 draw_sprts(n_sprts,offset)
end

function create_human(x,bottom_y)
 local instance={
  x=x,
  y=bottom_y-16,
  z=0,
  dx=0,
  dy=0,
  dz=0,
  floor_z=0,
  spr_aux=spr_duration(),
  spr_index=1,
  shad_col=5,
 }
 
 instance._update=function()
  update(instance)
 end

 instance._draw=function()
  draw(instance)
 end
 
 return instance
end
-->8
-- bone info --

local sprts={
 {{colswap=nil},{27}},
 {{colswap=nil},{28}},
}
local frames_per_sprite=18

local function update(inst)
 -- update sprites
 inst.spr_aux+=1
 if inst.spr_aux>#sprts*frames_per_sprite then
  inst.spr_aux=frames_per_sprite
 end
 inst.spr_index=flr(inst.spr_aux/frames_per_sprite+0.5)

 -- update the shadow color
 inst.shad_col=5
 if inst.y<113 and inst.y>40 then
  inst.shad_col=0
 elseif inst.floor_z!=0 then
  inst.shad_col=1
 end
end

local function draw(inst)
 if not inst.taken then
  -- draw shadow
  ovalfill(
   inst.x+1,
   inst.y+3+inst.floor_z,
   inst.x+6,
   inst.y+5+inst.floor_z,
   inst.shad_col
  )
 
  -- draw sprite
  local offset={
   x=inst.x,
   y=inst.y,
   z=inst.z,
  }
  draw_sprts(
   sprts[inst.spr_index],
   offset
  )
 end
end

function create_bone(
 x,
 bottom_y,
 z
)
 local instance={
  x=x,
  y=bottom_y-7,
  z=z,
  floor_z=0,
  spr_aux=frames_per_sprite,
  spr_index=1,
  shad_col=5,
  taken=false,
 }
 
 instance._update=function()
  update(instance)
 end

 instance._draw=function()
  draw(instance)
 end
 
 instance._collision=function(x,y,z)
  if instance.floor_z<0 then
   -- wider collision box when
   -- on top of a car
   return collision(
    x,y,z,
    instance.x-3,
    instance.x+10,
    instance.y-3,
    instance.y+10,
    instance.z+5,
    instance.z-14
   )
  else
   return collision(
    x,y,z,
    instance.x-2,
    instance.x+9,
    instance.y-1,
    instance.y+8,
    instance.z+5,
    instance.z-9
   )
  end
 end
 
 return instance
end
-->8
-- game over message info --

-- todo: simplify this ugly code
local function update(inst)
 -- make the rectangle expand
 local target_x=human.x-human_offset_x+3
 local target_y=34
 local target_x2=human.x-human_offset_x+124
 local target_y2=144
 local skip_anim=btn(❎) or btn(🅾️)

 if not skip_anim
 and abs(target_x-inst.x)>1
 then
  inst.x+=0.1*(target_x-inst.x)
 else
  inst.x=target_x
 end

 if not skip_anim
 and abs(target_y-inst.y)>1
 then
  inst.y+=0.1*(target_y-inst.y)
 else
  inst.y=target_y
 end

 if not skip_anim
 and abs(target_x2-inst.x2)>1
 then
  inst.x2+=0.1*(target_x2-inst.x2)
 else
  inst.x2=target_x2
 end

 if not skip_anim
 and abs(target_y2-inst.y2)>1
 then
  inst.y2+=0.1*(target_y2-inst.y2)
 else
  inst.y2=target_y2
 end

 -- ensure text is shown once
 -- the rectangle is expanded
 -- to its target size, making
 -- sure to make it appear
 -- one character at a time
 local show_text=inst.x==target_x
  and inst.y==target_y
  and inst.x2==target_x2
  and inst.y2==target_y2
 if show_text then
  local all_text_shown=true
  if skip_anim then
   -- skip the text animation
   -- and show all the text
   -- directly
   inst.texts_to_show_chars=1000
  else
   inst.texts_to_show_chars+=1
  end
  inst.texts_to_show={}
  local aux_count=inst.texts_to_show_chars
  for _,text in ipairs(inst.texts) do
   inst.texts_to_show[#inst.texts_to_show+1]={text[1],""}
   local aux_text=""
   local new_aux_count=aux_count
   for i=1,min(#text[2],aux_count) do
    aux_text=aux_text..text[2][i]
    new_aux_count-=1
   end
   inst.texts_to_show[#inst.texts_to_show][2]=aux_text
   aux_count=new_aux_count
   if aux_count==0 then
    all_text_shown=false
    break
   end
  end
  if all_text_shown then
   -- the animation for the
   -- game over text is
   -- finished, but the user
   -- needs to release the
   -- button first in case it
   -- is pressed, otherwise
   -- the tap to skip the
   -- animation would also
   -- restart the game
   inst.finished=not (btn(❎) or btn(🅾️))
  end
 end
 
 -- increment counter that will
 -- be used to animate the
 -- "press button to restart"
 -- text
 if inst.finished then
  inst.counter+=1
  if inst.counter>120 then
   inst.counter=0
  end
 end
end

local function draw(inst)
 rect(
  inst.x,
  inst.y,
  inst.x2,
  inst.y2,
  2
 )

 if inst.texts_to_show!=nil then
  local text_y=inst.y+5
  for _,text in ipairs(inst.texts_to_show) do
   print(
    text[2],
    inst.x+6,
    text_y,
    text[1]
   )
   text_y+=12
  end
 end
 
 if inst.finished
 and inst.counter>50
 then
  print(
   "press button to restart",
   inst.x+14,
   inst.y+58,
   7
  )
 end
end

function create_game_over_msg()
 local function concat(a,b)
  local result=a
  for _=1,28-#a-#b do
   result=result.."."
  end
  return result..b
 end
 
 local texts={
  {7,concat("distance","1 x "..meters.." = "..meters)},
  {15,concat("bones","10 x "..bones_count.." = "..(10*bones_count))},
  {0,""},
  {0,""},
  {0,""},
  {0,""},
  {0,""},
  {0,""},
  {14,concat("total score",tostr(meters+10*bones_count))},
 }
 local instance={
  x=human.x-human_offset_x+63,
  y=89,
  x2=human.x-human_offset_x+63,
  y2=89,
  texts=texts,
  texts_to_show=nil,
  texts_to_show_chars=0,
  show_text=false,
  finished=false,
  counter=0,
 }
 
 instance._update=function()
  update(instance)
 end

 instance._draw=function()
  draw(instance)
 end
 
 return instance
end
__gfx__
00000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbaaaaaaaaaaaaaaaaa0000000000000000aaaa8aaa00000000
00000000aaaaaaaaaaaaaaaaaaaaa0aaaaaaa0aaaaaaaaaaaaaaaaaaaaaaaaaaaaa3bbbbbbbbbbb3aaaaaaaaaaaaaaaa0000000000000000aaaa8aaa00000000
007007004aaaa0aaaaaaa0aaaaaaa44aaaaaa44aaaaaa0aa4aaaa0aaaaaaaaaaa333bbbbbbbbbbb33aaaaaaaaaaaa0aa0000000000000000aaaa8aaa00000000
000770004aaaa44a4aaaa44a4aaa80404aaa80404aaaa44a4aaaa44aaabbbbb331d3bbbbbbbbbbb31333bbaa4aaaa44a0000000000000000aaaaaaaa00000000
00077000a44480404a4480404a4480444a4480444a448040a4448040abbbbb3111d3bbbbbbbbbbb3103b3b1a4a4480400000000000000000aaaa8aaa00000000
00700700a4448044a4448044a444484aa44448aaa4448044a44480446bbbbb3111d3bbbbbbbbbbb31133bb30a44480440000000000000000aaaaaaaa00000000
00000000aa4448aaa44448aaa444aaaa444444aaa44448aaa44448aa3bbbbb3111d3bbbbbbbbbbb3103b3b10a44448aa0000000000000000aaa0faaa00000000
00000000aa44aaaaaa4a4aaaa4aaaaaaaaaaaa4a4aaaa4aaaaaa4aaa3bbbbb3111d33333333333331133bb30aa44a4aa0000000000000000aaaffaaa00000000
666666665655555556555555666666666666666666666666aaaaaaaa3bbbbb311331111113111111303b3b10aaaaa4aaaaaaa9aaaaaaaaaaaaa22aaa00000000
666666665555565555555655666666666666666666666666aaadddaa3bbbbbb331111111131111111333bb30aaaa474aaaaa979aaaaaaaaaaa222aaa00000000
666666665555555555555555666666666666666666666666aadd6dda3b3333333333333333333333333338e0aaaa4774aaaa9779aaaafaaaaa222aaa00000000
666666665555555555555555555555556666666666666666a5ddddda63333333333333333333333333333885aaa4722aaaa97eeaaaaaffaaaaf22faa00000000
666666665565555555655555556555556666666666666666a55d5d5a76333333111333333333331113333315a4472aaaa997eaaaaaafaaaaaaaccaaa00000000
666666665555556555555555555555656666666666666666a155555a5133333155513333333331555133331a4772aaaa977eaaaaaffaaaaaaaaccaaa00000000
666666665555555550505050555555556777777777666666aa1111aaa511111055501111111110555011115aa462aaaaa96eaaaaaafaaaaaaaaccaaa00000000
666666665555555505050505555555556777777777666666aaaaaaaaaa5555550005555555555500055555aaaa2aaaaaaaeaaaaaaaaaaaaaaaa11aaa00000000
aaaaaaaaaaaaaaaaaaaaa0aaaaaaa0aaaaaaa0aaaaaaaaaa4aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00000000000000000000000000000000
aaaaaaaaaaaaa0aaaaaaa44aaaaaa44a4aaaa44a4aaaa0aa4aaaa0aa4aaaa0aaaaaaa0aaaaaaaaaaaaaaaaaaaaaaaaaa00000000000000000000000000000000
aaaaa0aaaaaaa44aaaaa80404aaa80404aaa80404aaaa44aa4aaa44a4aaaa44a4aaaa44a4aaaa0aaaaaaaaaaaaaaaaaa00000000000000000000000000000000
4aaaa44a4aaa80404aa480444a448044a4448044a4aa8040444a8040a44a80404aaa80404aaaa44aaaaaaaaaaaaaaaaa00000000000000000000000000000000
4a4480404a4480444a4448aaa44448aa444448aa444480444444804444448044a4448044a4448040aaaaaaaaaaaaaaaa00000000000000000000000000000000
a4448044a44448aaa44444aa444444aa444444aa444448aa444448aa444448aaa44448aaa4448044aaa0faaaaaaaaaaa00000000000000000000000000000000
a44448aa444444aa444aaaaa44aaaaaa44aaa4aa444444aaa4a444aa44a444aaa4a44aaaa4a448aaaaaffaaaaaa0faaa00000000000000000000000000000000
aaa44aaa44aaaaaa44aaaaaaaaaaaaaaaaaaaaaaaaaaa4aaaaaaa4aaa4aa4aaaa4aa4aaaaa4a4aaaaa222aaaaaaffaaa00000000000000000000000000000000
aa267daaaa267daaaddaaddaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa565555555050505050505050a2a222faaa222aaaaaa22aaaaaa22aaaaaa22aaaaa222aaa
aa267daaaa267daa267dd76daaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa555556550505050505050505afa22aaaaaf22aaaaaa22aaaaaa22aaaaa222aaaaaf222fa
aa267daaaa267daa2677777d4aaa656aaaaa656aaaaa656aaaaa656a555555555050505050505050aaa22aaaaaa22faaaaa22aaaaaa22aaaaa222aaaaaa22aaa
aa267daaaa267daaa26777da4aa66ff64aa66ff64aa66ff64aa66ff6555555550505050505050505aaaccaaaaaa22aaaaaaf2aaaaaa2faaaaaf22faaaaacccaa
a26777daaa267daaaa267daaa44fe5f54a4fe5f54a4fe5f54a4fe5f5505050505050505050505050aaacacaaaaaccaaaaaaccaaaaaaccaaaaaaccaaaaaacacaa
2677777daa267daaaa267daaa44fe5ffa44fe5ffa44fe5ffa44fe5ff050505050505050505050505a1caaacaaaaccaaaaaaccaaaaaaccaaaaaacacaaaacaaa1a
267dd76daa267daaaa267daaa444fe6aa4444e6aa444444aa4444e6a505050505555555550505050aaaaaaa1aa1cacaaaaa1caaaaaac1aaaaacaa1aaaa1aaaaa
addaaddaaa267daaaa267daaa4aa4aaaa4aaa4aaa4aaaaaa4aaaa4aa050505055555555505050505aaaaaaaaaaaaa1aaaaaa1aaaaaa1aaaaaa1aaaaaaaaaaaaa
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000aaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000aaaaaaaaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000aaaaaaaaaaaaaaaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000aaaaaaaaaaaaaaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000aaaaaaaaaaaaaaaaaaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000aaaaaaaaaaaaaaaaaaaaaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000aaaaaaaaaaaaaaaaaaaaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000aaaaaaaaaaaaaaaaaaaaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaaaaaaaaaaaaaaaaaaaaaaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaaaaaaaaaaaaaaaaaaaaaaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaaaaaaaaaaaaaaaaaaaaaaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaaaaaaaaaaaaaaaaaaaaaaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaaaaaaaaaaaaaaaaaaaaaaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaaaaaaaaaaaaaaaaaaaaaaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000aaaaaaaaaaaaaaaaaaaaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000aaaaaaaaaaaaaaaaaaaaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000aaaaaaaaaaaaaaaaaaaaaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000aaaaaaaaaaaaaaaaaaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000aaaaaaaaaaaaaaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000aaaaaaaaaaaaaaaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000aaaaaaaaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000aaaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
3737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737
3939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939
3939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939
3939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939
3939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939393939
3838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838383838
1212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212121212
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415141514151415
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
