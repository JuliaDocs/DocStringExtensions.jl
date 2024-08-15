Base.@kwdef struct ASTArg
    name::Union{Symbol, Nothing} = nothing
    type = nothing
    default = nothing
    variadic::Bool = false
end

# Parse an argument with a type annotation.
# Example input: `x::Int`
function parse_arg_with_type(arg_expr::Expr)
    if arg_expr.head != :(::)
        throw(ArgumentError("Argument is not a :(::) expr"))
    end

    n_expr_args = length(arg_expr.args)
    return if n_expr_args == 1
        # '::Int'
        ASTArg(; type=arg_expr.args[1])
    elseif n_expr_args == 2
        # 'x::Int'
        ASTArg(; name=arg_expr.args[1], type=arg_expr.args[2])
    end
end

# Parse an argument with a default value.
# Example input: `x=5`
function parse_arg_with_default(arg_expr::Expr)
    if arg_expr.head != :kw
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
        elseif arg_expr.head == :(::)
            # With a type annotation
            push!(list, parse_arg_with_type(arg_expr))
        elseif arg_expr.head == :kw
            # With a default value (and possibly a type annotation)
            push!(list, parse_arg_with_default(arg_expr))
        elseif arg_expr.head == :parameters
            # Keyword arguments
            parse_arglist!(arg_expr.args, args, kwargs, true)
        elseif arg_expr.head === :...
            # Variadic argument
            if arg_expr.args[1] isa Symbol
                # Without a type annotation
                push!(list, ASTArg(; name=arg_expr.args[1], variadic=true))
            elseif arg_expr.args[1].head === :(::)
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
# tokens like `where` clauses.
function find_call_expr(expr::Expr)
    if expr.head === :macrocall && expr.args[1] === Symbol("@generated")
        # If this is a generated function, find the first := expr to find
        # the :call expr.
        assignment_idx = findfirst(x -> x isa Expr && x.head === :(=), expr.args)

        expr.args[assignment_idx].args[1]
    elseif expr.head === :(=)
        find_call_expr(expr.args[1])
    elseif expr.head == :where
        # Function with one or more `where` clauses
        find_call_expr(expr.args[1])
    elseif expr.head === :function
        find_call_expr(expr.args[1])
    elseif expr.head === :call
        expr
    else
        Meta.dump(expr)
        error("Can't parse current expr (printed above)")
    end
end

# Parse an expression to find a :call expr, and return as much information as
# possible about the arguments.
# Example input: `foo(x) = x^2`
function parse_call(expr::Expr)
    Base.remove_linenums!(expr)
    expr = find_call_expr(expr)

    if expr.head != :call
        throw(ArgumentError("Argument is not a :call, cannot parse it."))
    end

    args = ASTArg[]
    kwargs = ASTArg[]
    # Skip the first argument because that's just the function name
    parse_arglist!(expr.args[2:end], args, kwargs)

    return (; args, kwargs)
end
