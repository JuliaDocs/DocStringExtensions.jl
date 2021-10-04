using Infiltrator

sigStringStrippedAcceptable=("\$TYPEDSIGNATURES","\$SIGNATURES", 
                            "\$(TYPEDSIGNATURES)", "\$(SIGNATURES)")


function components_display(components)
    display(collect(enumerate(components)))
    print("\n----------------------\n")
end

"""
function_signatures_add_to_file(filePath, signatureString, removeExistingSignatureFirst)

Edits the file at filePath to make sure every function in it has a function signature in it's docstring.

If removeExistingSignatureFirst is true, then it also removes existing function signatures and replaces those.

signatureString should be one of $sigStringStrippedAcceptable
"""
function function_signatures_add_to_file(filePath, signatureString, removeExistingSignatureFirst)

    if signatureString ∉ ("\$TYPEDSIGNATURES","\$SIGNATURES", "\$(TYPEDSIGNATURES)", "\$(SIGNATURES)")
        throw(ArgumentError("'$signatureString' is not one of these: $sigStringStrippedAcceptable"))
    end

    #Says if we'll output debugging info when we run:
    printStuff=false

    #Read the file:
    fileAsString=file_contents_as_string(filePath)

    #Our regexes that we'll put together into one big one (so the groups numbers refer to the whole thing not the parts)
    everythingBefore=r"(.*?)"s
    #Inspired by https://stackoverflow.com/questions/49906179/regex-to-match-string-syntax-in-code
    #Groups:  begQuote, docString, endQuote
    docStringGroups=r"(?:(\"\"\"|\")((?:(?!\2)(?:\\.|[^\\]))*)(\2))?"s
    whitespaceGroup=r"([ \t]*\n)"
    #matches:whiteSpaceBeforeFunction functionWordAndWhitespaceAfter moduleAndFunctionName restOfLine
    functionGroup=r"([ \t]*)(function[ \t]+)([^\(\s]+)(.*?\n)"

    regexToMatch=everythingBefore   * docStringGroups * whitespaceGroup * functionGroup

    printStuff && ( println(regexToMatch); println(""))

    #Get all of the matches, one per function that has a docstring:
    docStringsWhitespaceAndFunctions=eachmatch(regexToMatch, fileAsString)
    
    #This is to keep this at this scope and to initialize if there isn't a match:
    endOfLastGroup=1

    #This is an array we'll append to and then concatenate to make sure the regexes don't miss anything.
    inFileParts=[]

    #This is where we'll accumulate the output:
    outFileParts=[]

    #Go through them, one by one:
    for regexMatch in docStringsWhitespaceAndFunctions
        
        inComponents=regexMatch.captures 
        
        #Break it up:
        (everythingBefore, begQuote, docString, endQuote, whitespace,
             whiteSpaceBeforeFunction, func, moduleAndFunctionName, funcRestOfLine)=inComponents
        
        #Debugging info:
        printStuff && components_display(inComponents)

        #Get info we'll need about where we left off so we can calculate restOfFile later:
        startOfLastGroup=regexMatch.offsets[end]
        endOfLastGroup=startOfLastGroup+length(funcRestOfLine)

        #Calculate our new docString:
        outDocString=doc_string_modify(docString, moduleAndFunctionName, signatureString, removeExistingSignatureFirst)

        #Make outComponents from inComponents by replacing the docString and wrapping in tripple quotes always:
        outComponents=deepcopy(inComponents)
        outComponents[2]=indent_with_string(whiteSpaceBeforeFunction, "\"\"\"")
        outComponents[3]=indent_with_string(whiteSpaceBeforeFunction, outDocString)
        outComponents[4]="\"\"\""

        #If we're inserting our own docString, add an additional \n before it to make the spacing right:
        if docString == nothing
            outComponents[2]="\n"*outComponents[2]
        end

        #Add what we've parsed to inFileParts as a double-check, and also the output stuff outFileParts:
        push!(inFileParts,join(inComponents, ""))
        push!(outFileParts, join(outComponents, ""))
    end

    #The remainder of our file:
    restOfFile=fileAsString[endOfLastGroup:end]
    
    #Complete both inFileParts and outFileParts by adding the rest of the file:
    push!(inFileParts, restOfFile)
    push!(outFileParts, restOfFile)

    inFileReassembled=join(inFileParts,"")
    outFileStr=join(outFileParts,"")
    
    printStuff && print(restOfFile)

    # @assert inFileReassembled==fileAsString "Oh, crap, some part of the document escaped my regex!!"

    #Write the file to disk:
    write(filePath, outFileStr)
end

function file_contents_as_string(filePath)
    open(filePath) do fileHandle
        return read(fileHandle, String)
    end
end

"Adds stringToAdd at the beginning of each line in str"
function indent_with_string(stringToAdd, str)
    str |> x->split(x,"\n") |> y-> map(x->stringToAdd * x, y) |> x-> join(x,"\n")
end

"""
Takes something like "Abc.Def.funcName" or "funcName" and returns just "funcName"
"""
function get_function_name(moduleAndFunctionName)
    replace(moduleAndFunctionName, r".*\." => "")
end

"""
Takes the doc_string and either adds a function signature or replaces the existing one, depending on removeExistingSignatureFirst.  
"""
function doc_string_modify(docString, moduleAndFunctionName, signatureString, removeExistingSignatureFirst)
    
    printStuffHere=false

    #Make sure we actually have a string, even if the docString thing didn't match:
    if docString==nothing
        docString=""
    end

    #Strip out any module path stuff from the function name, since it may or may not be in the signture:
    functionName=get_function_name(moduleAndFunctionName)

    #I use ra to keep from having to escape a bunch of stuff, and I use Regex instead of r"asdf" so I can interporate
    # the functionName in it.
    #Matching parenthesis inspired by https://stackoverflow.com/questions/546433/regular-expression-to-match-balanced-parentheses
    docStrRe=Regex(raw"(^\s*)([^s]*?" * "$functionName" * raw")?(\((?:[^)(]+|(?-1))*+\))?([^\n]*\n\s*)?(.*?)(\s*)$","s")
    
    printStuffHere && ( println(docStrRe); println(""))

    docStrMatch=match(docStrRe, docString)
    @assert(docStrMatch!=nothing, "docStrRe should always match and it didn't!  String was : \"\"\"$docString\"\"\"")

    (whitespaceBeforeSignature, f1,f2,f3, restOfDocString, endingWhitespace)=docStrMatch.captures

    functionSignatureAndWhitespaceAfter=join((f1,f2,f3), "")

    printStuffHere && components_display(docStrMatch.captures)

    #If we're supposed to keep existing signatures and there's something to keep:
    if !removeExistingSignatureFirst && functionSignatureAndWhitespaceAfter != nothing
        #Use what's there:
        outSignatureString=functionSignatureAndWhitespaceAfter
    else
        #Insert our own:
        outSignatureString=signatureString

        #Add two \n\n between if there is stuff to separate.  If it's just the signatureString, then don't add the extra newlines:        
        if length(restOfDocString)!=0
            outSignatureString=outSignatureString* "\n\n"
        end
    end

    docStringOut=outSignatureString * restOfDocString
        
    #Wrap in \n so it feels at home in """:
    docStringOut="\n" * docStringOut * "\n"

    return docStringOut
end