defmodule Mix.Tasks.Mavlink do
  use Mix.Task

  
  import Mavlink.Parser
  import Enum, only: [count: 1, join: 2, map: 2, filter_map: 3]
  import String, only: [trim: 1, replace: 3]


  @shortdoc "Generate Mavlink Module from XML"
  def run(["generate", input, output]) do
    %{
      version: version,
      dialect: dialect,
      enums: enums,
      messages: messages
     } = parse_mavlink_xml(input)
     
    enum_details = get_enum_details(enums)
     
    File.write(output,
    """
    defmodule Mavlink do
       
      @typedoc "An atom representing a Mavlink enumeration type"
      @type enum_type :: #{map(enums, & ":#{&1[:name]}") |> join(" | ")}
       
      @typedoc "An atom representing a Mavlink enumeration type value"
      @type enum_value :: #{map(enums, & "#{&1[:name]}") |> join(" | ")}
      
      #{enum_details |> map(& &1[:type]) |> join("\n  ")}
      
      @typedoc "A parameter description"
      @type param_description :: %{
        index: pos_integer,
        description: String.t
      }
      
      @typedoc "A list of parameter descriptions"
      @type param_description_list :: [param_description]
      
      @typedoc "Type used for field in encoded message"
      @type field_type :: int8 | int16 | int32 | int64 | uint8 | uint16 | uint32 | uint64 | float
      
      @typedoc "8-bit signed integer"
      @type int8 :: -128..127
      
      @typedoc "16-bit signed integer"
      @type int16 :: -32_768..32_767
      
      @typedoc "32-bit signed integer"
      @type int32 :: -2_147_483_647..2_147_483_647
      
      @typedoc "64-bit signed integer"
      @type int64 :: integer
      
      @typedoc "8-bit unsigned integer"
      @type uint8 :: 0..255
      
      @typedoc "16-bit unsigned integer"
      @type uint16 :: 0..65_535
      
      @typedoc "32-bit unsigned integer"
      @type uint32 :: 0..4_294_967_295
      
      @typedoc "64-bit unsigned integer"
      @type uint64 :: pos_integer
      
      @typedoc "0 -> not an array 1..255 an array"
      @type field_ordinality :: 0..255
      
      @typedoc "Measurement unit of field value"
      @type field_unit :: :pc | :bytes | :bps | :cpc | :cA | :cdeg | :cmps | :deg | :degE7 | :Mibytes | :m | :mm | :ms | :mV | :pix | :s | :us  # TODO generate unique set from fields
      
      @typedoc "A message field description"
      @type field_description :: %{
        type: field_type,
        ordinality: field_ordinality,
        name: String.t,
        units: field_unit,
        description: String.t
      }
      
      @typedoc "A list of message field descriptions"
      @type field_description_list :: [field_description]
      
      @typedoc "A Mavlink message"
      @type message :: Heartbeat.t  # TODO generate
      
      @typedoc "A Mavlink message id"
      @type message_id :: 0..1_000
       
      @doc "Mavlink version"
      @spec mavlink_version() :: integer
      def mavlink_version(), do: #{version}
       
      @doc "Mavlink dialect"
      @spec mavlink_dialect() :: integer
      def mavlink_dialect(), do: #{dialect}
       
      @doc "Return a String description of a Mavlink enumeration"
      @spec describe(enum_type | enum_value) :: String.t
      #{enum_details |> map(& &1[:describe]) |> join("\n  ") |> trim}
       
      @doc "Return keyword list of mav_cmd parameters"
      @spec describe_params(mav_cmd) :: param_description_list
      #{enum_details |> map(& &1[:describe_params]) |> join("\n  ") |> trim}
       
      @doc "Return encoded integer value used in a Mavlink message for an enumeration value"
      @spec encode(enum_value) :: integer
      #{enum_details |> map(& &1[:encode]) |> join("\n  ") |> trim}
       
      @doc "Return the atom representation of a Mavlink enumeration value from the enumeration type and encoded integer"
      @spec decode(enum_type, integer) :: enum_value
      #{enum_details |> map(& &1[:decode]) |> join("\n  ") |> trim}
      
      @doc "Convert a binary into a Mavlink message"
      @spec decode(<<>>) :: message
      def decode(<<>>) do
        # TODO
      end
      
      defprotocol Message do
        @doc "Encode a message"
        @spec encode_msg(Mavlink.message) :: <<>>
        def encode_msg(message)
        
        @doc "Get message id"
        @spec msg_id(Mavlink.message) :: Mavlink.message_id
        def msg_id(message)
        
        @doc "Describe message"
        @spec describe_msg(Mavlink.message) :: String.t
        def describe_msg(message)
        
        @doc "Return keyword list of field details"
        @spec describe_msg_fields(Mavlink.message) :: Mavlink.field_descrption_list
        def describe_msg_fields(message)
      end
      
      defmodule Heartbeat do
        
        defstruct type: nil, autopilot: nil, base_mode: nil, custom_mode: nil, system_status: nil, mavlink_version: #{version}
       
        @typedoc "The heartbeat message shows that a system is present and responding...Type of the MAV..."
        @type t :: %Heartbeat{
          type: Mavlink.mav_type,
          autopilot: Mavlink.mav_autopilot,
          base_mode: Mavlink.mav_mode_flag,
          custom_mode: Mavlink.uint32,
          system_status: Mavlink.mav_state,
          mavlink_version: Mavlink.uint8
        }
        
        defimpl Message, for: Heartbeat do
          def msg_id(message), do: 0
          def encode_msg(message), do: <<>>
          def describe_msg(message), do: "The heartbeat message shows..."
          def describe_msg_fields(message), do: []
        end
        
      end
      
    end
    """
    )
    
  end
  
  
  defp get_enum_details(enums) do
    for enum <- enums do
      %{
        name: name,
        description: description,
        entries: entries
      } = enum
      
      entry_details = get_entry_details(name, entries)
      
      %{
        type: ~s/@typedoc "#{description}"\n  / <>
          ~s/@type #{name} :: / <>
          (map(entry_details, & ":#{&1[:name]}") |> join(" | ")),
          
        describe: ~s/def describe(:#{name}), do: "#{description}"\n  / <>
          (map(entry_details, & &1[:describe])
          |> join("\n  ")),
          
        describe_params: filter_map(entry_details, & &1 != nil,& &1[:describe_params])
          |> join("\n  "),
          
        encode: map(entry_details, & &1[:encode])
          |> join("\n  "),
        
        decode: map(entry_details, & &1[:decode])
          |> join("\n  ")
      }
    end
  end
  
  
  defp get_entry_details(enum_name, entries) do
    for entry <- entries do
      %{
        name: entry_name,
        description: entry_description,
        value: entry_value,
        params: entry_params
      } = entry
      
      entry_value_string = cond do
        entry_value == nil ->
          "nil"
        true ->
          entry_value
      end
      
      %{
        name: entry_name,
        describe: ~s/def describe(:#{entry_name}), do: "#{entry_description |> escape_dq}"/,
        describe_params: get_param_details(entry_name, entry_params),
        encode: ~s/def encode(:#{entry_name}), do: #{entry_value_string}/,
        decode: ~s/def decode(:#{enum_name}, #{entry_value_string}), do: :#{entry_name}/
      }
    end
  end
  
  
  defp get_param_details(entry_name, entry_params) do
    cond do
      count(entry_params) == 0 ->
        nil
      true ->
        ~s/def describe_params(:#{entry_name}), do: [/ <>
        (map(entry_params, & ~s/{#{&1[:index]}, "#{&1[:description]}"}/) |> join(", ")) <>
        ~s/]/
    end
  end
  
  defp escape_dq(s) do
    s |> replace(~S/"/, ~s/\\"/)
  end
  
end
