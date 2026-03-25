# Solving Optimization Problems with SCIP

## Introduction

The `scip` package provides an R interface to
[SCIP](https://www.scipopt.org/) (Solving Constraint Integer Programs),
one of the fastest non-commercial solvers for mixed-integer programming
(MIP) and mixed-integer nonlinear programming (MINLP). SCIP supports
linear, quadratic, SOS, and indicator constraints with continuous,
binary, and integer variables.

This vignette demonstrates the package through examples adapted from the
[SCIP documentation and example
suite](https://www.scipopt.org/doc/html/EXAMPLES.php) (Copyright
2002–2026 Zuse Institute Berlin, Apache-2.0 license).

The package offers two interfaces:

- **One-shot interface** (`scip_solve`): pass a constraint matrix and
  get a solution back in one call.
- **Model-building interface** (`scip_model`, `scip_add_var`, etc.):
  build a model incrementally, useful for complex formulations.

## Example 1: A Production Planning LP

A company produces two products. Each unit of Product 1 yields \$5
profit and each unit of Product 2 yields \$4 profit. Production is
limited by labour (6 hours available) and materials (8 kg available).
Product 1 requires 1 hour and 2 kg per unit; Product 2 requires 2 hours
and 1 kg per unit.

$$\max\; 5x_{1} + 4x_{2}$$ subject to:
$$x_{1} + 2x_{2} \leq 6\quad\text{(labour)}$$$$2x_{1} + x_{2} \leq 8\quad\text{(materials)}$$$$x_{1},x_{2} \geq 0$$

``` r
A <- matrix(c(1, 2,
              2, 1), nrow = 2, byrow = TRUE)
b <- c(6, 8)
## scip_solve minimizes, so negate the objective for maximization
res <- scip_solve(obj = c(-5, -4), A = A, b = b,
                  sense = c("<=", "<="),
                  control = list(verbose = FALSE))
res$status
#> [1] "optimal"
-res$objval  # negate back to get the maximized profit
#> [1] 22
res$x
#> [1] 3.333333 1.333333
```

## Example 2: The Knapsack Problem

*Adapted from SCIP’s `solveknapsackexactly.c` unit test (Marc Pfetsch,
Gregor Hendel, Zuse Institute Berlin).*

A hiker can carry at most 13 kg. Six items are available with weights 7,
2, 7, 5, 1, and 3 kg, each with equal value. Which items should the
hiker pack to carry as many as possible?

$$\max\;\sum\limits_{i = 1}^{6}x_{i}$$ subject to:
$$7x_{1} + 2x_{2} + 7x_{3} + 5x_{4} + x_{5} + 3x_{6} \leq 13$$$$x_{i} \in \{ 0,1\}$$

``` r
A <- matrix(c(7, 2, 7, 5, 1, 3), nrow = 1)
res <- scip_solve(obj = c(-1, -1, -1, -1, -1, -1),
                  A = A, b = 13, sense = "<=",
                  vtype = "B",
                  control = list(verbose = FALSE))
res$status
#> [1] "optimal"
items_packed <- which(res$x == 1)
items_packed
#> [1] 1 2 5 6
total_weight <- sum(c(7, 2, 7, 5, 1, 3)[items_packed])
total_weight
#> [1] 13
```

## Example 3: N-Queens Problem

*Adapted from SCIP’s Queens example (`examples/Queens/src/queens.cpp`,
Cornelius Schwarz, University of Bayreuth).*

Place $n$ queens on an $n \times n$ chessboard so that no two queens
attack each other. This classic combinatorial problem is naturally
modelled as a binary integer program.

Let $x_{i,j} \in \{ 0,1\}$ indicate whether a queen is placed at row
$i$, column $j$. The constraints are:

- **Rows**: exactly one queen per row, $\sum_{j}x_{i,j} = 1$
- **Columns**: exactly one queen per column, $\sum_{i}x_{i,j} = 1$
- **Diagonals**: at most one queen per diagonal,
  $\sum_{{(i,j)} \in D}x_{i,j} \leq 1$

``` r
solve_nqueens <- function(n) {
    m <- scip_model(paste0(n, "-queens"))
    scip_set_objective_sense(m, "maximize")

    ## Create n*n binary variables x[i,j] with objective 1
    ## Variable (i,j) is stored at index (i-1)*n + j
    idx <- function(i, j) (i - 1L) * n + j
    scip_add_vars(m, obj = rep(1, n * n), lb = 0, ub = 1, vtype = "B",
                  names = sprintf("x%d_%d", rep(1:n, each = n), rep(1:n, n)))

    ## Row constraints: exactly one queen per row
    for (i in 1:n) {
        scip_add_linear_cons(m, vars = idx(i, 1:n), coefs = rep(1, n),
                             lhs = 1, rhs = 1, name = sprintf("row_%d", i))
    }

    ## Column constraints: exactly one queen per column
    for (j in 1:n) {
        scip_add_linear_cons(m, vars = idx(1:n, j), coefs = rep(1, n),
                             lhs = 1, rhs = 1, name = sprintf("col_%d", j))
    }

    ## Diagonal constraints: at most one queen per diagonal
    ## Down-right diagonals
    for (d in (-(n - 2)):(n - 2)) {
        rows <- max(1, 1 + d):min(n, n + d)
        cols <- rows - d
        if (length(rows) >= 2) {
            scip_add_linear_cons(m, vars = idx(rows, cols),
                                 coefs = rep(1, length(rows)),
                                 rhs = 1, name = sprintf("diag_down_%d", d))
        }
    }
    ## Down-left diagonals (anti-diagonals)
    for (s in 3:(2 * n - 1)) {
        rows <- max(1, s - n):min(n, s - 1)
        cols <- s - rows
        if (length(rows) >= 2) {
            scip_add_linear_cons(m, vars = idx(rows, cols),
                                 coefs = rep(1, length(rows)),
                                 rhs = 1, name = sprintf("diag_up_%d", s))
        }
    }

    scip_optimize(m)
    sol <- scip_get_solution(m)

    ## Extract queen positions
    x_mat <- matrix(round(sol$x), nrow = n, byrow = TRUE)
    positions <- which(x_mat == 1, arr.ind = TRUE)
    colnames(positions) <- c("row", "col")
    list(status = scip_get_status(m),
         n_queens = as.integer(sol$objval),
         positions = positions[order(positions[, "row"]), ],
         board = x_mat)
}
```

``` r
result <- solve_nqueens(8)
result$status
#> [1] "optimal"
result$n_queens
#> [1] 8
result$positions
#>      row col
#> [1,]   1   4
#> [2,]   2   6
#> [3,]   3   1
#> [4,]   4   5
#> [5,]   5   2
#> [6,]   6   8
#> [7,]   7   3
#> [8,]   8   7
```

Visualize the board (`.` = empty, `Q` = queen):

``` r
board_str <- apply(result$board, 1, function(row) {
    paste(ifelse(row == 1, "Q", "."), collapse = " ")
})
cat(board_str, sep = "\n")
#> . . . Q . . . .
#> . . . . . Q . .
#> Q . . . . . . .
#> . . . . Q . . .
#> . Q . . . . . .
#> . . . . . . . Q
#> . . Q . . . . .
#> . . . . . . Q .
```

## Example 4: Circle Packing (Quadratic Constraints)

*Adapted from SCIP’s CallableLibrary example
(`examples/CallableLibrary/src/circlepacking.c`, Jose Salmeron and
Stefan Vigerske, Zuse Institute Berlin).*

Pack $n$ circles with given radii into a rectangle of minimum area. For
each circle $i$ with radius $r_{i}$, find center coordinates
$\left( x_{i},y_{i} \right)$. The rectangle has width $W$ and height
$H$.

**Constraints:**

- Circles stay within the rectangle: $r_{i} \leq x_{i} \leq W - r_{i}$
  and $r_{i} \leq y_{i} \leq H - r_{i}$
- Circles do not overlap:
  $\left( x_{i} - x_{j} \right)^{2} + \left( y_{i} - y_{j} \right)^{2} \geq \left( r_{i} + r_{j} \right)^{2}$
  for all $i < j$

**Objective:** Minimize $W \times H$ (area).

Since bilinear objectives are harder to handle, we use a simpler
approach: minimize $W + H$ as a proxy and fix one dimension. Here we
minimize the width given a fixed height, packing 3 circles.

``` r
radii <- c(1.0, 1.5, 0.8)
n <- length(radii)
H <- 5.0  # fixed height

m <- scip_model("circlepacking")

## Variables: x_i, y_i for each circle, plus W
x_idx <- integer(n)
y_idx <- integer(n)
for (i in seq_len(n)) {
    x_idx[i] <- scip_add_var(m, obj = 0, lb = radii[i], ub = 100,
                              name = sprintf("x%d", i))
    y_idx[i] <- scip_add_var(m, obj = 0, lb = radii[i], ub = H - radii[i],
                              name = sprintf("y%d", i))
}
w_idx <- scip_add_var(m, obj = 1, lb = 0, ub = 100, name = "W")

## x_i <= W - r_i  =>  x_i - W <= -r_i
for (i in seq_len(n)) {
    scip_add_linear_cons(m, vars = c(x_idx[i], w_idx), coefs = c(1, -1),
                         rhs = -radii[i],
                         name = sprintf("fit_x_%d", i))
}

## Non-overlap: (x_i - x_j)^2 + (y_i - y_j)^2 >= (r_i + r_j)^2
## Expand: x_i^2 - 2*x_i*x_j + x_j^2 + y_i^2 - 2*y_i*y_j + y_j^2 >= (r_i+r_j)^2
for (i in 1:(n - 1)) {
    for (j in (i + 1):n) {
        min_dist_sq <- (radii[i] + radii[j])^2
        scip_add_quadratic_cons(m,
            quadvars1 = c(x_idx[i], x_idx[i], x_idx[j], y_idx[i], y_idx[i], y_idx[j]),
            quadvars2 = c(x_idx[i], x_idx[j], x_idx[j], y_idx[i], y_idx[j], y_idx[j]),
            quadcoefs = c(1, -2, 1, 1, -2, 1),
            lhs = min_dist_sq,
            name = sprintf("nooverlap_%d_%d", i, j))
    }
}

scip_optimize(m)
cat("Status:", scip_get_status(m), "\n")
#> Status: optimal
sol <- scip_get_solution(m)
W_opt <- sol$x[w_idx]
cat(sprintf("Minimum width: %.3f (height fixed at %.1f)\n", W_opt, H))
#> Minimum width: 3.515 (height fixed at 5.0)
for (i in seq_len(n)) {
    cat(sprintf("  Circle %d (r=%.1f): center = (%.3f, %.3f)\n",
                i, radii[i], sol$x[x_idx[i]], sol$x[y_idx[i]]))
}
#>   Circle 1 (r=1.0): center = (1.000, 4.000)
#>   Circle 2 (r=1.5): center = (1.500, 1.500)
#>   Circle 3 (r=0.8): center = (2.715, 3.453)
```

## Example 5: Facility Location (Mixed-Integer)

*Adapted from SCIP’s SCFLP example
(`examples/SCFLP/doc/xternal_scflp.c`, Zuse Institute Berlin).*

A company must decide which of $p$ potential warehouse locations to
open. Each warehouse $i$ has a fixed opening cost $f_{i}$ and a capacity
$k_{i}$. Each of $q$ customers $j$ has a demand $d_{j}$ and a per-unit
shipping cost $c_{ij}$ from warehouse $i$. Minimize total cost.

$$\min\;\sum\limits_{i}f_{i}y_{i} + \sum\limits_{i,j}c_{ij}x_{ij}$$
subject to:
$$\sum\limits_{i}x_{ij} \geq d_{j}\quad\forall j\quad\text{(demand)}$$$$\sum\limits_{j}x_{ij} \leq k_{i}\, y_{i}\quad\forall i\quad\text{(capacity)}$$$$y_{i} \in \{ 0,1\},\; x_{ij} \geq 0$$

``` r
## Problem data
p <- 3  # warehouses
q <- 4  # customers
fixed_cost <- c(100, 150, 120)
capacity <- c(50, 60, 40)
demand <- c(20, 25, 15, 30)
## Shipping cost matrix (warehouses x customers)
ship_cost <- matrix(c(
    4, 8, 5, 6,
    6, 3, 7, 4,
    5, 5, 4, 8
), nrow = p, byrow = TRUE)

m <- scip_model("facility_location")

## Binary variables y_i: open warehouse i?
y_idx <- integer(p)
for (i in 1:p) {
    y_idx[i] <- scip_add_var(m, obj = fixed_cost[i], vtype = "B",
                              name = sprintf("y%d", i))
}

## Continuous variables x_ij: amount shipped from i to j
x_idx <- matrix(0L, nrow = p, ncol = q)
for (i in 1:p) {
    for (j in 1:q) {
        x_idx[i, j] <- scip_add_var(m, obj = ship_cost[i, j],
                                     lb = 0, ub = max(capacity),
                                     name = sprintf("x%d_%d", i, j))
    }
}

## Demand constraints: sum_i x_ij >= d_j
for (j in 1:q) {
    scip_add_linear_cons(m, vars = x_idx[, j], coefs = rep(1, p),
                         lhs = demand[j],
                         name = sprintf("demand_%d", j))
}

## Capacity constraints: sum_j x_ij - k_i * y_i <= 0
for (i in 1:p) {
    scip_add_linear_cons(m,
                         vars = c(x_idx[i, ], y_idx[i]),
                         coefs = c(rep(1, q), -capacity[i]),
                         rhs = 0,
                         name = sprintf("capacity_%d", i))
}

scip_optimize(m)
sol <- scip_get_solution(m)
cat("Status:", scip_get_status(m), "\n")
#> Status: optimal
cat("Total cost:", sol$objval, "\n")
#> Total cost: 600

open_warehouses <- which(round(sol$x[y_idx]) == 1)
cat("Open warehouses:", open_warehouses, "\n")
#> Open warehouses: 1 2

shipments <- matrix(sol$x[x_idx], nrow = p)
cat("\nShipment plan (rows=warehouses, cols=customers):\n")
#> 
#> Shipment plan (rows=warehouses, cols=customers):
rownames(shipments) <- paste0("W", 1:p)
colnames(shipments) <- paste0("C", 1:q)
print(round(shipments, 1))
#>    C1 C2 C3 C4
#> W1 20  0 15  0
#> W2  0 25  0 30
#> W3  0  0  0  0
```

## Example 6: Indicator Constraints

*Adapted from SCIP’s indicator test instances
(`check/instances/Indicator/`, Zuse Institute Berlin).*

Indicator constraints model logical implications: “if a binary variable
is 1, then a linear constraint must hold.” They are widely used in
scheduling, network design, and disjunctive programming.

Here we model a simple production problem with setup costs: a machine
must be “turned on” ($z_{i} = 1$) before it can produce. Turning on a
machine costs \$50. Each unit produced on machine $i$ earns revenue
$r_{i}$. Machine $i$ can produce at most $u_{i}$ units, but only if
turned on.

$$\max\;\sum\limits_{i}\left( r_{i}x_{i} - 50z_{i} \right)$$ subject to:
$$\left. z_{i} = 1\Longrightarrow x_{i} \leq u_{i}\quad\text{(capacity when on)} \right.$$$$\left. z_{i} = 0\Longrightarrow x_{i} = 0\quad\text{(nothing when off)} \right.$$$$x_{i} \geq 0,\; z_{i} \in \{ 0,1\}$$

We model $\left. z_{i} = 0\Longrightarrow x_{i} \leq 0 \right.$ as an
indicator constraint on the negated variable. Equivalently, we add the
big-M constraint $x_{i} \leq u_{i}z_{i}$.

``` r
revenue <- c(12, 8, 15)
max_prod <- c(10, 20, 8)
setup_cost <- 50

m <- scip_model("setup_production")
scip_set_objective_sense(m, "maximize")

z_idx <- integer(3)
x_idx <- integer(3)
for (i in 1:3) {
    z_idx[i] <- scip_add_var(m, obj = -setup_cost, vtype = "B",
                              name = sprintf("z%d", i))
    x_idx[i] <- scip_add_var(m, obj = revenue[i], lb = 0, ub = max_prod[i],
                              name = sprintf("x%d", i))
    ## x_i <= max_prod[i] * z_i  =>  x_i - max_prod[i] * z_i <= 0
    scip_add_linear_cons(m, vars = c(x_idx[i], z_idx[i]),
                         coefs = c(1, -max_prod[i]),
                         rhs = 0,
                         name = sprintf("link_%d", i))
}

scip_optimize(m)
sol <- scip_get_solution(m)
cat("Status:", scip_get_status(m), "\n")
#> Status: optimal
cat("Profit:", sol$objval, "\n")
#> Profit: 250
for (i in 1:3) {
    on <- round(sol$x[z_idx[i]])
    prod <- sol$x[x_idx[i]]
    cat(sprintf("  Machine %d: %s, produce %.0f units\n",
                i, if (on) "ON" else "OFF", prod))
}
#>   Machine 1: ON, produce 10 units
#>   Machine 2: ON, produce 20 units
#>   Machine 3: ON, produce 8 units
```

## Solver Controls

Use [`scip_control()`](../reference/scip_control.md) with the one-shot
interface, or [`scip_set_param()`](../reference/scip_set_param.md) with
the model-building interface, to tune solver behavior.

``` r
## One-shot: time limit and gap tolerance
ctrl <- scip_control(verbose = FALSE, time_limit = 60, gap_limit = 0.01)

## Model-building: set SCIP parameters directly
m <- scip_model("tuning_example")
scip_set_param(m, "display/verblevel", 0L)   # suppress output
scip_set_param(m, "limits/time", 60.0)        # 60-second time limit
scip_set_param(m, "limits/gap", 0.01)         # 1% optimality gap
```

Common SCIP parameters:

| Parameter           | Type    | Description                    |
|---------------------|---------|--------------------------------|
| `display/verblevel` | int     | Verbosity (0=silent, 5=max)    |
| `limits/time`       | real    | Time limit in seconds          |
| `limits/gap`        | real    | Relative MIP gap tolerance     |
| `limits/nodes`      | longint | Maximum B&B nodes              |
| `limits/solutions`  | int     | Stop after this many solutions |

See the [SCIP parameter
documentation](https://www.scipopt.org/doc/html/PARAMETERS.php) for the
complete list.

## References

- SCIP Optimization Suite: <https://www.scipopt.org/>
- Bestuzheva, K., Besançon, M., Chen, W.-K., Chmiela, A., Donkiewicz,
  T., van Doornmalen, J., et al. (2021). The SCIP Optimization Suite
  8.0. *ZIB-Report* 21-41, Zuse Institute Berlin.
- Examples in this vignette are adapted from the SCIP example suite
  (Copyright 2002–2026 Zuse Institute Berlin, Apache-2.0 license),
  available at `examples/` in the [SCIP
  source](https://github.com/scipopt/scip).
