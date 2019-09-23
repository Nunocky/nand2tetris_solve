require './CompilationEngine'


if __FILE__ == $0

  def parseFile(srcfilename, outfilename)
pp "#{srcfilename} -> #{outfilename}"

    tokenizer = JackTokenizer.new(srcfilename)
    engine = CompilationEngine.new(outfilename, tokenizer)
    engine.compileClass
  end

  path = ARGV[0]

  if FileTest.directory? path
    # Directory
    Dir.chdir(path) do

      Dir.glob("*.jack") do |srcfilename|
        outfilename = File.basename(srcfilename, '.*') + ".xml"

        parseFile(srcfilename, outfilename)
      end

    end

  elsif FileTest.file? path
    # File
    if File.extname(path) != ".jack"
      puts "#{path} : not a jack file."
      exit 0
    end

    basename = File.basename(path, '.*')

    srcfilename = ARGV[0]
    outfilename = "#{basename}.xml"

    parseFile(srcfilename, outfilename)

  else
    puts "No such file or directory."
    exit 0
  end

end
