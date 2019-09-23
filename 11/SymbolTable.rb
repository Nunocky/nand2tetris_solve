# coding: cp932
class SymbolTable
  COL_NAME = 0
  COL_TYPE = 1
  COL_KIND = 2

  C_NONE   = -1
  C_STATIC = 0
  C_FIELD  = 1
  C_ARG    = 2
  C_VAR    = 3

  def initialize
    @tbl_static = []
    @tbl_field = []
    @tbl_argument = []
    @tbl_var = []
  end

  def startSubroutine()
#puts "startSubroutine"
    @tbl_argument = []
    @tbl_var = []
  end

  def define(name, type, kind)
    puts "    #{name} #{type} #{kind_name(kind)}"

    tbl = case kind
          when C_STATIC
            @tbl_static
          when C_FIELD
            @tbl_field
          when C_ARG
            @tbl_argument
          when C_VAR
            @tbl_var
          else
            raise ""
          end

    tbl << [name, type, kind]
  end

  def varCount(kind)
    tbl = case kind
          when C_STATIC
            @tbl_static
          when C_FIELD
            @tbl_field
          when C_ARG
            @tbl_argument
          when C_VAR
            @tbl_var
          else
            raise ""
          end

    return tbl.length
  end

  def kindOf(name)
    [@tbl_var, @tbl_argument, @tbl_field, @tbl_static].each do |tbl|
      tbl.each do |row|
        return row[COL_KIND] if name == row[COL_NAME]
      end
    end

    return nil
  end

  def typeOf(name)
    [@tbl_var, @tbl_argument, @tbl_field, @tbl_static].each do |tbl|
      tbl.each do |row|
        return row[COL_TYPE] if name == row[COL_NAME]
      end
    end

    return nil
  end

  def indexOf(name)
    [@tbl_var, @tbl_argument, @tbl_field, @tbl_static].each do |tbl|
      tbl.each_with_index do |row, n|
        return n if name == row[COL_NAME]
      end
    end
    
    return nil
  end


  def kind_name(kind)
    case kind
    when C_STATIC
      return "static"
    when C_FIELD
      return "field"
    when C_ARG
      return "argument"
    when C_VAR
      return "local"
    end
    raise ""
  end

end
