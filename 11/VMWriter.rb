class VMWriter
  C_CONST    = 0
  C_ARG      = 1
  C_LOCAL    = 2
  C_STATIC   = 3
  C_THIS     = 4
  C_THAT     = 5
  C_POINTER  = 6
  C_TEMP     = 7

  C_ADD = 0
  C_SUB = 1
  C_NEG = 2
  C_EQ  = 3
  C_GT  = 4
  C_LT  = 5
  C_AND = 6
  C_OR  = 7
  C_NOT = 8

  def initialize(outfilename)
    @fw = File.open(outfilename, "w")
  end

  def writePush(segment, index)
      write "push #{segment_name(segment)} #{index}"
  end

  def writePop(segment, index)
      write "pop #{segment_name(segment)} #{index}"
  end

  def writeArithmetic(command)
    case command
    when VMWriter::C_ADD
      write "add"
    when VMWriter::C_SUB
      write "sub"
    when VMWriter::C_NEG
      write "neg"
    when VMWriter::C_EQ
      write "eq"
    when VMWriter::C_GT
      write "gt"
    when VMWriter::C_LT
      write "lt"
    when VMWriter::C_AND
      write "and"
    when VMWriter::C_OR
      write "or"
    when VMWriter::C_NOT
      write "not"
    else
      raise "unknown operator"
    end
  end

  def writeLabel(label)
    write "label #{label}"
  end

  def writeGoto(label)
    write "goto #{label}"
  end

  def writeIf(label)
    write "if-goto #{label}"
  end

  def writeCall(name, nArgs)
    write "call #{name} #{nArgs}"
  end

  def writeFunction(name, nLocals)
    write "function #{name} #{nLocals}"
  end

  def writeReturn()
    write "return"
  end

  def close()
    @fw.close
  end


  def write(code)
    @fw.puts code
  end
  
  def segment_name(segment)
    retVal = case segment
             when VMWriter::C_CONST
               "constant"
             when VMWriter::C_ARG
               "argument"
             when VMWriter::C_LOCAL
               "local"
             when VMWriter::C_STATIC
               "static"
             when VMWriter::C_THIS
               "this"
             when VMWriter::C_THAT
               "that"
             when VMWriter::C_POINTER
               "pointer"
             when VMWriter::C_TEMP
               "temp"
             else
               raise "unknown segment"
             end

    return retVal
  end
end
