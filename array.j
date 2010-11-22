## array.j: Base Array functionality

typealias Dims (Size...)

## Basic functions ##

size(a::Array) = a.dims
numel(a::Array) = arraylen(a)

## Constructors ##

jl_comprehension_zeros{T,n}(oneresult::Tensor{T,n}, dims...) = Array(T, dims...)
jl_comprehension_zeros{T}(oneresult::T, dims...) = Array(T, dims...)
jl_comprehension_zeros(oneresult::(), dims...) = Array(None, dims...)

clone{T}(a::Array{T}) = Array(T, size(a))
clone{T}(a::Array{T}, dims::Dims) = Array(T, dims)
clone{T}(a::Array{T}, dims::Size...) = Array(T, dims)
clone{T}(a::Array, T::Type) = Array(T, size(a))
clone{T}(a::Array, T::Type, dims::Dims) = Array(T, dims)
clone{T}(a::Array, T::Type, dims::Size...) = Array(T, dims)

for (t, f) = ((Float64, `rand), (Float32, `randf), (Float64, `randn))
    eval(`function ($f)(dims::Dims)
              A = Array($t, dims)
              for i = 1:numel(A)
                  A[i] = ($f)()
              end
              return A
          end)
    eval(`( ($f)(dims::Size...) = ($f)(dims) ))
end

zeros{T}(::Type{T}, dims::Dims) = fill(Array(T, dims), zero(T))
zeros(T::Type, dims::Size...) = zeros(T, dims)
zeros(dims::Dims) = zeros(Float64, dims)
zeros(dims::Size...) = zeros(dims)

ones{T}(::Type{T}, dims::Dims) = fill(Array(T, dims), one(T))
ones(T::Type, dims::Size...) = ones(T, dims)
ones(dims::Dims) = ones(Float64, dims)
ones(dims::Size...) = ones(dims)

trues(dims::Dims) = fill(Array(Bool, dims), true)
trues(dims::Size...) = trues(dims)

falses(dims::Dims) = fill(Array(Bool, dims), false)
falses(dims::Size...) = falses(dims)

## Conversions ##

convert{T,n}(::Type{Array{T,n}}, x::Array{T,n}) = x
convert{T,n,S}(::Type{Array{T,n}}, x::Array{S,n}) = copy_to(clone(x,T), x)

int8   {T,n}(x::Array{T,n}) = convert(Array{Int8   ,n}, x)
uint8  {T,n}(x::Array{T,n}) = convert(Array{Uint8  ,n}, x)
int16  {T,n}(x::Array{T,n}) = convert(Array{Int16  ,n}, x)
uint16 {T,n}(x::Array{T,n}) = convert(Array{Uint16 ,n}, x)
int32  {T,n}(x::Array{T,n}) = convert(Array{Int32  ,n}, x)
uint32 {T,n}(x::Array{T,n}) = convert(Array{Uint32 ,n}, x)
int64  {T,n}(x::Array{T,n}) = convert(Array{Int64  ,n}, x)
uint64 {T,n}(x::Array{T,n}) = convert(Array{Uint64 ,n}, x)
bool   {T,n}(x::Array{T,n}) = convert(Array{Bool   ,n}, x)
char   {T,n}(x::Array{T,n}) = convert(Array{Char   ,n}, x)
float32{T,n}(x::Array{T,n}) = convert(Array{Float32,n}, x)
float64{T,n}(x::Array{T,n}) = convert(Array{Float64,n}, x)

## Indexing: ref ##

ref(a::Array, i::Index) = arrayref(a,i)
ref{T}(a::Array{T,1}, i::Index) = arrayref(a,i)
ref(a::Array{Any,1}, i::Index) = arrayref(a,i)
ref{T}(a::Array{T,2}, i::Index, j::Index) = arrayref(a, (j-1)*a.dims[1] + i)

## Indexing: assign ##

assign(A::Array{Any}, x, i::Index) = arrayset(A,i,x)
assign{T}(A::Array{T}, x, i::Index) = arrayset(A,i,convert(T, x))

## Concatenation ##

cat(catdim::Int) = Array(None,0)

vcat() = Array(None,0)
hcat() = Array(None,0)

## cat: special cases
hcat{T}(X::T...) = [ X[j] | i=1, j=1:length(X) ]
vcat{T}(X::T...) = [ X[i] | i=1:length(X) ]

hcat{T}(V::Array{T,1}...) = [ V[j][i] | i=1:length(V[1]), j=1:length(V) ]

function vcat{T}(V::Array{T,1}...)
    a = clone(V[1], sum(map(length, V)))
    pos = 1
    for k=1:length(V)
        Vk = V[k]
        for i=1:length(Vk)
            a[pos] = Vk[i]
            pos += 1
        end
    end
    a
end

function hcat{T}(A::Array{T,2}...)
    nargs = length(A)
    ncols = sum(ntuple(nargs, i->size(A[i], 2)))
    nrows = size(A[1], 1)
    B = clone(A[1], nrows, ncols)
    pos = 1
    for k=1:nargs
        Ak = A[k]
        for i=1:numel(Ak)
            B[pos] = Ak[i]
            pos += 1
        end
    end
    return B
end

function vcat{T}(A::Array{T,2}...)
    nargs = length(A)
    nrows = sum(ntuple(nargs, i->size(A[i], 1)))
    ncols = size(A[1], 2)
    B = clone(A[1], nrows, ncols)
    pos = 1
    for j=1:ncols, k=1:nargs
        Ak = A[k]
        for i=1:size(Ak, 1)
            B[pos] = Ak[i,j]
            pos += 1
        end
    end
    return B
end

## cat: general case

function cat(catdim::Int, X...)
    typeC = promote_type(map(typeof, X)...)
    nargs = length(X)
    if catdim == 1
        dimsC = nargs
    elseif catdim == 2
        dimsC = (1, nargs)
    end
    C = Array(typeC, dimsC)

    for i=1:nargs
        C[i] = X[i]
    end
    return C
end

vcat(X...) = cat(1, X...)
hcat(X...) = cat(2, X...)

function cat(catdim::Int, A::Array...)
    # ndims of all input arrays should be in [d-1, d]

    nargs = length(A)
    dimsA = ntuple(nargs, i->size(A[i]))
    ndimsA = ntuple(nargs, i->length(dimsA[i]))
    d_max = max(ndimsA)
    d_min = min(ndimsA)

    cat_ranges = ntuple(nargs, i->(catdim <= ndimsA[i] ? dimsA[i][catdim] : 1))

    function compute_dims(d)
        if d == catdim
            if catdim <= d_max
                return sum(cat_ranges)
            else
                return nargs
            end
        else
            if d <= d_max
                return dimsA[1][d]
            else
                return 1
            end
        end
    end

    ndimsC = max(catdim, d_max)
    dimsC = ntuple(ndimsC, compute_dims)
    typeC = promote_type(ntuple(nargs, i->typeof(A[i]).parameters[1])...)
    C = Array(typeC, dimsC)

    cat_ranges = cumsum(1, cat_ranges...)
    for k=1:nargs
        cat_one = ntuple(ndimsC, i->(i != catdim ? 
                                     Range1(1,dimsC[i]) :
                                     Range1(cat_ranges[k],cat_ranges[k+1]-1) ))
        C[cat_one...] = A[k]
    end
    return C
end

vcat(A::Array...) = cat(1, A...)
hcat(A::Array...) = cat(2, A...)