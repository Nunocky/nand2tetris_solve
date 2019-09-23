# coding: cp932
require './JackTokenizer.rb'
require './SymbolTable.rb'
require './VMWriter.rb'

class CompilationEngine
  def initialize(outfilename, tokenizer)
    @tokenizer = tokenizer

    @symbolTable = SymbolTable.new()
    @vmWriter = VMWriter.new(outfilename)
  end

  def advance
    @tokenizer.advance
  end

  def step_back
    @tokenizer.step_back
  end

  def compileClass
    compile_keyword("class")
    @className = compileClassName()
    compile_symbol("{")
    compileClassVarDecs()
    compileSubroutineDecs()
    compile_symbol("}")
  end

  def compileClassVarDecs()
    loop do
      advance
      if ["static", "field"].include? @tokenizer.keyword
        step_back
        compileClassVarDec()
      else
        step_back
        break
      end
    end
  end

  def compileSubroutineDecs()
    loop do
      advance
      keyword = @tokenizer.keyword
      step_back
      if ["constructor", "function", "method"].include? keyword
        compileSubroutineDec()
      else
        break
      end
    end
  end

  def compileClassVarDec
    qual = compile_keyword(["static", "field"])
    type = compileType()
    varName = compileVarName()

    if qual == "static"
      @symbolTable.define(varName, type, SymbolTable::C_STATIC)
    else
      @symbolTable.define(varName, type, SymbolTable::C_FIELD)
    end

    loop do
      advance
      symbol = @tokenizer.symbol
      step_back

      break if symbol != ","

      compile_symbol(",")
      varName = compileVarName()

      if qual == "static"
        @symbolTable.define(varName, type, SymbolTable::C_STATIC)
      else
        @symbolTable.define(varName, type, SymbolTable::C_FIELD)
      end
    end

    compile_symbol(";")
  end

  def compileType()
    begin
      compile_keyword(["int", "char", "boolean"])
    rescue
      step_back

      begin
        compile_identifier()
      rescue
        raise ""
      end
    end
  end

  def compileSubroutineDec
    @modifier = compile_keyword(["constructor", "function", "method"])

    advance
    type = @tokenizer.keyword
    step_back

    if ["void", "int", "char", "boolean"].include?(type)
      compile_keyword(["void", "int", "char", "boolean"])
    else
      compile_identifier()
    end

    @subroutine_name = compile_identifier()

    @symbolTable.startSubroutine()

    compile_symbol("(")

    compileParameterList()

    compile_symbol(")")

    compileSubroutineBody()
  end


  def compileParameterList
    if @modifier == "method"
      @symbolTable.define("$this", @className, SymbolTable::C_ARG)
    end

    advance
    keyword, identifier = @tokenizer.keyword, @tokenizer.identifier
    step_back

    if ["int", "char", "boolean"].include?(keyword) || identifier != nil
      type = compileType()
      varName = compileVarName()

      @symbolTable.define(varName, type, SymbolTable::C_ARG)

      loop do
        advance
        symbol = @tokenizer.symbol
        step_back

        break unless symbol == ","

        compile_symbol(",")

        type = compileType()
        varName = compileVarName()
        @symbolTable.define(varName, type, SymbolTable::C_ARG)
      end
    end
  end

  def compileSubroutineBody
    # '{' varDec* statements '}'

    compile_symbol("{")

    compileVarDecs()

    @vmWriter.writeFunction("#{@className}.#{@subroutine_name}", 
                            @symbolTable.varCount(SymbolTable::C_VAR))

    case @modifier
    when "constructor"
      nFields = @symbolTable.varCount(SymbolTable::C_FIELD)

#      @vmWriter.writeFunction("#{@className}.#{@subroutine_name}", 
#                              @symbolTable.varCount(SymbolTable::C_VAR))

      @vmWriter.writePush(VMWriter::C_CONST, nFields)
      @vmWriter.writeCall("Memory.alloc", 1)
      @vmWriter.writePop(VMWriter::C_POINTER, 0)

    when "function"
#      @vmWriter.writeFunction("#{@className}.#{@subroutine_name}", 
#                              @symbolTable.varCount(SymbolTable::C_VAR))
#      @arg_offset = 0

    when "method"
#      @vmWriter.writeFunction("#{@className}.#{@subroutine_name}", 
#                              @symbolTable.varCount(SymbolTable::C_VAR))

      @vmWriter.writePush(VMWriter::C_ARG, 0)
      @vmWriter.writePop(VMWriter::C_POINTER, 0)
#      @arg_offset = 1
    end
    
    compileStatements()

    compile_symbol("}")
  end

  def compileVarDecs
    loop do
      advance
      keyword = @tokenizer.keyword
      step_back

      if keyword == "var"
        compileVarDec()
      else
        break
      end
    end
  end

  # varDec : 'var' type varName (',' varName)* ';'
  def compileVarDec
    # 'var'
    compile_keyword("var")

    # type
    type = compileType()

    # varName (',' varName)* ';'
    loop do
      varName = compileVarName()

      @symbolTable.define(varName, type, SymbolTable::C_VAR)
      
      begin
        compile_symbol(";")
        break
      rescue
        begin
          step_back
          compile_symbol(",")
        rescue
          raise ""
        end
      end

    end
  end

  def compileSubroutineName()
    return compile_identifier()
  end

  def compileClassName()
    return compile_identifier()
  end

  def compileVarName()
    return compile_identifier()
  end

  def compileStatements
    loop do
      advance
      keyword = @tokenizer.keyword
      step_back

      break unless ["let", "if", "while", "do", "return"].include? keyword
      compileStatement()
    end
  end

  def compileStatement
    @tokenizer.advance
    keyword  = @tokenizer.keyword
    step_back

    case keyword
    when "let"       then compileLet()
    when "if"        then compileIf()
    when "while"     then compileWhile()
    when "do"        then compileDo()
    when "return"    then compileReturn()
    else
      raise ""
    end
  end

  def compileLet
    compile_keyword("let")
    varName = compileVarName()

    segment, index = vm_get_variable_segment_index(varName)

    advance
    symbol = @tokenizer.symbol
    step_back

    if symbol == "["

      @vmWriter.writePush(segment, index)

      compile_symbol('[')
      compileExpression()
      compile_symbol(']')

      @vmWriter.writeArithmetic(VMWriter::C_ADD)

      compile_symbol('=')
      compileExpression()
      compile_symbol(';')

      @vmWriter.writePop(VMWriter::C_TEMP, 0)
      @vmWriter.writePop(VMWriter::C_POINTER, 1)
      @vmWriter.writePush(VMWriter::C_TEMP, 0)

      @vmWriter.writePop(VMWriter::C_THAT, 0)

    else
      compile_symbol('=')
      expression = compileExpression()
      compile_symbol(';')

      @vmWriter.writePop(segment, index)
    end
  end

  def compileIf
    label2 = getNewLabel("IF_TRUE")
    label1 = getNewLabel("IF_FALSE")

    compile_keyword("if")
    compile_symbol("(")
    compileExpression()
    compile_symbol(")")

    @vmWriter.writeArithmetic(VMWriter::C_NOT)
    @vmWriter.writeIf(label1)

    compile_symbol("{")
    compileStatements()
    compile_symbol("}")

    @vmWriter.writeGoto(label2)
    @vmWriter.writeLabel(label1)

    advance
    keyword = @tokenizer.keyword
    step_back

    if @tokenizer.keyword == "else"
      compile_keyword("else")
      compile_symbol("{")
      compileStatements()
      compile_symbol("}")
    end

    @vmWriter.writeLabel(label2)
  end

  def compileWhile
    label1 = getNewLabel("WHILE_START")
    label2 = getNewLabel("WHILE_END")

    compile_keyword("while")
    @vmWriter.writeLabel(label1)
    compile_symbol("(")
    compileExpression()
    @vmWriter.writeArithmetic(VMWriter::C_NOT)
    compile_symbol(")")
    compile_symbol("{")

    @vmWriter.writeIf(label2)
    compileStatements()
    @vmWriter.writeGoto(label1)
    compile_symbol("}")
    @vmWriter.writeLabel(label2)
  end

  def compileDo
    compile_keyword("do")
    compileSubroutineCall()
    compile_symbol(";")

    @vmWriter.writePop(VMWriter::C_TEMP, 0)
  end

  def compileReturn
    compile_keyword("return")

    advance
    symbol = @tokenizer.symbol
    step_back

    if symbol == ";"
      @vmWriter.writePush(VMWriter::C_CONST, 0)
      compile_symbol(";")
    else
      compileExpression()
      compile_symbol(";")
    end

    @vmWriter.writeReturn()
  end

  def compileExpression
    compileTerm()

    loop do
      advance
      symbol = @tokenizer.symbol
      step_back

      break unless ["+", "-", "*", "/", "&", "|", "<", ">", "="].include? symbol
      compile_symbol(symbol)
      compileTerm()

      case symbol
      when "+"
        @vmWriter.writeArithmetic(VMWriter::C_ADD)
      when "-"
        @vmWriter.writeArithmetic(VMWriter::C_SUB)
      when "*"
        @vmWriter.writeCall("Math.multiply", 2)
      when "/"
        @vmWriter.writeCall("Math.divide", 2)
      when "&"
        @vmWriter.writeArithmetic(VMWriter::C_AND)
      when "|"
        @vmWriter.writeArithmetic(VMWriter::C_OR)
      when "<"
        @vmWriter.writeArithmetic(VMWriter::C_LT)
      when ">"
        @vmWriter.writeArithmetic(VMWriter::C_GT)
      when "="
        @vmWriter.writeArithmetic(VMWriter::C_EQ)
      else
        raise ""
      end

    end
  end

  def compileTerm
    # integerConstant
    # stringConstant
    # keywordConstant
    # varName
    # varName '[' expression ']'
    # subroutineCall
    # '(' expression ')'
    # unaryOp term

    advance
    intVal     = @tokenizer.intVal
    stringVal  = @tokenizer.stringVal
    keyword    = @tokenizer.keyword
    symbol     = @tokenizer.symbol
    identifier = @tokenizer.identifier
    step_back

    if intVal != nil
      compile_intVal(intVal)
      @vmWriter.writePush(VMWriter::C_CONST, intVal)

    elsif stringVal != nil
      compile_stringVal(stringVal)

      @vmWriter.writePush(VMWriter::C_CONST, stringVal.length)
      @vmWriter.writeCall("String.new", 1)
      stringVal.each_char do |ch|
        @vmWriter.writePush(VMWriter::C_CONST, ch.ord)
        @vmWriter.writeCall("String.appendChar", 2)
      end

    elsif keyword != nil
      compileKeywordConstant(keyword)

      case keyword
      when "true"
        @vmWriter.writePush(VMWriter::C_CONST, 0)
        @vmWriter.writeArithmetic(VMWriter::C_NOT)
      when "false"
        @vmWriter.writePush(VMWriter::C_CONST, 0)
      when "null"
        @vmWriter.writePush(VMWriter::C_CONST, 0)
      when "this"
        @vmWriter.writePush(VMWriter::C_POINTER, 0)
      else
        raise ""
      end

    elsif identifier != nil
      advance
      advance
      symbol = @tokenizer.symbol
      step_back
      step_back

      if ["[", ".", "("].include?(symbol) == false
        varName = compileVarName()

        segment, index = vm_get_variable_segment_index(varName)
        @vmWriter.writePush(segment, index)

      elsif symbol == "["
        varName = compileVarName()
        segment, index = vm_get_variable_segment_index(varName)
        @vmWriter.writePush(segment, index)

        compile_symbol("[")
        compileExpression()
        compile_symbol("]")

        @vmWriter.writeArithmetic(VMWriter::C_ADD)
        @vmWriter.writePop(VMWriter::C_POINTER, 1)
        @vmWriter.writePush(VMWriter::C_THAT, 0)
        
      elsif symbol == "."
        @receiver = identifier
        compileSubroutineCall()

      elsif symbol == "("
        compile_symbol("(")
        compileExpression()
        compile_symbol(")")

      else
        raise ""
      end

    elsif symbol == "("

      compile_symbol("(")
      compileExpression()
      compile_symbol(")")

    elsif ["-", "~"].include?(symbol)
      compileUnaryOp(symbol)
      compileTerm()

      case symbol
      when "-"
        @vmWriter.writeArithmetic(VMWriter::C_NEG)
      when "~"
        @vmWriter.writeArithmetic(VMWriter::C_NOT)
      end

    else
      raise ""
    end

  end

  def compileSubroutineCall()
    # subroutineName        '(' expressionList ')'
    # (className | varName) '.' subroutineName '(' expressionList ')'

    advance
    identifier = @tokenizer.identifier
    advance
    symbol = @tokenizer.symbol
    step_back
    step_back

    case symbol
    when "("
      subroutineName = compileSubroutineName()
      @vmWriter.writePush(VMWriter::C_POINTER, 0) # this

      compile_symbol("(")
      
      nArgs = compileExpressionList()
      compile_symbol(")")

      @vmWriter.writeCall("#{@className}.#{subroutineName}", nArgs + 1)
      
    when "."

      begin
        cvName = compileClassName()
      rescue
        begin
          step_back
          cvName = compileVarName
        rescue
          raise ""
        end
      end

      if @symbolTable.typeOf(cvName) == nil
        # function call
        compile_symbol(".")
        subroutineName = compileSubroutineName()
        compile_symbol("(")
        
        nArgs = compileExpressionList()
        compile_symbol(")")

        @vmWriter.writeCall("#{cvName}.#{subroutineName}", nArgs)
      else
        # method call
        className = @symbolTable.typeOf(cvName)

        segment, index = vm_get_variable_segment_index(cvName)
        @vmWriter.writePush(segment, index)
        
        compile_symbol(".")
        subroutineName = compileSubroutineName()
        compile_symbol("(")
        
        nArgs = compileExpressionList()
        compile_symbol(")")

        @vmWriter.writeCall("#{className}.#{subroutineName}", nArgs + 1)
      end

    else
      raise ""
    end


  end

  def compileExpressionList
    nArgs = 0

    advance
    intVal     = @tokenizer.intVal
    stringVal  = @tokenizer.stringVal
    keyword    = @tokenizer.keyword
    symbol     = @tokenizer.symbol
    identifier = @tokenizer.identifier
    step_back

    val = false
    val |= intVal != nil
    val |= stringVal != nil
    val |= keyword != nil
    val |= identifier != nil
    val |= symbol == "("
    val |= symbol == "-"
    val |= symbol == "~"

    if val
      compileExpression()
      nArgs += 1

      loop do
        advance
        symbol = @tokenizer.symbol
        step_back

        break if symbol != ','

        compile_symbol(",")
        compileExpression()
        nArgs += 1
      end
    end

    return nArgs
  end

  #
  #
  #
  #
  #
  def advance_and_check(&cond)
    @tokenizer.advance

    val = yield
    if !val
      raise
    end
  end

  def compile_keyword(keyword)
    advance_and_check {@tokenizer.tokenType == JackTokenizer::KEYWORD && [keyword].flatten.include?(@tokenizer.keyword)}

    return @tokenizer.keyword
  end

  def compile_identifier()
    advance_and_check {@tokenizer.tokenType == JackTokenizer::IDENTIFIER}

    return @tokenizer.identifier
end

  def compile_symbol(symbol)
    advance_and_check { @tokenizer.tokenType == JackTokenizer::SYMBOL && @tokenizer.symbol == symbol }

    return @tokenizer.symbol
  end




  def compile_intVal(intVal)
    advance_and_check {@tokenizer.tokenType == JackTokenizer::INT_CONST}

    return @tokenizer.intVal
  end

  def compile_stringVal(stringVal)
    advance_and_check {@tokenizer.tokenType == JackTokenizer::STRING_CONST}

    return @tokenizer.stringVal
  end

  def compileKeywordConstant(keyword)
    advance_and_check {@tokenizer.tokenType == JackTokenizer::KEYWORD && ["true", "false", "null", "this"].include?(@tokenizer.keyword)}

    return @tokenizer.keyword
  end

  def compileUnaryOp(op)
    advance_and_check {@tokenizer.tokenType == JackTokenizer::SYMBOL && ["-", "~"].include?(@tokenizer.symbol)}

    return @tokenizer.symbol
  end




  def vm_get_variable_segment_index(varName)
    kind  = @symbolTable.kindOf(varName)
    segment = case kind
              when SymbolTable::C_STATIC then VMWriter::C_STATIC
              when SymbolTable::C_FIELD  then VMWriter::C_THIS
              when SymbolTable::C_ARG    then VMWriter::C_ARG
              when SymbolTable::C_VAR    then VMWriter::C_LOCAL
              else
                raise "??? #{varName}"
              end

    index = @symbolTable.indexOf(varName)


#    if segment == VMWriter::C_ARG
#      @arg_offset ||= 0
#      index += @arg_offset
#    end

    return segment, index
  end
  
  def getNewLabel(label)
    @label_count ||= 1
    retVal = "#{@className}.#{@subroutine_name}_#{label}_#{@label_count}"
    @label_count += 1

    return retVal
  end

end

