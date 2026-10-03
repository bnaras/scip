library(scip)

## -----------------------------------------------------------------------
## Test 1: Default control values
## -----------------------------------------------------------------------
ctrl <- scip_control()
expect_true(ctrl$verbose)
expect_true(inherits(ctrl, "scip_control"))
expect_equal(length(ctrl$scip_params), 0L)

## -----------------------------------------------------------------------
## Test 2: Custom control values — R-friendly parameter names
## -----------------------------------------------------------------------
ctrl2 <- scip_control(verbose = FALSE, time_limit = 10, gap_limit = 0.01)
expect_false(ctrl2$verbose)
expect_equal(ctrl2$scip_params[["display/verblevel"]], 0L)
expect_equal(ctrl2$scip_params[["limits/time"]], 10)
expect_equal(ctrl2$scip_params[["limits/gap"]], 0.01)

## -----------------------------------------------------------------------
## Test 3: Extra SCIP parameters pass-through via ...
## -----------------------------------------------------------------------
ctrl3 <- scip_control("lp/fastmip" = 1L)
expect_true(!is.null(ctrl3$scip_params))
expect_equal(ctrl3$scip_params[["lp/fastmip"]], 1L)

## -----------------------------------------------------------------------
## Test 4: Presolving off sets presolving/maxrounds to 0
## -----------------------------------------------------------------------
ctrl4 <- scip_control(presolving = FALSE)
expect_equal(ctrl4$scip_params[["presolving/maxrounds"]], 0L)

## -----------------------------------------------------------------------
## Test 5: Node limit
## -----------------------------------------------------------------------
ctrl5 <- scip_control(node_limit = 500L)
expect_equal(ctrl5$scip_params[["limits/nodes"]], 500L)

## -----------------------------------------------------------------------
## Test 6: Heuristics emphasis
## -----------------------------------------------------------------------
ctrl6 <- scip_control(heuristics_emphasis = "aggressive")
expect_equal(ctrl6$heuristics_emphasis, "aggressive")

## -----------------------------------------------------------------------
## Test 6b: Presolve / separating / global emphasis (issue #2)
## -----------------------------------------------------------------------
ctrl6b <- scip_control(presolve_emphasis = "aggressive",
                       separating_emphasis = "fast",
                       emphasis = "feasibility")
expect_equal(ctrl6b$presolve_emphasis, "aggressive")
expect_equal(ctrl6b$separating_emphasis, "fast")
expect_equal(ctrl6b$emphasis, "feasibility")
## Defaults are not stored at all, so the C layer leaves SCIP untouched
expect_null(ctrl6$presolve_emphasis)
expect_null(ctrl6$separating_emphasis)
expect_null(ctrl6$emphasis)
## Invalid values are rejected by match.arg()
expect_error(scip_control(presolve_emphasis = "very"))
expect_error(scip_control(separating_emphasis = "very"))
expect_error(scip_control(emphasis = "very"))
## Print method lists them
out6b <- capture.output(print(ctrl6b))
expect_true(any(grepl("presolve emphasis: aggressive", out6b)))
expect_true(any(grepl("separating emphasis: fast", out6b)))
expect_true(any(grepl("emphasis: feasibility", out6b)))

## -----------------------------------------------------------------------
## Test 6c: The emphasis settings reach SCIP and solve correctly
## -----------------------------------------------------------------------
## Small knapsack-style MIP; optimum is x = (1, 1, 0), objective -7.
A6c <- matrix(c(3, 4, 2), nrow = 1)
for (ps in c("aggressive", "fast", "off")) {
    res6c <- scip_solve(
        obj   = c(-3, -4, -2),
        A     = A6c,
        b     = 7,
        sense = "<=",
        vtype = "B",
        control = list(verbose = FALSE,
                       presolve_emphasis = ps,
                       separating_emphasis = ps,
                       heuristics_emphasis = ps)
    )
    expect_equal(res6c$status, "optimal", info = ps)
    expect_equal(res6c$objval, -7, info = ps)
}
for (em in c("feasibility", "optimality", "hardlp", "numerics", "easycip",
             "cpsolver")) {
    res6d <- scip_solve(
        obj   = c(-3, -4, -2),
        A     = A6c,
        b     = 7,
        sense = "<=",
        vtype = "B",
        control = list(verbose = FALSE, emphasis = em)
    )
    expect_equal(res6d$status, "optimal", info = em)
    expect_equal(res6d$objval, -7, info = em)
}

## -----------------------------------------------------------------------
## Test 7: Print method works
## -----------------------------------------------------------------------
expect_true(is.character(capture.output(print(ctrl2))))

## -----------------------------------------------------------------------
## Test 8: Verbose off suppresses output
## -----------------------------------------------------------------------
A <- matrix(c(1, 1), nrow = 1)
b <- 2
res <- scip_solve(
    obj   = c(-1, -1),
    A     = A,
    b     = b,
    sense = "<=",
    control = list(verbose = FALSE)
)
expect_equal(res$status, "optimal")

## -----------------------------------------------------------------------
## Test 9: Solve with scip_control object directly
## -----------------------------------------------------------------------
res2 <- scip_solve(
    obj   = c(-1, -1),
    A     = A,
    b     = b,
    sense = "<=",
    control = scip_control(verbose = FALSE)
)
expect_equal(res2$status, "optimal")

## -----------------------------------------------------------------------
## Test 10: Solution limit — from SCIP's limit tests
## -----------------------------------------------------------------------
A5 <- matrix(c(1, 1, 1, 0, 0, 1), nrow = 3, byrow = TRUE)
b5 <- c(10, 6, 8)
res5 <- scip_solve(
    obj   = c(-1, -1),
    A     = A5,
    b     = b5,
    sense = rep("<=", 3),
    vtype = "I",
    control = list(verbose = FALSE, sol_limit = 1L)
)
expect_true(res5$status %in% c("optimal", "sollimit"))
expect_true(res5$sol_count >= 1L)
