require 'pp'



class String
  def is_number?
    true if Float(self) rescue false
  end
end

class JackTokenizer
  KEYWORD      = 0
  SYMBOL       = 1
  IDENTIFIER   = 2
  INT_CONST    = 3
  STRING_CONST = 4

  def initialize(src)
    @tokens=[]
    @token_index = 0
    scan(src)
  end

  def hasMoreTokens
    @token_index < @tokens.length
  end

  def advance
    @tokenType, @keyword, @symbol, @identifier, @intVal, @stringVal = @tokens[@token_index]
    @token_index += 1
  end

  def step_back
    @token_index -= 1
    @tokenType, @keyword, @symbol, @identifier, @intVal, @stringVal = @tokens[@token_index]
  end

  attr_reader :tokenType, :keyword, :symbol, :identifier, :intVal, :stringVal


  private

  KEYWORDS=[
    "class",
    "constructor",
    "function",
    "method",
    "field",
    "static",
    "var",
    "int",
    "char",
    "boolean",
    "void",
    "true",
    "false",
    "null",
    "this",
    "let",
    "do",
    "if",
    "else",
    "while",
    "return",
  ]

  SYMBOLS=[
    "{",
    "}",
    "(",
    ")",
    "[",
    "]",
    ".",
    ",",
    ";",
    "+",
    "-",
    "*",
    "/",
    "&",
    "|",
    "<",
    ">",
    "=",
    "~",
  ]

  def scan(src)
    File.open(src, "r") do |f|
      @file_str = f.read
      @idx = 0
      @stage = ""

      while @idx < @file_str.length
        c0 = @file_str[@idx]

        case c0
        when " ", "\t", "\n", "\r" then
          @idx += 1

        when "/" then
          c1 = @file_str[@idx+1]

          if c1 == "/"
            process_comment0()
          elsif c1 == "*"
            process_comment1()
          else
            process_symbol("/")
          end

        when "\"" then
          process_quote()

        else
          if SYMBOLS.include?(c0)
            process_symbol(c0)
          else
            process_str_token()
          end
        end
      end
    end
  end

  def process_comment0()
    while @file_str[@idx] != "\n"
      @idx += 1
    end
    @idx += 1
  end

  def process_comment1()
    @idx += 1
    
    loop do
      @idx += 1
      break if @file_str[@idx] == "*" && @file_str[@idx+1] == "/"
    end

    @idx += 3
  end

  def process_symbol(sym)
    @tokens << [SYMBOL, nil, sym, nil, nil, nil]
    @idx += 1    
  end

  def process_quote()
    token = ""
    @idx += 1    

    loop do
      token += @file_str[@idx]
      @idx += 1

      break if @file_str[@idx] == "\""
    end

    @idx += 1
    @tokens << [STRING_CONST, nil, nil, nil, nil, token]
  end

  def process_str_token()
    token = ""

    loop do
      token += @file_str[@idx]
      @idx += 1
      break if [" ", "\t", "\r", "\n"].include? @file_str[@idx]
      break if SYMBOLS.include? @file_str[@idx]
    end

    if KEYWORDS.include? token
      @tokens << [KEYWORD,    token, nil, nil,   nil,        nil]
    elsif token.is_number?
      @tokens << [INT_CONST,  nil,   nil, nil,   token.to_i, nil]
    else
      @tokens << [IDENTIFIER, nil,   nil, token, nil,        nil]
    end
    
  end

  

end








if __FILE__ == $0
  scanner = JackTokenizer.new(ARGV[0])

  puts "<tokens>"

  while scanner.hasMoreTokens
    scanner.advance

    case scanner.tokenType
        when JackTokenizer::KEYWORD then
          puts "<keyword> #{scanner.keyword} </keyword>"
        when JackTokenizer::SYMBOL then
          sym = scanner.symbol
          if sym == "<"
            sym = "&lt;"
          elsif sym == ">"
            sym = "&gt;"
          elsif sym == "&"
            sym = "&amp;"
          end

          puts "<symbol> #{sym} </symbol>"

        when JackTokenizer::IDENTIFIER then
          puts "<identifier> #{scanner.identifier} </identifier>"
        when JackTokenizer::INT_CONST then
          puts "<integerConstant> #{scanner.intVal} </integerConstant>"
        when JackTokenizer::STRING_CONST then
          puts "<stringConstant> #{scanner.stringVal} </stringConstant>"

    end
  end

  puts "</tokens>"

end


__END__



