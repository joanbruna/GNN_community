--local gnn_sq_final, parent = torch.class('nn.gnn_sq_final', 'nn.Module')

function gnn_final_multiclass(featuremaps, J, nclasses, N)
	
	local x = nn.Identity()()
	local W = nn.Identity()()

	--first layer
	local x1 = nn.GMul2()({x, W})
	local y1 = nn.SpatialConvolutionMM( J*featuremaps[1] , nclasses, 1 ,1)(x1)
	local y5 = nn.Squeeze()(y1)
	local yy5 = nn.Transpose({2,1})(y5)

	net = nn.gModule( {x, W}, {yy5} )
	return net

end

