
function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

-- code snipped obtained from Stackoverflow
function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function tablemerge(t1, t2)
   for k,v in ipairs(t2) do
      table.insert(t1, v)
   end 
 
   return t1
end

function tablefuse(test)

local hash = {}
local res = {}

for _,v in ipairs(test) do
   if (not hash[v]) then
       res[#res+1] = v -- you could print here instead of saving to resul
       hash[v] = true
   end

end
return res
end

function setNew (t)
      local set = {}
      for _, l in ipairs(t) do set[l] = true end
      return set
end

function settotable (a)
      local table = {}
	local counter = 1
      for  l in pairs(a) do 
	table[counter] = l 
	counter = counter + 1
	end
      return table
end

function setContains(set, key)
    return set[key] ~= nil
end

function tableunion_size (ta,tb)
      	local a = setNew(ta)
	local b = setNew(tb)
      	local res = {}
      	for k in pairs(a) do res[k] = true end
      	for k in pairs(b) do res[k] = true end
      	return tablelength(res), tablelength(a), tablelength(b)
end

function tableintersection_size (ta,tb)
	local a = setNew(ta)
	local b = setNew(tb)
      	local res = {}
      	for k in pairs(a) do
        	res[k] = b[k]
      	end
      	return tablelength(res)
end

function tableunion (ta,tb)
      	local a = setNew(ta)
	local b = setNew(tb)
      	local res = {}
      	for k in pairs(a) do res[k] = true end
      	for k in pairs(b) do res[k] = true end
      	return res
end

function tableintersection (ta,tb)
	local a = setNew(ta)
	local b = setNew(tb)
      	local res = {}
      	for k in pairs(a) do
        	res[k] = b[k]
      	end
      	return res
end

function setintersection (a,b)
      	local res = {}
      	for k in pairs(a) do
        	res[k] = b[k]
      	end
      	return res
end

-- code snipped obtained from Stackoverflow
function tablemin(t)
    if #t == 0 then return nil, nil end
    local key, value = 1, t[1]
    for i = 2, #t do
        if value > t[i] then
            key, value = i, t[i]
        end
    end
    return key, value
end

-- code snipped obtained from Stackoverflow
function spairs(t, order)
	local keys = {}
	for k in pairs(t) do keys[#keys+1] = k end

	if order then
		table.sort(keys, function(a,b) return order(t, a, b) end)
	else
		table.sort(keys)
	end

	local i = 0
	return function()
		i = i + 1
		if keys[i] then
			return keys[i], t[keys[i]]
		end
	end
end

function tablesampleg(t1, t2)

	out={}
	local set2 = setNew(t2)
	tmp={}
	for _, l in ipairs(t1) do
		if setContains(set2,l) == false then
			tmp[l]=Csize[l]
		end
	end
	stmp = spairs(tmp, function(t,a,b) return t[b] < t[a] end)

return stmp
end



function tablesample(t1, t2)

	out={}
	local set2 = setNew(t2)
	tmp={}
	for _, l in ipairs(t1) do
		if setContains(set2,l) == false then
			tmp[l]=math.abs(Csize[l]-targetsize)
			refval = tmp[l]
			pos = l
		end
	end
	for i,l in ipairs(tmp) do
		if l < refval then
			refval = l
			pos = i
		end
	end

return pos
end

function inverttablekeys( t )
	r={}
	count = 1
	for i in pairs(t) do
		r[i] = count
		count = count + 1
	end
	return r
end


