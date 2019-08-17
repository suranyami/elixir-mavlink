defmodule Listen do
  
  import MAVLink.Utils
  
  def run() do
    {:ok, _socket} = :gen_udp.open(14550, [:binary, active: :true])
    IO.puts("Listening for UDP MAVLink frames on 127.0.0.1:14550:")
    run(:socket_opened)
  end
  
  def run(:socket_opened) do
    receive do
      {:udp, _sock, {a1, a2, a3, a4}, port,
        raw=<<0xfd,
          payload_length::unsigned-integer-size(8),
          0::unsigned-integer-size(8),                # Reject all incompatible flags
          _compatible_flags::unsigned-integer-size(8),
          sequence_number::unsigned-integer-size(8),
          system_id::unsigned-integer-size(8),
          component_id::unsigned-integer-size(8),
          message_id::little-unsigned-integer-size(24),
          payload::binary-size(payload_length),
          checksum::little-unsigned-integer-size(16)>>} ->
      
          dump(2, a1, a2, a3, a4, port, raw, payload_length, sequence_number, system_id, component_id, message_id, payload, checksum)
      
      {:udp, _sock, {a1, a2, a3, a4}, port,
        raw=<<0xfe,
          payload_length::unsigned-integer-size(8),
          sequence_number::unsigned-integer-size(8),
          system_id::unsigned-integer-size(8),
          component_id::unsigned-integer-size(8),
          message_id::unsigned-integer-size(8),
          payload::binary-size(payload_length),
          checksum::little-unsigned-integer-size(16)>>} ->
      
          dump(1, a1, a2, a3, a4, port, raw, payload_length, sequence_number, system_id, component_id, message_id, payload, checksum)
          
      _other ->
        IO.puts "???: UNKNOWN FRAME #{inspect(_other)}"
    end
    run(:socket_opened)
  end
  
  
  def dump(version, a1, a2, a3, a4, port, raw, payload_length, sequence_number, system_id, component_id, message_id, payload, checksum) do
    case MAVLink.msg_crc_size(message_id) do
      {:ok, crc, expected_length} ->
        checksum_calc = :binary.bin_to_list(raw, {1, payload_length + elem({0, 5, 9}, version)}) |> x25_crc() |> x25_crc([crc])
        checksum_ok = (checksum == checksum_calc)
        
        case checksum_ok do
          true ->
            payload_truncation = 8 * (expected_length - payload_length)
            payload = payload <> <<0::size(payload_truncation)>>
            
            case MAVLink.unpack(message_id, payload) do
              {:ok, message = %{__struct__: :"Elixir.MAVLink.Message.RcChannels"}} ->  #{:ok, message} ->
                IO.puts("#{sequence_number}: #{a1}.#{a2}.#{a3}.#{a4}:#{port} sent MAVLink v#{version} message from system #{system_id} component #{component_id}")
                IO.inspect(message)
              {:ok, _} ->
                :ok
              {:error, _} ->
                IO.puts("...COULDN'T UNPACK message id #{message_id}: #{inspect(raw)}")
            end
          _ ->
            IO.puts("#{sequence_number}: FAILED CHECKSUM message id #{message_id}\npayload expected/actual length #{expected_length}/#{payload_length} crc #{crc}:\n#{inspect(raw)}")
        end
        
      {:error, _} ->
        IO.puts("#{sequence_number}: UNKNOWN MESSAGE ID #{message_id}")
    end
  end
end

Listen.run()
