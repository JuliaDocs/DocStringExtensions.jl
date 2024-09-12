Base.@kwdef struct ASTArg
    name::Union{Symbol, Nothing} = nothing
    type = nothing
    default = nothing
    variadic::Bool = false
end

# Parse an argument with a type annotation.
# Example input: `x::Int`
function parse_arg_with_type(arg_expr::Expr)
    if !Meta.isexpr(arg_expr, :(::))
        throw(ArgumentError("Argument is not a :(::) expr"))
    end

    n_expr_args = length(arg_expr.args)
    return if n_expr_args == 1
        # '::Int'
        ASTArg(; type=arg_expr.args[1])
    elseif n_expr_args == 2
        # 'x::Int'
        ASTArg(; name=arg_expr.args[1], type=arg_expr.args[2])
    else
        Meta.dump(arg_expr)
        error("Couldn't parse typed argument (printed above)")
    end
end

# Parse an argument with a default value.
# Example input: `x=5`
function parse_arg_with_default(arg_expr::Expr)
    if !Meta.isexpr(arg_expr, :kw)
        throw(ArgumentError("Argument is not a :kw expr"))
    end

    if arg_expr.args[1] isa Symbol
        # This is an argument without a type annotation
        ASTArg(; name=arg_expr.args[1], default=arg_expr.args[2])
    else
        # This is an argument with a type annotation
        tmp = parse_arg_with_type(arg_expr.args[1])
        ASTArg(; name=tmp.name, type=tmp.type, default=arg_expr.args[2])
    end
end

# Parse a list of expressions, assuming the list is an argument list containing
# positional/keyword arguments.
# Example input: `(x, y::Int; z=5, kwargs...)`
function parse_arglist!(exprs, args, kwargs, is_kwarg_list=false)
    list = is_kwarg_list ? kwargs : args

    for arg_expr in exprs
        if arg_expr isa Symbol
            # Plain argument name with no type or default value
            push!(list, ASTArg(; name=arg_expr))
        elseif Meta.isexpr(arg_expr, :(::))
            # With a type annotation
            push!(list, parse_arg_with_type(arg_expr))
        elseif Meta.isexpr(arg_expr, :kw)
            # With a default value (and possibly a type annotation)
            push!(list, parse_arg_with_default(arg_expr))
        elseif Meta.isexpr(arg_expr, :parameters)
            # Keyword arguments
            parse_arglist!(arg_expr.args, args, kwargs, true)
        elseif Meta.isexpr(arg_expr, :...)
            # Variadic argument
            if arg_expr.args[1] isa Symbol
                # Without a type annotation
                push!(list, ASTArg(; name=arg_expr.args[1], variadic=true))
            elseif Meta.isexpr(arg_expr.args[1], :(::))
                # With a type annotation
                arg_expr = arg_expr.args[1]
                push!(list, ASTArg(; name=arg_expr.args[1], type=arg_expr.args[2], variadic=true))
            else
                Meta.dump(arg_expr)
                error("Couldn't parse variadic Expr in arg list (printed above)")
            end
        else
            Meta.dump(arg_expr)
            error("Couldn't parse Expr in arg list (printed above)")
        end
    end
end

# Find a :call expression within an Expr. This will take care of ignoring other
# tokens like `where` clauses. It will return `nothing` if a :call expression
# wasn't found.
function find_call_expr(obj)
    if Meta.isexpr(obj, :call)
        # Base case: we've found the :call expression
        return obj
    elseif !(obj isa Expr) || isempty(obj.args)
        # Base case: this is the end of a branch in the expression tree
        return nothing
    end

    # Recursive case: recurse over all the Expr arguments
    for arg in obj.args
        if arg isa Expr
            result = find_call_expr(arg)
            if !isnothing(result)
                return result
            end
        end
    end

    return nothing
end

# Parse an expression to find a :call expr, and return as much information as
# possible about the arguments.
# Example input: `foo(x) = x^2`
function parse_call(expr::Expr)
    Base.remove_linenums!(expr)
    expr = find_call_expr(expr)

    if !Meta.isexpr(expr, :call)
        throw(ArgumentError("Couldn't find a :call Expr, are you documenting a function? If so this may be a bug in DocStringExtensions.jl, please open an issue and include the function being documented."))
    end

    args = ASTArg[]
    kwargs = ASTArg[]
    # Skip the first argument because that's just the function name
    parse_arglist!(expr.args[2:end], args, kwargs)

    return (; args, kwargs)
end
