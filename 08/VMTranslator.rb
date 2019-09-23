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

      when "label" then
        @commandType = C_LABEL

      when "goto" then
        @commandType = C_GOTO

      when "if-goto" then
        @commandType = C_IF

      when "function" then
        @commandType = C_FUNCTION

      when "call" then
        @commandType = C_CALL

      when "return" then
        @commandType = C_RETURN

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
    writeSysInit()
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
  def getNewLabel
    label = "#{@basename}.#{@count}"
    @count += 1
    return label
  end

  def getNewReturnLabel()
    @retlabel_count ||= 0
    label = "_RETURN_LABEL_#{@retlabel_count}"
    
    @retlabel_count+=1
    return label
  end





  #--------------------
  def writeArithmetic_unary(op)
      @fw.print <<EOF
@SP
A=M-1

M=#{op}M
EOF
  end

  #--------------------
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



  #----------------------------------------
  # Chapter 8 の実装
  #----------------------------------------

  def writeLabel(label)
    @fw.puts "(#{@current_function_name}$#{label})"
  end

  def writeGoto(label)
    @fw.puts "@#{@current_function_name}$#{label}"
    @fw.puts "0;JMP"
  end

  def writeIfGoto(label)
    @fw.puts "@SP"
    @fw.puts "M=M-1"
    @fw.puts "A=M"
    @fw.puts "D=M"
    @fw.puts "@#{@current_function_name}$#{label}"
    @fw.puts "D;JNE"
  end

  def writeFunction(functionName, numLocals)
    # (f)
    # push 0 (numLocals回)

    writeCodes([
                 "(#{functionName})",
                 "D=0",
               ])

    numLocals.times do
      writeCodes(
        codes_push_D()
      )
    end

    @current_function_name = functionName
  end

  def writeReturn()
    # FRAME : R13
    # RET : R14

    writeCodes([
                 "// FRAME=LCL",
                 "@LCL",
                 "D=M",
                 "@R13",
                 "M=D",
                 "",

                 "// RET = *(FRAME-5)",
                 "@5",
                 "D=A",
                 "@R13",
                 "A=M-D",
                 "D=M",
                 "@R14",
                 "M=D",
                 "",

                 "// *ARG = pop()",
                 codes_pop_to_M(),
                 "D=M",
                 "@ARG",
                 "A=M",
                 "M=D",
                 "",

                 "// SP=ARG+1",
                 "@ARG",
                 "D=M+1",
                 "@SP",
                 "M=D",
                 "",

                 "// THAT= *(FRAME-1)",
                 "@R13",
                 "AM=M-1",
                 "D=M",
                 "@THAT",
                 "M=D",
                 "",

                 "// THIS= *(FRAME-2)",
                 "@R13",
                 "AM=M-1",
                 "D=M",
                 "@THIS",
                 "M=D",
                 "",

                 "// ARG= *(FRAME-3)",
                 "@R13",
                 "AM=M-1",
                 "D=M",
                 "@ARG",
                 "M=D",
                 "",

                 "// LCL= *(FRAME-4)",
                 "@R13",
                 "AM=M-1",
                 "D=M",
                 "@LCL",
                 "M=D",
                 "",

                 "// goto RET",
                 "@R14",
                 "A=M",
                 "0;JMP",
                 "",
               ])
  end


  def writeCall(functionName, numArgs)

    # push return-address
    return_label = getNewReturnLabel()
    writeCodes([
                 "// -----",
                 "// CALL",
                 "// -----",

                 "// push return-address",
                 "@#{return_label}",
                 "D=A",
                 codes_push_D(),

                 "// push LCL",
                 "@LCL",
                 "D=M",
                 codes_push_D(),
                 
                 "// push ARG",
                 "@ARG",
                 "D=M",
                 codes_push_D(),
                 
                 "// push THIS",
                 "@THIS",
                 "D=M",
                 codes_push_D(),
                 
                 "// push THAT",
                 "@THAT",
                 "D=M",
                 codes_push_D(),
                 
                 "// ARG = SP-n-5",
                 "@SP",
                 "D=M",
                 "@5",
                 "D=D-A",
                 "@#{numArgs}",
                 "D=D-A",
                 "@ARG",
                 "M=D",
                 "",

                 "// LCL=SP",
                 "@SP",
                 "D=M",
                 "@LCL",
                 "M=D",
                 "",

                 "// goto #{functionName}",
                 "@#{functionName}",
                 "0;JMP",
                 "",
                 
                 "(#{return_label})",
                 "",
               ])

  end

  def writeSysInit()
    # SP=256
    # call Sys.init 0

    writeCodes([
                 "// call Sys.init 0",
                 "@256",
                 "D=A",
                 "@SP",
                 "M=D",
                 "",
    ])

    writeCall("Sys.init", 0)
    
  end
  

  def writeCodes(ary)
    ary.flatten!
    
    ary.each do |code|
      @fw.puts code
    end
  end

  def codes_push_D
    [
      "@SP",
      "A=M",
      "M=D",
      "@SP",
      "M=M+1",
      "",
    ]
  end

  def codes_pop_to_M
    [
      "@SP",
      "M=M-1",
      "A=M",
    ]
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
      codeWriter.writeLabel(parser.arg1)

    when C_GOTO       then
      codeWriter.writeGoto(parser.arg1)

    when C_IF         then
      codeWriter.writeIfGoto(parser.arg1)

    when C_FUNCTION   then
      codeWriter.writeFunction(parser.arg1, parser.arg2)

    when C_RETURN     then
      codeWriter.writeReturn()

    when C_CALL       then
      codeWriter.writeCall(parser.arg1, parser.arg2)
    end
  end
end



path = ARGV[0]

if !File.exist?(path)
  puts "No such file or directory."
  exit 0
end



if FileTest.directory? path
  # Directory
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

