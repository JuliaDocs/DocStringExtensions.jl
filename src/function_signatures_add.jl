#!/opt/bin/julia --project="."

using Infiltrator

include("./function_signatures_add_to_file.jl")

"""
Converts a path to a file or directory to a list of all of the files under it.

followSymlinks (defulat false) says whether to follow symbolic links when recursively traversing directories.
"""
function file_list_get(path::AbstractString,  followSymlinks::Bool=false)::Vector{String}
    
    if !ispath(path)
        throw(ArgumentError("'$path' could not be found."))
    end

    if isfile(path) || (islink(path) && followSymlinks)
        return [path]
    elseif !isdir(path)
        throw(ArgumentError("path='$path' is not a directory or a file. " 
                            *"If it's a symlink, make sure to use followSymlinks=true."))
    end

    #Ok, at this point, path should be a directory.

    walkdir(path, follow_symlinks=followSymlinks) |> #Produces a collection of (root, dirs, files)
        y-> map(x-> [ joinpath(x[1], file) for file in x[3]],y) |> #Converts each tuple to a list of full paths to the files.
        x->vcat(x...) #Concatenates the list of lists into a single list
end


"""
files_ok_with_user(files,confirmFirst::bool)

If confirmFirst is true, then this checks with the user to see if the list of files we're about to edit is ok.

If !confirmFirst, then we just assume it's ok.
"""
function files_ok_with_user(files,confirmFirst::Bool)
    if confirmFirst
        print("These are the files I am about to edit:\n\n")
        foreach(x->println("\t"*x), files)
        print("\n")

        cont=input("Would you like me to continue? y/[n]:")

        if strip(cont)!= "y"
            println("\nOk, let's get the heck out of here!")
            return false
        end
    end

    return true
end

function input(prompt::AbstractString)
    print(prompt)
    readline()
end

"""
function_signatures_add(path::AbstractString,
                        signatureString::AbstractString="\$TYPEDSIGNATURES",
                        confirmFirst::Bool=true,
                        replaceExistingSignatures::Bool=true,
                        followSymlinks=::Bool=false)::Nothing

This function is used to add function signatures to an entire code-base with one command, or to standarsize
function signatures if they already exist.

This function edits all of the .jl files at or below path (which can be a directory or a .jl file).
If confirmFirst is true(default), it will display the list of files it intends to edit and seek user 
confirmation first.

After that, it reads the files, searches for strings ending on the line before a line starting with "function",
removes any existing function signatures (if replaceExistingSignatures, which is default), and makes sure 
the beginning of the string starts with signatureString (Defaults to TYPEDSIGNATURES), two newlines, 
and then whatever printable text was there before that was not a function signature.

followSymlinks (default: false) says whether to follow symbolic links when recursively traversing directories.

If you're using git, the changes can be reviewed before comitting, to help build confidence.

"""
function function_signatures_add(path::AbstractString;
                                 signatureString::AbstractString="\$TYPEDSIGNATURES",
                                 confirmFirst::Bool=true,
                                 replaceExistingSignatures::Bool=true,
                                 followSymlinks::Bool=false)
    
    allFiles=file_list_get(path,followSymlinks)
    onlyJlFiles=filter( x-> match(r"\.jl$", x)!=nothing , allFiles)

    if !files_ok_with_user(onlyJlFiles,confirmFirst)
        return
    end

    #Actually add them:
    foreach(x->function_signatures_add_to_file(x,signatureString,replaceExistingSignatures), onlyJlFiles)

end

function_signatures_add("/home/andromodon/tmp/genie/genie.jl", confirmFirst=false)
# function_signatures_add("/home/andromodon/tmp/genie/test.jl", confirmFirst=false)
