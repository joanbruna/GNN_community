
dofile('tablejoanutils.lua')
file = io.open(opt.datagraphpath)
cfile = io.open(opt.datacommpath)

function convert_to_Tensor( NE, NC )
	--this function receives a table of neighbors per node 
	--and a table of labels.

	local inverse = inverttablekeys(NE)
	local N = tablelength(NE)
	local W = torch.Tensor(N, N):zero()
	local lab = torch.Tensor(N,3):zero()
	for v,r in pairs(NE) do
		--r contains the list of neighbs
		for _,s in ipairs(r) do
			W[inverse[v]][inverse[s]] = 1
		end
		if NC[v][1] == true and NC[v][2] == true then
			lab[inverse[v]][3] = 1
		elseif NC[v][1] == true and NC[v][2] == false then 
			lab[inverse[v]][2] = 1
		else
			lab[inverse[v]][1] = 1
		end
	end
	
	return W, lab
end

function extract_subgraph( v)
	-- v here contains the indices of the two communities
	local Lunion = tableunion(C[v[1]],C[v[2]])
	-- extract subgraph
	local LNE={}
	local LNC={}
	for w in pairs(Lunion) do
		-- NE[w] contains all neighbors of w
		local neighs = setNew(NE[w])
		local sneighs = setintersection(neighs, Lunion)	 
		LNE[w] = settotable(sneighs)
		LNC[w] = {setContains(setNew(C[v[1]]),w), setContains(setNew(C[v[2]]),w)}
	end

	W, lab = convert_to_Tensor(LNE, LNC)
	return W, lab, LNC

end


N={}
NE={}
	
E={}
i=1
if file then
	for line in file:lines() do
		local l = line:split("\t")
		E[i]={}
  		for key, val in ipairs(l) do
			table.insert(E[i],val)
			N[val]={}
  		end
		if NE[l[1]] == nil then
			NE[l[1]]={}
		end
		if NE[l[2]] == nil then
			NE[l[2]]={}
		end
		table.insert(NE[l[1]],l[2])
		table.insert(NE[l[2]],l[1])
		i = i+1
		if i%20000 == 0 then
			print(i)
		end
	end
end



C={}
Csize={}
Cavg = 0
i=1
if cfile then
	for line in cfile:lines() do
		local l = line:split("\t")
		C[i]={}
  		for key, val in ipairs(l) do
			table.insert(C[i],val)
			table.insert(N[val],i)
  		end
		Csize[i] = tablelength(C[i])
		Cavg = Cavg + Csize[i]	
		i=i+1
		if i%100 == 0 then
			print(i)
		end
	end
end
Cavg = Cavg/(i-1)
Cnumber = tablelength(C)
print('average community size is ' .. Cavg)

-- 1st step: identify edges that cross communities. 			
El = tablelength(E)
cross={}
for i=1,El do
	local lun,ll1,ll2 = tableunion_size(N[E[i][1]], N[E[i][2]])	
	if ll1 > 0 and ll2 > 0 and lun > ll1 and lun > ll2 then
		table.insert(cross,i)
	end
	if i % 100 == 0 then
	collectgarbage("step",1)
	end
end

-- 2nd step: for each cross edge, we want to grow a subgraph of limited size. 
maxsubsize = 1000
rho = 0.05 -- maximum imbalance between communities
alpha = 0.7 -- fraction of communities reserved for training/testing
cthres = alpha * Cnumber
goodcross_train={}
goodcross_test={}
counter_train = 0
counter_test = 0
plate = torch.randperm(Cnumber);

for _,v in ipairs(cross) do
	local L1 = shallowcopy(N[E[v][1]])
	local L2 = shallowcopy(N[E[v][2]])
	--pick one element in L1 not in L2 and viceversa
	local cc1 = tablesampleg(L1, L2)
	local cc2 = tablesampleg(L2, L1)	
	for i1,j1 in cc1 do
		for i2, j2 in cc2 do
			if j1 + j2 < 2*maxsubsize and j1 > rho*j2 and j2 > rho*j1 and plate[i1] < cthres and plate[i2] < cthres then
				counter_train = counter_train + 1
				goodcross_train[counter_train]={i1, i2}
			end
			if j1 + j2 < 2*maxsubsize and j1 > rho*j2 and j2 > rho*j1 and plate[i1] > cthres and plate[i2] > cthres then
				counter_test = counter_test + 1
				goodcross_test[counter_test]={i1, i2}
			end
		end
	end
end
trsize = counter_train -1
tesize = counter_test - 1
print('total found clusts are (train:' .. trsize .. ' || test: ' .. tesize)

collectgarbage()


