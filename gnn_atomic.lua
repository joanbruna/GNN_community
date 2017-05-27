function gnn_atomic(featuremaps, J, last)
	
	local x = nn.Identity()()
	local W = nn.Identity()()

	--first layer
	local x1 = nn.GMul2()({x, W})
	local y1 = nn.SpatialConvolutionMM( J*featuremaps[1] , featuremaps[3], 1 ,1)(x1)
	local z1 = nn.ReLU()(y1)
	local yl1 = nn.SpatialConvolutionMM( J*featuremaps[1] , featuremaps[3], 1,1)(x1)
	local zb1 = nn.JoinTable(1,3)({yl1, z1})
	local zc1 = nn.SpatialBatchNormalization(2*featuremaps[3]){zb1}

	if last == 0 then
		net = nn.gModule( {x, W}, {zc1, W} )
	else
		net = nn.gModule( {x, W}, {zc1, W} )
	end

	return net
end



