local GMul2, parent = torch.class('nn.GMul2', 'nn.Module')

function GMul2:__init(c)
   parent.__init(self)
	self.c = c or 0
end

function GMul2:updateOutput(input)
	local x, W = unpack(input)
	-- x is a tensor of size (bs, p1, N, 1)
	-- W is a tensor of size (bs, N, N, J)
	local xsize= x:size()
	local wsize= W:size()
	local output = cast(torch.Tensor(xsize[1], wsize[4]*xsize[2], wsize[3], 1)):zero()
	for i=1,xsize[1] do 
	for j=1,wsize[4] do 
		local slice = W:narrow(1,i,1):narrow(4,j,1):squeeze()
		local xW =((x:narrow(1,i,1):view(xsize[2], xsize[3]))*slice):clone()
 		output:narrow(1,i,1):narrow(2,1+(j-1)*xsize[2],xsize[2]):copy(xW:view(1, xsize[2], wsize[3], 1))
	end
	end
      return output
end

function GMul2:updateGradInput(input, gradOutput)

	--input is a gradient tensor of size (bs, p1, N, 2)
	-- gradOuput is a table of tensors (and the gradoutput for the elements W and D is 0). 
	local osize = gradOutput:size()
	local xd, W = unpack(input)
	local xsize = xd:size()
	local wsize =W:size()
	local gradInput = {}
	local gtot = cast(torch.Tensor(xsize[1], xsize[2], xsize[3])):zero()
	for i=1,xsize[1] do 
		local gtmp = cast(torch.Tensor(xsize[2], xsize[3])):zero()
		for j=1,wsize[4] do  
			local gW = gradOutput:narrow(1,i,1):narrow(2,1+(j-1)*xsize[2],xsize[2]):contiguous():view(xsize[2], wsize[3]):contiguous()
			gW = gW * (W:narrow(1,i,1):narrow(4,j,1):contiguous():squeeze():t())
			gtmp:add(gW)
		end
		gtot:narrow(1,i,1):copy(gtmp)
	end
	
	local dummy = W:clone():zero()
	--now we create the table containing the gradient wrt input
	local gradInput = {}
	gradInput[1] = gtot:view(xsize[1], xsize[2], xsize[3], 1):contiguous()	
	gradInput[2] = dummy

    return gradInput
end


