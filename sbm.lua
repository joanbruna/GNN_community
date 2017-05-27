require 'nn'
require 'optim'
require 'nngraph'
local c = require 'trepl.colorize'


cmd = torch.CmdLine()
cmd:option('-batchSize',1, 'mini-batch size')
cmd:option('-maxepoch',200,'epochs')
cmd:option('-path','.', 'save episodes')
cmd:option('-gpunum',3)
cmd:option('-weightDecay',0)
cmd:option('-learningRate',0.001)
cmd:option('-learningRate_damping',0.75)
cmd:option('-momentum',0.9)
cmd:option('-learningRateDecay',0)
cmd:option('-epoch_step',32,'epoch step')
cmd:option('-type','cuda')
cmd:option('-optmethod','adamax')
cmd:option('-nclasses', 2, 'number of communities')
cmd:option('-L',32,'epoch size')
cmd:option('-N',1000,'input size')
cmd:option('-mixture',0,'training setup: 0: no mixture (set p and q probabilities), > 0: see sbmdiffusion funcion')
cmd:option('-generator',0,'choice of generator (0:default, 1: symmetric Laplacian, 2:Random Walk Laplacian')
cmd:option('-layers',30,'input layers')
cmd:option('-nfeatures',10,'feature maps')
cmd:option('-preload','none','preload model')
cmd:option('-trainingon',1,'do train')
cmd:option('-p',10,'proba p')
cmd:option('-q',2,'proba q')
cmd:option('-avgdg',3,'average degree')
cmd:option('-SNR',1,'limit SNR')
cmd:option('-J',3,'maximum scale of the adjancency')
cmd:option('-verbose',0)
cmd:option('-prefix','')
opt = cmd:parse(arg or {})

if opt.type == 'cuda' then
require 'cutorch'
require 'cunn'
cutorch.setDevice(opt.gpunum)
cutorch.manualSeed(os.time())
end

NN = torch.round(opt.N/opt.nclasses)

--SNR = (a - b)^2 / [k*( a + (k-1)*b)]
-- avgdg = (a + (k-1)*b)/k
--SNR = (a-b)^2 / (k^2)*avgdg
--k avgdg - (k-1)*b = a
--
-- (a - b) = sqrt(SNR) k sqrt(avdg)
-- a = b + sqrt(SNR) k sqrt(avdg)
-- k avdg - (k-1)*b = b + sqrt(SNR) k sqrt(avdg)
-- k (avdg - sqrt(SNR avdg)) = k b 
-- avdg - sqrt(SNR avdg) = b

function cast(t)
    if opt.type == 'cuda' then
        require 'cunn'
        return t:cuda()
    elseif opt.type == 'double' then
        return t:double()
    elseif opt.type == 'cl' then
        require 'clnn'
        return t:cl()
    else
        error('Unknown type '..opt.type)
    end
end

local function permuteposs(N, nclasses)
-- create copies of labels for each possible global permutation

	if nclasses == 2 then
		p=torch.Tensor(2,2)
		p[1][1]=1
		p[1][2]=2
		p[2][1]=2
		p[2][2]=1

	elseif nclasses == 3 then
		p=torch.Tensor(6,3)
		p[1][1]=1
		p[1][2]=2
		p[1][3]=3
		p[2][1]=1
		p[2][2]=3
		p[2][3]=2
		p[3][1]=2
		p[3][2]=1
		p[3][3]=3
		p[4][1]=2
		p[4][2]=3
		p[4][3]=1
		p[5][1]=3
		p[5][2]=1
		p[5][3]=2
		p[6][1]=3
		p[6][2]=2
		p[6][3]=1
	elseif nclasses == 4 then
		dofile('permute4.lua')
	else
		print('not implemented yet')
	end

	tg = cast(torch.Tensor(p:size(1),opt.N))
	print(tg:size())
	local pluses = cast(torch.Tensor(NN)):fill(1)
	for k=1, opt.nclasses do
	for t=1, p:size(1) do
		tg:narrow(1,t,1):narrow(2,1+(k-1)*NN,NN):copy(pluses:clone():mul(p[t][k]));
	end
	end
	
	return tg

end

if opt.preload == 'none' then
--create model
model = paths.dofile('gnn_modular.lua')

else

dofile('GMul2.lua')
dofile('gnn_atomic.lua')
dofile('gnn_final_multiclass.lua')
model = torch.load(opt.preload)

end

model=cast(model)
if opt.type == 'cuda' then
   require 'cudnn'
   cudnn.convert(model, cudnn)
end

parameters,gradParameters = model:getParameters()

--create criterion
crit = cast(nn.CrossEntropyCriterion())

labels = permuteposs(opt.N, opt.nclasses)

optimState = {
    learningRate = opt.learningRate,
    weightDecay = opt.weightDecay,
    momentum = opt.momentum,
    learningRateDecay = opt.learningRateDecay,
}

-- create directory
  opt.dpath = opt.path .. '_p_' .. opt.p .. '_q_' .. opt.q .. '_J_' .. opt.J .. '_mixt_' .. opt.mixture .. '_k_' .. opt.nclasses .. '_' .. os.time()
  os.execute('mkdir -p ' .. opt.dpath)


--logging
if opt.nclasses == 2 then
classes = {'1', '2'}
elseif opt.nclasses == 3 then
classes = {'1', '2', '3'}
else
classes = {'1', '2', '3', '4'}
end
confusion = optim.ConfusionMatrix(classes)
accLogger = optim.Logger(paths.concat(opt.dpath,'accuracy.log'))
errLogger = optim.Logger(paths.concat(opt.dpath,'error.log'))

confusionbase = optim.ConfusionMatrix(classes)

if opt.mixture > 0 and opt.nclasses > 2 then
	opt.mixture = 5
end

-- p and q should satisfy (p - q)^2 > 2(p+q)
function sbmdiffusion( nclasses, p, q, J, mixture) 

	-- we first draw the similariy matrix W from sbm
	-- and then compute Q =  D^{-1/2} W D^{1/2}
	-- we return I, Q, Q^2, .. Q^J. 

	if mixture == 1 then --we fix average degree but randomize over (p,q)
		-- p = m+d
		-- q = m-d
		-- d^2 > m --> m > d > sqrt(m)
		local mitj = opt.avgdg 
		local s1 = math.sqrt(mitj*opt.SNR)
		local inti = mitj - s1
		local diff = torch.rand(1):mul(inti):add(s1)
		p = mitj + diff[1]
		q = mitj - diff[1]
		print('p=' .. p .. ' q=' .. q)

	elseif mixture == 2 then --we randomize over both average degree and (p,q)
		local rien = torch.rand(1):mul(2*opt.avgdg-1):add(1)
		local mitj = rien[1]
		local s1 = math.sqrt(mitj*opt.SNR)
		local inti = mitj - s1
		local diff = torch.rand(1):mul(inti):add(s1)
		p = mitj + diff[1]
		q = mitj - diff[1]
		print('p=' .. p .. ' q=' .. q)
	
	elseif mixture == 3 then --we fix average degree but randomize over (p,q) and assoc/disassoc
		-- p = m+d
		-- q = m-d
		-- d^2 > m --> m > d > sqrt(m)
		local mitj = opt.avgdg 
		local s1 = math.sqrt(mitj*opt.SNR)
		local inti = mitj - s1
		local diff = torch.rand(1):mul(inti):add(s1)
		local signi = torch.sign(torch.randn(1))
		p = mitj + signi[1]*diff[1]
		q = mitj - signi[1]*diff[1]
		print('p=' .. p .. ' q=' .. q)
	elseif mixture == 4 then --fully randomize over (p,q)
		-- p = m+d
		-- q = m-d
		-- d^2 > m --> m > d > sqrt(m)
		local rien = torch.rand(1):mul(2*opt.avgdg-1):add(1)
		local mitj = rien[1]
		local s1 = math.sqrt(mitj*opt.SNR)
		local inti = mitj - s1
		local diff = torch.rand(1):mul(inti):add(s1)
		local signi = torch.sign(torch.randn(1))
		p = mitj + signi[1]*diff[1]
		q = mitj - signi[1]*diff[1]
		print('p=' .. p .. ' q=' .. q)
	elseif mixture == 5 then -- randomize over (p,q) and avdg for multiclass
		--local avdg = torch.rand(1):mul(2*opt.avgdg-1):add(1)
		local avdg = opt.avgdg
		local s1 = math.sqrt(avdg*opt.SNR)
		local inti = avdg - s1
		local rr = torch.rand(1)
		q = inti*rr[1]
		p = opt.nclasses * avdg - (opt.nclasses-1)*q
		print('p=' .. p .. ' q=' .. q)
	end

	local pluses = (torch.Tensor(NN)):fill(1)
	local tg = (torch.Tensor(opt.N))
	for k=1, opt.nclasses do
		tg:narrow(1,1+(k-1)*NN,NN):copy(pluses:clone():mul(k));
	end

	local W = (torch.Tensor(opt.N, opt.N)):zero()
	--fill diag to make sure we can invert D
	for n=1,opt.N do
		--W[n][n]=1
		local aux = torch.rand(opt.N)
		for m=n+0,opt.N do
			if tg[m] == tg[n] and aux[m] < p/opt.N then
				W[m][n] = 1
			end
			if tg[m] ~= tg[n] and aux[m] < q/opt.N then
				W[m][n] = 1
			end
			W[n][m]=W[m][n]
		end
	end

	local d = W:sum(1)
	local Dfwd = torch.diag(d:squeeze())
	local QQ = W:clone()
	if opt.generator == 0 then
		QQ = W:clone()
	elseif opt.generator == 1 then -- symmetric Laplacian
		local dinv = torch.pow(d, -1/2)
		local Dsq = torch.diag(dinv:squeeze())
		QQ = W:clone()
		QQ = QQ * Dsq
		QQ = Dsq * QQ
	else -- random walk
		local dinv = torch.pow(d, -1)
		local Dsq = torch.diag(dinv:squeeze())
		QQ = W:clone()
		QQ = Dsq * QQ
	end

	local WW = cast(torch.Tensor(opt.N, opt.N, J+2)):fill(0)
	WW:narrow(3,1,1):copy(torch.eye(opt.N))
	for j=1,J-1 do 
		WW:narrow(3,1+j,1):copy(QQ)
		QQ = QQ * QQ;
	end
	WW:narrow(3,J+1,1):copy(Dfwd:view(opt.N,opt.N,1))
	WW:narrow(3,J+2,1):fill(1/opt.N)

	WW=WW:view(1,opt.N,opt.N,J+2)
	local inp = cast(d):view(1,1,opt.N,1)
	
	return WW, inp

end

local function train() 

	epoch = epoch or 1

	 -- drop learning rate every "epoch_step" epochs
    	if epoch % opt.epoch_step == 0 then
        	optimState.learningRate = optimState.learningRate * opt.learningRate_damping
    	end

	local totloss = 0
	for l=1,opt.L do 
		ii={}
		Wtmp, inp = sbmdiffusion( opt.nclasses, opt.p, opt.q, opt.J, opt.mixture)
		ii={inp, Wtmp}
	
		local feval = function(x)
			if x ~= parameters then parameters:copy(x) end
			gradParameters:zero()
			pred = model:forward(ii)
		
			--eval predictions against permuted labels	
			losses=cast(torch.Tensor(labels:size(1)))
			predt = pred:clone()
			for s=1, labels:size(1) do
				local critt = crit:clone()
				losses[s] = critt:forward(predt, labels[s])
			end
			lmin, lpos = torch.min(losses,1)
			fout = crit:forward(pred, labels[lpos[1]])
			df = crit:backward(pred, labels[lpos[1]])

			--backpropagate through model
			model:backward(ii,df)
			confusion:batchAdd(pred,labels[lpos[1]])			

			return fout, gradParameters
		end
		_, batchloss = optim[opt.optmethod](feval, parameters, optimState)
		totloss = totloss + batchloss[1]
		collectgarbage()
	end
	print(('Epoch[%d] Train loss ' ..c.cyan'%f '):format( epoch, totloss/opt.L))
	print(confusion)
	local trainAccuracy = confusion.totalValid * 100
	confusion:zero()

	epoch = epoch + 1 

	return trainAccuracy
end

local function test(ptest,qtest) 

	test_acc = torch.Tensor(opt.L):zero()

	for l=1,opt.L do 
		ii={}
		Wtmp, inp = sbmdiffusion( opt.nclasses, ptest, qtest, opt.J, 0)
		ii={inp, Wtmp}
	
		pred = model:forward(ii)
		losses=cast(torch.Tensor(labels:size(1)))
		predt = pred:clone()
		for s=1, labels:size(1) do
			local critt = crit:clone()
			losses[s] = critt:forward(predt, labels[s])
		end
		lmin, lpos = torch.min(losses,1)
		confusion:batchAdd(pred,labels[lpos[1]])			
		confusion:updateValids()
		test_acc[l] = confusion.totalValid * 100
		confusion:zero()

		collectgarbage()
	end

	test_avg = test_acc:mean()
	test_std = test_acc:std()

	return test_avg, test_std
end


if opt.trainingon > 0 then
for jj=1,opt.maxepoch do
	train_acc = train()
	accLogger:add{['% train accuracy'] = train_acc}
	accLogger:style{['% train accuracy'] = '-'}
	accLogger:plot()
end
end
	if opt.mixture > 0 then
		if opt.mixture == 5 then 
			local ntestpoints = 7
			local avdg = opt.avgdg + 0.5
			local s1 = math.sqrt(avdg*opt.SNR)
			local inti = avdg - s1	
			qt = torch.range(0,ntestpoints-1):mul(inti/(ntestpoints-1))
			pt = qt:clone()
			pt = pt:mul(1-opt.nclasses):add(avdg*opt.nclasses)
			ptable={}
			qtable={}
			for ii=1,ntestpoints do
				ptable[ii] = pt[ii]
				qtable[ii] = qt[ii]
			end
			print(ptable)
			print(qtable)
		else	
			ptable={6, 5.75, 5.5, 5.25, 5, 4.75, 4.5, 0, 0.25, 0.5, 0.75, 1, 1.25, 1.5}
			qtable={0, 0.25, 0.5, 0.75, 1, 1.25, 1.5, 6, 5.75, 5.5, 5.25, 5, 4.75, 4.5}
		end
		for jj in pairs(ptable) do
			test_avg, test_std = test(ptable[jj], qtable[jj])
			print(test_avg)
			print(test_std)
			--save to file final performance
			messg = 'final perf is ' .. test_avg .. ' std dev ' .. test_std
			fd = io.open(paths.concat(opt.dpath,'finalperf_p' .. ptable[jj] .. '_q_' .. qtable[jj] .. '.log'),'w')
			dofile('tableUtils.lua')
			local optstr = t2spp(opt)
			fd:write(optstr)
			fd:write('\n')
			fd:write(messg)
			fd:close()
		end
	else
	test_avg, test_std = test(opt.p, opt.q)
	print(test_avg)
	print(test_std)
	--save to file final performance
	messg = 'final perf is ' .. test_avg .. ' std dev ' .. test_std
	fd = io.open(paths.concat(opt.dpath,'finalperf.log'),'w')
	dofile('tableUtils.lua')
	local optstr = t2spp(opt)
	fd:write(optstr)
	fd:write('\n')
	fd:write(messg)
	fd:close()
	end



