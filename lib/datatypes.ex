defmodule McProtocol.DataTypes do
  # For <<< (left shift) operator
  use Bitwise

  defmodule ChatMessage do
    defstruct [:text, :translate, :with, :score, :selector, :extra,
      :bold, :italic, :underligned, :strikethrough, :obfuscated, :color,
      :clickEvent, :hoverEvent, :insertion]

    defmodule Score do
      defstruct [:name, :objective]
    end
    defmodule ClickEvent do
      defstruct [:action, :value]
    end
    defmodule HoverEvent do
      defstruct [:action, :value]
    end
  end

  defmodule Slot do
    defstruct id: nil, count: 0, damage: 0, enchantments: []
    defmodule Enchantment, do: defstruct [:id, :level]
  end

  defmodule Decode do

    @spec varint(binary) :: {integer, binary}
    def varint(data) do
      {:ok, resp} = varint?(data)
      resp
    end

    def varint?(data) do
      decode_varint(data, 0, 0)
    end
    defp decode_varint(<<1::1, curr::7, rest::binary>>, num, acc) when num < (64-7) do
      decode_varint(rest, num+7, (curr <<< num) + acc)
    end
    defp decode_varint(<<0::1, curr::7, rest::binary>>, num, acc) do
      {:ok, {(curr <<< num) + acc, rest}}
    end
    defp decode_varint(_, num, _) when num >= (64-7), do: :too_big
    defp decode_varint("", _, _), do: :incomplete
    defp decode_varint(_, _, _), do: :error

    @spec bool(binary) :: {boolean, binary}
    def bool(<<value::size(8), rest::binary>>) do
      case value do
        1 -> {true, rest}
        _ -> {false, rest}
      end
    end

    def string(data) do
      {length, data} = varint(data)
      <<result::binary-size(length), rest::binary>> = data
      {to_string(result), rest}
      #result = :binary.part(data, {0, length})
      #{result, :binary.part(data, {length, byte_size(data)-length})}
    end

    def chat(data) do
      json = string(data)
      Poison.decode!(json, as: McProtocol.DataTypes.ChatMessage)
    end

    def slot(data) do
      <<id::signed-integer-2*8, data::binary>> = data
      slot_id(data, id)
    end
    defp slot_id(data, -1), do: {%McProtocol.DataTypes.Slot{}, data}
    defp slot_id(data, id) do
      <<count::unsigned-integer-1*8, damage::unsigned-integer-2*8, has_nbt::unsigned-integer-1*8, data::binary>> = data
      struct = %McProtocol.DataTypes.Slot{id: id, count: count, damage: damage}
      case has_nbt do
        0 -> {struct, data}
        _ ->
          {ench, data} = slot_nbt(data)
          {%{struct | enchantments: ench}, data}
      end
    end
    defp slot_nbt(data) do
      {data, ench} = McProtocol.NBT.read(data)
      {ench, data}
    end

    def varint_length_binary(data) do
      {length, data} = varint(data)
      result = :binary.part(data, {0, length})
      {result, :binary.part(data, {length, byte_size(data)-length})}
    end

    def byte(data) do
      <<num::signed-integer-size(8), data::binary>> = data
      {num, data}
    end
    def fixed_point_byte(data) do
      {num, data} = byte(data)
      {num / 32, data}
    end
    def u_byte(data) do
      <<num::unsigned-integer-size(8), data::binary>> = data
      {num, data}
    end

    def short(data) do
      <<num::signed-integer-size(16), data::binary>> = data
      {num, data}
    end
    def u_short(data) do
      <<num::unsigned-integer-size(16), data::binary>> = data
      {num, data}
    end

    def int(data) do
      <<num::signed-integer-size(32), data::binary>> = data
      {num, data}
    end
    def fixed_point_int(data) do
      {num, data} = int(data)
      {num / 32, data}
    end
    def long(data) do
      <<num::signed-integer-size(64), data::binary>> = data
      {num, data}
    end

    def float(data) do
      <<num::signed-float-4*8, data::binary>> = data
      {num, data}
    end
    def double(data) do
      <<num::signed-float-8*8, data::binary>> = data
      {num, data}
    end

    def position(data) do
      <<x::signed-integer-26, y::signed-integer-12, z::signed-integer-26, data::binary>> = data
      {{x, y, z}, data}
    end

    def byte_array_rest(data) do
      {data, <<>>}
    end

    def byte_flags(data) do
      <<flags::binary-1*8, data::binary>> = data
      {flags, data}
    end

    def chunk(data, mask) do

    end
  end

  defmodule Encode do

    def byte_flags(bin) do
      bin
    end

    @spec varint(integer) :: binary
    def varint(int) do
      :gpb.encode_varint(int)
    end

    @spec bool(boolean) :: binary
    def bool(bool) do
      if bool do
        <<1::size(8)>>
      else
        <<0::size(8)>>
      end
    end

    def string(string) do
      <<varint(IO.iodata_length(string))::binary, IO.iodata_to_binary(string)::binary>>
    end
    def chat(struct) do
      string(Poison.Encoder.encode(struct, []))
    end

    def varint_length_binary(data) do
      <<varint(byte_size(data))::binary, data::binary>>
    end

    def byte(num) when is_integer(num) do
      <<num::signed-integer-1*8>>
    end
    def fixed_point_byte(num) do
      byte(round(num * 32))
    end
    def u_byte(num) do
      <<num::unsigned-integer-size(8)>>
    end

    def short(num) do
      <<num::unsigned-integer-size(16)>>
    end
    def u_short(num) do
      <<num::unsigned-integer-size(16)>>
    end

    def int(num) do
      <<num::signed-integer-size(32)>>
    end
    def fixed_point_int(num) do
      int(round(num * 32))
    end
    def long(num) do
      <<num::signed-integer-size(64)>>
    end

    def float(num) do
      <<num::signed-float-4*8>>
    end
    def double(num) do
      <<num::signed-float-8*8>>
    end

    def position({x, y, z}) do
      <<x::signed-integer-26, y::signed-integer-12, z::signed-integer-26>>
    end

    def data(data) do
      data
    end

    def angle(num) do
      byte(num)
    end
    def metadata(meta) do
      McProtocol.EntityMeta.write(meta)
    end
  end

end
