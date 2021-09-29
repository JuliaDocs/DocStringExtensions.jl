
function file_contents_as_string(filePath)
    open(filePath) do fileHandle
        return read(fileHandle, String)
    end
end

signatureStringsAcceptable=("\$TYPEDSIGNATURES","\$SIGNATURES", 
                            "\$(TYPEDSIGNATURES)", "\$(SIGNATURES)")

"""
Edits the file at filePath to make sure every function in it has a function signature in it's docstring.

If replaceExistingSignatures is true, then it also removes existing function signatures and replaces those.

signatureString should be one of $signatureStringsAcceptable
"""
function function_signatures_add_to_file(filePath, signatureString, replaceExistingSignatures)
    if signatureString ∉ ("\$TYPEDSIGNATURES","\$SIGNATURES", "\$(TYPEDSIGNATURES)", "\$(SIGNATURES)")
        throw(ArgumentError("'$signatureString' is not one of these expected values: $signatureStringsAcceptable"))
    end

    #Read the file:
    fileAsString=file_contents_as_string(filePath)

    #Inspired by https://stackoverflow.com/questions/49906179/regex-to-match-string-syntax-in-code
    everythingBefore=r"(.*?)"s
    docStringGroups=r"(\"\"\"|\")((?:(?!\2)(?:\\.|[^\\]))*)(\2)"s
    whitespaceGroup=r"([ \t]*\n)"
    functionGroup=r"([ \t]*function .*?\n)"

    regexToMatch=everythingBefore   * docStringGroups * whitespaceGroup * functionGroup

    #Get all of the matches, one per function that has a docstring:
    docStringsWhitespaceAndFunctions=eachmatch(regexToMatch, fileAsString)
    
    #This is just to keep this at this scope:
    endOfLastGroup=-1

    #This is an array we'll append to and then concatenate to make sure we don't miss anything
    # in the regexes:
    fileParts=[]

    #Go through them, one by one:
    for regexMatch in docStringsWhitespaceAndFunctions
        
        components=regexMatch.captures 
        
        #Break it up:
        (everythingBefore, begQuote, docString, endQuote, whitespace, func)=components

        # print(join(components, "|"))
        # print("\n----------------------\n")

        startOfLastGroup=regexMatch.offsets[end]
        endOfLastGroup=startOfLastGroup+length(func)

        push!(fileParts,join(components, ""))
    end

    #The remainder of our file:
    restOfFile=fileAsString[endOfLastGroup:end]
    # print(restOfFile)
    push!(fileParts, restOfFile)

    fileReassembled=join(fileParts,"")

    @assert fileReassembled==fileAsString "Oh, crap, some part of the document escaped my regex!!"
end