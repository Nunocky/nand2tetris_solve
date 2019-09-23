# coding: utf-8

class String
  def numeric?
    Float(self) != nil rescue false
  end
end

class Parser
  A_COMMAND=0
  C_COMMAND=1
  L_COMMAND=2

  REGEXP_A = /@([a-zA-Z_\.\$:]?[a-zA-Z0-9_\.\$:]*)/
  REGEXP_C = /(([AMD]+)=)?([A-Z0-1\-\+\!\&\|]+)(?=;(J[A-Z]+))?/
  REGEXP_L = /\(([a-zA-Z_\.\$:]?[a-zA-Z0-9_\.\$:]*)\)/

  attr_reader :commandType, :symbol, :dest, :comp, :jump

  def initialize(filename)
    @lines = []
    @address = 0

    File.open(filename).readlines.each do |line|
      line.chomp!               # 改行文字を削除
      line.gsub!(/\/\/.*/, "")  # // 以降をカット
      line.gsub!(/ /, "")       # 空白をカット

      @lines << line
    end
  end

  def hasMoreCommands
    return @address < @lines.count
  end

  def advance
    s = @lines[@address]

    @commandType = -1

    if s.size == 0
      @address += 1
      return s
    end

    if s =~ REGEXP_L
      @symbol = $1
      @dest   = nil
      @comp   = nil
      @jump   = nil
      @commandType = L_COMMAND

    elsif s =~ REGEXP_A
      @symbol = $1
      @dest   = nil
      @comp   = nil
      @jump   = nil
      @commandType = A_COMMAND

    elsif s =~ REGEXP_C
      @symbol = nil
      @dest   = $2
      @jump   = $4
      @comp   = $3
      @commandType = C_COMMAND

    else
      if s.size != 0
        pp s
        abort
      end
    end

    @address += 1
    return s
  end

end


class Code
  Dest = {
    "M"   => "001",
    "D"   => "010",
    "MD"  => "011",
    "A"   => "100",
    "AM"  => "101",
    "AD"  => "110",
    "AMD" => "111",
  }

  Comp = {
    "0"   => "0101010",
    "1"   => "0111111",
    "-1"  => "0111010",
    "D"   => "0001100",
    "A"   => "0110000",
    "!D"  => "0001101",
    "!A"  => "0110001",
    "-D"  => "0001111",
    "-A"  => "0110011",
    "D+1" => "0011111",
    "A+1" => "0110111",
    "D-1" => "0001110",
    "A-1" => "0110010",
    "D+A" => "0000010",
    "D-A" => "0010011",
    "A-D" => "0000111",
    "D&A" => "0000000",
    "D|A" => "0010101",

    "M"   => "1110000",
    "!M"  => "1110001",
    "-M"  => "1110011",
    "M+1" => "1110111",
    "M-1" => "1110010",
    "D+M" => "1000010",
    "D-M" => "1010011",
    "M-D" => "1000111",
    "D&M" => "1000000",
    "D|M" => "1010101",
  }

  Jump = {
    #"" => "",
    "JGT" => "001",
    "JEQ" => "010",
    "JGE" => "011",
    "JLT" => "100",
    "JNE" => "101",
    "JLE" => "110",
    "JMP" => "111",
  }

  def dest(s)
    return Dest[s]
  end

  def comp(s)
    return Comp[s]
  end

  def jump(s)
    return Jump[s]
  end

end




class SymbolTable
  def initialize
    @tbl = {}
  end

  def addEntry(sym, address)
    @tbl[sym] = address
  end

  def contains(sym)
    @tbl.has_key?(sym)
  end

  def getAddress(sym)
    return @tbl[sym]
  end

end



# ---------------------------------------------------------------------
# ここからアセンブラ本体
# ---------------------------------------------------------------------

srcfilename = ARGV[0]

unless File.exist?(srcfilename)
  puts "file not found"
  exit 0
end

if FileTest.directory?(srcfilename)
  puts "#{srcfilename} is a directory"
  exit 0
end


basename = File.basename(srcfilename, ".*")

destfilename = "#{basename}.hack"

puts "#{srcfilename} -> #{destfilename}"



symTable = SymbolTable.new

symTable.addEntry("SP"     , 0x0000)
symTable.addEntry("LCL"    , 0x0001)
symTable.addEntry("ARG"    , 0x0002)
symTable.addEntry("THIS"   , 0x0003)
symTable.addEntry("THAT"   , 0x0004)
symTable.addEntry("R0"     , 0x0000)
symTable.addEntry("R1"     , 0x0001)
symTable.addEntry("R2"     , 0x0002)
symTable.addEntry("R3"     , 0x0003)
symTable.addEntry("R4"     , 0x0004)
symTable.addEntry("R5"     , 0x0005)
symTable.addEntry("R6"     , 0x0006)
symTable.addEntry("R7"     , 0x0007)
symTable.addEntry("R8"     , 0x0008)
symTable.addEntry("R9"     , 0x0009)
symTable.addEntry("R10"    , 0x000a)
symTable.addEntry("R11"    , 0x000b)
symTable.addEntry("R12"    , 0x000c)
symTable.addEntry("R13"    , 0x000d)
symTable.addEntry("R14"    , 0x000e)
symTable.addEntry("R15"    , 0x000f)
symTable.addEntry("SCREEN" , 0x4000)
symTable.addEntry("KBD"    , 0x6000)

# --------------------
# 1周目 : ラベルだけ
# --------------------

parser = Parser.new(srcfilename)

address = 0
while parser.hasMoreCommands
  line = parser.advance

  next if line.size == 0

  if parser.commandType == Parser::L_COMMAND
    sym = parser.symbol
    if symTable.contains(sym) == false
      symTable.addEntry(sym, address)
    end
  else
    address += 1
  end

end


# --------------------
# 2周目
# --------------------
code = Code.new

variable_index = 0x0010

fw = File.open(destfilename, "w")

parser = Parser.new(srcfilename)

address = 0
while parser.hasMoreCommands
  line = parser.advance

  next if line.size == 0

  case parser.commandType
  when Parser::A_COMMAND then

    if parser.symbol.numeric?
      value = parser.symbol.to_i

    elsif symTable.contains(parser.symbol)
      value = symTable.getAddress(parser.symbol)

    else
      symTable.addEntry(parser.symbol, variable_index)
      variable_index += 1

      value = symTable.getAddress(parser.symbol)
    end

    ss = "0" + ("0000000000000000" + (value.to_s(2)))[-15..-1]
    fw.puts ss

  when Parser::C_COMMAND then

    d = code.dest(parser.dest) || "000"
    c = code.comp(parser.comp)
    j = code.jump(parser.jump) || "000"

    ss = "111" + c + d + j

    fw.puts ss

  when Parser::L_COMMAND then
    # skip label

  else
    puts line
    raise "error"

  end

  address += 1

end


fw.close
puts "done."
