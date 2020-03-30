# Matlab compability 
function ndgrid(x, y)
    nx = length(x)
    ny = length(y)
    vartype = typeof(x[1])
    @assert typeof(y[1])==vartype
    X = Array{vartype}(undef,nx, ny)
    Y = Array{vartype}(undef,nx, ny)
    for i=1:nx
        for j=1:ny
            X[i,j] = x[i]
            Y[i,j] = y[j]
        end
    end
    return X,Y
end
