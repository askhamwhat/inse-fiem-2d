# Dev code for free space solver for modified stokes
push!(LOAD_PATH, string(pwd(),"/src"))

using ModifiedStokesSolver 
using Test
using LinearAlgebra
using Random

@testset "FreeSpaceSolver" begin
    # Setup problem
    Random.seed!(1)
    L = 4.0
    lambda = 5.6

    sigma = L/20
    x0 = 0.12376938253
    y0 = 0.21938752311

    xi = 1/sqrt(2*sigma^2)
    # Reference solution derived by applying modified biharmonic to Gaussian
    # ufuncr(r) = exp(-xi^2*r^2)
    ffuncr(r) = -4*xi^2*exp(-xi^2*r^2)*( lambda^2*(1-r^2*xi^2) + 4*xi^2*(2 - 4*r^2*xi^2 + r^4*xi^4) )
    s1r(r) = -2*xi^2*exp(-xi^2*r^2)*(2*xi^2*r^2-1)
    s2r(r) = 4*xi^4*exp(-xi^2*r^2)
    pr(r) = 2*xi^2*exp(-xi^2*r^2)*(lambda^2 + 8*xi^2 - 4*xi^4*r^2)

    r1(x,y) = x-x0
    r2(x,y) = y-y0
    r(x,y) = sqrt( (x-x0)^2 + (y-y0)^2 )

    c1 = rand()
    c2 = rand()
    ffunc1(x, y) = c1*ffuncr(r(x,y))
    ffunc2(x, y) = c2*ffuncr(r(x,y))

    ufunc1(x, y) = c1*s1r(r(x,y)) + s2r(r(x,y))*r1(x,y)*(c1*r1(x,y) + c2*r2(x,y))
    ufunc2(x, y) = c2*s1r(r(x,y)) + s2r(r(x,y))*r2(x,y)*(c1*r1(x,y) + c2*r2(x,y))
    pfunc(x, y) = pr(r(x,y))*(c1*r1(x,y) + c2*r2(x,y))

    function solve(N)
        # Grid domain
        x = range(-L/2, stop=L/2, length=N+1)
        x = x[1:end-1] # Note that intervals are closed/open!
        y = x
        X,Y = ndgrid(x, y)
        # Nonuniform test points
        M = 1000
        xt = L*(1/2 .- rand(M, 1))
        yt = L*(1/2 .- rand(M, 1))

        # Get rhs
        F1 = ffunc1.(X,Y)
        F2 = ffunc2.(X,Y)
        Fedges1=[F1[1,:];F1[end,:];F1[:,1];F1[:,end]]
        Fedges2=[F2[1,:];F2[end,:];F2[:,1];F2[:,end]]
        Fgridresolution1 = norm(Fedges1, Inf) / norm(vec(F1), Inf)
        Fgridresolution2 = norm(Fedges2, Inf) / norm(vec(F2), Inf)
        Fgridresolution = max(Fgridresolution1, Fgridresolution2)

        # Get reference solution
        U1ref = ufunc1.(X,Y)
        U2ref = ufunc2.(X,Y)

        # Compute solution with FFT method
        U1, U2, ut1, ut2 = fs_modstokes(F1, F2, L, lambda, xt, yt)

        # Compute error on grid
        E1 = U1 - U1ref
        E2 = U2 - U2ref
        relerr1 = norm(E1[:], Inf) / norm(vec(U1ref), Inf)
        relerr2 = norm(E2[:], Inf) / norm(vec(U2ref), Inf)
        relerr = max(relerr1, relerr2)

        # Compute error at nonuniform test points
        enu1 = ut1-ufunc1.(xt,yt)
        enu2 = ut2-ufunc2.(xt,yt)
        relerrnu1 = norm(enu1, Inf) / norm(ut1, Inf)
        relerrnu2 = norm(enu2, Inf) / norm(ut2, Inf)
        relerrnu = max(relerrnu1, relerrnu2)

        # Compute numerical derivatives to check that we actually satisfy the PDE
        Unorm = norm(sqrt.( vec(U1).^2 + vec(U2).^2 ), Inf)
        h = X[2]-X[1]
        int = 2:N-1
        U1x = (U1[int .+ 1,int]-U1[int .- 1,int])/(2*h)
        U2y = (U2[int,int .+ 1]-U2[int,int .- 1])/(2*h)

        P = pfunc.(X,Y)
        Pnorm = norm( vec(P), Inf)
        
        Udiv = U1x+U2y
        diverr_rel = maximum(abs.(Udiv))/Unorm

        LP = (-4*P[int,int] + P[int .+ 1,int] + P[int .- 1,int] + P[int,int .+ 1] + P[int,int .- 1])/h^2
        Px = (P[int .+ 1,int]-P[int .- 1,int])/(2*h)
        Py = (P[int,int .+ 1]-P[int,int .- 1])/(2*h)
        LU1 = (-4*U1[int,int] + U1[int .+ 1,int] + U1[int .- 1,int] + U1[int,int .+ 1] + U1[int,int .- 1])/h^2
        LU2 = (-4*U2[int,int] + U2[int .+ 1,int] + U2[int .- 1,int] + U2[int,int .+ 1] + U2[int,int .- 1])/h^2

        pde1 = LU1 - lambda^2*U1[int,int] - Px - F1[int,int]
        pde2 = LU2 - lambda^2*U2[int,int] - Py - F2[int,int]

        pdeerr1_rel = maximum(abs.(pde1))/Unorm
        pdeerr2_rel = maximum(abs.(pde2))/Unorm
        pdeerr_rel = max(pdeerr1_rel, pdeerr2_rel)

        return relerr, relerrnu, diverr_rel, pdeerr_rel
    end

    # Solve above problem for a variety of N
    iters = 3;
    diverr_list = zeros(iters)
    pdeerr_list = zeros(iters)
    N_list = zeros(iters)
    for i=0:iters-1
        N = 64*2^i
        relerr, relerrnu, diverr_rel, pdeerr_rel = solve(N)
        @test relerr < 1e-13
        @test relerrnu < 1e-13
        N_list[i+1] = N
        diverr_list[i+1] = diverr_rel
        pdeerr_list[i+1] = pdeerr_rel
    end
    # Estimate convergence constant of FD test (should be 2)
    A = [ones(iters) -log.(N_list)]    
    div_conv = (A\log.(diverr_list))[2]
    pde_conv = (A\log.(pdeerr_list))[2]
    @test abs(div_conv - 2) < 0.05
    @test abs(pde_conv - 2) < 0.05    
end
