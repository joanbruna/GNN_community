dofile('GMul2.lua')
dofile('gnn_atomic.lua')
dofile('gnn_final_multiclass.lua')

local featuremap_in= { 1, 1, opt.nfeatures}
local featuremap_mi= {2*opt.nfeatures,2*opt.nfeatures,opt.nfeatures}
local featuremap_end={2*opt.nfeatures,2*opt.nfeatures,1}

local model = nn.Sequential()
model:add(gnn_atomic(featuremap_in, 2+opt.J,0))
for i=1,opt.layers do
model:add(gnn_atomic(featuremap_mi, 2+opt.J,0))
end
model:add(gnn_atomic(featuremap_mi, 2+opt.J,1))
model:add(gnn_final_multiclass(featuremap_end, 2+opt.J, opt.nclasses, opt.N))

return model


