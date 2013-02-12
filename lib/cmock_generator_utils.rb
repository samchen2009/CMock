# ==========================================
#   CMock Project - Automatic Mock Generation for C
#   Copyright (c) 2007 Mike Karlesky, Mark VanderVoord, Greg Williams
#   [Released under MIT License. Please refer to license.txt for details]
# ==========================================

class CMockGeneratorUtils

  attr_accessor :config, :helpers, :ordered, :ptr_handling, :arrays, :cexception

  def initialize(config, helpers={})
    @config = config
    @ptr_handling = @config.when_ptr
    @ordered      = @config.enforce_strict_ordering
    @arrays       = @config.plugins.include? :array
    @cexception   = @config.plugins.include? :cexception
    @treat_as     = @config.treat_as
      @helpers = helpers

    if (@arrays)
      #case(@ptr_handling)
        #when :smart        then alias :code_verify_an_arg_expectation :code_verify_an_arg_expectation_with_smart_arrays
        #when :compare_data then alias :code_verify_an_arg_expectation :code_verify_an_arg_expectation_with_normal_arrays
        alias :code_verify_an_arg_expectation :code_verify_an_arg_expectation_with_normal_arrays
        #when :compare_ptr  then raise "ERROR: the array plugin doesn't enjoy working with :compare_ptr only.  Disable one option."
      #end
    else
      alias :code_verify_an_arg_expectation :code_verify_an_arg_expectation_with_no_arrays
    end
  end
   
  def code_add_base_expectation(function, global_ordering_supported=true, with_array = false)
    func_name = function[:name]
    lines =  "  CMOCK_MEM_INDEX_TYPE cmock_guts_index = CMock_Guts_MemNew(sizeof(CMOCK_#{func_name}_CALL_INSTANCE));\n"
    lines << "  CMOCK_#{func_name}_CALL_INSTANCE* cmock_call_instance = (CMOCK_#{func_name}_CALL_INSTANCE*)CMock_Guts_GetAddressFor(cmock_guts_index);\n"
    lines << "  UNITY_TEST_ASSERT_NOT_NULL(cmock_call_instance, cmock_line, \"CMock has run out of memory. Please allocate more.\");\n"
    lines << "  Mock.#{func_name}_CallInstance = CMock_Guts_MemChain(Mock.#{func_name}_CallInstance, cmock_guts_index);\n"
    function[:args].reject {|x| !(x[:extra?] and x[:ptr?] and x[:depth_name]!="1")}.each do |arg|
      lines << "  CMOCK_MEM_INDEX_TYPE cmock_guts_index_#{arg[:name]} = CMock_Guts_MemNew(sizeof(#{arg[:type].sub("*","")}) * #{arg[:depth_name]});\n"
      lines << "  #{arg[:type]} cmock_array_instance_#{arg[:name]} = (#{arg[:type]})CMock_Guts_GetAddressFor(cmock_guts_index_#{arg[:name]});\n"
      lines << "  UNITY_TEST_ASSERT_NOT_NULL(cmock_array_instance_#{arg[:name]}, cmock_line, \"CMock has run out of memory. Please allocate more.\");\n"
      lines << "  Mock.#{func_name}_ArrayInstance_#{arg[:name]} = CMock_Guts_MemChain(Mock.#{func_name}_ArrayInstance_#{arg[:name]}, cmock_guts_index_#{arg[:name]});\n"
      lines << "  cmock_call_instance->Expected_#{arg[:name]} = cmock_array_instance_#{arg[:name]};\n"
    end if with_array 

    lines << "  cmock_call_instance->LineNumber = cmock_line;\n"
    lines << "  cmock_call_instance->CallOrder = ++GlobalExpectCount;\n" if (@ordered and global_ordering_supported)
    lines << "  cmock_call_instance->ExceptionToThrow = CEXCEPTION_NONE;\n" if (@cexception)
    lines
  end

  # args_to_s
  # plugins: expect
  #    args_string: (int i, int *j, int **k)
  #    call_args_string: (i, j, k)
  #    mock_args_string: (int i, int *j, int *j_Val, int **k, int k_Val)
  #    mock_call_args_string: (i, j, 1, j_Val, k, k_Val)
  # plugin:  array
  #    args_string: (int i, int *j, int **k)
  #    mock_args_string: (int i, int *j, int j_Depth, int *j_Val, int **k, int k_Val)
  #    mock_call_args_string: (i, j, j_Depth, j_Val, k, k_Val)
  # 
  def args_to_s(args, mock=true, plugin="expect")
    return "void", "void" if args.empty?
    new_args = args.reject {|x| mock ? false : (x[:extra?])}
    args_string = new_args.collect{|arg| "#{arg[:type]} #{arg[:name]}"}.compact.join(',')
    call_args_string = new_args.collect{|arg| "#{arg[:name]}"}.compact.join(',')  

    if plugin == "expect"
      args_string = new_args.collect {|arg| "#{arg[:type]} #{arg[:name]}" unless (arg[:extra?] and arg[:name].include?"Depth")}.compact.join(',')
      call_args_string = new_args.collect {|arg| (arg[:name].include?"Depth" and arg[:extra?]) ? "1" : "#{arg[:name]}"}.compact.join(',') 
    else  
      #add your special args string here.
    end  
    return args_string, call_args_string
  end
  
  def code_add_an_arg_expectation(arg, depth=1)
    lines = ""
    if (arg[:extra?] and arg[:name].include? "_Val" and arg[:depth_name] != "1")
      depth = arg[:name].gsub("_Val","_Depth")
      sizeof_arg = arg[:type].sub("*","")
      #if arg[:depth_name] == "1"
      #  "  cmock_call_instance->Expected_#{arg[:name]} = #{arg[:name]};\n"
      #else
        lines = "  if ( #{depth} > 1 )\n"  +
              "      memcpy((unsigned char*)(cmock_call_instance->Expected_#{arg[:name]}), (unsigned char*)(#{arg[:name]}), (#{depth} * sizeof(#{sizeof_arg})));\n" +
              "  else\n"  +
              "      cmock_call_instance->Expected_#{arg[:name]} = #{arg[:name]};\n"
      #end        
    else              
      lines =  code_assign_argument_quickly("cmock_call_instance->Expected_#{arg[:name]}", arg)
    end
    #lines << "  cmock_call_instance->Expected_#{arg[:name]}_Depth = #{arg[:name]}_Depth;\n" if (@arrays and (depth.class == String))
    lines
  end

  def code_assign_argument_quickly(dest, arg)
    if (arg[:ptr?] or @treat_as.include?(arg[:type]))
      "  #{dest} = #{arg[:const?] ? "(#{arg[:type]})" : ''}#{arg[:name]};\n"
    else
      "  memcpy(&#{dest}, &#{arg[:name]}, sizeof(#{arg[:type]}));\n"
    end
  end

  def code_add_argument_loader(function)
    args_string, call_args_string = args_to_s(function[:args], true, (@arrays ? "array" : "expect"))
    if (args_string != "void")
      "void CMockExpectParameters_#{function[:name]}(CMOCK_#{function[:name]}_CALL_INSTANCE* cmock_call_instance, #{args_string})\n{\n" +
        #function[:args].inject("") { |all, arg| all + code_add_an_arg_expectation(arg, (arg[:ptr?] ? "#{arg[:name]}_Depth" : 1) ) } +
        function[:args].inject("") { |all, arg| all + code_add_an_arg_expectation(arg)} +
        "}\n\n"
    else
      ""
    end
  end

  def code_call_argument_loader(function, plugin="expect")
    line = ""
    args_string, call_args_string = args_to_s(function[:args], true, plugin)
    if call_args_string != "void"
      line = "  CMockExpectParameters_#{function[:name]}(cmock_call_instance, #{call_args_string});\n"
    end
    return line
  end

  #private ######################
  # PTR handling
  # (int *i)
  # 1 Expect(i, __IGNORE__): ==> i == ? only compare data. ignore content.
  # 2 Expect(__IGNORE__, j_Val); ==> i = j_Val;  return address expected. ignore compare.
  # 3 Expect(i, i_Val) ==> i == ? and *i = i_Val; copmare data and return value expected.
  # 4 ExpectWithArray(i, depth, i_Val);   ==> memcpy(i,i_Val, depth) compare ptr, copy content expected.
  # 5 ExpectWithArray(__IGNORE__,depth, i_Val) ==> memcpy(?, depth, i_Val); only copy data expected.
  

  def lookup_expect_type(function, arg)
    c_type     = arg[:type]
    arg_name   = arg[:name]
    expected   = "cmock_call_instance->Expected_#{arg_name}"

    unity_func = if arg[:extra?] and arg[:name].include?"_Val"
                    ["UNITY_TEST_ASSERT_EQUAL_PTR",""]
                 elsif arg[:ptr?]
                    ["UNITY_TEST_ASSERT_EQUAL_PTR",""]
                 else
                    (@helpers.nil? or @helpers[:unity_helper].nil?) ? ["UNITY_TEST_ASSERT_EQUAL",''] : @helpers[:unity_helper].get_helper(c_type)
                 end     
    #puts "#{c_type} --> #{unity_func}"
    unity_msg  = "Function '#{function[:name]}' called with unexpected value for argument '#{arg_name}'."
    return c_type, arg_name, expected, unity_func[0], unity_func[1], unity_msg
  end

  def code_verify_an_arg_expectation_with_no_arrays(function, arg)
    return "" if arg[:extra?] and !(arg[:name].include?"_Val")
    c_type, arg_name, expected, unity_func, pre, unity_msg = lookup_expect_type(function, arg)
    case(unity_func)
      when "UNITY_TEST_ASSERT_EQUAL_MEMORY"
        c_type_local = c_type.gsub(/\*$/,'')
        return "  UNITY_TEST_ASSERT_EQUAL_MEMORY((void*)(#{pre}#{expected}), (void*)(#{pre}#{arg_name}), sizeof(#{c_type_local}), cmock_line, \"#{unity_msg}\");\n"
      when "UNITY_TEST_ASSERT_EQUAL_MEMORY"
        [ "  if (#{pre}#{expected} == NULL)",
          "    { UNITY_TEST_ASSERT_NULL(#{pre}#{arg_name}, cmock_line, \"Expected NULL. #{unity_msg}\"); }",
          "  else",
          "    { UNITY_TEST_ASSERT_EQUAL_MEMORY((void*)(#{pre}#{expected}), (void*)(#{pre}#{arg_name}), sizeof(#{c_type.sub('*','')}), cmock_line, \"#{unity_msg}\"); }\n"].join("\n")
      when /_ARRAY/
        [ "  if (#{pre}#{expected} == NULL)",
          "    { UNITY_TEST_ASSERT_NULL(#{pre}#{arg_name}, cmock_line, \"Expected NULL. #{unity_msg}\"); }",
          "  else",
          "    { #{unity_func}(#{pre}#{expected}, #{pre}#{arg_name}, 1, cmock_line, \"#{unity_msg}\"); }\n"].join("\n")
      else
        return "  #{unity_func}(#{pre}#{expected}, #{pre}#{arg_name}, cmock_line, \"#{unity_msg}\");\n"
    end
  end

  def code_verify_an_arg_expectation_with_normal_arrays(function, arg)
    return "" if arg[:extra?] and !arg[:name].include?"_Val"
    c_type, arg_name, expected, unity_func, pre, unity_msg = lookup_expect_type(function, arg)

    if arg[:extra?]     # int *i_Val, unsigned int k_Val
      depth_name = arg[:depth_name] == "1" ? "1" : "cmock_call_instance->Expected_#{arg[:depth_name]}"
      arg_target = arg[:name].gsub(/_Val$/,"")
      sizeof_arg = arg[:type].sub("*","")
      
      if arg[:depth_name] == "1"  # int **
        lines = " if ((int)#{expected} != (int)__IGNORE__){\n" +
                "    *#{arg_target} = #{expected};\n" +
                " }\n"
      else  # int *   
        lines = "  if ((int)#{expected} != (int)__IGNORE__){\n" + 
                "     memcpy((unsigned char*)(#{arg_target}), (unsigned char*)(#{expected}), (sizeof(#{sizeof_arg}) * #{depth_name}));\n" +
                "  }\n" 
      end          
      return lines
    end

    depth_name = (arg[:ptr?]) ? "#{expected}_Depth" : "1"
    case(unity_func)
      when "UNITY_TEST_ASSERT_EQUAL_PTR"
          [ "  if (#{pre}#{expected} == NULL)",
            "    { UNITY_TEST_ASSERT_NULL(#{pre}#{arg_name}, cmock_line, \"Expected NULL. #{unity_msg}\"); }",
            "  else",
            "    { UNITY_TEST_ASSERT_EQUAL_PTR(#{pre}#{expected}, #{pre}#{arg_name}, cmock_line, \"#{unity_msg}\"); }\n"].compact.join("\n")
      when "UNITY_TEST_ASSERT_EQUAL_MEMORY"
        c_type_local = c_type.gsub(/\*$/,'')
        return "  UNITY_TEST_ASSERT_EQUAL_MEMORY((void*)(#{pre}#{expected}), (void*)(#{pre}#{arg_name}), sizeof(#{c_type_local}), cmock_line, \"#{unity_msg}\");\n"
      when "UNITY_TEST_ASSERT_EQUAL_MEMORY_ARRAY"
        [ "  if (#{pre}#{expected} == NULL)",
          "    { UNITY_TEST_ASSERT_NULL(#{pre}#{arg_name}, cmock_line, \"Expected NULL. #{unity_msg}\"); }",
          "  else",
          "    { UNITY_TEST_ASSERT_EQUAL_MEMORY_ARRAY((void*)(#{pre}#{expected}), (void*)(#{pre}#{arg_name}), sizeof(#{c_type.sub('*','')}), #{depth_name}, cmock_line, \"#{unity_msg}\"); }\n"].compact.join("\n")
      when /_ARRAY/
        if (pre == '&')
          "  #{unity_func}(#{pre}#{expected}, #{pre}#{arg_name}, #{depth_name}, cmock_line, \"#{unity_msg}\");\n"
        else
          [ "  if (#{pre}#{expected} == NULL)",
            "    { UNITY_TEST_ASSERT_NULL(#{pre}#{arg_name}, cmock_line, \"Expected NULL. #{unity_msg}\"); }",
            "  else",
            "    { UNITY_TEST_ASSERT_EQUAL_PTR(#{pre}#{expected}, #{pre}#{arg_name}, cmock_line, \"#{unity_msg}\"); }\n"].compact.join("\n")
        end
      else
        return "  #{unity_func}(#{pre}#{expected}, #{pre}#{arg_name}, cmock_line, \"#{unity_msg}\");\n"
    end
  end

  def code_verify_an_arg_expectation_with_smart_arrays(function, arg)
    c_type, arg_name, expected, unity_func, pre, unity_msg = lookup_expect_type(function, arg)
    depth_name = (arg[:ptr?]) ? "cmock_call_instance->Expected_#{arg_name}_Depth" : 1
    case(unity_func)
      when "UNITY_TEST_ASSERT_EQUAL_MEMORY"
        c_type_local = c_type.gsub(/\*$/,'')
        return "  UNITY_TEST_ASSERT_EQUAL_MEMORY((void*)(#{pre}#{expected}), (void*)(#{pre}#{arg_name}), sizeof(#{c_type_local}), cmock_line, \"#{unity_msg}\");\n"
      when "UNITY_TEST_ASSERT_EQUAL_MEMORY_ARRAY"
        [ "  if (#{pre}#{expected} == NULL)",
          "    { UNITY_TEST_ASSERT_NULL(#{arg_name}, cmock_line, \"Expected NULL. #{unity_msg}\"); }",
          ((depth_name != 1) ? "  else if (#{depth_name} == 0)\n    { UNITY_TEST_ASSERT_EQUAL_PTR(#{pre}#{expected}, #{pre}#{arg_name}, cmock_line, \"#{unity_msg}\"); }" : nil),
          "  else",
          "    { UNITY_TEST_ASSERT_EQUAL_MEMORY_ARRAY((void*)(#{pre}#{expected}), (void*)(#{pre}#{arg_name}), sizeof(#{c_type.sub('*','')}), #{depth_name}, cmock_line, \"#{unity_msg}\"); }\n"].compact.join("\n")
      when /_ARRAY/
        if (pre == '&')
          "  #{unity_func}(#{pre}#{expected}, #{pre}#{arg_name}, #{depth_name}, cmock_line, \"#{unity_msg}\");\n"
        else
          [ "  if (#{pre}#{expected} == NULL)",
            "    { UNITY_TEST_ASSERT_NULL(#{pre}#{arg_name}, cmock_line, \"Expected NULL. #{unity_msg}\"); }",
            ((depth_name != 1) ? "  else if (#{depth_name} == 0)\n    { UNITY_TEST_ASSERT_EQUAL_PTR(#{pre}#{expected}, #{pre}#{arg_name}, cmock_line, \"#{unity_msg}\"); }" : nil),
            "  else",
            "    { #{unity_func}(#{pre}#{expected}, #{pre}#{arg_name}, #{depth_name}, cmock_line, \"#{unity_msg}\"); }\n"].compact.join("\n")
        end
      else
        return "  #{unity_func}(#{pre}#{expected}, #{pre}#{arg_name}, cmock_line, \"#{unity_msg}\");\n"
    end
  end

end
