# Convert a matrix to CSC (Compressed Sparse Column) format

Convert a matrix to CSC (Compressed Sparse Column) format

## Usage

``` r
make_csc_matrix(x)
```

## Arguments

- x:

  A matrix, dgCMatrix, or simple_triplet_matrix

## Value

A list with components `i` (row indices, 0-based), `p` (column pointers,
0-based), `x` (values), `nrow`, `ncol`
