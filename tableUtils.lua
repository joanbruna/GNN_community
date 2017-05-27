
-- Function to convert a table to a string
-- Metatables not followed
-- Unless key is a number it will be taken and converted to a string
function t2s(t)
	-- local levels = 0
	local rL = {cL = 1}	-- Table to track recursion into nested tables (cL = current recursion level)
	rL[rL.cL] = {}
	local result = {}
	do
		rL[rL.cL]._f,rL[rL.cL]._s,rL[rL.cL]._var = pairs(t)
		--result[#result + 1] =  "{\n"..string.rep("\t",levels+1)		
		result[#result + 1] = "{"		-- Non pretty version
		rL[rL.cL].t = t
		while true do
			local k,v = rL[rL.cL]._f(rL[rL.cL]._s,rL[rL.cL]._var)
			rL[rL.cL]._var = k
			if not k and rL.cL == 1 then
				break
			elseif not k then
				-- go up in recursion level
				-- If condition for pretty printing
				-- if result[#result]:sub(-1,-1) == "," then
					-- result[#result] = result[#result]:sub(1,-3)	-- remove the tab and the comma
				-- else
					-- result[#result] = result[#result]:sub(1,-2)	-- just remove the tab
				-- end
				result[#result + 1] = "},"	-- non pretty version
				-- levels = levels - 1
				rL.cL = rL.cL - 1
				rL[rL.cL+1] = nil
				--rL[rL.cL].str = rL[rL.cL].str..",\n"..string.rep("\t",levels+1)
			else
				-- Handle the key and value here
				if type(k) == "number" then
					result[#result + 1] = "["..tostring(k).."]="
				else
					result[#result + 1] = "["..[["]]..tostring(k)..[["]].."]="
				end
				if type(v) == "table" then
					-- Check if this is not a recursive table
					local goDown = true
					for i = 1, rL.cL do
						if v==rL[i].t then
							-- This is recursive do not go down
							goDown = false
							break
						end
					end
					if goDown then
						-- Go deeper in recursion
						-- levels = levels + 1
						rL.cL = rL.cL + 1
						rL[rL.cL] = {}
						rL[rL.cL]._f,rL[rL.cL]._s,rL[rL.cL]._var = pairs(v)
						--result[#result + 1] = "{\n"..string.rep("\t",levels+1)
						result[#result + 1] = "{"	-- non pretty version
						rL[rL.cL].t = v
					else
						--result[#result + 1] = "\""..tostring(v).."\",\n"..string.rep("\t",levels+1)
						result[#result + 1] = "\""..tostring(v).."\","	-- non pretty version
					end
				elseif type(v) == "number" or type(v) == "boolean" then
					--result[#result + 1] = tostring(v)..",\n"..string.rep("\t",levels+1)
					result[#result + 1] = tostring(v)..","	-- non pretty version
				else
					--result[#result + 1] = string.format("%q",tostring(v))..",\n"..string.rep("\t",levels+1)
					result[#result + 1] = string.format("%q",tostring(v))..","	-- non pretty version
				end		-- if type(v) == "table" then ends
			end		-- if not rL[rL.cL]._var and rL.cL == 1 then ends
		end		-- while true ends here
	end		-- do ends
	-- If condition for pretty printing
	-- if result[#result]:sub(-1,-1) == "," then
		-- result[#result] = result[#result]:sub(1,-3)	-- remove the tab and the comma
	-- else
		-- result[#result] = result[#result]:sub(1,-2)	-- just remove the tab
	-- end
	result[#result + 1] = "}"	-- non pretty version
	return table.concat(result)
end

-- Function to convert a table to a string with indentation for pretty printing
-- Metatables not followed
-- Unless key is a number it will be taken and converted to a string
function t2spp(t)
	local levels = 0
	local rL = {cL = 1}	-- Table to track recursion into nested tables (cL = current recursion level)
	rL[rL.cL] = {}
	local result = {}
	do
		rL[rL.cL]._f,rL[rL.cL]._s,rL[rL.cL]._var = pairs(t)
		result[#result + 1] =  "{\n"..string.rep("\t",levels+1)		
		--result[#result + 1] = "{"		-- Non pretty version
		rL[rL.cL].t = t
		while true do
			local k,v = rL[rL.cL]._f(rL[rL.cL]._s,rL[rL.cL]._var)
			rL[rL.cL]._var = k
			if not k and rL.cL == 1 then
				break
			elseif not k then
				-- go up in recursion level
				-- If condition for pretty printing
				if result[#result]:sub(-1,-1) == "," then
					result[#result] = result[#result]:sub(1,-3)	-- remove the tab and the comma
				else
					result[#result] = result[#result]:sub(1,-2)	-- just remove the tab
				end
				--result[#result + 1] = "},"	-- non pretty version
				levels = levels - 1
				rL.cL = rL.cL - 1
				rL[rL.cL+1] = nil
				result[#result + 1] = "},\n"..string.rep("\t",levels+1)		-- for pretty printing
			else
				-- Handle the key and value here
				if type(k) == "number" then
					result[#result + 1] = "["..tostring(k).."]="
				else
					result[#result + 1] = "["..[["]]..tostring(k)..[["]].."]="
				end
				if type(v) == "table" then
					-- Check if this is not a recursive table
					local goDown = true
					for i = 1, rL.cL do
						if v==rL[i].t then
							-- This is recursive do not go down
							goDown = false
							break
						end
					end
					if goDown then
						-- Go deeper in recursion
						levels = levels + 1
						rL.cL = rL.cL + 1
						rL[rL.cL] = {}
						rL[rL.cL]._f,rL[rL.cL]._s,rL[rL.cL]._var = pairs(v)
						result[#result + 1] = "{\n"..string.rep("\t",levels+1)	-- For pretty printing
						--result[#result + 1] = "{"	-- non pretty version
						rL[rL.cL].t = v
					else
						result[#result + 1] = "\""..tostring(v).."\",\n"..string.rep("\t",levels+1)	-- For pretty printing
						--result[#result + 1] = "\""..tostring(v).."\","	-- non pretty version
					end
				elseif type(v) == "number" or type(v) == "boolean" then
					result[#result + 1] = tostring(v)..",\n"..string.rep("\t",levels+1)	-- For pretty printing
					--result[#result + 1] = tostring(v)..","	-- non pretty version
				else
					result[#result + 1] = string.format("%q",tostring(v))..",\n"..string.rep("\t",levels+1)		-- For pretty printing
					--result[#result + 1] = string.format("%q",tostring(v))..","	-- non pretty version
				end		-- if type(v) == "table" then ends
			end		-- if not rL[rL.cL]._var and rL.cL == 1 then ends
		end		-- while true ends here
	end		-- do ends
	-- If condition for pretty printing
	if result[#result]:sub(-1,-1) == "," then
		result[#result] = result[#result]:sub(1,-3)	-- remove the tab and the comma
	else
		result[#result] = result[#result]:sub(1,-2)	-- just remove the tab
	end
	result[#result + 1] = "}"
	return table.concat(result)
end

-- Function to convert a table to string following the recursive tables also
-- Metatables are not followed
function t2sr(t)
	if type(t) ~= 'table' then return nil, 'Expected table parameter' end 
	local rL = {cL = 1}	-- Table to track recursion into nested tables (cL = current recursion level)
	rL[rL.cL] = {}
	local tabIndex = {}	-- Table to store a list of tables indexed into a string and their variable name
	local latestTab = 0
	local result = {}
	do
		rL[rL.cL]._f,rL[rL.cL]._s,rL[rL.cL]._var = pairs(t)
		result[#result + 1] = 't0={}'	-- t0 would be the main table
		--rL[rL.cL].str = 't0={}'
		rL[rL.cL].t = t
		rL[rL.cL].tabIndex = 0
		tabIndex[t] = rL[rL.cL].tabIndex
		while true do
			local key
			local k,v = rL[rL.cL]._f(rL[rL.cL]._s,rL[rL.cL]._var)
			rL[rL.cL]._var = k
			if not k and rL.cL == 1 then
				break
			elseif not k then
				-- go up in recursion level
				--rL[rL.cL-1].str = rL[rL.cL-1].str..'\\n'..rL[rL.cL].str
				rL.cL = rL.cL - 1
				if rL[rL.cL].vNotDone then
					key = 't'..rL[rL.cL].tabIndex..'[t'..tostring(rL[rL.cL+1].tabIndex)..']'
					--rL[rL.cL].str = rL[rL.cL].str..'\\n'..key..'='
					result[#result + 1] = "\n"..key.."="
					v = rL[rL.cL].vNotDone
				end
				rL[rL.cL+1] = nil
			else
				-- Handle the key and value here
				if type(k) == 'number' then
					key = 't'..rL[rL.cL].tabIndex..'['..tostring(k)..']'
					--rL[rL.cL].str = rL[rL.cL].str..'\\n'..key..'='
					result[#result + 1] = "\n"..key.."="
				elseif type(k) == 'string' then
					key = 't'..rL[rL.cL].tabIndex..'.'..tostring(k)
					--rL[rL.cL].str = rL[rL.cL].str..'\\n'..key..'='
					result[#result + 1] = "\n"..key.."="					
				else
					-- Table key
					-- Check if the table already exists
					if tabIndex[k] then
						key = 't'..rL[rL.cL].tabIndex..'[t'..tabIndex[k]..']'
						--rL[rL.cL].str = rL[rL.cL].str..'\\n'..key..'='
						result[#result + 1] = "\n"..key.."="
					else
						-- Go deeper to stringify this table
						latestTab = latestTab + 1
						--rL[rL.cL].str = rL[rL.cL].str..'\\nt'..tostring(latestTab)..'={}'
						result[#result + 1] = "\nt"..tostring(latestTab).."={}"
						rL[rL.cL].vNotDone = v
						rL.cL = rL.cL + 1
						rL[rL.cL] = {}
						rL[rL.cL]._f,rL[rL.cL]._s,rL[rL.cL]._var = pairs(k)
						rL[rL.cL].tabIndex = latestTab
						rL[rL.cL].t = k
						--rL[rL.cL].str = ''
						tabIndex[k] = rL[rL.cL].tabIndex
					end		-- if tabIndex[k] then ends
				end		-- if type(k)ends
			end		-- if not k and rL.cL == 1 then ends
			if key then
				rL[rL.cL].vNotDone = nil
				if type(v) == 'table' then
					-- Check if this table is already indexed
					if tabIndex[v] then
						--rL[rL.cL].str = rL[rL.cL].str..'t'..tabIndex[v]
						result[#result + 1] = 't'..tabIndex[v]
					else
						-- Go deeper in recursion
						latestTab = latestTab + 1
						--rL[rL.cL].str = rL[rL.cL].str..'{}'
						--rL[rL.cL].str = rL[rL.cL].str..'\\nt'..tostring(latestTab)..'='..key
						result[#result + 1] = "{}\nt"..tostring(latestTab)..'='..key		-- New table
						rL.cL = rL.cL + 1
						rL[rL.cL] = {}
						rL[rL.cL]._f,rL[rL.cL]._s,rL[rL.cL]._var = pairs(v)
						rL[rL.cL].tabIndex = latestTab
						rL[rL.cL].t = v
						--rL[rL.cL].str = ''
						tabIndex[v] = rL[rL.cL].tabIndex
					end
				elseif type(v) == 'number' then
					--rL[rL.cL].str = rL[rL.cL].str..tostring(v)
					result[#result + 1] = tostring(v)
				elseif type(v) == 'boolean' then
					--rL[rL.cL].str = rL[rL.cL].str..tostring(v)
					result[#result + 1] = tostring(v)
				else
					--rL[rL.cL].str = rL[rL.cL].str..string.format('%q',tostring(v))
					result[#result + 1] = string.format('%q',tostring(v))
				end		-- if type(v) == "table" then ends
			end		-- if key then ends
		end		-- while true ends here
	end		-- do ends
	--return rL[rL.cL].str
	return table.concat(result)
end


-- Function to convert a string containing a lua table to a lua table object
function s2t(str)
	local safeenv = {}
	local fileFunc = load("t="..str,"stringToTable","t",safeenv)
	local err,msg = pcall(fileFunc)
	if not err or not safeenv.t or type(safeenv.t) ~= "table" then
		return nil,msg or type(safeenv.t) ~= "table" and "Not a table"
	end
	return safeenv.t
end


function compareTables(t1,t2)
	for k,v in pairs(t1) do
		--print(k,v)
		if type(v) == "number" or type(v) == "string" or type(v) == "boolean" or type(v) == "function" or type(v) == "thread" or type(v) == "userdata" then
			if v ~= t2[k] then
				--print("Value "..tostring(v).." does not match")
				return nil
			end
		else
			-- type(v) = ="table"
			--print("-------->Going In "..tostring(v))
			if not compareTables(v,t2[k]) then
				return nil
			end
		end
	end
	return true
end

-- Copy table t1 to t2 overwriting any common keys
-- If full is true then copy is recursively going down into nested tables
-- returns t2 
function copyTable(t1,t2,full)
	for k,v in pairs(t1) do
		if type(v) == "number" or type(v) == "string" or type(v) == "boolean" or type(v) == "function" or type(v) == "thread" or type(v) == "userdata" then
			if type(k) == "table" and full then
				local kp = {}
				copyTables(k,kp,true)
				t2[kp] = v
			else
				t2[k] = v
			end
		else
			-- type(v) = ="table"
			if full then 
				if type(k) == "table" then
					local kp = {}
					copyTables(k,kp,true)
					t2[kp] = {}
					copyTables(v,t2[kp],true)
				else
					t2[k] = {}
					copyTables(v,t2[k],true)
				end
			else
				t2[k] = v
			end
		end
	end
	return t2
end

function emptyTable(t)
	for k,v in pairs(t) do
		t[k] = nil
	end
	return true
end
