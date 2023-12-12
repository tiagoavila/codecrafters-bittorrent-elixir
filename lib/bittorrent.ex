defmodule Bittorrent.CLI do
  def main(argv) do
    case argv do
      ["decode" | [encoded_str | _]] ->
        # You can use print statements as follows for debugging, they'll be visible when running tests.
        # IO.puts("Logs from your program will appear here!")

        # Uncomment this block to pass the first stage
        decoded_str = Bencode.decode(encoded_str)
        IO.puts(Jason.encode!(decoded_str))

      [command | _] ->
        IO.puts("Unknown command: #{command}")
        System.halt(1)

      [] ->
        IO.puts("Usage: your_bittorrent.sh <command> <args>")
        System.halt(1)
    end
  end
end

defmodule Bencode do
  def decode(<<"d", rest::binary>>) do
    dict_content_size = byte_size(rest) - 1
    <<dict_content::binary-size(dict_content_size), "e"::binary>> = rest

    decode_dict(dict_content, %{})
  end

  defp decode_dict("", dict), do: dict
  # defp decode_dict(<<"e", remaining::binary>>, dict), do: {dict, remaining}

  defp decode_dict(dict_content, dict) do
    {key, dict_content} = extract_bencoded_string_and_decode(dict_content)
    {value, dict_content} = decode_dict_value(dict_content)

    decode_dict(dict_content, Map.put(dict, key, value))
  end

  defp extract_bencoded_string_and_decode(dict_content) do
    case Regex.run(~r/^(\d+):/, dict_content) do
      [_, string_length] ->
        bencoded_string = extract_bencoded_string(string_length, dict_content)
        remaining = String.replace_leading(dict_content, bencoded_string, "")
        {decode(bencoded_string), remaining}

      nil -> "Invalid dict key"
    end
  end

  defp extract_bencoded_integer_and_decode(dict_content) do
    [{start_index, match_len}] = Regex.run(~r/^i-*\d+e/, dict_content, return: :index)
    bencoded_integer = String.slice(dict_content, start_index, match_len)
    remaining = String.replace_leading(dict_content, bencoded_integer, "")

    {decode(bencoded_integer), remaining}
  end

  defp decode_dict_value(dict_content) do
    cond do
      Regex.match?(~r/^\d+:/, dict_content) -> extract_bencoded_string_and_decode(dict_content)
      Regex.match?(~r/^i/, dict_content) -> extract_bencoded_integer_and_decode(dict_content)
      Regex.match?(~r/^d/, dict_content) ->
        dict_content_size = byte_size(dict_content) - 2
        <<"d", dict_content::binary-size(dict_content_size), "e">> = dict_content
        {decode_dict(dict_content, %{}), ""}
      Regex.match?(~r/^l/, dict_content) ->
        dict_content_size = byte_size(dict_content) - 2
        <<"l", dict_content::binary-size(dict_content_size), "e">> = dict_content
        {do_decode(dict_content, [], nil), ""}
      true -> "Invalid dict value"
    end
  end

  def decode(<<"l", rest::binary>>) do
    list_content_size = byte_size(rest) - 1
    <<list_content::binary-size(list_content_size), "e"::binary>> = rest

    do_decode(list_content, [], nil)
  end

  def decode(<<"i", rest::binary>>) do
    rest
    |> String.replace("e", "")
    |> String.to_integer()
  end

  def decode(encoded_value) when is_binary(encoded_value) do
    binary_data = :binary.bin_to_list(encoded_value)

    case Enum.find_index(binary_data, fn char -> char == 58 end) do
      nil ->
        IO.puts("The ':' character is not found in the binary")

      index ->
        rest = Enum.slice(binary_data, (index + 1)..-1)
        List.to_string(rest)
    end
  end

  def decode(_), do: "Invalid encoded value: not binary"

  defp do_decode("", main_list, _), do: Enum.reverse(main_list)

  defp do_decode(<<"i", _::binary>> = remaining, main_list, inner_list) do
    [{start_index, match_len}] = Regex.run(~r/^i-*\d+e/, remaining, return: :index)
    bencoded_integer = String.slice(remaining, start_index, match_len)
    remaining = String.replace_leading(remaining, bencoded_integer, "")

    decoded_integer = decode(bencoded_integer)

    insert_item(remaining, main_list, inner_list, decoded_integer)
  end

  defp do_decode(<<"l", rest::binary>>, main_list, nil) do
    do_decode(rest, main_list, [])
  end

  defp do_decode(<<"e", rest::binary>>, main_list, inner_list) do
    do_decode(rest, [Enum.reverse(inner_list) | main_list], nil)
  end

  defp do_decode(remaining, main_list, inner_list) do
    case Regex.run(~r/^(\d+):/, remaining) do
      [_, string_length] ->
        bencoded_string = extract_bencoded_string(string_length, remaining)
        remaining = String.replace_leading(remaining, bencoded_string, "")
        decoded_string = decode(bencoded_string)
        insert_item(remaining, main_list, inner_list, decoded_string)

      nil ->
        Enum.reverse(main_list)
    end
  end

  defp extract_bencoded_string(string_length, content) do
    String.slice(
      content,
      0,
      # length of the number before ':', 1 for the ':' and the length of the string
      String.length(string_length) + 1 + String.to_integer(string_length)
    )
  end

  defp insert_item(remaining, main_list, nil, new_item),
    do: do_decode(remaining, [new_item | main_list], nil)

  defp insert_item(remaining, main_list, inner_list, new_item),
    do: do_decode(remaining, main_list, [new_item | inner_list])
end
