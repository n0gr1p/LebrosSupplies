_addon.name = 'LebrosSupplies'
_addon.version = '0.1.0'
_addon.commands = {'lebrossupplies','lsupply'}
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
log('Loaded in safe observation mode.')
