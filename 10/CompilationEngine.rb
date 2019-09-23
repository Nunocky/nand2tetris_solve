# coding: utf-8
require './JackTokenizer.rb'

class CompilationEngine
  def initialize(outfilename, tokenizer)
    @fw = File.open(outfilename, "w")
    @tokenizer = tokenizer
    @indent = 0
  end


  def advance
    @tokenizer.advance
  end

  def step_back
    @tokenizer.step_back
  end

  def compileClass
    write "<class>"
    @indent += 1

    compile_keyword("class")
    compileClassName()
    compile_symbol("{")
    compileClassVarDecs()
    compileSubroutineDecs()
    compile_symbol("}")

    @indent -= 1
    write "</class>"
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
    write "<classVarDec>"
    @indent += 1

    compile_keyword(["static", "field"])
    compileType()
    compileVarName

    loop do
      advance
      symbol = @tokenizer.symbol
      step_back

      break if symbol != ","

      compile_symbol(",")
      compileVarName
    end

    compile_symbol(";")

    @indent -= 1
    write "</classVarDec>"
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
    write "<subroutineDec>"
    @indent += 1

    compile_keyword(["constructor", "function", "method"])

    @tokenizer.advance
    if @tokenizer.tokenType == JackTokenizer::KEYWORD && ["void", "int", "char", "boolean"].include?(@tokenizer.keyword)
      step_back
      compile_keyword(["void", "int", "char", "boolean"])
    elsif @tokenizer.tokenType == JackTokenizer::IDENTIFIER
      step_back
      compile_identifier()
    else
      raise ""
    end

    compile_identifier()

    compile_symbol("(")

    compileParameterList()

    compile_symbol(")")

    compileSubroutineBody()

    @indent -= 1
    write "</subroutineDec>"
  end


  def compileParameterList
    write "<parameterList>"
    @indent += 1

    advance
    keyword, identifier = @tokenizer.keyword, @tokenizer.identifier
    step_back

    if ["int", "char", "boolean"].include?(keyword) || identifier != nil
      compileType()
      compileVarName()

      loop do
        advance
        symbol = @tokenizer.symbol
        step_back

        break unless symbol == ","

        compile_symbol(",")
        compileType()
        compileVarName()
      end
    end

    @indent -= 1
    write "</parameterList>"
  end

  def compileSubroutineBody
    # '{' varDec* statements '}'

    write "<subroutineBody>"
    @indent += 1

    compile_symbol("{")

    # compileVarDecs()
    loop do
      @tokenizer.advance
      if @tokenizer.tokenType == JackTokenizer::KEYWORD && @tokenizer.keyword == "var"
        @tokenizer.step_back
        compileVarDec()
      else
        @tokenizer.step_back
        break
      end
    end

    compileStatements()

    compile_symbol("}")

    @indent -= 1
    write "</subroutineBody>"
  end

  # varDec : 'var' type varName (',' varName)* ';'
  def compileVarDec
    write "<varDec>"
    @indent += 1

    # 'var'
    compile_keyword("var")

    # type
    compileType()

    # varName (',' varName)* ';'
    loop do
      compileVarName()

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

    @indent -= 1
    write "</varDec>"
  end

  def compileSubroutineName()
    compile_identifier()
  end

  def compileClassName()
    compile_identifier()
  end

  def compileVarName()
    compile_identifier()
  end

  def compileStatements
    write "<statements>"
    @indent += 1

    loop do
      advance
      keyword = @tokenizer.keyword
      step_back

      break unless ["let", "if", "while", "do", "return"].include? keyword
      compileStatement()
    end

    @indent -= 1
    write "</statements>"
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
    write "<letStatement>"
    @indent += 1

    compile_keyword("let")
    compileVarName()

    advance
    symbol = @tokenizer.symbol
    step_back

    if symbol == "["
      compile_symbol('[')
      compileExpression()
      compile_symbol(']')
    end

    compile_symbol('=')

    compileExpression()

    compile_symbol(';')

    @indent -= 1
    write "</letStatement>"
  end

  def compileIf
    write "<ifStatement>"
    @indent += 1

    compile_keyword("if")
    compile_symbol("(")
    compileExpression()
    compile_symbol(")")
    compile_symbol("{")
    compileStatements()
    compile_symbol("}")

    advance
    keyword = @tokenizer.keyword
    step_back
    if @tokenizer.keyword == "else"
      compile_keyword("else")
      compile_symbol("{")
      compileStatements()
      compile_symbol("}")
    end

    @indent -= 1
    write "</ifStatement>"
  end

  def compileWhile
    write "<whileStatement>"
    @indent += 1

    compile_keyword("while")
    compile_symbol("(")
    compileExpression()
    compile_symbol(")")
    compile_symbol("{")
    compileStatements()
    compile_symbol("}")

    @indent -= 1
    write "</whileStatement>"
  end

  def compileDo
    write "<doStatement>"
    @indent += 1

    compile_keyword("do")
    compileSubroutineCall()
    compile_symbol(";")

    @indent -= 1
    write "</doStatement>"
  end

  def compileReturn
    write "<returnStatement>"
    @indent += 1

    compile_keyword("return")

    advance
    symbol = @tokenizer.symbol
    step_back

    if symbol == ";"
      compile_symbol(";")
    else
      compileExpression()
      compile_symbol(";")
    end

    @indent -= 1
    write "</returnStatement>"
  end


  #
  def compileExpression
    write "<expression>"
    @indent += 1

    compileTerm()

    loop do
      advance
      symbol = @tokenizer.symbol
      step_back

      break unless ["+", "-", "*", "/", "&", "|", "<", ">", "="].include? symbol
      compile_symbol(symbol)
      compileTerm()
    end

    @indent -= 1
    write "</expression>"
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

    write "<term>"
    @indent += 1

    advance
    intVal     = @tokenizer.intVal
    stringVal  = @tokenizer.stringVal
    keyword    = @tokenizer.keyword
    symbol     = @tokenizer.symbol
    identifier = @tokenizer.identifier
    step_back

    if intVal != nil
      compile_intVal(intVal)

    elsif stringVal != nil
      compile_stringVal(stringVal)

    elsif keyword != nil
      compileKeywordConstant(keyword)

    elsif identifier != nil
      advance
      advance
      symbol = @tokenizer.symbol
      step_back
      step_back

      if ["[", ".", "("].include?(symbol) == false
        compileVarName()

      elsif symbol == "["
        compileVarName()
        compile_symbol("[")
        compileExpression()
        compile_symbol("]")

      elsif symbol == "."
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

    else
      raise ""
    end


    @indent -= 1
    write "</term>"
  end

  def compileSubroutineCall()
    # subroutineName        '(' expressionList ')'
    # (className | varName) '.' subroutineName '(' expressionList ')'

    #compile_identifier()

    advance
    identifier = @tokenizer.identifier
    advance
    symbol = @tokenizer.symbol
    step_back
    step_back

    case symbol
    when "("
      compileSubroutineName()
      compile_symbol("(")
      compileExpressionList()
      compile_symbol(")")
    when "."

      begin
        compileClassName()
      rescue
        begin
          step_back
          compileVarName
        rescue
          raise ""
        end
      end

      compile_symbol(".")
      compileSubroutineName()
      compile_symbol("(")
      compileExpressionList()
      compile_symbol(")")
    else
      raise ""
    end


  end

  def compileExpressionList
    write "<expressionList>"
    @indent += 1

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

      loop do
        advance
        symbol = @tokenizer.symbol
        step_back

        break if symbol != ','

        compile_symbol(",")
        compileExpression()
      end
    end


    @indent -= 1
    write "</expressionList>"
  end

  #
  #
  #
  #
  #
  def advance_and_check(&cond)
    @tokenizer.advance

#    puts "#{@tokenizer.tokenType} #{@tokenizer.keyword} #{@tokenizer.symbol} #{@tokenizer.identifier} #{@tokenizer.intVal} #{@tokenizer.stringVal}"

    val = yield
    if !val
      raise
    end
  end

  def write(str)
    @fw.print(" " * (2 * @indent) + str + "\n")
  end

  def write_keyword(keyword)
    write "<keyword> #{keyword} </keyword>"
  end

  def write_symbol(symbol)
    case symbol
      when "<"  then symbol = "&lt;"
      when ">"  then symbol = "&gt;"
      when "&"  then symbol = "&amp;"
    end

    write "<symbol> #{symbol} </symbol>"
  end

  def write_identifier(identifier)
    write "<identifier> #{identifier} </identifier>"
  end

  def write_intVal(intVal)
    write "<integerConstant> #{intVal} </integerConstant>"
  end

  def write_stringVal(stringVal)
    write "<stringConstant> #{stringVal} </stringConstant>"
  end

  def compile_keyword(keyword)
    advance_and_check {@tokenizer.tokenType == JackTokenizer::KEYWORD && [keyword].flatten.include?(@tokenizer.keyword)}
    write_keyword(@tokenizer.keyword)
  end

  def compile_identifier()
    advance_and_check {@tokenizer.tokenType == JackTokenizer::IDENTIFIER}
    write_identifier(@tokenizer.identifier)
  end

  def compile_symbol(symbol)
    advance_and_check { @tokenizer.tokenType == JackTokenizer::SYMBOL && @tokenizer.symbol == symbol }
    write_symbol(symbol)
  end

#  def compileVarDecs
#    loop do
#      @tokenizer.advance
#      if @tokenizer.tokenType == JackTokenizer::KEYWORD && @tokenizer.keyword == "var"
#        @tokenizer.step_back
#        compileVarDec()
#      else
#        @tokenizer.step_back
#        break
#      end
#    end
#  end



  def compile_intVal(intVal)
    advance_and_check {@tokenizer.tokenType == JackTokenizer::INT_CONST}
    write_intVal(@tokenizer.intVal)
  end

  def compile_stringVal(stringVal)
    advance_and_check {@tokenizer.tokenType == JackTokenizer::STRING_CONST}
    write_stringVal(@tokenizer.stringVal)
  end

  def compileKeywordConstant(keyword)
    advance_and_check {@tokenizer.tokenType == JackTokenizer::KEYWORD && ["true", "false", "null", "this"].include?(@tokenizer.keyword)}
    write_keyword(@tokenizer.keyword)
  end

  def compileUnaryOp(op)
    advance_and_check {@tokenizer.tokenType == JackTokenizer::SYMBOL && ["-", "~"].include?(@tokenizer.symbol)}
    write_symbol(@tokenizer.symbol)
  end


end

