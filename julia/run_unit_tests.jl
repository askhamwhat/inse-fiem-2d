using Test

testdir = "tests/"
tests = filter(x -> occursin(r"^test_.*\.jl$", x), readdir(testdir))

@testset "All tests" begin
    for t in tests
        println("########## ", t, " ##########")
        include(string(testdir, t))
    end
end
