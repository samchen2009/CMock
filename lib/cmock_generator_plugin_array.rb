# ==========================================
#   CMock Project - Automatic Mock Generation for C
#   Copyright (c) 2007 Mike Karlesky, Mark VanderVoord, Greg Williams
#   [Released under MIT License. Please refer to license.txt for details]
# ==========================================

class CMockGeneratorPluginArray

  attr_reader :priority
  attr_accessor :config, :utils, :unity_helper, :ordered
  def initialize(config, utils)
    @config       = config
    @ptr_handling = @config.when_ptr
    @ordered      = @config.enforce_strict_ordering
    @utils        = utils
    @unity_helper = @utils.helpers[:unity_helper]
    @priority     = 8
  end

  def instance_typedefs(function)
    function[:args].inject("") do |all, arg|
      #(arg[:ptr?]) ? all + "  int Expected_#{arg[:name]}_Depth;\n" : all
    end
  end

  def mock_function_declarations(function)
    return nil unless function[:contains_ptr?]
    args_string,call_args_string = @utils.args_to_s(function[:args], true, "array")
    if (function[:return][:void?])
      return "#define #{function[:name]}_ExpectWithArray(#{call_args_string}) #{function[:name]}_CMockExpectWithArray(__LINE__, #{call_args_string})\n" +
             "void #{function[:name]}_CMockExpectWithArray(UNITY_LINE_TYPE cmock_line, #{args_string});\n"
    else
      return "#define #{function[:name]}_ExpectWithArrayAndReturn(#{call_args_string}, cmock_retval) #{function[:name]}_CMockExpectWithArrayAndReturn(__LINE__, #{call_args_string}, cmock_retval)\n" +
             "void #{function[:name]}_CMockExpectWithArrayAndReturn(UNITY_LINE_TYPE cmock_line, #{args_string}, #{function[:return][:str]});\n"
    end
  end

  def mock_interfaces(function)
    return nil unless function[:contains_ptr?]
    lines = []
    func_name = function[:name]
    mock_args_string, call_args_string = @utils.args_to_s(function[:args], true, "array")
    if (function[:return][:void?])
      lines << "void #{func_name}_CMockExpectWithArray(UNITY_LINE_TYPE cmock_line, #{mock_args_string})\n"
    else
      lines << "void #{func_name}_CMockExpectWithArrayAndReturn(UNITY_LINE_TYPE cmock_line, #{mock_args_string}, #{function[:return][:str]})\n"
    end
    lines << "{\n"
    lines << @utils.code_add_base_expectation(function, false, true)
    lines << @utils.code_call_argument_loader(function, "array")
    #lines << "  cmock_call_instance->ReturnVal = cmock_to_return;\n" unless (function[:return][:void?])
    lines << @utils.code_assign_argument_quickly("cmock_call_instance->ReturnVal", function[:return]) unless (function[:return][:void?])
    lines << "}\n\n"
  end

end
