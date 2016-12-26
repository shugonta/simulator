/* Minimum-cost flow problem */

param N integer, >0 ;
param M integer, >0 ;
param p integer, >0 ;
param q integer, >0 ;
param B integer, >0 ;
param Q, >=0 ;
param C_MAX, >= 0 ;

set V := 1..N;
set E within {V, V};
set K := 1..M;

param d{E}; /* length of edge */
param c{E}; /* capacity of edge */


/* decision variables */
var x{K, E}, binary;
var y{K, E}, >= 0, integer;
var b{K}, >= 0, integer; /* capacity of route */

/* Objective function */
minimize FLOW_COST: sum{k in K} sum{(i, j) in E}( y[k, i, j] * d[i, j]);

s.t. INTERNAL{k in K, i in V: i != p && i != q}:
     sum{j in V: (i,j) in E} (x[k, i, j]) - sum{j in V: (j, i) in E} (x[k, j, i]) = 0;
     
s.t. SOURCE{k in K, i in V: i = p}:
     sum{j in V: (i,j) in E} (x[k, i, j]) - sum{j in V: (j, i) in E} (x[k, j, i]) = 1;     

s.t. CAPACITY{(i,j) in E}:
     0 <= sum{k in K} ( y[k, i, j] ) <= c[i, j];

s.t. MAINROUTE{k in K: k = 1}:
     b[k] = B;
     
s.t. BACKUPROUTE{k in K: k != 1}:
     b[k] = Q * B;

s.t. DISJOINT{(i,j) in E, k1 in K, k2 in K: k1 != k2}:
     x[k1,i,j] + x[k2,i,j] <= 1;

s.t. st1{k in K, (i,j) in E}:
     y[k, i, j] >= b[k] + ( C_MAX * (x[k, i, j] - 1) );

s.t. st2{k in K, (i,j) in E}:
     y[k, i, j] <= c[i,j] * x[k, i, j];

s.t. st3{k in K, (i,j) in E}:
     y[k, i, j] >= 0 ;

end;
