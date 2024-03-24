pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- unleashed game --

function init(initial_state)
 state=initial_state
 enter_transition=nil

 if initial_state=="intro" then
  intro_screen=create_intro_screen()
  return
 elseif initial_state=="play" then
  enter_transition=transition(0,0)
 end

 exit_transition=nil
 intro_screen=nil
 scroll_speed_deft=1
 scroll_speed=scroll_speed_deft
 gravity=0.35
 jump_acc=2.4
 human_offset_x=6
 human=create_human(human_offset_x,114)
 dog_offset_x=48
 dog=create_dog(dog_offset_x,114)
 cam_shake=0
 cam_x=0
 cam_y=0
 cam_offset_x=0
 cam_offset_y=0
 buildings={}
 bones={}
 obstacles={}
 to_render={}
 blocked_lane=nil
 bones_count=0
 bone_being_lost=false
 meters_aux=0
 real_meters=0
 meters=0
 game_over_msg=nil
 restart_requested=false
end

function _init()
 cartdata("ernestoyaquello_unleashed")
 extcmd("set_title", "unleashed")
 init("intro")
end

function _update60()
 -- if the intro screen exists,
 -- update it and ignore
 -- everything else
 if intro_screen!=nil then
  intro_screen._update()
  return
 end

 -- the exit transition, if
 -- present, is the only thing
 -- shown
 if exit_transition!=nil then
  if exit_transition.finished then
   exit_transition=nil
   -- exit transition finished,
   -- time to start the game
   init("play")
   _update60()
  else
   exit_transition.x=cam_x
   exit_transition.y=cam_y
   exit_transition._update()
  end
  return
 end

 local btn_pressed=btn(❎) or btn(🅾️)

 -- request a game restart
 -- if needed
 if state=="game over"
 and game_over_msg!=nil
 and game_over_msg.finished
 and btn_pressed
 then
  restart_requested=true
 end

 -- restart upon button
 -- release by triggering
 -- the exit transition
 if restart_requested
 and not btn_pressed
 then
  sfx(5)
  exit_transition=transition(cam_x,cam_y,true)
  return
 end

 local start_x=human.x-human_offset_x
 local end_x=human.x-human_offset_x+127

 -- shift everything if
 -- needed to keep the
 -- scroll infinite
 local offset=nil
 local map_end_x=(128*8)-1
 if end_x>=map_end_x then
  offset=-flr(map_end_x)+127
 elseif start_x<=0 then
  offset=-flr(start_x+0.5)+127
 end
 if offset!=nil then
  dog.x+=offset
  for p in all(dog.leash.leash) do
   p.x+=offset
  end
  human.x+=offset

  for b in all(buildings) do
   b.x+=offset
  end

  for o in all(obstacles) do
   o.x+=offset
   if o.bone!=nil then
    o.bone.x+=offset
   end
  end

  for b in all(bones) do
   b.x+=offset
  end

  start_x=human.x-human_offset_x
  end_x=human.x-human_offset_x+127
 end

 to_render={}

 -- only keep buildings
 -- that are within view
 local max_b_end_x,bi=0,1
 while bi<=#buildings do
  local b=buildings[bi]
  local b_end_x=b.x+b.width-1
  -- using a margin in case
  -- the camera goes back
  if b_end_x+32>=start_x then
   add(to_render,b)
   max_b_end_x=max(max_b_end_x,b_end_x)
   bi+=1
  else
   del(buildings,b)
  end
 end

 -- fill gaps with
 -- buildings
 while max_b_end_x<end_x do
  local nb=create_building(max_b_end_x+1,10)
  add(buildings,nb)
  max_b_end_x+=nb.width
 end

 -- update obstacles
 local scaffold_x=start_x+300
 local scaffold_end_x=start_x-300
 local vehicles={}
 local vehicle_ys={
  [18]=1.2,
  [40]=1.3,
  [104]=-0.85,
  [116]=-1.05,
  [131]=-0.95,
 }
 local oi=1
 local last_bike_end_x=-1
 while oi<=#obstacles do
  local o=obstacles[oi]
  local o_end_x=o.x+o.width-1
  if o.x<=end_x+1 and o_end_x>=start_x-33 then
   -- obstacle within view
   if o.type=="vehicle" then
    -- vehicles in another
    -- list to sort them
    -- by lane
    del(obstacles,o)
    add(vehicles,o)
    
    -- save bike most end x
    -- so we can decide if
    -- a scaffold can be
    -- added
    if o.v_type=="bike" then
     last_bike_end_x=max(
      last_bike_end_x,
      o.x+o.width-1
     )
    end
    
    -- stop new vehicles
    -- from spawning here
    -- if needed
    if (
     (o.dx<0 or o.dx<scroll_speed)
     and o_end_x+o.width+18>=end_x
    )
    or (
     o.dx>scroll_speed
     and o.x-o.width-18<=start_x
    )
    then
     vehicle_ys[o.y]=nil
    end
   else
    -- keep obstacle in list
    if o_end_x>=start_x
    and o.x<=end_x
    then
     add(to_render,o)
     if o.type=="scaffold" then
      scaffold_x=o.x
      scaffold_end_x=o.x+o.width
     end
    end
    oi+=1
   end
  else
   -- obstacle not within view
   del(obstacles,o)
  end
 end

 -- add new scaffolds
 if state=="play"
 and enter_transition==nil
 and #obstacles==0
 and end_x>last_bike_end_x+20
 and flr(rnd(200/scroll_speed))==1
 then
  local s=create_scaffold(end_x+1,101)
  add(obstacles,s)
  scaffold_x=s.x
  scaffold_end_x=s.x+s.width
 end

 -- remove hidden sidewalk
 -- bones
 local bi=1
 while bi<=#bones do
  local b=bones[bi]
  if b.x+7<start_x
  or (not b.is_lost
   and b.x+7>=scaffold_x
   and b.x<=scaffold_end_x)
  then
   del(bones,b)
  else
   add(to_render,b)
   bi+=1
  end
 end

 -- add new sidewalk
 -- bones
 if state=="play"
 and enter_transition==nil
 and #bones==0
 and flr(rnd(200/scroll_speed))==1
 then
  local bx=end_x+1
  for _=1,1+flr(rnd(3)) do
   if not (bx+7>=scaffold_x
    and bx<=scaffold_end_x)
   then
    local nb=create_bone(bx,117,-18)
    add(bones,nb)
   end
   bx+=12
  end
 end

 -- update sidewalk bones
 for b in all(bones) do
  b._update()
 end

 -- add new vehicles
 for vy,spd in pairs(vehicle_ys) do
  -- avoid vehicles whose
  -- speed matches the
  -- scrolling
  local factor=abs(spd-scroll_speed)
  if factor!=0
  and enter_transition==nil
  and (
   (vy!=104
    and flr(rnd(50/factor))==0)
   or (vy==104
    and flr(rnd(60/factor))==0)
  )
  then
   local nv_x=end_x+1
   if spd>scroll_speed then
    nv_x=start_x-32
   end
   local nv=nil
   if vy!=104 then
    nv=create_car(nv_x,vy,spd)
   elseif scaffold_end_x<=start_x then
    nv=create_bike(nv_x,vy,spd)
   end
   add(vehicles,nv)
  end
 end

 -- sort vehicles by lane
 -- with the dog and human
 -- in the right place too
 local dog_added=false
 local human_added=false
 for vy in all({18,40,104,116,131}) do
  local remaining_vehicles={}
  for v in all(vehicles) do
   if v.y==vy then
    -- vehicle in correct lane,
    -- add it now
    add(obstacles,v)
    if v.dx>0 then
     -- vehicle is behind
     -- buildings
     add(to_render,v,1)
    else
     -- vehicle is in front
     -- of buildings
     if not dog_added
     and dog.y<=v.y
     then
      add(to_render,dog)
      dog_added=true
     end
     if not human_added
     and human.y+7<=v.y
     then
      add(to_render,human)
      human_added=true
     end

     add(to_render,v)
    end
   else
    -- vehicle not in correct
    -- lane, add it later
    add(remaining_vehicles,v)
   end
  end
  vehicles=remaining_vehicles
 end

 -- add dog and human
 -- for rendering
 if dog.y+7>human.y+15 then
  if (not human_added) add(to_render,human)
  if (not dog_added) add(to_render,dog)
 else
  if (not dog_added) add(to_render,dog)
  if (not human_added) add(to_render,human)
 end

 -- update obstacles
 for o in all(obstacles) do
  o._update()
 end

 -- update human and dog
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

 -- increase scroll speed
 -- with distance
 scroll_speed=scroll_speed_deft
  +min(1,flr(meters/100)/20)

 -- shake the camera if needed
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

   -- shake effect over,
   -- bone is fully lost
   bone_being_lost=false
  end
 end

 -- check if it is game over
 if state=="play"
 and (dog.x-13<=human.x
  or dog.x-human.x<=8)
 then
  state="game over"
  sfx(4)

  -- save record locally
  local record=meters+10*bones_count
  local last_record=dget(0)
  if last_record==nil
  or last_record<record
  then
   dset(0,record)
  end
 end

 -- if the game is over and
 -- the dog captured, show
 -- game over message
 if state=="game over"
 and abs(human.dx)<1
 and abs(human.dy)<1
 and game_over_msg==nil
 then
  game_over_msg=create_game_over_msg()
 end

 -- update the game over
 if game_over_msg!=nil then
  game_over_msg._update()
 end

 -- update camera position
 cam_x=human.x-human_offset_x+cam_offset_x
 cam_y=20+cam_offset_y

 -- update enter transition
 if enter_transition!=nil then
  if enter_transition.finished then
   enter_transition=nil
  else
   enter_transition.x=cam_x
   enter_transition.y=cam_y
   enter_transition._update()
  end
 end
end

function _draw()
 -- intro screen overrides
 -- everything else
 if intro_screen!=nil then
  intro_screen._draw()
  return
 end

 -- show different palette
 -- during game over
 if state=="game over"
 and game_over_msg!=nil
 then
  fillp(0b1111111111111111.011)
 end

 -- yellow for transparencies
 palt(0, false)
 palt(10, true)

 -- map background
 camera(cam_x,cam_y)
 map()

 -- draw elements
 for tr in all(to_render) do
  tr._draw()
 end

 -- restore color palette
 -- before rendering texts
 if state=="game over"
 and game_over_msg!=nil
 then
  fillp(0b0000000000000000.011)
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
 rect(
  m_end_x+4,
  cam_y+3,
  m_end_x+16+4*#bc_str,
  cam_y+11,
  0
 )
 local bc_bg_color=2
 if bone_being_lost then
  bc_bg_color=8
 end
 rectfill(
  m_end_x+3,
  cam_y+2,
  m_end_x+15+4*#bc_str,
  cam_y+10,
  bc_bg_color
 )
 spr(
  50,
  m_end_x+5,
  cam_y+2
 )
 local bc_offset_x=0
 local bc_offset_y=0
 if bone_being_lost then
  bc_offset_x=cam_offset_x
  bc_offset_y=cam_offset_y
 end
 print(
  bc_str,
  m_end_x+14+bc_offset_x,
  cam_y+4+bc_offset_y,
  15
 )

 -- if present, draw transitions
 -- over everything else
 if enter_transition!=nil then
  enter_transition._draw()
 elseif exit_transition!=nil then
  exit_transition._draw()
 end
end
-->8
-- dog info --

local jump_done=nil
local can_move_up=nil
local can_move_down=nil

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
 shadow_col=nil,
 low_shadow=nil,
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
 local last_dog_z=dog.z

 local btn_click=btn(❎) or btn(🅾️)

 -- jump available again
 -- upon button release
 jump_done=jump_done
  or not btn_click

 -- jump if needed and able
 if btn_click
 and state=="play"
 and abs(dog.z-dog.floor_z)<1
 and abs(dog.dz)<0.1
 and dog.dx>=0
 and jump_done
 and scroll_speed>0
 then
  sfx(0)
  dog.dz=-jump_acc
  jump_done=false
 end

 -- re-enable vertical move
 -- upon button release
 can_move_up=can_move_up
  or not btn(⬆️)
 can_move_down=can_move_down
  or not btn(⬇️)

 -- move up and down if able
 if state=="play"
 and (dog.dy==0 or dog.z<dog.floor_z)
 and dog.dx>=0
 then
  if btn(⬆️)
  and can_move_up
  and dog.y>=107.1
  and scroll_speed>0
  then
   dog.dy-=0.1
   can_move_up=false
  elseif btn(⬇️)
  and can_move_down
  and dog.y<=133.9
  and scroll_speed>0
  then
   dog.dy+=0.1
   can_move_down=false
  end
 end

 -- smoothes out the vertical
 -- movement by making the
 -- dog go faster in the
 -- middle
 local function dy_speed(a,b)
  local diff=abs(a-b)/2
  local offst=min(a,b)+diff
  local div=diff^2
  local spd=1-((dog.y-offst)^2)/div

  if dog.dz==0 then
   return 2.4*(0.25+spd)
  end

  -- slower vertical movement
  -- when jumping to help
  -- jump feel natural
  return 1.3*(0.25+spd)
 end

 -- move vertically
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

 -- dog doesn't enter the floor
 if dog.z>=dog.floor_z then
  dog.z=dog.floor_z
  dog.dz=0
 end

 -- apply gravity, unless
 -- the jump is being extended
 -- through a longer button
 -- press
 local current_dz=dog.dz
 if dog.z<dog.floor_z then
  if not btn_click
  or dog.floor_z-dog.z>13 -- too high
  or dog.dz>=-1.5 -- too slow
  then
   dog.dz+=gravity
  end
 end

 -- dog isn't pushed
 -- backwards forever
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

 -- dog reaches a valid
 -- lane
 if dog.dy>0 then
  for lane_y in all({119,134}) do
   if last_dog_y<lane_y
   and dog.y>=lane_y
   then
    dog.dy=0
    dog.y=lane_y
   end
  end
 elseif dog.dy<0 then
  for lane_y in all({119,107}) do
   if last_dog_y>lane_y
   and dog.y<=lane_y
   then
    dog.dy=0
    dog.y=lane_y
   end
  end
 end

 -- collisions with obstacles
 dog.floor_z=0
 local cp={dog.x+6,dog.y+7,0}
 for o in all(obstacles) do
  if o.type=="scaffold"
  or o.dx<0
  then
   local col=o._collision(
    cp[1],cp[2],cp[3]
   )
   if col!=nil then
    local dog_moved=false
    local crash=false
    dog.low_shadow=o.v_type=="bike"
     and (col[3]>-12 or dog.z<-15)

    -- frontal collision?
    if col[1]<0
    and dog.z>=col[3]
    and ((o.v_type!="bike"
      and abs(cp[1]-(o.x+o.col_x_ofst))-3<=scroll_speed-o.dx)
     or (o.v_type=="bike"
      and col[3]>-11)
      and dog.dx>=0)
    then
     if o.dx<0 then
      -- crash with moving
      -- obstacle, push dog
      -- back
      sfx(1)
      dog.dx=min(
       -2,
       1.8*(o.dx-scroll_speed)
      )
      dog.dz=-1
      -- slow down the obstacle
      o.dx2=2.5*scroll_speed
      -- shake cam
      cam_shake=1
      dog_moved=true
      crash=true
     else
      -- crash with static
      -- obstacle, move dog
      -- back
      dog.x+=col[1]
      dog_moved=true
     end

    -- side collision?
    elseif dog.z>=col[3]
    and ((col[2]<0
     and last_dog_y-1<=dog.y+col[2])
      or (col[2]>0
       and last_dog_y+1>=dog.y+col[2]))
    then
     -- push dog to previous
     -- lane
     sfx(1)
     dog.y+=col[2]
     dog.y=min(max(dog.y,107),134)
     if col[2]>0 then
      dog.dy=0.1
     else
      dog.dy=-0.1
     end
     -- shake cam
     cam_shake=0.5
     dog_moved=true
     crash=true

    -- backwards collision?
    elseif col[1]>0
    and dog.dx<0
    and dog.z>=col[3]
    and last_dog_x+1>=dog.x-col[1]+o.dx
    then
     dog.x+=col[1]+4
     dog.dx=0
     dog_moved=true
    end

    -- dog on top of obstacle
    -- or jumping over it?
    if col[3]!=0
    and not dog_moved
    then
     dog.floor_z=col[3]

     if col[3]<dog.z then
      dog.z=col[3]
      dog.dz=0
     end
    end

    -- lose a bone as a
    -- punishment for crashing
    if crash
    and bones_count>0
    then
     bones_count-=1
     sfx(6)

     -- lost bone flies back
     local b=create_bone(
      dog.x,
      dog.y,
      dog.z
     )
     if dog.dx<0 then
      b.dx=dog.dx-0.25
     else
      b.dx=-3.2
     end
     b.dz=-4
     b.is_lost=true
     add(bones,b)
     bone_being_lost=true
    end

    -- collision found, end
    -- the loop
    break
   end
  end
 end

 -- collisions with bones
 if state=="play" then
  local nt_bones={}
  -- sidewalk bones
  for b in all(bones) do
   if not b.taken
   and not b.is_lost
   then
    add(nt_bones,b)
   end
  end
  -- bones on vehicles
  for o in all(obstacles) do
   if o.type=="vehicle"
   and o.bone!=nil
   and not o.bone.taken
   and not o.bone.is_lost
   then
    add(nt_bones,o.bone)
   end
  end
  local cp={
   dog.x+6,
   dog.y+7,
   dog.z-2,
  }
  for b in all(nt_bones) do
   local col=b._collision(
    cp[1],cp[2],cp[3]
   )
   if col!=nil then
    b.taken=true
    bones_count+=1
    sfx(3,1)
    break
   end
  end
 end

 -- update dog sprite
 if state=="play"
 or state=="intro"
 then
  if current_dz==0 then
   -- is running
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
   -- is jumping
   dog.sprite=32+9*((current_dz+jump_acc)/(2*jump_acc))
   dog.sprite=max(32,min(41,dog.sprite))
  end
 elseif state=="game over" then
  -- is sitting down for
  -- game over
  dog.sprite=51
 end

 -- update leash
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
 local shadow_offset_y=0
 if dog.low_shadow then
  shadow_offset_y=-dog.floor_z
 end
 ovalfill(
  dog.x+1,
  dog.y+dog.floor_z+6+shadow_offset_y,
  dog.x+6,
  dog.y+dog.floor_z+8+shadow_offset_y,
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
 dog.shadow_col=5
 dog.low_shadow=false

 jump_done=true
 can_move_up=true
 can_move_down=true

 return dog
end
-->8
-- dog's leash info --

local leash_length=10

local leash={
 leash=nil,
}

-- neck leash position
-- for any given dog
-- sprite, positioned
-- relative to the
-- sprite
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

-- current neck leash
-- position
local function leash_rel_origin()
 local p=leash_positions[1]
 if dog!=nil then
  p=leash_positions[flr(dog.sprite)]
 end
 return {x=p.x,y=p.y,z=p.z}
end

function leash._update()
 if state=="play"
 or state=="intro"
 then
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
   p.x+=-(scroll_speed+dog.dx)
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

   -- ensure there are no gaps
   -- between this point and the
   -- one it is attached to
   local v_diff=(lp.y+lp.z)-(p.y+p.z)
   if v_diff>1 then
    p.y+=v_diff-1
   elseif v_diff<-1 then
    p.y+=v_diff+1
   end

   add(new_leash,p)
  end

  -- use updated leash
  dog.leash.leash=new_leash
 end
end

function leash._draw()
 -- draw leash normally
 -- while playing
 if state=="play"
 or state=="intro"
 then
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
   human.x+8,
   human.y+human.z+13,
   dog.x+4,
   dog.y+dog.z+6,
   14
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
  -- follow the dog vertically
  inst.dy=(dog.y-inst.y-8)/8
 elseif state=="game over" then
  -- get next to the dog to
  -- hold it by the leash
  inst.dx=(dog.x-inst.x-11)/18
  inst.dy=(dog.y-inst.y-8)/5
 end

 -- apply gravity
 inst.dz+=gravity
 if inst.z>=inst.floor_z then
  inst.z=inst.floor_z
  inst.dz=0
 end

 -- detect obstacles
 inst.floor_z=0
 local collided=false
 local cp={inst.x+5,inst.y+15,0}
 for o in all(obstacles) do
  if o.type=="scaffold"
  or o.dx<0
  then
   local col=nil
   if o.type!="scaffold" then
    col=o._collision(
     cp[1],cp[2],cp[3]
    )
   else
    col=o._collision(
     cp[1],cp[2]-2,cp[3]
    )
   end
   if col!=nil then
    if o.v_type=="car" then
     -- the obstacle "roof" is
     -- now the  floor for the
     -- human
     inst.floor_z=col[3]

     -- ensure human is on
     -- top if needed
     if col[3]<=inst.z then
      inst.z=col[3]
      inst.dz=min(inst.dz,0)
     end
    else
     -- avoid trespassing
     -- inside the obstacle
     inst.y+=col[2]
    end

    -- collision found, end
    -- the loop
    collided=true
    break
   end
  end
 end

 -- detect upcoming obstacles
 if not collided
 and state=="play"
 then
  local cp_future={
   cp[1]+(18*scroll_speed),
   cp[2]+(10*inst.dy),
   0,
  }
  for o in all(obstacles) do
   col=nil
   if o.type!="scaffold" then
    col=o._collision(
     cp_future[1],
     cp_future[2],
     cp_future[3]
    )
   else
    col=o._collision(
     cp_future[1],
     cp_future[2]-2,
     cp_future[3]
    )
   end
   if col!=nil then
    if o.v_type=="car" then
     if col[3]<0
     and inst.z==0
     and inst.dz==0
     then
      -- make the human jump
      -- to avoid the car
      -- he is heading towards
      inst.dz=-jump_acc*1.2

      -- collision found, end
      -- the loop
      break
     end
    else
     if col[2]>0
     and inst.dy<=0
     then
      -- push human away from
      -- the obstacle
      local push=col[2]-(cp[2]-cp_future[2])
      inst.y+=push/3
     end
    end
   end
  end
 end

 -- update sprites
 local running=scroll_speed>0
  and (state=="play"
   or state=="intro"
   or (state=="game over"
    and (abs(dog.x-inst.x-11)>1
     or abs(dog.y-inst.y-8)>1)))
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

 -- update the shadow color
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
  {colswap=nil},{43},{44},
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
-- building info --

function create_building(x,y)
 local pub=flr(rnd(20))==10
 if pub then
  for b in all(buildings) do
   if b.pub then
    pub=false
    break
   end
  end
 end
 local instance={
  x=x,
  y=y,
  width=7*8,
  height=13*8,
  pub=pub,
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
    add(new_gr_row,-ground[i][j])
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
 end

 return instance
end
-->8
-- scaffolding info --

function create_scaffold(x,y)
 -- define number of scaffolds
 local num_blocks=3+flr(rnd(4))
 local instance={
  x=x,
  y=y,
  z=0,
  dx=0,
  col_x_ofst=14,
  width=32+num_blocks*12,
  height=25,
  type="scaffold",
 }

 instance._update=function()
 end

 instance._draw=function()
  -- draw first diversion sign
  spr(242,instance.x,instance.y+6)

  -- draw scaffolding blocks
  local x=instance.x+16
  for i=1,num_blocks do
   sspr(
    0,
    96,
    13,
    32,
    x,
    instance.y-15
   )
   x+=12

   -- stop drawing if the next
   -- block is off screen
   if x>cam_x+128+scroll_speed then
    return
   end
  end

  -- if we have drawn all the
  -- blocks, also draw the
  -- last diversion sign
  spr(242,x+8,instance.y+6,1,1,true)
 end

 instance._collision=function(x,y,z)
  return collision(
   x,y,z,
   instance.x+instance.col_x_ofst,
   instance.x+instance.width-12,
   instance.y,--+11
   instance.y+16,
   0,
   -instance.height
  )
 end

 return instance
end
-->8
-- vehicle info --

local function update(inst)
 -- reduce horizontal acc
 inst.dx2/=1.3
 if abs(inst.dx2)<0.001 then
  inst.dx2=0
 end

 -- apply scroll speed to
 -- moving obstacle, but
 -- only if the game is
 -- playing (or if the lane
 -- isn't occupied by the dog
 -- while the game is over)
 if (blocked_lane!=inst.y
  and (state=="play"
   or inst.dx>0
   or (inst.y==104 and dog.y!=107)
   or (inst.y==116 and dog.y!=119)
   or (inst.y==131 and dog.y!=134)
   or inst.x-24>dog.x))
 or inst.x<dog.x
 then
  inst.x+=inst.dx
 else
  blocked_lane=inst.y
 end
 inst.x+=inst.dx2

 -- update bone if needed
 if inst.bone!=nil then
  if not inst.bone.taken then
   inst.bone.x=inst.x+inst.bone_offset_x
  end
  inst.bone._update()
 end
end

function create_car(x,y,speed)
 -- randomly place a bone on
 -- top of the car
 local bone=nil
 if speed<0
 and flr(rnd(6))<5
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
  dx=speed,
  dx2=0,
  col_x_ofst=0,
  width=4*8,
  height=2*8,
  bone=bone,
  bone_offset_x=13,
  type="vehicle",
  v_type="car",
 }

 -- change car colors
 -- at random
 local cs={}
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

 instance._update=function()
  update(instance)
 end

 instance._draw=function()
  -- draw car
  for s in all(cs) do
   pal(s[1],s[2])
  end
  sspr(
   56,0,
   32,16,
   instance.x,instance.y,
   32,16,
   instance.dx>0 -- flip h
  )
  for s in all(cs) do
   pal(s[1],s[1])
  end

  -- draw bone if needed
  if instance.bone!=nil then
   instance.bone._draw()
  end
 end

 instance._collision=function(x,y,z)
  local col=collision(
   x,y,z,
   instance.x+11,
   instance.x+24,
   instance.y+7,
   instance.y+instance.height-1,
   0,
   -7
  )
  if col!=nil then
   return col
  end

  return collision(
   x,y,z,
   instance.x,
   instance.x+instance.width+2,
   instance.y+7,
   instance.y+instance.height-1,
   0,
   -4
  )
 end

 return instance
end

function create_bike(x,y,speed)
 local instance={
  x=x,
  y=y,
  z=0,
  dx=speed,
  dx2=0,
  col_x_ofst=0,
  width=2*8,
  spr_aux=0,
  spr_index=1,
  type="vehicle",
  v_type="bike",
 }

 -- change bike colors
 local cs={}

 -- bike color
 local cs_rnd=flr(rnd(5))
 if cs_rnd==0 then
  cs={{9,14}}
 elseif cs_rnd==1 then
  cs={{9,3}}
 elseif cs_rnd==2 then
  cs={{9,8}}
 elseif cs_rnd==3 then
  cs={{9,11}}
 end

 -- backpack color
 cs_rnd=flr(rnd(2))
 if cs_rnd==0 then
  add(cs,{3,8})
  add(cs,{11,9})
 end

 -- clothes color
 cs_rnd=flr(rnd(3))
 if cs_rnd==0 then
  add(cs,{1,12})
  add(cs,{13,2})
 elseif cs_rnd==1 then
  add(cs,{1,2})
  add(cs,{13,1})
 end

 -- skin color
	cs_rnd=flr(rnd(2))
	if cs_rnd==0 then
	 add(cs,{15,4})
 end

 local bike_sprts={
  {{colswap=cs},{11,12},{27,28}},
  {{colswap=cs},{11,14},{29,30}},
  {{colswap=cs},{11,15},{27,31}},
  {{colswap=cs},{11,47},{45,46}},
 }

 instance._update=function()
  update(instance)

  if blocked_lane!=instance.y then
   instance.spr_aux+=1
  end
  instance.spr_index=1+flr(abs(instance.dx)*instance.spr_aux/5)
  if instance.spr_index>#bike_sprts then
   instance.spr_aux=0
   instance.spr_index=1
  end
 end

 instance._draw=function()
  local offset={
   x=instance.x,
   y=instance.y-2,
   z=instance.z,
  }
  draw_sprts(bike_sprts[instance.spr_index],offset)
 end

 instance._collision=function(x,y,z)
  local col=collision(
   x,y,z,
   instance.x+8,
   instance.x+16,
   instance.y,--+9
   instance.y+12,
   0,
   -12
  )
  if col!=nil then
   return col
  end

  return collision(
   x,y,z,
   instance.x,
   instance.x+18,
   instance.y,--+9
   instance.y+12,
   0,
   -5
  )
 end

 return instance
end
-->8
-- bone info --

local sprts={49,48}
local frames_per_sprite=18

local function update(inst)
 -- only lost bones use
 -- physics, as they need to
 -- fly and fall back down for
 -- dramatic effect
 if inst.is_lost then
  -- apply velocity deltas
  inst.x+=inst.dx
  inst.z+=inst.dz

  -- reduce dx over time
  if inst.dx<0 then
   inst.dx+=0.16*scroll_speed
   inst.dx=min(inst.dx,0)
  end

  -- apply gravity, ensuring
  -- the bone doesn't go
  -- through the floor
  if inst.z>inst.floor_z then
   inst.z=inst.floor_z
   inst.dz=0
   inst.taken=true
  else
   inst.dz+=gravity
  end
 end

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
  spr(
   sprts[inst.spr_index],
   inst.x,
   inst.y+inst.z
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
  dx=0,
  dz=0,
  is_lost=false,
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
   -- on top of a vehicle
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
-- intro screen info --

local initial_patterns={
 0b0000000000000000,
 0b0000000001000000,
}
local patterns={
 0b0001000001000000,
 0b0010000010000000,
 0b0100000000010000,
 0b1000000000100000,
}
local button_pressed=false
local arrow_button_pressed=false

local function update(inst)
 -- if the exit transition is
 -- present, ensure that's the
 -- only thing that updates
 if inst.exit_transition!=nil then
  inst.exit_transition._update()
  if inst.exit_transition.finished then
   inst.exit_transition=nil
   -- exit transition finished,
   -- time to start the game
   init("play")
   _update60()
  end
  return
 end

 button_pressed=btn(❎) or btn(🅾️)
 arrow_button_pressed=btn(⬆️) or btn(⬇️)

 -- request the start of the
 -- game or the opening of the
 -- pause menu
 if inst.menu_fully_shown
 and button_pressed
 then
  -- schedule the action for
  -- when the button is
  -- released
  if inst.play_btn_selected then
   if inst.action_requested!="start" then
    inst.action_requested="start"
    sfx(5)
   end
  else
   -- no sound here because
   -- it'd be interrupted by
   -- the menu opening anyway
   inst.action_requested="menu"
  end
 end

 -- actually start the game
 -- or open the pause menu
 -- upon button release
 if not button_pressed then
  if inst.action_requested=="start" then
   if inst.exit_transition==nil then
    -- the exit transition will
    -- trigger the start of the
    -- game
    inst.exit_transition=transition(0,0,true)
   end
   inst.action_requested=nil
   return
  elseif inst.action_requested=="menu" then
   extcmd("pause")
   inst.action_requested=nil
   return
  end
 end

 -- request changing the
 -- currently selected button
 if inst.menu_fully_shown
 and arrow_button_pressed
 and inst.action_requested!="change button"
 then
  -- schedule the action for
  -- when the button is
  -- released
  inst.action_requested="change button"
  sfx(5)
 end

 -- actually change selected
 -- button upon button release
 if inst.action_requested=="change button"
 and not arrow_button_pressed
 then
  inst.play_btn_selected=not inst.play_btn_selected
  inst.action_requested=nil
  return
 end

 -- make the dog run and jump,
 -- or skip if needed
 if dog.x<150 then
  if not button_pressed then
   dog.x+=scroll_speed
   if (abs(dog.x-60)<3
    or abs(dog.x-116)<3)
   and dog.dz==0
   then
    dog.dz=-jump_acc
    sfx(0)
   end
  else
   -- skip dog animation
   dog.x=150
  end
  dog._update()
 end

 -- make the human run after
 -- the dog, or skip if needed
 if human.x<150 then
  if not button_pressed then
   if dog==nil or dog.x>=40 then
    human.x+=scroll_speed
   end
  else
   -- skip human animation
   human.x=150
  end
  human._update()
 end

 -- if the human has reached
 -- far enough, animate in the
 -- logo
 if human.x>110 then
  inst.logo_y+=inst.logo_dy
  if (inst.logo_dy<=0 and inst.logo_y<=18)
  or button_pressed
  then
   -- logo animation finished,
   -- either the logo has
   -- reached its target y (18)
   -- after bouncing or the
   -- animation has been
   -- skipped
   inst.logo_y=18
   inst.logo_dy=0
  elseif inst.logo_y<18 then
   inst.logo_dy+=0.15
  else
   inst.logo_dy-=0.4
  end
 end

 -- ensure author is shown
 -- once the logo has moved
 -- far enough
 if not inst.finished
 and not inst.show_author
 and inst.author_y>30
 then
  inst.show_author=inst.logo_dy<=0
   and inst.logo_y<=23
  if inst.show_author then
   -- show author, but only for
   -- a little while
   inst.pause=100
   if not button_pressed then
    sfx(7)
   end
  end
 end

 -- once the author's name has
 -- been shown for long enough,
 -- animate it out
 if inst.show_author
 and (inst.pause==0
  or button_pressed)
 then
  if inst.author_y>30
  and not button_pressed
  then
   inst.author_y-=1
  else
   inst.author_y=30
   inst.show_author=false
  end
 end

 -- if the author text is out,
 -- we consider the intro
 -- finished, time to show the
 -- menu
 if inst.author_y==30
 and not inst.show_author
 and not button_pressed
 and not inst.finished
 then
  inst.finished=true
 end

 -- if the menu is to be shown
 -- but hasn't expanded yet,
 -- make it expand to its
 -- target size
 if inst.finished then
  if inst.menu_bg_y2<94 then
   inst.menu_bg_y2+=3
  elseif not inst.menu_fully_shown then
   inst.menu_bg_y2=94
   inst.menu_fully_shown=true
   sfx(7)
  end
 end

 -- progress background
 -- animation
 inst.bg_frame_aux+=1
 if inst.bg_frame_aux==10 then
  inst.bg_frame_aux=0
  inst.bg_frame+=1
  if inst.bg_frame>#patterns then
   inst.bg_frame=1
  end
 end

 -- progress pause
 if inst.pause>0 then
  inst.pause-=1
 end
end

local function draw(inst)
 -- yellow for transparencies
 palt(0, false)
 palt(10, true)

 -- background pattern
 local pattern=nil
 if inst.bg_frame<1 then
  pattern=initial_patterns[inst.bg_frame+#initial_patterns]
 else
  pattern=patterns[inst.bg_frame]
 end
 fillp(pattern)
 rectfill(0,0,127,127,1)

 -- restore default pattern
 fillp(0b0000000000000000)

 -- draw menu if needed
 if inst.finished then
  rectfill(
   24,
   30,
   inst.menu_bg_x2,
   inst.menu_bg_y2,
   0
  )
  if inst.menu_fully_shown then
   local selected_bg=2
   if button_pressed then
    selected_bg=14
   end

   -- draw play button
   if inst.play_btn_selected then
    rectfill(29,50,98,62,selected_bg)
    rect(29,50,98,62,7)
   else
    rect(29,50,98,62,2)
   end
   print("play",57,54,7)

   -- draw menu button
   if not inst.play_btn_selected then
    rectfill(29,67,98,79,selected_bg)
    rect(29,67,98,79,7)
   else
    rect(29,67,98,79,2)
   end
   print("menu",57,71,7)

   -- draw footer
   print("v1.0",83,86,13)
  end
 end

 -- dog and human
 dog._draw()
 human._draw()

 -- logo and author text
 if inst.show_author then
  local msg="by ernestoyaquello"
  print(msg,29,inst.author_y+1,0)
  print(msg,28,inst.author_y,6)
 end
 sspr(0,64,80,24,24,inst.logo_y+6,80,24)

 -- exit transition
 if inst.exit_transition!=nil then
  inst.exit_transition._draw()
 end
end

function create_intro_screen()
 -- recreate the global
 -- variables the human and
 -- the dog expect to find,
 -- including themselves
 scroll_speed=1
 gravity=0.35
 jump_acc=3.5
 dog=create_dog(-50,70)
 human=create_human(-20,70)

 local instance={
  bg_frame=-1,
  bg_frame_aux=0,
  logo_y=-32,
  logo_dy=1,
  menu_bg_x2=103,
  menu_bg_y2=31,
  show_author=false,
  author_y=50,
  pause=0,
  menu_fully_shown=false,
  finished=false,
  play_btn_selected=true,
  action_requested=nil,
  exit_transition=nil,
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
-- game over message info --

local function update(inst)
 -- allow the user to skip the
 -- animation with a button
 -- press once the first line
 -- has already been shown (its
 -- animation won't be
 -- skippable, but it will
 -- last very very little, so
 -- that's fine actually)
 local skip_anim=(btn(❎) or btn(🅾️))
  and inst.texts_to_show_chars>=28
  and inst.shake==0
 if skip_anim then
  -- no pause needed when
  -- skipping animations
  inst.temp_pause=0
 end

 -- message is in right place
 inst.x=human.x-human_offset_x+3
 inst.y=35

 -- make the rectangle expand
 -- if needed:
 local target_x2=human.x-human_offset_x+123
 local target_y2=99

 -- 1.a get closer to x target
 if not skip_anim
 and inst.x2<target_x2
 and inst.temp_pause==0
 then
  inst.x2+=8
 end

 -- 1.b ...or reach x target
 if inst.x2>=target_x2
 or skip_anim
 then
  inst.x2=target_x2
 end

 -- 2.a get closer to y target
 if not skip_anim
 and inst.y2<target_y2
 and inst.temp_pause==0
 then
  inst.y2+=1.5
 end

 -- 2.b ...or reach y target
 if inst.y2>=target_y2
 or skip_anim
 then
  inst.y2=target_y2
 end

 -- ensure text is shown once
 -- the rectangle is expanded
 -- to its target size, making
 -- sure to make it appear
 -- one character at a time
 local show_text=inst.x2==target_x2
  and (inst.y2==target_y2
   or (inst.texts_to_show_chars==0))
 if show_text then
  if skip_anim then
   -- skip the text animation
   -- and show all the text
   -- directly
   inst.texts_to_show_chars=28*5
   -- ensure message about
   -- pressing to restart
   -- appears immediately
   inst.counter=50
  elseif inst.temp_pause==0 then
   local total_chars=#inst.texts*28
   if inst.texts_to_show_chars<=total_chars then
    -- show next character, or
    -- the whole line (28
    -- characters) if this is
    -- the first line
    if inst.texts_to_show_chars>0 then
     inst.texts_to_show_chars+=1
    else
     inst.texts_to_show_chars=28
     -- ensure the first line is
     -- shaken when shown (for
     -- dramatic effect, as it
     -- is the line that tells
     -- the user about the game
     -- over)
     inst.shake=1
    end

    -- make a sound as soon as
    -- a line is almost fully
    -- shown, except for the
    -- first line, as it
    -- doesn't show a score
    if inst.texts_to_show_chars>28
    and inst.texts_to_show_chars%25==0
    then
     sfx(2)
    end

    -- check if a new line
    -- has been reached, and
    -- if so, make a pause
    -- before the next one
    -- (unless this is the
    -- last one, in which case
    -- no pause after it is
    -- needed)
    if inst.texts_to_show_chars<total_chars
    and inst.texts_to_show_chars%28==0
    then
     inst.temp_pause=30
    end
   end
  end

  -- ugly code to ensure
  -- characters are shown one
  -- by one
  inst.texts_to_show={}
  local all_text_shown=true
  local aux_count=inst.texts_to_show_chars
  for _,text in ipairs(inst.texts) do
   inst.texts_to_show[#inst.texts_to_show+1]={text[1],""}
   local aux_text=""
   local i_max=min(#text[2],aux_count)
   for i=1,i_max do
    aux_text=aux_text..text[2][i]
    aux_count-=1
   end
   inst.texts_to_show[#inst.texts_to_show][2]=aux_text
   if aux_count==0 then
    all_text_shown=false
    break
   end
  end
  if all_text_shown
  and not inst.finished
  then
   -- the game over information
   -- is all on the screen now,
   -- so the user will be able
   -- to restart the game
   inst.finished=true

   -- if this is a new record,
   -- take a screenshot
   if dget(0)==meters+10*bones_count then
    extcmd("screen")
   end
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

 -- progress the temporary
 -- pause by reducing it if
 -- needed (when zero, the
 -- pause will be considered
 -- finished)
 if inst.temp_pause>0 then
  inst.temp_pause-=1
 end

 -- shake the text if needed
 if inst.shake!=0 then
  inst.text_offset_x=4-rnd(8)
  inst.text_offset_y=4-rnd(8)
  inst.text_offset_x*=inst.shake
  inst.text_offset_y*=inst.shake

  inst.shake/=1.6
  if inst.shake<0.05 then
   inst.shake=0
   inst.text_offset_x=0
   inst.text_offset_y=0
  end
 end
end

local function draw(inst)
 -- draw background rectangle,
 -- its border and its shadow
 rectfill(
  inst.x+1,
  inst.y+1,
  inst.x2-1,
  inst.y2-1,
  0
 )
 rect(
  inst.x+1,
  inst.y+1,
  inst.x2+1,
  inst.y2+1,
  0
 )
 rect(
  inst.x,
  inst.y,
  inst.x2,
  inst.y2,
  2
 )

 -- draw the texts with the
 -- game over information
 if inst.texts_to_show!=nil then
  local text_y=inst.y+6
  for i,text in ipairs(inst.texts_to_show) do
   local y_offset=0
   if i==1 then
    y_offset=2
   end
   print(
    text[2],
    inst.x+5+inst.text_offset_x,
    text_y+y_offset+inst.text_offset_x,
    text[1]
   )
   text_y+=11+2*y_offset
  end
 end

 -- draw the blinking text
 -- that tells the user to
 -- press a button to restart
 if inst.finished
 and inst.counter>50
 then
  local msg="press to restart"
  print(msg,inst.x+27,inst.y+85,0)
  print(msg,inst.x+26,inst.y+84,7)
 end
end

function create_game_over_msg()
 -- adds dots between a and b
 -- to ensure the final string
 -- is exactly 28 characters
 -- long
 local function concat(a,b)
  local result=a
  for _=1,28-#a-#b do
   result=result.."."
  end
  return result..b
 end

 local texts={
  {13, "    you've been caught!     "},
  {7,concat("distance","1 x "..meters.." = "..meters)},
  {15,concat("bones","10 x "..bones_count.." = "..(10*bones_count))},
  {14,concat("total score",tostr(meters+10*bones_count))},
  {14,concat("personal best",tostr(dget(0)))},
 }
 local instance={
  x=human.x-human_offset_x+3,
  y=35,
  x2=human.x-human_offset_x+3,
  y2=35,
  texts=texts,
  texts_to_show=nil,
  texts_to_show_chars=0,
  finished=false,
  counter=0,
  temp_pause=10,
  shake=0,
  text_offset_x=0,
  text_offset_y=0,
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
  for col in all(colswap) do
   -- apply color swap
   pal(col[1],col[2])
  end
 end
 local col,row=0,0
 while row<#sprts-1 do
  while col<#sprts[row+2] do
   local sprite=sprts[row+2][col+1]
   spr(
    abs(sprite),
    col*8+offset.x,
    (row*8+offset.y)+offset.z,
    1,1,
    sprite<0
   )
   col+=1
  end
  row+=1
  col=0
 end
 if colswap~=nil then
  for col in all(colswap) do
   -- restore color after swap
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
   fix[1]=min(fix[1],-0.5)
  else
   -- push right
   fix[1]=obs_x2-x
   fix[1]=max(fix[1],0.5)
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
   fix[2]=min(fix[2],-0.5)
  else
   -- push down
   fix[2]=obs_y2-y
   fix[2]=max(fix[2],0.5)
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
  fix[3]=min(fix[3],-0.5)
 else
  -- no collision found
  return nil
 end

 return fix
end

-- performs a simple transition
-- to allow moving from one
-- screen to another nicely
function transition(x,y,exit)
 local patterns={
  0b1111111111111111.1,
  0b0111011101110111.1,
  0b0011001100110011.1,
  0b0001000100010001.1,
  0b0000000000000000.1,
 }

 local start=patterns[1]
 if not exit then
  local start=patterns[#patterns]
 end

 local instance={
  x=x,
  y=y,
  counter=0,
  current=start,
  finished=false,
 }

 instance._update=function()
  local i=flr(instance.counter/5)+1
  if not exit then
   -- the order for the
   -- patterns is inverted
   -- for enter transitions
   i=#patterns-i+1
  end

  if i>=1 and i<=#patterns then
   instance.current=patterns[i]
   instance.counter+=1
  else
   instance.finished=true
  end
 end

 instance._draw=function()
  -- draw black vertical lines
  fillp(instance.current)
  rectfill(
   instance.x,
   instance.y,
   instance.x+127,
   instance.y+127,
   0
  )

  -- restore everything
  fillp(0b0000000000000000)
 end

 return instance
end
__gfx__
00000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbaaaaaaaaaaaaaaaaaaaaaaaaa00000000aaaaaaaaaf0aaaaa
00000000aaaaaaaaaaaaaaaaaaaaa0aaaaaaa0aaaaaaaaaaaaaaaaaaaaaaaaaaaaa3bbbbbbbbbbb3aaaaaaaaaaaaaaaaaf0aaaaa00000000af0aaaaaaffaaaaa
007007004aaaa0aaaaaaa0aaaaaaa44aaaaaa44aaaaaa0aa4aaaa0aaaaaaaaaaa333bbbbbbbbbbb33aaaaaaaaaaaaaaaaffaaaaa00000000affaaaaaaddbbbaa
000770004aaaa44a4aaaa44a4aaa80404aaa80404aaaa44a4aaaa44aaabbbbb331d3bbbbbbbbbbb31333bbaaaaaaaaaaaddbbbaa00000000addbbbaaadd333aa
00077000a44480404a4480404a4480444a4480444a448040a4448040abbbbb3111d3bbbbbbbbbbb3103b3b1aaaaaaaaaadd333aa00000000add333aaddd333aa
00700700a4448044a4448044a444484aa44448aaa4448044a44480446bbbbb3111d3bbbbbbbbbbb31133bb30aaaaa0fdddd333aa00000000ddd333aaa11333aa
00000000aa4448aaa44448aaa444aaaa444444aaa44448aaa44448aa3bbbbb3111d3bbbbbbbbbbb3103b3b10aaaaa9aaa11333aa00000000a11333aaa10aaaaa
00000000aa44aaaaaa4a4aaaa4aaaaaaaaaaaa4a4aaaa4aaaaaa4aaa3bbbbb3111d33333333333331133bb30aaaaa99991aaaaaa00000000991aaaaa91aaaaaa
666666665655555556555555666666666666666666666666aaaaaaaa3bbbbb311331111113111111303b3b10aa0009a91a9000aaaa0009a9a19000aa119000aa
666666665555565555555655666666666666666666666666aaadddaa3bbbbbb331111111131111111333bb30a0aa90a91a09aa0aa0aa90a0a109aa0a0a09aa0a
666666665555555555555555666666666666666666666666aadd6dda3b3333333333333333333333333338e00aa9aa0099999aa00aa9aa0a09999aa099999aa0
666666665555555555555555555555556666666666666666a5ddddda633333333333333333333333333338850aaaaa0aa0aaaaa00aaaaa0aa0aaaaa0a0aaaaa0
666666665565555555655555556555556666666666666666a55d5d5a76333333111333333333331113333315a0aaa0aaaa0aaa0aa0aaa0aaaa0aaa0aaa0aaa0a
666666665555556555555555555555656666666666666666a155555a5133333155513333333331555133331aaa000aaaaaa000aaaa000aaaaaa000aaaaa000aa
666666665555555550505050555555556777777777666666aa1111aaa511111055501111111110555011115aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
666666665555555505050505555555556777777777666666aaaaaaaaaa5555550005555555555500055555aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaa0aaaaaaa0aaaaaaa0aaaaaaaaaa4aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa22aaaaa0009a11a9000aaaf0aaaaa
aaaaaaaaaaaaa0aaaaaaa44aaaaaa44a4aaaa44a4aaaa0aa4aaaa0aa4aaaa0aaaaaaa0aaaaaaaaaaaaaaaaaaaaaaaaaaaa222aaaa0aa90a0a109aa0aaffaaaaa
aaaaa0aaaaaaa44aaaaa80404aaa80404aaa80404aaaa44aa4aaa44a4aaaa44a4aaaa44a4aaaa0aaaaaaaaaaaaaaaaaaaa222aaa0aa9aa0a09999aa0addbbbaa
4aaaa44a4aaa80404aa480444a448044a4448044a4aa8040444a8040a44a80404aaa80404aaaa44aaaaaaaaaaaaaaaaaaaf22faa0aaaaa0aa0aaaaa0add333aa
4a4480404a4480444a4448aaa44448aa444448aa444480444444804444448044a4448044a4448040aaaaaaaaaaaaaaaaaaaccaaaa0aaa0aaaa0aaa0addd333aa
a4448044a44448aaa44444aa444444aa444444aa444448aa444448aa444448aaa44448aaa4448044aaa0faaaaaaaaaaaaaaccaaaaa000aaaaaa000aaa11333aa
a44448aa444444aa444aaaaa44aaaaaa44aaa4aa444444aaa4a444aa44a444aaa4a44aaaa4a448aaaaaffaaaaaa0faaaaaaccaaaaaaaaaaaaaaaaaaaa10aaaaa
aaa44aaa44aaaaaa44aaaaaaaaaaaaaaaaaaaaaaaaaaa4aaaaaaa4aaa4aa4aaaa4aa4aaaaa4a4aaaaa222aaaaaaffaaaaaa11aaaaaaaaaaaaaaaaaaa11aaaaaa
aaaaa9aaaaaaa4aaaaaaaaaaaaaaaaaa000000000000000000000000565555555050505050505050a2a222faaa222aaaaaa22aaaaaa22aaaaaa22aaaaa222aaa
aaaa979aaaaa474aaaaaaaaaaaaaaaaa000000000000000000000000555556550505050505050505afa22aaaaaf22aaaaaa22aaaaaa22aaaaa222aaaaaf222fa
aaaa9779aaaa4774aaaafaaaaaaaa0aa000000000000000000000000555555555050505050505050aaa22aaaaaa22faaaaa22aaaaaa22aaaaa222aaaaaa22aaa
aaa97eeaaaa4722aaaaaffaa4aaaa44a000000000000000000000000555555550505050505050505aaaccaaaaaa22aaaaaaf2aaaaaa2faaaaaf22faaaaacccaa
a997eaaaa4472aaaaaafaaaa4a448040000000000000000000000000505050505050505050505050aaacacaaaaaccaaaaaaccaaaaaaccaaaaaaccaaaaaacacaa
977eaaaa4772aaaaaffaaaaaa4448044000000000000000000000000050505050505050505050505a1caaacaaaaccaaaaaaccaaaaaaccaaaaaacacaaaacaaa1a
a96eaaaaa462aaaaaafaaaaaa44448aa000000000000000000000000505050505555555550505050aaaaaaa1aa1cacaaaaa1caaaaaac1aaaaacaa1aaaa1aaaaa
aaeaaaaaaa2aaaaaaaaaaaaaaa44a4aa000000000000000000000000050505055555555505050505aaaaaaaaaaaaa1aaaaaa1aaaaaa1aaaaaa1aaaaaaaaaaaaa
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
0000000000000000000000000000000000000000000000000000000000000000000000000000aaaa000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000aaa000000000000000000000000000000000000000000000000
0077000077777777777777777700eee00eee00eee00eee00eee00eee0077777777777777777000aa000000000000000000000000000000000000000000000000
0099000099999999999999999900eee00eee00eee00eee00eee00eee00999999999999999997000a000000000000000000000000000000000000000000000000
00990000990000000000000000000000000000000000000000000000000000000000009999997000000000000000000000000000000000000000000000000000
00990000990000000000000000000000000000000000000000000000000000000000009900099700000000000000000000000000000000000000000000000000
00990000990077000077007700000007777700007700000777770077007700077777009900009900000000000000000000000000000000000000000000000000
00990000990099700099009900000079999900079970007999990099009900799999009900009900000000000000000000000000000000000000000000000000
00990000990099900099009900000099000000790097009900000099009900990000009900009900000000000000000000000000000000000000000000000000
00990000990099970099009900000099000000990099009900000099009900990000009900009900000000000000000000000000000000000000000000000000
00990000990099990099009900000099777700997799009977770099779900997777009900009900000000000000000000000000000000000000000000000000
00990000990099097099009900000099999900999999000999990099999900999999009900009900000000000000000000000000000000000000000000000000
00990000990099099099009900000099000000990099000000990099009900990000009900009900000000000000000000000000000000000000000000000000
00990000990099009799009900000099000000990099000000990099009900990000009900009900000000000000000000000000000000000000000000000000
00990000990099009999009977770099777700990099007777990099009900997777009900009900000000000000000000000000000000000000000000000000
00990000990099000999009999990099999900990099009999990099009900999999009900009900000000000000000000000000000000000000000000000000
00997777990022000222002222220022222200220022002222220022002200222222009977779900000000000000000000000000000000000000000000000000
00999999990022000222002222220022222200220022002222220022002200222222009999999900000000000000000000000000000000000000000000000000
00222222220000000000000000000000000000000000000000000000000000000000002222222200000000000000000000000000000000000000000000000000
00222222220000000000000000000000000000000000000000000000000000000000002222222200000000000000000000000000000000000000000000000000
000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000000000000000000000000000000000000000000000000000000000000
a0000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0000000000a000000000000000000000000000000000000000000000000
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000000000000000000000000000000000000000000000000
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5aaaaaaaaaaa5aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5555555555555aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5000500050005aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5aaa55555aaa5aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5aaa55555aaa5aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaa50005aaa0aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0555555555550aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaa0aaa0aaa0aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaa0aaa0aaa0aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaa0aaa0aaa0aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaa0aaa0aaa0aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaa0aaa0aaa0aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0555055505550aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaa05550aaa0aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaa05550aaa0aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaa00000aaa0aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0555055505550aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaa0aaa0aaa0aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9aaa9aaa9aaa9aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
92aa9aaa9aa69aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
92aa9aaa9aa69aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9222926696669aaaaa9999aa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9228987797669aaaa999099a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9228988797669aaaa990999a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9220905095669aaaa990099a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0825050500670aaaaa9999aa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8882026606777aaaaa6aa6aa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8888887777777aaaa600006a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8888888777777aaaaaaaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
66666611dd11dd11dd11dd11dd11dd11dd11dd11dd11dd116666666666666611dd11dd11dd11dd11dd11dd11dd11dd11dd11dd116666666666666611dd11dd11
dccc11dd11dd11dd11dd11dd11d111dd11dd11dd11dd11dd11666666666611dd11dd11dd11dd11dd11d111dd11dd11dd11dd11dd11666666666611dd11dd11dd
1d122222222222222222dd222222222222222221dd11dd11dd1166666611dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd1166666611dd11dd11dd11
11d222222222222222220122222222222222222011dd11dd11dd166661dd11dd11dd11dd11dd11dd111d11dd11dd11dd11dd11dd11dd166661dd11dd11dd11dd
111222222272727772220d222222f2222fff2220dd11dd11dd1116666111dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd1116666111dd11dd11dd11
11d2222222727272722201222222ff222f2f222011dd11dd11dd166661dd11dd11dd11dd11dd11dd11d111dd11dd11dd11dd11dd11dd166661dd11dd11dd11dd
111222222277727272220d22222f22222fff2220dd11dd11dd1116666111dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd1116666111dd11dd11dd11
d1d2222222227272722201222ff222222f2f222011dd11dd11dd166661dd11dd11dd11dd11dd11dd111d11dd11dd11dd11dd11dd11dd166661dd11dd11dd11dd
d11222222222727772220d2222f222222fff2220dd11dd11dd1116666111dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd1116666111dd11dd11dd15
d1d222222222222222220122222222222222222011dd11dd11dd166661dd11dd11dd11dd11dd11dd11d111dd11dd11dd11dd11dd11dd166661dd11dd11dd11d5
d11222222222222222220d222222222222222220dd11dd11dd1116666111dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd1116666111dd11dd11dd15
11dd000000000000000001d0000000000000000011dd11dd11dd166661dd11dd11dd11dd11dd11dd111d11dd11dd11dd11dd11dd11dd166661dd11dd11dd11d2
0111dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd1116666111dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd1116666111dd11dd11dd15
51dd11dd11dd11dd11dd11dd11d111dd11dd11dd11dd11dd11dd166661dd11dd11dd11dd11dd11dd11d111dd11dd11dd11dd11dd11dd166661dd11dd11dd11d2
6111dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd1116666111dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd1116666111dd11dd11dd15
61dd11dd11dd11dd11dd11dd111d11dd11dd11dd11dd11dd11dd166661dd11dd11dd11dd11dd11dd111d11dd11dd11dd11dd11dd11dd166661dd11dd11dd11d2
6111dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd1116666111dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd1116666111dd11dd11dd15
61dd11dd11dd11dd11dd11dd11d111dd11dd11dd11dd11dd11dd166661dd11dd11dd11dd11dd11dd11d111dd11dd11dd11dd11dd11dd166661dd11dd11dd11d2
6111dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd1116677111dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd1117776111dd11dd11dd15
61dd11dd11dd11dd11dd11dd111d11dd11dd11dd11dd11dd11dd166771dd11dd11dd11dd11dd11dd111d11dd11dd11dd11dd11dd11dd177761dd11dd11dd11d2
6111dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd1116666111dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd1116666111dd11dd11dd15
61dd11dd11dd11dd11dd11dd11d111dd11dd11dd11dd11dd11dd166661dd11dd11dd11dd11dd11dd11d111dd11dd11dd11dd11dd11dd166661dd11dd11dd11d0
6111dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd1116666111dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd1116666111dd11dd11dd11
61dd11dd11dd11dd11dd11dd111d11dd11dd11dd11dd11dd11dd166661dd11dd11dd11dd11dd11dd111d11dd11dd11dd11dd11dd11dd166161dd11dd11dd11dd
6111dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd1116666111dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd11dd1116016111dd11dd11dd11
61dd11dd11dd11dd11dd11dd110011dd11dd11dd11dd11dd11dd166661dd11dd11dd11dd11dd11dd110011dd11dd11dd11dd11dd11dd161161dd11dd11dd11dd
6111dd11dd11dd11dd11dd1105665011dd11dd11dd11dd11dd1116666111dd11dd11dd11dd11dd1105665011dd11dd11dd11dd11dd1116016111dd11dd11dd11
61dd11dd11dd11dd11dd11056666665011dd11dd11dd11dd11dd166661dd11dd11dd11dd11dd11056666665011dd11dd11dd11dd11dd161161dd11dd11dd11dd
6111dd11dd11dd11dd110566665566665011dd11dd11dd11dd1116666111dd11dd11dd11dd110566665566665011dd11dd11dd11dd1116061111dd11dd11dd11
61dd11dd11dd11dd1105666655555566665011dd11dd11dd11dd166661dd11dd11dd11dd1105666655555566665011dd11dd11dd11dd166111dd11dd11dd11dd
6111dd11dd11dd1105666655d5dd5d5566665011dd11dd11dd1116666111dd11dd11dd11056666554544545566665011dd11dd11dd1116666111dd11dd11dd11
61dd11dd11dd1105666655d5dd55dd5d5566665011dd11dd11dd166661dd11dd11dd110566665545445544545566665011dd11dd11dd166661dd11dd11dd1105
6111dd11dd1105666655d5dd5dddd5dd5d5566665011dd11dd1116666111dd11dd1105666655454454444544545566665011dd11dd1116611111dd11dd110566
61dd11dd1105666655d5dd5dddddddd5dd5d5566665011dd11dd166661dd11dd11056666554544544444444544545566665011dd11dd161551dd11dd11056666
6111dd1105666655d5dd5dddddddddddd5dd5d5566665011dd1116666111dd110566665545445444444444444544545566665011dd1111055111dd1105666655
61dd1105666655d5dd5dddddddddddddddd5dd5d5566665011dd166661dd1105666655454454444444444444444544545566665011dd155001dd110566665545
611105666655d5dd5dddddddddddddddddddd5dd5d55666650111666611105666655454454444444444444444444454454556666501116666111056666554544
6155666655d5dd5dddddddddddddddddddddddd5dd5d556666551666615566665545445444444444444444444444444544545566665516666155666655454454
65666655d5dd5dddddddddddddddddddddddddddd5dd5d5566665666656666554544544444444444444444444444444445445455666656666566665545445444
5566665d5d5dddddddddddddddddddddddddddddddd5d5d566665555556666545454444444444444444444444444444444454545666655555566665454544444
65566655dddddddddddddddddddddddddddddddddddddd5566655555655666554444444444444444444444444444444444444455666555556556665544444444
5556555d5dddddddddddddddddddddddddddddddddddd5d555656555555655545444444444444444444444444444444444444545556565555556555454444444
5556665dddddddddddddddddddddddddddddddddddddddd566655555555666544444444444444444444444444444444444444445666555555556665444444444
55566655dddddddddddddddddddddddddddddddddddddd5566655555555666554444444444444444444444444444444444444455666555555556665544444444
5556555d5dddd666666666dddddddddd666666666dddd5d555655556555655545444466666666644444444446666666664444545556555565556555454444666
5556665ddddd65555555556dddddddd65555555556ddddd566655555555666544444655555555564444444465555555556444445666555555556665444446555
55566655dddd60000000006dddddddd60000000006dddd5566655555555666554444600006000064444444460000600006444455666555555556665544446000
5556555d5ddd60ddddddd06dddddddd60ddddddd06ddd5d55565555555565554544460dd060dd064444444460dd060dd064445455565555555565554544460dd
5006665ddddd60111111106dddddddd60111111106ddddd566605050500666544444601106011064444444460110601106444445666050505006665444446011
05066655dddd60111111106dddddddd60111111106dddd5566600505050666554444600006000064444444460000600006444455666005050506665544446011
5006555d5ddd60000000006dddddddd60000000006ddd5d555605050500655545444666666666664444444466666666666444545556050505006555454446000
0506665ddddd66666666666dddddddd66666666666ddddd566600505050666544444600006000064444444460000600006444445666005050506665444446666
50066655dddd60000000006dddddddd60000000006dddd556660505050066655444460dd060dd064444444460dd060dd06444455666050505006665544446000
0506555d5ddd60000000006dddddddd60000000006ddd5d555600505050655545444601106011064444444460110601106444545556005050506555454446000
5006665ddddd60000000006dddddddd60000000006ddddd566605050500666544444600006000064444444460000600006444445666050505006665444446000
05066655dddd66666666666dddddddd66666666666dddd5566600505050666554444666666666664444444466666666666444455666005050506665544446666
5006555d5dd5555555555555dddddd5555555555555dd5d555605050500655545445555555555555444444555555555555544545556050505006555454455555
0506665dddddddddddddddddddddddddddddddddddddddd566600505050666544444444444444444444444444444444444444445666005050506665444444444
50066655dddddddddddddddddddddddddddddddddddddd5566605050500666554444444444444444444444444444444444444455666050505006665544444444
050655555dddddddddddddddddddddddddddddddddddd55555600505050655555444444444444444444444444444444444444555556005050506555554444444
50066665d5d5d5d5d5d5d5d5d5555d5d5d5d5d5d5d5d5d5666605050500666654545454545454545455554545454545454545456666050505006666545454545
050666655d5d5d5d5d5d5d5d556655d5d5d5d5d5d5d5d55666600505050666655454545454545454556655454545454545454556666005050506666554545454
50066665555555555555555555555555555555555555555666605050500666654545454545454545455554545454545454545456666050505006666545454545
05666666666666666666666666666666666666666666666666660505050655555444444444444444444444444444444444444555556005050506555554444444
50555555555555555555555555555555555555555555555555555050500666554444444444444444444444444444444444444455666050505006665544444444
05111111111111111111111111111111111111111111111111110505050656545444444444444444444444444444444444444545656005050506565454444444
5011f1f1f1f1f1f1f1f1f1777171717771f1f1f1f1f1f1ff1f115050500666544444444444444444444444444444444444444445666050505006665444444444
051f1f1f1f1f1f1f1f1f117771717177711f1f1f1f1f1f11f1f10505050656554444444444444444444444444444444444444455656005050506565544444444
5011f1f1f1f1f1f1f1f1f1711177717771f1f1f1f1f1f1ff1f115050500666545444466666666644444444446666666664444545666050505006665454444666
05111111111111111111111111111111111111111111111111110505050656544444655555555564444444465555555556444445656005050506565444446555
50000000000000000000000000000000000000000000000000005050500666554444600000000064444444460000600006444455666050505006665544446000
050655560f0105050101010104010101010101010101006555600505050656545444600000000064444444460dd060dd064445456560050505065654544460dd
5006666600f010501010101020201010101010101010206666605050500666544444600d0d0d0064444444460110601106444445666050505006665444446011
0506555601011555111111122226111611111117111f006555600505050656554444600101010064444444460000600006444455656005050506565544446011
5006666600411555555555f4556665666555eee9ef50206666605050500666545444600000000064444444466666666666444545666050505006665454446000
0506555601011555555555ff556665666555eeeee222006555600505050656544444600d0d0d0064444444460000600006444445656005050506565444446666
5006666600111ddddddddddddddddddddddddddddd20206666605050500666554444600101010064444444460dd060dd06444455666050505006665544446000
0506555601011ddddddddd4dddddddddddddddddddcc006555600505050656545444600000000064444444460110601106444545656005050506565454446000
5006666600111fddddddd343ddddddddddddd7ddddc0c06666605050500666544444600d0d0d0064444444460000600006444445666050505006665444446000
0506555601017f6111111333311111111747474411c1006555600505050656554444600101010064444444466666666666444455656005050506565544446666
50066666001777647444433431111111474744444100006666605050500666545445600000000065444444555555555555544545666050505006665454455555
050655560107f6649447444c41111111444444444111006555600505050656544444600505050064444444444444444444444445656005050506565444444444
50066666001fdd444449444c11111111114444411110106666605050500666554445600050500065444444444444444444444455666050505006665544444444
050655560101010104040000010101010101010101010065556005050506565454546005050500645f0444444444444444444555656005050506565554444444
500666660010202010001010101010101010001010101066666050505006665545456000000000654ff454545454545454545455666050505006665545454545
050655560000000000000000000000000000000000000065556005050506565554556000000000655dd999454545454545454555656005050506565554545454
500666667777777777777777777777777777777777777766666050505006667777776303030303677dd888777777777777777777666050505006667777777777
050655566666666666666666666666666666666666666665556005050506566666666d3d3d3d30fdddd888666666666666666666656005050506566666666666
50666666666666666666666666666666666666666666666666660050506666666666639393939966611888666666666666666666666600505066666666666666
006555556666666666666666666666666666666666666655555605050065556666666f3f3f3f3999991666666666666666666666555605050065556666666666
55555555555555555555555555555555555555555555555555555555555555555555555555000959519000555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555550559050510955055555555555555555555555555555555555555555
55555556555555565555555655555556555555565555555655555556555555565555555605595506099995505555555655555556555555565555555655555556
55565555555655555556555555565555555655555556555555565555555655555556555505565505505655505556555555565555555655555556555555565554
55555555555555555555555555555555555555555555555555555555555555555555555550555055550555055555555555555555555555555555555555555547
55555555555555555555555555555555555555555555555555555555555555555555555555000555555000555555555555555555555555555555555555555554
6555555560f555556555555565555555655555556555555565555555655555556555555565555555655555556555555565555555655555556555555565555888
555555555ff555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555552888
50505050222050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050222888
05050505f225050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505088888221d2881
66666666622f666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666888882111d2888
666666666226666666666666666666666666666666666666666660666666666666666666666666666666666666666666666666666666666666888882111d2888
666666666cc6666666666666666666666666666666666666466664466666666666666666666666666666666666666666666666666666666662888882111d2888
666666666cc6666666666666666666666666666666666666464480406666666666666666666666666666666666666666666666666666666662888882111d2222
666666661c5c66666666666666666666666666666666666664448044666666666666666466666666666666666666666666666666666666666288888211221111
66666666555156666666666666666666666666666600666664442866666666666666664746666666666666666666666666666666666666666288888822111111
66666666655566666666666666666666666666666600222222224556666666666666664774666666666666666666666666666666666666666282222222222222
66666666666666666666666666666666666666666666666666555566666666666666647226666666666666666666666666666666666666666622222222222222
66666666666666666666666666666666666666666666666666666666666666666664472666666666666666666666666666666666666666666762222221112222
66666666666666666666666666666666666666666666666666666666666666666647726666666666666666666666666666666666666666666512222215551222
66666666666666666666666666666666666666666666666666666666666666666664626666666666666666666666666666666666666666666651111105550111
66666666666666666666666666666666666666666666666666666666666666666ccc2ccccccc6666666666666666666666666666666666666665555550005555
6666666666666666666666666666666666666666666666666666666666666666dcccccccccccd666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666dddccc1111ccccdd66666666666666666666666666666666666666666666666666
6666666777777777666666677777777766666667777777776666666cccccdd1ddcc111111cccd1dddcc666677777777766666667777777776666666777777777
666666677777777766666667777777776666666777777777666666cccccd111ddccc1111ccccd10dcdc166677777777766666667777777776666666777777777
666666666666666666666666666666666666666666666666666666cccccd111ddcccccccccccd11ddccd06666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666dcccccd111ddcccccccccccd10dcdc106666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666dcccccd111dddddddddddddd11ddccd06666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666dcccccd11dd111111d111111d0dcdc106666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666dccccccdd11111111d1111111dddccd06666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666dcddddddddddddddddddddddddddd8e06666666666666666666666666666666666666666666
666666666666666666666666666666666666666666666666666666dddddddddddddddddddddddddddd8856666666666666666666666666666666666666666666
6666666666666666666666666666666666666666666666666666676dddddd111ddddddddddd111ddddd156666666666666666666666666666666666666666666
6666666666666666666666666666666666666666666666666666651ddddd15551ddddddddd15551dddd166666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666651111105550111111111055501111566666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666665555550005555555555500055555666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666

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
__sfx__
0001000005010080100b0100f010140101b010230102e0100e000120001600016000130001400015000160001600017000180001800018000170001700017000170001600016000160000d0000d0000d0000d000
aa0100002d663286632766323653216431c6431b64317633156330f6330e6330a6330763302633006030460300603026030160300603006030060300603006030060300603006030060300603006030060300603
010200002175725757267572675725757227572075714757187571d75725757327573c7573c7573c7572770727707087070870708707087070870708707087070270702707027070270702707027070270702707
480200000e550125501455015550125500f550145501b5501f55022550235002b5002a5002e500305001650016500005000050000500005000050000500005000050000500005000050000500005000050000500
ab0200000525305253042530324303243032430323302233022330222302223022230221302213022500225002251022510225102251022510225102251022510225102251022510225102251022510225102251
0002000007030080300c0301103019030220302f03000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d60100002a66023060256601e0501f640180401a64012040146300a03007630030300063002600016000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
180300000c5570c5570e55714557195571e5572155716507195071b5072550727507295072b5072d5070050700507005070050700507005070050700507005070050700507005070050700507005070050700507
