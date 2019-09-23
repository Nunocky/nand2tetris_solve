# coding: cp932
C_NULL       = -1
C_ARITHMETIC = 0
C_PUSH       = 1
C_POP        = 2
C_LABEL      = 3
C_GOTO       = 4
C_IF         = 5
C_FUNCTION   = 6
C_RETURN     = 7
C_CALL       = 8

class Parser
  def initialize(src_filename)
    @fr = File.open(src_filename, "r")
    @hasMoreCommands = true
  end

  def advance
    loop do
      @commandType = nil
      @arg1 = nil
      @arg2 = nil

      s = @fr.gets

      if s == nil
        @hasMoreCommands = false
        return C_NULL
      end

      s = s.gsub(/\/\/.*/, "").strip

      next if s.length == 0 # empty line

      c, @arg1, @arg2 = s.split
      @arg2 = @arg2.to_i if @arg2 != nil

      case c
      when "add", "sub", "neg", "eq", "gt", "lt", "and", "or", "not" then
        @arg1 = c
        @commandType = C_ARITHMETIC

      when "push" then
        @commandType = C_PUSH

      when "pop" then
        @commandType = C_POP

#      when "label" then
#        @commandType = C_LABEL
#
#      when "goto" then
#        @commandType = C_GOTO
#
#      when "if-goto" then
#        @commandType = C_IF
#
#      when "function" then
#        @commandType = C_FUNCTION
#
#      when "call" then
#        @commandType = C_CALL
#
#      when "return" then
#        @commandType = C_RETURN

      else
        puts "unsuppoted command #{c}"
        abort
      end

      break
    end
    
  end

  attr_reader :hasMoreCommands, :commandType, :arg1, :arg2
end


class CodeWriter
  def initialize(dest_filename)
#    @fw = STDOUT
    @fw = File.open(dest_filename, "w")
  end

  def setFileName(filename)
    @basename = File.basename(filename, '.*')
    @count=0
  end

  def writeArithmetic(command)
    @fw.puts("// #{command}")

    case command 
    when "add" then writeArithmetic_binary('+')
    when "sub" then writeArithmetic_binary('-')
    when "and" then writeArithmetic_binary('&')
    when "or"  then writeArithmetic_binary('|')

    when "not" then writeArithmetic_unary('!')
    when "neg" then writeArithmetic_unary('-')

    when "eq"  then writeArithmetic_comp('JEQ')
    when "gt"  then writeArithmetic_comp('JGT')
    when "lt"  then writeArithmetic_comp('JLT')

    else
      puts "unsupported"
    end
  end

  def writePushPop(command, segment, index)
    if command == C_PUSH
      case segment
        
      when "constant" then push_constant(index)

      when "local"    then push0("LCL", index)
      when "argument" then push0("ARG", index)
      when "this"     then push0("THIS", index)
      when "that"     then push0("THAT", index)

      when "pointer"  then push1(3, index)
      when "temp"     then push1(5, index)

      when "static"   then push_static(index)

      else
        puts "unsupported #{command}"
      end

    else
      # POP
      case segment

      when "local"    then pop0("LCL", index)
      when "argument" then pop0("ARG", index)
      when "this"     then pop0("THIS", index)
      when "that"     then pop0("THAT", index)

      when "pointer"  then pop1(3, index)
      when "temp"     then pop1(5, index)

      when "static"   then pop_static(index)
      else
        puts "unsupported #{command}"
      abort
      end

    end


  end

  def close
    @fw.close
  end


  #--------------------
  private 
  def getNewLabel
    label = "#{@basename}.#{@count}"
    @count += 1
    return label
  end


  #--------------------
  private
  def writeArithmetic_unary(op)
      @fw.print <<EOF
@SP
A=M-1

M=#{op}M
EOF
  end

  #--------------------
  private
  def writeArithmetic_binary(op)
    @fw.print <<EOF
@SP
M=M-1
A=M

D=M

@SP
M=M-1
A=M

D=M#{op}D

@SP
A=M
M=D

@SP
M=M+1

EOF
  end

  private
  def writeArithmetic_comp(op)
    label1 = getNewLabel
    label2 = getNewLabel
    @fw.print <<EOF
@SP
M=M-1
A=M

D=M

@SP
M=M-1
A=M

D=M-D
@#{label1}
D;#{op}
D=0
@#{label2}
0;JMP
(#{label1})
D=-1
(#{label2})

@SP
A=M
M=D

@SP
M=M+1
EOF

  end


  #----------------------------------------
  private
  def push_constant(index)
      @fw.print <<EOF
// PUSH constant #{index}
@#{index}
D=A

@SP
A=M
M=D

@SP
M=M+1
EOF
  end

  #----------------------------------------
  # push (local, argument, this, that)
  #----------------------------------------
  private
  def push0(segment, index)

      @fw.puts "// push #{segment} #{index}"
      @fw.puts "@#{segment}"
      @fw.puts "A=M"
      index.times do
        @fw.puts "A=A+1"
      end

      @fw.puts "D=M"

      @fw.print <<EOF
@SP
A=M
M=D

@SP
M=M+1
EOF

  end

  #----------------------------------------
  # pop (local, argument, this, that)
  #----------------------------------------
  private
  def pop0(segment, index)
      @fw.print <<EOF
// pop #{segment} #{index}
@SP
M=M-1
A=M

D=M

@#{segment}
A=M
EOF
      index.times do
        @fw.puts "A=A+1"
      end
      @fw.puts "M=D"
    
  end

  #----------------------------------------
  # push (pointer, temp)
  #----------------------------------------
  private
  def push1(base, index)
    @fw.puts "// PUSH #{base} #{index}"

    @fw.puts "@#{base}"
    index.times do 
      @fw.puts "A=A+1"
    end
    @fw.puts "D=M"

    @fw.puts "@SP"
    @fw.puts "A=M"
    @fw.puts "M=D"

    @fw.puts "@SP"
    @fw.puts "M=M+1"
  end
  
  #----------------------------------------
  # pop (pointer, temp)
  #----------------------------------------
  private
  def pop1(base, index)
    
    @fw.puts "// POP #{base} #{index}"
    @fw.puts "@SP"
    @fw.puts "M=M-1"
    @fw.puts "A=M"
    @fw.puts "D=M"
    @fw.puts "@#{base}"
    index.times do 
      @fw.puts "A=A+1"
    end
    @fw.puts "M=D"
  end

  #----------------------------------------
  # push static
  #----------------------------------------
  private
  def push_static(index)
    @fw.puts "// push static #{index}"
    @fw.puts "@#{@basename}.#{index}"
    @fw.puts "D=M"

    @fw.puts "@SP"    
    @fw.puts "A=M"    
    @fw.puts "M=D"    
    @fw.puts ""    
    @fw.puts "@SP"    
    @fw.puts "M=M+1"    
  end

  #----------------------------------------
  # pop static
  #----------------------------------------
  private
  def pop_static(index)
    @fw.puts "// pop static #{index}"
    @fw.puts "@SP"
    @fw.puts "M=M-1"
    @fw.puts "A=M"
    @fw.puts ""
    @fw.puts "D=M"
    @fw.puts "@#{@basename}.#{index}"
    @fw.puts "M=D"
  end



end



# --------------------------------------------------------------------------------
#
# --------------------------------------------------------------------------------

def parseFile(codeWriter, srcfilename)
  if File.extname(srcfilename) != ".vm"
    puts "not vm file : #{srcfilename}"
    return
  end

  puts "#{srcfilename}"
  
  parser = Parser.new(srcfilename)
  codeWriter.setFileName(srcfilename)
      
  while parser.hasMoreCommands
    parser.advance

    case parser.commandType
    when C_ARITHMETIC then
      codeWriter.writeArithmetic(parser.arg1)
    when C_PUSH, C_POP then
      codeWriter.writePushPop(parser.commandType, parser.arg1, parser.arg2)

    when C_LABEL      then
    when C_GOTO       then
    when C_IF         then
    when C_FUNCTION   then
    when C_RETURN     then
    when C_CALL       then
    end
  end
end



path = ARGV[0]

if FileTest.directory? path
  # Directory
  puts "directory"

  Dir.chdir(path) do
    pwd = File.basename(Dir.pwd)

    outfilename = "#{pwd}.asm"
    puts outfilename

    codeWriter = CodeWriter.new(outfilename)
    
    Dir.glob("*.vm") do |srcfilename|
      parseFile(codeWriter, srcfilename)
    end

    codeWriter.close
  end

elsif FileTest.file? path
  # File
  basename = File.basename(path, '.*')

  srcfilename = ARGV[0]
  outfilename = "#{basename}.asm"


  codeWriter = CodeWriter.new(outfilename)

  parseFile(codeWriter, srcfilename)
    
  codeWriter.close
  
else
  raise 'not file nor directory'
end

__END__

