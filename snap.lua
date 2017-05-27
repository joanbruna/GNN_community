require 'nn'
require 'optim'
require 'nngraph'
local c = require 'trepl.colorize'

cmd = torch.CmdLine()
cmd:option('-batchSize',1, 'mini-batch size')
cmd:option('-maxepoch',24,'epochs')
cmd:option('-maxepochsize',2000,'epochs')
cmd:option('-maxtestsize',2000,'epochs')
cmd:option('-path','.', 'save episodes')
cmd:option('-graph','dblp', 'graph')
cmd:option('-gpunum',3)
cmd:option('-weightDecay',0)
cmd:option('-learningRate',0.001)
cmd:option('-learningRate_damping',0.75)
cmd:option('-momentum',0.9)
cmd:option('-learningRateDecay',0)
cmd:option('-epoch_step',1,'epoch step')
cmd:option('-type','cuda')
cmd:option('-optmethod','adamax')
cmd:option('-nclasses', 3)
cmd:option('-L',20000,'epoch size')
cmd:option('-layers',10,'input layers')
cmd:option('-nfeatures',10,'feature maps')
cmd:option('-J',3,'scale of the extrapolation')
cmd:option('-verbose',0)
cmd:option('-prefix','')
opt = cmd:parse(arg or {})

if opt.type == 'cuda' then
require 'cutorch'
require 'cunn'
cutorch.setDevice(opt.gpunum)
cutorch.manualSeed(os.time())
end

opt.datagraphpathroot='.' -- path to the folder where corresponding graph files are
opt.datagraphpath = opt.datagraphpathroot .. 'com-' .. opt.graph .. '.ungraph.txt'
opt.datacommpath = opt.datagraphpathroot .. 'com-' .. opt.graph .. '.top5000.cmty.txt'


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

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

--create model
model = paths.dofile('gnn_modular.lua')

model=cast(model)
if opt.type == 'cuda' then
   require 'cudnn'
   cudnn.convert(model, cudnn)
end

parameters,gradParameters = model:getParameters()

--create criterion
crit = cast(nn.CrossEntropyCriterion())

-- create directory
opt.dpath = opt.path .. 'bs_' .. opt.batchSize .. '_J_' .. opt.J .. '_' .. os.time()
os.execute('mkdir -p ' .. opt.dpath)

opt.pathbaselinetest = opt.datagraphpathroot .. opt.graph .. '_baseline/'

--load dataset
dofile('snapload.lua')
if file_exists(paths.concat(opt.pathbaselinetest,'traintestpartition.th')) == true then
	local YY=torch.load(paths.concat(opt.pathbaselinetest,'traintestpartition.th'))
	goodcross_train = YY["goodcross_train"]
	goodcross_test = YY["goodcross_test"]
else
	object={ goodcross_train=goodcross_train, goodcross_test = goodcross_test}
	torch.save(paths.concat(opt.pathbaselinetest,'traintestpartition.th'),object)
end
trsize = tablelength(goodcross_train)
tesize = tablelength(goodcross_test)
print(trsize)
print(tesize)


optimState = {
    learningRate = opt.learningRate,
    weightDecay = opt.weightDecay,
    momentum = opt.momentum,
    learningRateDecay = opt.learningRateDecay,
}


--logging
if opt.nclasses == 2 then
classes = {'1', '2'}
else
classes = {'1', '2', '3'}
end
confusion = optim.ConfusionMatrix(classes)
accLogger = optim.Logger(paths.concat(opt.dpath,'accuracy_train.log'))
acctLogger = optim.Logger(paths.concat(opt.dpath,'accuracy_test.log'))
errLogger = optim.Logger(paths.concat(opt.dpath,'error.log'))

confusionbase = optim.ConfusionMatrix(classes)

function loadexample ( ind, J , test)

	if test == 0 then
		W, target = extract_subgraph(goodcross_train[ind])
	else
		W, target = extract_subgraph(goodcross_test[ind])
	end
	target = cast(target)
	local d = W:sum(1)
	local Dfwd = torch.diag(d:squeeze())
	local QQ = W:clone()
	local N = W:size(1)
	
	local WW = cast(torch.Tensor(N, N, J+2)):fill(0)
	WW:narrow(3,1,1):copy(torch.eye(N))
	for j=1,J-1 do 
		WW:narrow(3,1+j,1):copy(QQ)
		QQ = QQ * QQ;
	end
	WW:narrow(3,J+1,1):copy(Dfwd:view(N,N,1))
	WW:narrow(3,J+2,1):fill(1/N)

	WW=WW:view(1,N,N,J+2)
	local inp = cast(d):view(1,1,N,1)

	return WW, inp, target
end

local permuteprotect = nn.Index(2)
if opt.nclasses == 2 then
plate = torch.LongTensor({{1,2},{2,1}})
perms = 2
else
plate = torch.LongTensor({{1,2,3},{2,1,3}})
perms = 2
end

permuteprotect = cast(permuteprotect)
plate = cast(plate)

prho = 0.98 --running average factor (display purposes only)
running_avg = 0
running_avg_b = 0

local function train() 

	epoch = epoch or 1

	 -- drop learning rate every "epoch_step" epochs
    	if epoch % opt.epoch_step == 0 then
        	optimState.learningRate = optimState.learningRate * opt.learningRate_damping
    	end
	
	shuffle = torch.randperm(trsize)

	local totloss = 0
	for l=1,math.min(trsize,opt.maxepochsize) do 
		ii={}
		Wtmp, inp, target = loadexample( shuffle[l], opt.J, 0)
		ii={inp, Wtmp}
	
		local feval = function(x)
			if x ~= parameters then parameters:copy(x) end
			gradParameters:zero()
			pred = model:forward(ii)
			--eval predictions against permuted labels
			
			losses=cast(torch.Tensor(perms))
			predt = pred:clone()
			local laball = cast(torch.Tensor(inp:size(3),perms)):zero()
			for s=1, perms do
				local critt = crit:clone()
				local tper = permuteprotect:forward({target,plate[s]})
				_,labtmp = torch.max(tper,2)
				labtmp = labtmp:double()
				labtmp = cast(labtmp)
				losses[s] = critt:forward(predt, labtmp)
				laball:narrow(2,s,1):copy(labtmp)
			end
			lmin, lpos = torch.min(losses,1)
			running_avg = prho * running_avg + (1- prho)*lmin[1]
			if l % 50 == 0 then
			print(running_avg)
			print(confusion)
			end
			fout = crit:forward(pred, laball:narrow(2,lpos[1],1))
			df = crit:backward(pred, laball:narrow(2,lpos[1],1))

			model:backward(ii,df)
			confusion:batchAdd(pred,laball:narrow(2,lpos[1],1))			

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

local function test() 

	shuffle = torch.randperm(math.min(tesize,opt.maxtestsize))

	local totloss = 0
	for l=1,math.min(tesize,opt.maxtestsize) do 
		ii={}
		Wtmp, inp, target = loadexample( shuffle[l], opt.J, 1)
		ii={inp, Wtmp}
		pred = model:forward(ii)
		losses=cast(torch.Tensor(perms))
		predt = pred:clone()
		local laball = cast(torch.Tensor(inp:size(3),perms)):zero()
		for s=1, perms do
			local critt = crit:clone()
			local tper = permuteprotect:forward({target,plate[s]})
			_,labtmp = torch.max(tper,2)
			labtmp = labtmp:double()
			labtmp = cast(labtmp)
			losses[s] = critt:forward(predt, labtmp)
			laball:narrow(2,s,1):copy(labtmp)
		end
		lmin, lpos = torch.min(losses,1)
		confusion:batchAdd(pred,laball:narrow(2,lpos[1],1))			
		totloss = totloss + lmin[1]
	
		collectgarbage()
	end
	print(('Epoch[%d] Test loss ' ..c.cyan'%f '):format( epoch, totloss/tesize))
	print(confusion)
	local testAccuracy = confusion.totalValid * 100
	confusion:zero()

	return testAccuracy
end


for jj=1,opt.maxepoch do
	train_acc = train()
	accLogger:add{['% train accuracy'] = train_acc}
	accLogger:style{['% train accuracy'] = '-'}
	accLogger:plot()
	test_acc = test()
	acctLogger:add{['% test accuracy'] = test_acc}
	acctLogger:style{['% test accuracy'] = '-'}
	acctLogger:plot()
end



