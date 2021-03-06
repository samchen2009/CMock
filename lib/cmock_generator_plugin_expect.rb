# ==========================================
#   CMock Project - Automatic Mock Generation for C
#   Copyright (c) 2007 Mike Karlesky, Mark VanderVoord, Greg Williams
#   [Released under MIT License. Please refer to license.txt for details]
# ==========================================

class CMockGeneratorPluginExpect

  attr_reader :priority
  attr_accessor :config, :utils, :unity_helper, :ordered

  def initialize(config, utils)
    @config       = config
    @ptr_handling = @config.when_ptr
    @ordered      = @config.enforce_strict_ordering
    @utils        = utils
    @unity_helper = @utils.helpers[:unity_helper]
    @priority     = 5
  end

  def instance_typedefs(function)
    lines = ""
    lines << "  #{function[:return][:type]} ReturnVal;\n"  unless (function[:return][:void?])
    lines << "  int CallOrder;\n"                          if (@ordered)
    function[:args].each do |arg|
      lines << "  #{arg[:type]} Expected_#{arg[:name]};\n"
    end
    lines
  end

  def mock_function_declarations(function)
    args_string, call_args_string = @utils.args_to_s(function[:args], true)
    args_string.gsub!(",1","")
    call_args_string.gsub!(",1","")

    if (function[:args].empty?)
      if (function[:return][:void?])
        return "#define #{function[:name]}_Expect() #{function[:name]}_CMockExpect(__LINE__)\n" +
               "void #{function[:name]}_CMockExpect(UNITY_LINE_TYPE cmock_line);\n"
      else
        return "#define #{function[:name]}_ExpectAndReturn(cmock_retval) #{function[:name]}_CMockExpectAndReturn(__LINE__, cmock_retval)\n" +
               "void #{function[:name]}_CMockExpectAndReturn(UNITY_LINE_TYPE cmock_line, #{function[:return][:str]});\n"
      end
    else
      if (function[:return][:void?])
        return "#define #{function[:name]}_Expect(#{call_args_string}) #{function[:name]}_CMockExpect(__LINE__, #{call_args_string})\n" +
               "void #{function[:name]}_CMockExpect(UNITY_LINE_TYPE cmock_line, #{args_string});\n"
      else
        return "#define #{function[:name]}_ExpectAndReturn(#{call_args_string}, cmock_retval) #{function[:name]}_CMockExpectAndReturn(__LINE__, #{call_args_string}, cmock_retval)\n" +
               "void #{function[:name]}_CMockExpectAndReturn(UNITY_LINE_TYPE cmock_line, #{args_string}, #{function[:return][:str]});\n"
      end
    end
  end

  def mock_implementation(function)
    lines = ""
    function[:args].reject{|x| !x[:extra?]}.each do |arg|
      lines << @utils.code_verify_an_arg_expectation(function, arg) 
    end    
    function[:args].reject{|x| x[:extra?]}.each do |arg|
      lines << @utils.code_verify_an_arg_expectation(function, arg)
    end
    lines
  end

  def mock_interfaces(function)
    lines = ""
    func_name = function[:name]
    mock_args_string, mock_call_args_string = @utils.args_to_s(function[:args], true, "expect")
    if (function[:return][:void?])
      if (mock_args_string == "void")
        lines << "void #{func_name}_CMockExpect(UNITY_LINE_TYPE cmock_line)\n{\n"
      else
        lines << "void #{func_name}_CMockExpect(UNITY_LINE_TYPE cmock_line, #{mock_args_string})\n{\n"
      end
    else
      if (mock_args_string == "void")
        lines << "void #{func_name}_CMockExpectAndReturn(UNITY_LINE_TYPE cmock_line, #{function[:return][:str]})\n{\n"
      else
        lines << "void #{func_name}_CMockExpectAndReturn(UNITY_LINE_TYPE cmock_line, #{mock_args_string}, #{function[:return][:str]})\n{\n"
      end
    end
    # prepare internal strcture.
    lines << @utils.code_add_base_expectation(function)
    # Call ExpectParameters ...
    lines << @utils.code_call_argument_loader(function)
    lines << @utils.code_assign_argument_quickly("cmock_call_instance->ReturnVal", function[:return]) unless (function[:return][:void?])
    lines << "}\n\n"
  end

  def mock_verify(function)
    func_name = function[:name]
    "  UNITY_TEST_ASSERT(CMOCK_GUTS_NONE == Mock.#{func_name}_CallInstance, cmock_line, \"Function '#{func_name}' called less times than expected.\");\n"
  end

end
