# GNN community
Implementation of the paper "Community Detection with Graph Neural Networks", by J. Bruna and L. Li [https://arxiv.org/abs/1705.08415](https://arxiv.org/abs/1705.08415). 


## Running the code 

The code is based on Lua Torch. See [here](http://torch.ch) for installation and basic tutorials.

The experiments on the Stochastic Block Model can be run with 

```
th -i sbm.lua [options]
```

An example with fixed probabilities (a=5, b=1), using adam as optimizer and using 30 gnn layers:

``` 
th -i sbm.lua -mixture 0 -p 5 -q 1 -path /scratch/sbmp5q1/ -optmethod adam -gpunum 2 -layers 30
```

The experiments on real-world community detection are based on the Snap graphs with ground-truth community; see [Stanford Network Analysis Project](http://snap.stanford.edu) for more details. An example of running the model on such data is

```
th -i snap.lua -gpunum 1 -graph 'youtube'
```

