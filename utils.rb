module Utils

  require 'test/unit'
  require 'fileutils'
  require 'json'

  APPLICATION_FIELD = :application
  PARAMETERS_FIELD  = :parameters
  SECURITY_LEVEL_FIELD = :securityLevel
  CREATE_PROCESS_METHOD_FIELD = :createProcessMethod
  USER_NAME_FIELD = :userName
  USER_TIME_LIMIT_FIELD = :userTimeLimit
  DEADLINE_FIELD = :deadline
  MEMORY_LIMIT_FIELD = :memoryLimit
  WRITE_LIMIT_FIELD = :writeLimit
  USER_TIME_FIELD = :userTime
  PEAK_MEMORY_USED_FIELD = :peakMemoryUsed
  WRITTEN_FIELD = :written
  TERMINATE_REASON_FIELD = :terminateReason
  EXIT_STATUS_FIELD = :exitStatus
  SPAWNER_ERROR_FIELD = :spawnerError

  EXIT_PROCESS_RESULT = 'ExitProcess'
  TIME_LIMIT_EXCEEDED_RESULT = 'TimeLimitExceeded'
  WRITE_LIMIT_EXCEEDED_RESULT = 'WriteLimitExceeded'
  MEMORY_LIMIT_EXCEEDED_RESULT = 'MemoryLimitExceeded'
  IDLENESS_LIMIT_EXCEEDED_RESULT = 'IdleTimeLimitExceeded'
  ABNORMAL_EXIT_PROCESS_RESULT = 'AbnormalExitProcess'
  LOAD_RATIO_RESULT = 'LoadRatio'

  ACCESS_VIOLATION_EXIT_STATUS = 'AccessViolation'
  STACK_OVERFLOW_EXIT_STATUS = 'StackOverflow'
  INT_DIVIDE_BY_ZERO_EXIT_STATUS = 'IntegerDivideByZero'
  ILLEGAL_INSTRUCTION_EXIT_STATUS = 'IllegalInstruction'
  PRIVILEGED_INSTRUCTION_EXIT_STATUS = 'PrivilegedInstruction'
  ARRAY_BOUNDS_EXCEEDED_EXIT_STATUS = 'ArrayBoundsExceeded'

  NONE_ERROR_SP_ERROR = '<none>'

  REPORT_FIELDS = %i[
        application
        parameters
        securityLevel
        createProcessMethod
        userName
        userTimeLimit
        deadline
        memoryLimit
        writeLimit
        userTime
        peakMemoryUsed
        written
        terminateReason
        exitStatus
        spawnerError
    ]

	def self.system_dir?(dir)
		%w[ . .. .idea .git ].include? dir
  end

  def self.get_compiler_for(source)
      extension = file_extension(source)

      case extension
        when 'cpp' then GCCCompilerWrapper.new
        when 'pas' then PascalCompilerWrapper.new
        when 'abc' then PascalABCCompilerWrapper.new
        when 'cs' then CSharpCompilerWrapper.new
        when 'rb' then RubyInterpreterWrapper.new
        when 'py' then PythonInterpreterWrapper.new
        else raise 'Wrong extension for test file!'
      end
  end

  def self.file_extension(filename)
    File.extname(filename).delete('.')
  end

  def self.file_name(path)
    File.basename(path).delete(File.extname(path))
  end

  def self.get_dir_name(test_name)
    test_name.slice(5, test_name.length)
  end

  def self.compile_for_test(test_name)
    tests_folder = "src/#{get_dir_name(test_name)}"

    Dir.foreach(tests_folder) do |source|
      unless system_dir?(source)
        full_path = "#{tests_folder}/#{source}"
        output_path = 'bin/'

        if File.file?(full_path)
          get_compiler_for(full_path).compile(full_path, output_path)
        else
          json = Dir.entries(full_path).select { |entry| entry == 'metadata.json' }

          if json.length == 0
            JavaInterpretableWrapper.new.compile(full_path, output_path)
          else
            test_metadata = JSON.parse(IO.read(full_path + '/' + json[0]))['test']
            order = test_metadata['order']
            out = output_path + source

            Dir.mkdir(out) unless Dir::exist?(out)

            raise 'Order of file doesn\'t specified!' if order.nil?

            order.each_index do |i|
              curr = full_path + '/' + order[i]

              get_compiler_for(curr).compile(curr, out, sprintf('%02d', i))
            end
          end
        end
      end
    end
  end

  def self.clear
    FileUtils.rm_rf('bin')
  end

  @spawner = nil

  def self.spawner
    @spawner
  end

  def self.init_spawner(type, path)
    @spawner = (case type
      when 'cats' then CatsSpawnerWrapper
      when 'pcms2' then PCMS2SpawnerWrapper
      else nil
    end).new(path)
  end

  class CompilerWrapper
    @cmd
    @out_arg

    attr_accessor :cmd,
                  :out_arg

    def initialize(run_command, output_argument)
      @cmd = run_command
      @out_arg = output_argument
    end

    def compile(source, output_dir, output_name = nil)
      outname = (output_name || Utils.file_name(source)) + '.exe'

      system("#{@cmd} #{@out_arg}#{output_dir + '/' + outname} #{source} 1>nul 2>nul")
    end

  end

  class GCCCompilerWrapper < CompilerWrapper

    def initialize
      super 'g++', '-o '
    end

  end

  class PascalCompilerWrapper < CompilerWrapper

    def initialize
      super 'fpc', '-o'
    end

    def compile(source, output_dir, output_name = nil)
      super

      File.delete(output_dir + Utils.file_name(source) + '.o')
    end

  end

  class PascalABCCompilerWrapper < CompilerWrapper

    def initialize
      super 'pabcnetc', ''
    end

    def compile(source, output_dir, output_name = nil)
      basename = output_name || Utils.file_name(source)
      source_copy = basename + '.pas'
      compiled = basename + '.exe'

      FileUtils.cp(source, source_copy)

      system("#{@cmd} #{source_copy} 1>nul")

      FileUtils.cp(compiled, output_dir + '/' + compiled)
      [source_copy, compiled].each{ |filename| File.delete(filename) }
    end

  end

  class CSharpCompilerWrapper < CompilerWrapper

    def initialize
      super 'csc', '/out:'
    end

    def compile(source, output_dir, output_name = nil)
      Dir.chdir(source.split(/\//).slice(0, 2).join('/'))
      super File.basename(source), '../../' + output_dir, output_name
      Dir.chdir('../..')
    end

  end

  class InterpretableCompilerWrapper < CompilerWrapper

    def initialize(cmd)
      super cmd, nil
    end

    def compile(source, output_dir, output_name = nil)
      compiled = output_name || File.basename(source)
      compiled += File.extname(source) if output_name

      FileUtils.cp(source, output_dir + '/' + compiled)
    end

  end

  class RubyInterpreterWrapper < InterpretableCompilerWrapper

    def initialize
      super 'ruby'
    end

  end

  class PythonInterpreterWrapper < InterpretableCompilerWrapper

    def initialize
      super 'python'
    end

  end

  class JavaInterpretableWrapper < InterpretableCompilerWrapper

    def initialize
      super 'java'
    end

    def compile(source, output)
      file = (Dir.entries(source) - %w[ . .. ])[0]
      binary = output + File.basename(source)

      FileUtils::mkdir_p(binary)

      system("javac -d #{binary} #{source + '/' + file} 1>nul 2>nul")
    end

  end

  class SpawnerTester < Test::Unit::TestCase

    private

    def fail_on_th_test_msg(test_order)
      "Fail on #{test_order}th test"
    end

    protected

    class FileHandler

      private

      @path

      public

      attr_reader :path

      def initialize(path, write_data = nil)
        @path = path
        write(write_data)
      end

      def read
        IO.read(@path)
      end

      def write(write_data)
        File.open(@path, 'w') { |f| f.write(write_data) } unless write_data.nil?
      end

      def clear
        File.open(@path, 'w') { |f| f.write(nil) }
      end

      def to_s
        @path
      end

      def delete
        FileUtils.rm(@path)
      end

    end

    def tests_count
      count = Dir.entries('.').size - 2
      (1..count)
    end

    def create_temporary_file(file_name, write_data = nil)
      FileHandler.new(file_name, write_data)
    end

    @one_test

    public

    def initialize(test_method_name, test = nil)
      super test_method_name

      @one_test = test
    end

    def run_spawner_test(test_order = nil, args = {}, flags = [], argv = [])
      executable = Dir[File.absolute_path(Dir.getwd) + '/*'].find do |filename|
        filename =~ /#{sprintf('%02d', test_order)}(\.(.*))?$/
      end

      raise "Wrong test order: #{test_order.inspect}" if executable.nil?

      if File.file?(executable)
        ext = Utils.file_extension(executable)

        unless ext == 'exe'

          executable = Utils.get_compiler_for(executable).cmd + ' ' + executable
          flags.push(:command)
        end
      else
        files = Dir.entries(executable) - %w[ . .. ]

        if files.length == 1
          file = (Dir.entries(executable) - %w[ . .. ])[0]
          executable = "java -classpath #{executable}/ #{file[0 .. file.length - 7]}"

          flags.push(:command)
        else
          return files.sort.map { |exec| Utils.spawner.run(exec, args, flags, argv) }
        end
      end

      Utils.spawner.run(executable, args, flags, argv)
    end

    def exit_success?(report, test_order = -1)
      aseq(Utils::EXIT_PROCESS_RESULT, report[TERMINATE_REASON_FIELD], test_order)
      aseq('0', report[EXIT_STATUS_FIELD], test_order)
      aseq('<none>', report[SPAWNER_ERROR_FIELD], test_order)
    end

    def setup
      name = self.class.name
      dir = name.slice(0, name.length - 5)
      dir[0] = dir[0].downcase!
      Dir.chdir("#{dir}Tests/")
      Dir.mkdir('bin') unless Dir.exists?('bin')
      Utils.compile_for_test(self.method_name)
      Dir.chdir('./bin/')
    end

    def teardown
      Dir.chdir('..')
      Utils.clear
      Dir.chdir('..')
    end

    def aseq(expected, actual, test_order)
      assert_equal(expected, actual, fail_on_th_test_msg(test_order))
    end

    def asindel(expected, actual, delta, test_order)
      assert_in_delta(expected, actual, delta, fail_on_th_test_msg(test_order))
    end

    def astrue(actual, test_order)
      assert_true(actual, fail_on_th_test_msg(test_order))
    end

    def asfalse(actual, test_order)
      assert_false(actual, fail_on_th_test_msg(test_order))
    end

  end

  class SpawnerWrapper

    protected

    @path
    @cmd_args_mapping
    @cmd_flags_mapping
    @cmd_arg_val_delim
    @cmd_args
    @cmd_args_multipliers
    @cmd_flags
    @tmp_file_name
    @environment_mods
    @features

    def parse_report(rpt)
      raise 'Virtual method called!'
    end

    def arg_for_property?(properties, arg)
      properties = [properties] unless properties.kind_of? Array
      properties.each { |property| return true if arg.to_s === @cmd_args_mapping[property].to_s }
      false
    end


    def unify(arg)
      raise 'Virtual method called!'
    end

    def suffix(arg_class)
      raise 'Virtual method called!'
    end

    def transform_arg(arg)
      u_arg = unify(arg)
      u_arg.to_s + suffix(u_arg)
    end

    public

    attr_reader :cmd_args,
                :cmd_args_multipliers,
                :cmd_flags,
                :tmp_file_name

    def initialize(path)
      @path = path
      @tmp_file_name = 'tmp.txt'
      @features = []
    end

    def run(executable, args = {}, flags = [], argv = [])
      cmd = @path
      args.each do |k, v|
        next if v.nil?

        key = (@cmd_args_mapping[k].nil? ? k : @cmd_args_mapping[k]).to_s

        if v.kind_of?(Array)
          cmd += v.map{ |val| " -#{key}#{@cmd_arg_val_delim}#{transform_arg(val)}" }.join(' ')
        else
          cmd += " -#{key}#{@cmd_arg_val_delim}#{transform_arg(v)}"
        end
      end
      run_flags = flags.map{ |el| "--#{@cmd_flags_mapping[el].to_s}" unless @cmd_flags_mapping[el].nil? }
      cmd += " #{ run_flags.join(' ') } #{ executable } #{ argv.join(' ') }"
      parse_report(%x[#{cmd}])
    end

    def get_correct_value_for(arg)

    end

    def get_wrong_value_for(arg)

    end

    def has_feature?(feature)
      @features.include?(feature)
    end

  end

  class CatsSpawnerWrapper < SpawnerWrapper

    private

    @environment_mods

    attr_accessor :environment_mods

    def add_degrees(units)
      degrees = %w[ da h k Ki M Mi G Gi T Ti P Pi d c m u n p f ]
      res = []
      units.each { |unit| degrees.each { |degree| res.push(degree + unit) } }
      res
    end

    protected

    def parse_report(rpt)
      res = {}
      REPORT_FIELDS.each do |field|
        rpt =~ /\n#{field}:\s+(.+)(\(\S+\))?\n/i
        v = $1
        v = $1.to_f if v =~ /^(\d+\.?\d+)\s?(\S+)?$/
        res[field.to_sym] = v
      end
      res
    end

    def unify(arg)
      arg
    end

    def suffix(arg)
      case arg
        when Args::SecondsArgument then 's'
        when Args::MinutesArgument then 'm'
        when Args::MillisecondsArgument then 'ms'
        when Args::ByteArgument then 'B'
        when Args::KilobyteArgument then 'kB'
        when Args::GigabyteArgument then 'GB'
        else ''
      end
    end

    public

    def initialize(path)
      super
      @cmd_arg_val_delim = ':'
      @cmd_args_mapping = {
          :time_limit => :tl,
          :memory_limit => :ml,
          :write_limit => :wl,
          :user => :u,
          :password => :p,
          :input => :i,
          :output => :so,
          :error => :se,
          :idleness => :y,
          :deadline => :d,
          :load_ratio => :lr,
          :directory => :wd,
          :environment_mode => :env,
          :environment_vars => :D,
      }
      @cmd_flags_mapping = {
          :hide_output => :ho,
          :hide_report => :hr,
          :command => :cmd,
      }
      @cmd_args = %w[ ml tl d wl u p runas s sr so i lr sl wd env D ]
      @cmd_flags = %w[ ho sw cmd ] #TODO: hide report workaround
      @cmd_args_multipliers = {
          :memory_limit => add_degrees(%w[ B b ]),
          :time_limit => add_degrees(%w[ s m h d ]),
      }
      @environment_mods = %w[ inherit user-default clear ]
      @features = %w[
          environment_modes
          deadline
          write_limit
      ]
    end

    def get_correct_value_for(arg)
      1
    end

    def get_wrong_value_for(arg)
      'something_wrong'
    end

  end

  class PCMS2SpawnerWrapper < SpawnerWrapper

    protected

    def parse_report(rpt)
      res = {}
      if rpt =~ /^running/i
        rpt =~ /^\s*time consumed:\s+([0-9]+\.[0-9]+)(.*)$/i
        res[Utils::USER_TIME_FIELD] = $1.to_f
        rpt =~ /^\s*peak memory:\s+([0-9]+)(.*)$/i
        res[Utils::PEAK_MEMORY_USED_FIELD] = $1.to_f / 2 ** 20
        if rpt =~ /crash/i
          rpt =~ /crash\s+([_a-z]+)\s+/i
          error_msg = $1.to_s
          res[Utils::EXIT_STATUS_FIELD] = case error_msg
            when 'EXCEPTION_ACCESS_VIOLATION' then Utils::ACCESS_VIOLATION_EXIT_STATUS
            when 'EXCEPTION_INT_DIVIDE_BY_ZERO' then Utils::INT_DIVIDE_BY_ZERO_EXIT_STATUS
            when 'EXCEPTION_PRIV_INSTRUCTION' then Utils::PRIVILEGED_INSTRUCTION_EXIT_STATUS
            when 'EXCEPTION_STACK_OVERFLOW' then Utils::STACK_OVERFLOW_EXIT_STATUS
            else nil
          end
          res[Utils::TERMINATE_REASON_FIELD] = Utils::ABNORMAL_EXIT_PROCESS_RESULT
        elsif rpt =~ /program successfully terminated/i
          res[Utils::TERMINATE_REASON_FIELD] = Utils::EXIT_PROCESS_RESULT
          res[Utils::EXIT_STATUS_FIELD] = '0'
          res[Utils::SPAWNER_ERROR_FIELD] = Utils::NONE_ERROR_SP_ERROR
        else
          rpt =~ /to terminate...\s+([ a-z]+)\s+/i
          exit_status_msg = $1.to_s.downcase
          res[Utils::SPAWNER_ERROR_FIELD] = Utils::NONE_ERROR_SP_ERROR
          res[Utils::TERMINATE_REASON_FIELD] = case exit_status_msg
            when 'memory limit exceeded' then Utils::MEMORY_LIMIT_EXCEEDED_RESULT
            when 'time limit exceeded' then Utils::TIME_LIMIT_EXCEEDED_RESULT
            when 'idleness limit exceeded' then Utils::IDLENESS_LIMIT_EXCEEDED_RESULT
            else res[Utils::SPAWNER_ERROR_FIELD] = nil
            end
        end
      end
      res
    end

    def unify(arg)
      case arg
        when Args::GigabyteArgument then arg.to_bytes
        when Args::MinutesArgument then arg.to_seconds
        else arg
      end
    end

    def suffix(arg)
      case arg
        when Args::MillisecondsArgument then 'ms'
        when Args::KilobyteArgument then 'K'
        when Args::MegabyteArgument then 'M'
        else ''
      end
    end

    public

    def initialize(path)
      super
      @cmd_arg_val_delim = ' '
      @cmd_args_mapping = {
          :time_limit => :t,
          :memory_limit => :m,
          :user => :l,
          :password => :p,
          :input => :i,
          :output => :o,
          :error => :e,
          :idleness => :y,
          :load_ratio => :r,
          :directory => :d,
          :store_in_file => :s,
          :environment_vars => :D,
      }
      @cmd_flags_mapping = {
          :hide_report => :q,
      }
      @cmd_args = %w[ t m r y d i o e s D ] #l p
      @cmd_flags = %w[ x w 1 ] # q
      @cmd_args_multipliers = {
          :memory_limit => %w[ K M ],
          :time_limit => %w[ s ms ],
      }
    end

    def get_correct_value_for(arg)
      case true
        when arg_for_property?(:load_ratio, arg) then 0.5
        when arg_for_property?(:directory, arg) then '.'
        when arg_for_property?(%i[input output error], arg) then @tmp_file_name
        else 1
      end
    end

    def get_wrong_value_for(arg)
      case true
        when arg_for_property?(%i[input output error store_in_file], arg) then '"L:\Some\Unknown\Folder\On\Not\Existing\HDD"'
        when arg_for_property?(:load_ratio, arg) then 1
        when arg_for_property?(%i[time_limit idleness], arg) then 0.5
        when arg_for_property?(:directory, arg) then nil
        else 'something_wrong'
      end
    end

  end

end