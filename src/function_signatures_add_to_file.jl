
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

    docStringGroup=r"(\"[^\"]*[^\\\"]\"|\"\"\".*?\"\"\")"s
    whitespaceGroup=r"([ \t]*\n)"
    functionGroup=r"([ \t]*function .*\n)"

    regexToMatch=docStringGroup * whitespaceGroup * functionGroup

    docStringsWhitespaceAndFunctions=eachmatch(regexToMatch, fileAsString)
    
    for regexMatch in docStringsWhitespaceAndFunctions
        
        (docString, whitespace, func)=regexMatch.captures 
        
        println("$docString|$whitespace|$func")
        println("----------------------")

    end
end