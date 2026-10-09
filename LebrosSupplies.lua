_addon.name = 'LebrosSupplies'
_addon.version = '0.3.1'
_addon.commands = {'lebrossupplies','lsupply','lsup'}
local texts = require('texts')
local config = require('config')
local res = require('resources')
local settings = config.load({radius=6,ui={pos={x=100,y=100},text={font='Arial',size=11,red=255,green=255,blue=255,alpha=255},bg={visible=true,alpha=170,red=0,green=0,blue=0},flags={draggable=true}}})
local view = texts.new('Lebros Supplies\nKnown: ${known}\nTarget: ${target}\nGroups: ${groups}\nFood: ${food}',settings.ui)
local soldiers,groups,inventory = {},{},{}
local foods = {['seafood stewpot']=7,['bison steak']=5,['coeurl sub']=4,['bison jerky']=3,['pea soup']=2,['white bread']=1}
local last=-100
local function log(s) windower.add_to_chat(207,'[LebrosSupplies] '..s) end
local function identity()
 local p=windower.ffxi.get_player()
 return p and p.name or 'unknown'
end
local function scan()
 local ids={}
 for _,m in pairs(windower.ffxi.get_mob_array() or {}) do
  if m and m.name=='Imperial Stormer' and m.valid_target and m.id and m.index and m.x and m.y and m.z then
   local s=soldiers[m.id] or {id=m.id,points=0,full=false}
   s.x,s.y,s.z,s.index=m.x,m.y,m.z,m.index
   s.range=m.distance and math.sqrt(m.distance) or 999
   soldiers[m.id]=s
   ids[#ids+1]=m.id
  end
 end
 table.sort(ids)
 local parents={}
 for _,id in ipairs(ids) do parents[id]=id end
 local function root(id)
  while parents[id]~=id do parents[id]=parents[parents[id]] id=parents[id] end
  return id
 end
 for i=1,#ids do
  for j=i+1,#ids do
   local a,b=soldiers[ids[i]],soldiers[ids[j]]
   local dx,dy,dz=a.x-b.x,a.y-b.y,a.z-b.z
   if dx*dx+dy*dy+dz*dz<=settings.radius*settings.radius then
    local ra,rb=root(a.id),root(b.id)
    if ra~=rb then parents[rb]=ra end
   end
  end
 end
 groups={}
 for _,id in ipairs(ids) do
  local r=root(id)
  groups[r]=groups[r] or {ids={}}
  table.insert(groups[r].ids,id)
 end
 for r,g in pairs(groups) do
  g.size=#g.ids
  g.valid=g.size==2 or g.size==3
  for _,id in ipairs(g.ids) do soldiers[id].group=r end
 end
end
local function food_scan()
 local owned={}
 for _,item in pairs((windower.ffxi.get_items() or {}).temporary or {}) do
  if type(item)=='table' and item.id and (item.count==nil or item.count>0) then
   local entry=res.items[item.id]
   local name=entry and (entry.en or entry.enl or ''):lower() or ''
   for f in pairs(foods) do
    if name==f or name:find(f,1,true) then owned[f]=(owned[f] or 0)+(item.count or 1) end
   end
  end
 end
 inventory[identity():lower()]=owned
 local vals={}
 for f,n in pairs(owned) do vals[#vals+1]=f..'='..n end
 windower.send_ipc_message('lebros|food|'..identity()..'|'..table.concat(vals,','))
end
local function selected()
 local m=windower.ffxi.get_mob_by_target('t')
 return m and m.name=='Imperial Stormer' and soldiers[m.id] or nil
end
local function draw()
 local n,full=0,0
 for _,s in pairs(soldiers) do n=n+1 if s.full then full=full+1 end end
 local gl={}
 for key,g in pairs(groups) do gl[#gl+1]=tostring(key)..':'..g.size..(g.valid and '' or '?') end
 table.sort(gl)
 local stock={}
 for who,items in pairs(inventory) do
  for f,count in pairs(items) do stock[#stock+1]=who..' '..f..' x'..count end
 end
 table.sort(stock)
 local s=selected()
 local target_text='none'
 if s then
  local g=groups[s.group]
  target_text=tostring(s.id)..' '..string.format('%.1fy',s.range)..' '..(g and g.size or '?')..'-group '..s.points..'/7 est.'..(s.full and ' FULL' or '')
  if g and g.size==3 then target_text=target_text..' STEWPOT PRIORITY' end
 end
 view:update({known=n..'/12, confirmed full '..full,target=target_text,groups=table.concat(gl,' '),food=table.concat(stock,'; ')})
 view:show()
end
local function record(food)
 local s=selected()
 if not s or not foods[food] then log('Target a soldier; use //lsupply record <food name>') return end
 local ids={s.id}
 if food=='seafood stewpot' then
  local g=groups[s.group]
  if not g or not g.valid then log('Group size ambiguous; cannot assign stewpot AoE credit.') return end
  ids=g.ids
 end
 for _,id in ipairs(ids) do soldiers[id].points=soldiers[id].points+foods[food] end
 windower.send_ipc_message('lebros|feed|'..food..'|'..table.concat(ids,','))
 log('Recorded '..food..' for '..#ids..' soldiers (estimated, not confirmed).')
end
windower.register_event('ipc message',function(message)
 if type(message)~='string' or message:sub(1,7)~='lebros|' then return end
 local action,a,b=message:match('^lebros|([^|]+)|([^|]*)|?(.*)$')
 if action=='food' then
  local stock={}
  for f,n in tostring(b):gmatch('([^,=]+)=(%d+)') do if foods[f] then stock[f]=tonumber(n) end end
  inventory[(a or ''):lower()]=stock
 elseif action=='feed' and foods[a] then
  for id in tostring(b):gmatch('%d+') do
   local s=soldiers[tonumber(id)]
   if s then s.points=s.points+foods[a] end
  end
 elseif action=='full' then
  local s=soldiers[tonumber(a)]
  if s then s.full=true end
 end
end)
windower.register_event('prerender',function()
 if os.clock()-last>2 then last=os.clock() scan() food_scan() draw() end
end)
windower.register_event('zone change',function()
 soldiers,groups,inventory={},{},{}
 view:hide()
end)
windower.register_event('unload',function() view:hide() end)
windower.register_event('addon command',function(cmd,...)
 local args={...}
 cmd=(cmd or 'status'):lower()
 if cmd=='status' then
  local n=0 for _ in pairs(soldiers) do n=n+1 end
  log('Known '..n..' soldiers. Observer mode: never automatically spends food.')
 elseif cmd=='record' then record(table.concat(args,' '):lower())
 elseif cmd=='full' then
  local s=selected()
  if s then s.full=true windower.send_ipc_message('lebros|full|'..s.id) log('Confirmed full ID '..s.id)
  else log('Target a soldier first') end
 elseif cmd=='radius' then
  local n=tonumber(args[1])
  if n and n>=1 and n<=20 then settings.radius=n config.save(settings) scan()
  else log('Usage: //lsupply radius 1-20') end
 elseif cmd=='inspect' then
  local s=selected()
  if s then log('ID '..s.id..' estimated '..s.points..'/7 full='..tostring(s.full))
  else log('Target a soldier first') end
 else log('//lsupply status|inspect|record <food name>|full|radius <yalms>') end
end)
log('Coordinator mode available. Choose leader with //lsupply coordinator <character>.')


-- Coordinator protocol v0.2.0. Only the coordinator issues assignments.
-- Each worker reports locally visible soldiers and food. No assumed global mob array.
local leader_name = ''
local sightings = {}
local jobs = {}
local pending_job = nil
local next_job_id = 1
local last_report = -100
local last_schedule = -100
local seq = 0
local marked_groups = {} -- soldier server ID -> player-confirmed group size (2 or 3)
local marked_by = {}
local stew_groups_fed = {} -- unique 3-soldier spatial groups with confirmed stew consumption
windower.register_event('zone change',function()
 marked_groups,marked_by,jobs,sightings,stew_groups_fed={}, {}, {}, {}, {}
 pending_job=nil
end)
local function norm(x) return tostring(x or ''):lower() end
local function who_leads()
 return leader_name
end
local function is_coordinator() return norm(identity())==who_leads() end
local function send(s) windower.send_ipc_message('lebrosc|'..s) end
local function report_visible()
 local lines={}
 local mob=windower.ffxi.get_mob_array() or {}
 for _,m in pairs(mob) do
  if m and m.name=='Imperial Stormer' and m.id and m.index and m.x and m.y and m.z and m.valid_target then
   local d=m.distance and math.sqrt(m.distance) or 999
   if d<=40 then
    lines[#lines+1]=table.concat({m.id,m.index,('%.1f'):format(d),
     ('%.2f'):format(m.x),('%.2f'):format(m.y),('%.2f'):format(m.z)},',')
   end
  end
 end
 send('sight|'..identity()..'|'..table.concat(lines,';'))
end
local function coordinator_candidates()
 local candidates={}
 for worker,snap in pairs(sightings) do
  if os.clock()-snap.time<5 and worker~=who_leads() then
   for _,s in pairs(snap.mobs) do
    local stock=inventory[worker] or {}
    local kinds,n=0,nil
    for food,amount in pairs(stock) do
     if amount>0 then kinds=kinds+1 n=food end
    end
    -- If the worker has multiple food types, server selection order is unknown.
    -- Don't silently gamble the scarce temporary provisions.
    if kinds==1 and marked_groups[s.id] and not jobs[s.id] and s.range<=4.5 then
     candidates[#candidates+1]={worker=worker,s=s,food=n}
    end
   end
  end
 end
 return candidates
end
local function group_size_at(s)
 local seen={}
 for _,snap in pairs(sightings) do
  if os.clock()-snap.time<5 then
   for id,m in pairs(snap.mobs) do seen[id]=m end
  end
 end
 local n=0
 for _,m in pairs(seen) do
  local dx,dy,dz=m.x-s.x,m.y-s.y,m.z-s.z
  if dx*dx+dy*dy+dz*dz<=settings.radius*settings.radius then n=n+1 end
 end
 return n
end

local function three_group_key(s)
 -- Use live merged mob sightings to identify exactly three nearby IDs.
 -- Never count the same 3-person cluster twice under different target IDs.
 local nearby,seen={},{}
 for _,snap in pairs(sightings) do
  if os.clock()-snap.time<5 then
   for id,m in pairs(snap.mobs) do
    local dx,dy,dz=m.x-s.x,m.y-s.y,m.z-s.z
    if dx*dx+dy*dy+dz*dz<=settings.radius*settings.radius then seen[id]=true end
   end
  end
 end
 for id in pairs(seen) do nearby[#nearby+1]=id end
 if #nearby~=3 then return nil end
 table.sort(nearby)
 return table.concat(nearby,',')
end
local function stew_group_count()
 local n=0
 for _ in pairs(stew_groups_fed) do n=n+1 end
 return n
end
local function coordinate()
 if leader_name=='' or not is_coordinator() then return end
 local candidates=coordinator_candidates()
 table.sort(candidates,function(a,b)
  local aa=(a.food=='seafood stewpot' and marked_groups[a.s.id]==3) and 100 or 0
  local bb=(b.food=='seafood stewpot' and marked_groups[b.s.id]==3) and 100 or 0
  if aa~=bb then return aa>bb end
  return a.s.range<b.s.range
 end)
 local assigned={}
 for _,v in ipairs(candidates) do
  if not assigned[v.worker] then
   -- Explicit player group classification is required for EVERY assignment.
   -- Never spend stewpots on two-soldier groups or inferred group size.
   local stew=v.food=='seafood stewpot'
   local group_key=stew and three_group_key(v.s) or nil
   local priority_done=stew_group_count()>=2
   local permitted=not stew or (priority_done and marked_groups[v.s.id]==2)
     or (not priority_done and marked_groups[v.s.id]==3 and group_key and not stew_groups_fed[group_key])
   if marked_groups[v.s.id] and permitted then
    local id=next_job_id next_job_id=next_job_id+1
    jobs[v.s.id]={worker=v.worker,job=id,time=os.clock(),state='assigned',food=v.food,group_key=group_key}
    assigned[v.worker]=true
    send(table.concat({'assign',v.worker,id,v.s.id,v.s.index,v.food},'|'))
    log('Assign '..v.worker..' -> NPC '..v.s.id..' ('..v.food..')')
   end
  end
 end
 for id,j in pairs(jobs) do
  if os.clock()-j.time>12 and j.state~='completed' then
   -- Timed-out transactions are NOT retried automatically; server outcome unknown.
   j.state='uncertain'
  end
 end
end
local function accept_job(args)
 if leader_name=='' or norm(args[2])~=norm(identity()) then return end
 local job,id,index,food=tonumber(args[3]),tonumber(args[4]),tonumber(args[5]),args[6]
 if not job or not id or not index or not foods[food] or pending_job then return end
 local found=windower.ffxi.get_mob_by_id(id)
 local stock=inventory[norm(identity())] or {}
 local count=0
 for _,amount in pairs(stock) do if amount>0 then count=count+1 end end
 local range=found and found.distance and math.sqrt(found.distance) or 999
 if not found or found.index~=index or found.name~='Imperial Stormer'
  or range>4.5 or (stock[food] or 0)<1 or count~=1 then
  send('fail|'..job..'|'..id..'|precondition')
  return
 end
 -- Worker receives a single id-scoped command. Do not perform repeats.
 pending_job={job=job,id=id,food=food,before=stock[food],time=os.clock(),state='sent'}
 local ok, pk=pcall(require,'packets')
 if not ok then send('fail|'..job..'|'..id..'|no-packets') pending_job=nil return end
 pk.inject(pk.new('outgoing',0x01A,{
  ['Target']=id,['Target Index']=index,['Category']=0,['Param']=0
 }))
 log('Coordinator requested interaction with '..id..' ('..food..')')
end
local function check_pending()
 if not pending_job then return end
 local j=pending_job
 if os.clock()-j.time<1.5 then return end
 local count=(inventory[norm(identity())] or {})[j.food] or 0
 if count<j.before then
  send('consumed|'..j.job..'|'..j.id..'|'..j.food)
  log('Confirmed food consumption for NPC '..j.id..'.')
  pending_job=nil
 elseif os.clock()-j.time>5 then
  send('fail|'..j.job..'|'..j.id..'|no-inventory-change')
  log('No confirmed consumption; not retrying automatically.')
  pending_job=nil
 end
end
windower.register_event('ipc message',function(message)
 if type(message)~='string' or message:sub(1,8)~='lebrosc|' then return end
 local a={}
 for v in message:gmatch('[^|]+') do a[#a+1]=v end
 if a[2]=='leader' then leader_name=norm(a[3])
 elseif a[2]=='sight' and a[3] then
  local mobs={}
  for entry in tostring(a[4] or ''):gmatch('[^;]+') do
   local id,idx,dist,x,y,z=entry:match('^(%d+),(%d+),([%d.]+),([%d.-]+),([%d.-]+),([%d.-]+)$')
   if id then
    id=tonumber(id)
    mobs[id]={id=id,index=tonumber(idx),range=tonumber(dist),
     x=tonumber(x),y=tonumber(y),z=tonumber(z)}
   end
  end
  sightings[norm(a[3])]={time=os.clock(),mobs=mobs}
 elseif a[2]=='mark' then
  local id,size,who=tonumber(a[3]),tonumber(a[4]),norm(a[5])
  if id and (size==2 or size==3) then
   marked_groups[id]=size
   marked_by[id]=who
   if is_coordinator() then log('Player confirmed NPC '..id..' belongs to '..size..'-soldier group ('..who..')') end
  end
 elseif a[2]=='assign' then accept_job(a)
 elseif (a[2]=='consumed' or a[2]=='fail') and is_coordinator() then
  local job,id=tonumber(a[3]),tonumber(a[4])
  local entry=id and jobs[id]
  if entry and entry.job==job then
   if a[2]=='consumed' then
    entry.state='completed'
    if entry.food=='seafood stewpot' and entry.group_key and not stew_groups_fed[entry.group_key] then
     stew_groups_fed[entry.group_key]=true
     log('Three-soldier group stewpot deliveries: '..stew_group_count()..'/2')
     if stew_group_count()==2 then log('Stewpot reserve released: two-soldier groups now eligible.') end
    end
    -- This proves consumption, not satisfaction or AoE group completion.
    log('Food consumed on NPC '..id..'; satisfaction unconfirmed.')
   else entry.state='uncertain'
    log('Assignment '..job..' unresolved on NPC '..id..': '..tostring(a[5]))
   end
  end
 end
end)
windower.register_event('prerender',function()
 local t=os.clock()
 if t-last_report>1 then
  last_report=t
  report_visible()
  check_pending()
 end
 if t-last_schedule>2 then last_schedule=t coordinate() end
end)
windower.register_event('addon command',function(cmd,name)
 if cmd=='2' or cmd=='3' then
  local s=selected()
  if not s then
   log('Target an Imperial Stormer first; //lsup '..cmd)
   return
  end
  local size=tonumber(cmd)
  marked_groups[s.id]=size
  marked_by[s.id]=norm(identity())
  send('mark|'..s.id..'|'..size..'|'..identity())
  log('Marked soldier ID '..s.id..' as a member of a '..size..'-soldier group.')
 elseif cmd=='coordinator' then
  if not name or name=='' then log('Usage: //lsupply coordinator <character|auto>') return end
  leader_name=name=='auto' and '' or norm(name)
  send('leader|'..leader_name)
  log('Coordinator '..who_leads())
 elseif cmd=='plan' then
  log('Coordinator: '..who_leads()..' | 3-group stewpots '..stew_group_count()..'/2 | unlocked='..tostring(stew_group_count()>=2))
  for id,size in pairs(marked_groups) do log(id..' -> '..size..'-soldier group ('..tostring(marked_by[id])..')') end
  for id,j in pairs(jobs) do log(id..' -> '..j.worker..' ('..j.state..')') end
 end
end)
