defmodule Bittorrent.CLI do
  @pieces_byte_size 20

  def main(argv) do
    case argv do
      ["decode" | [encoded_str | _]] ->
        # You can use print statements as follows for debugging, they'll be visible when running tests.
        # IO.puts("Logs from your program will appear here!")

        # Uncomment this block to pass the first stage
        decoded_str = Bencode.decode(encoded_str)
        IO.puts(Jason.encode!(decoded_str))

      ["info" | [torrent_file | _]] ->
        parse_torrent_file(torrent_file)

      ["peers" | [torrent_file | _]] ->
        discover_peers(torrent_file)

      [command | _] ->
        IO.puts("Unknown command: #{command}")
        System.halt(1)

      [] ->
        IO.puts("Usage: your_bittorrent.sh <command> <args>")
        System.halt(1)
    end
  end

  defp parse_torrent_file(torrent_file_path) do
    decoded_torrent_file = torrent_file_path |> read_torrent_file_and_decode()

    info_hash = decoded_torrent_file |> get_info_hash_hex_encoded()

    IO.puts("Tracker URL: #{Map.get(decoded_torrent_file, "announce")}")
    IO.puts("Length: #{get_in(decoded_torrent_file, ["info", "length"])}")
    IO.puts("Info Hash: #{info_hash}")
    IO.puts("Piece Length: #{get_in(decoded_torrent_file, ["info", "piece length"])}")
    IO.puts("Piece Hashes:")

    get_in(decoded_torrent_file, ["info", "pieces"])
    |> get_piece_hashes_list()
    |> Enum.each(&IO.puts/1)
  end

  defp get_piece_hashes_list(piece_hashes_string) do
    piece_hashes_string
    |> Base.decode16!(case: :lower)
    |> do_get_piece_hashes()
  end

  defp do_get_piece_hashes(pieces, result \\ [])
  defp do_get_piece_hashes(<<>>, result), do: Enum.reverse(result)

  defp do_get_piece_hashes(<<piece::binary-size(@pieces_byte_size), rest::binary>>, result) do
    encoded_piece = piece |> Base.encode16(case: :lower)

    do_get_piece_hashes(rest, [encoded_piece | result])
  end

  defp discover_peers(torrent_file_path) do
    decoded_torrent_file = read_torrent_file_and_decode(torrent_file_path)
    url = Map.get(decoded_torrent_file, "announce")
    info_hash = decoded_torrent_file |> get_info_hash() |> URI.encode()
    peer_id = "00112233445566778899"
    port = 6881
    uploaded = 0
    downloaded = 0
    left = get_in(decoded_torrent_file, ["info", "length"])
    compact = 1
    request_url = "#{url}?info_hash=#{info_hash}&peer_id=#{peer_id}&port=#{port}&uploaded=#{uploaded}&downloaded=#{downloaded}&left=#{left}&compact=#{compact}"

    case HTTPoison.get!(request_url) do
      %HTTPoison.Response{status_code: 200, body: body} ->
        body
        |> Bencode.decode()
        |> get_peers()
        |> Enum.each(&IO.puts/1)

      %HTTPoison.Response{status_code: status_code} ->
        IO.puts("Error: #{status_code}")
        System.halt(1)
    end
  end

  defp read_torrent_file_and_decode(torrent_file_path) do
    File.read!(torrent_file_path)
    |> IO.iodata_to_binary()
    |> Bencode.decode()
  end

  defp get_info_hash(decoded_torrent_file) do
    info_map_encoded = Map.get(decoded_torrent_file, "info") |> Bencode.encode()

    :crypto.hash(:sha, <<info_map_encoded::binary>>)
  end

  defp get_info_hash_hex_encoded(decoded_torrent_file) do
    decoded_torrent_file
    |> get_info_hash()
    |> Base.encode16(case: :lower)
  end

  defp get_peers(%{"peers" => peers}) do
    peers
    |> Base.decode16!(case: :lower)
    |> :binary.bin_to_list()
    |> Enum.chunk_every(6)
    |> Enum.map(fn peer_bytes ->
      <<a, b, c, d, port::binary-size(2)>> = peer_bytes |> :binary.list_to_bin()
      ip_value = :inet.ntoa({a, b, c, d})
      port_value = :binary.decode_unsigned(port, :big)
      "#{ip_value}:#{port_value}"
    end)
  end
end

defmodule Bencode do
  def encode(string) when is_binary(string) do
    case Base.decode16(string, case: :lower) do
      {:ok, binary} ->
        size = Integer.floor_div(String.length(string), 2)
        <<"#{size}:"::binary, binary::binary>>

      :error ->
        "#{byte_size(string)}:#{string}"
    end
  end

  def encode(number) when is_integer(number), do: "i#{number}e"

  def encode(list) when is_list(list) do
    Enum.reduce(list, "", fn item, acc -> acc <> encode(item) end)
    |> then(&"l#{&1}e")
  end

  def encode(map) when is_map(map) do
    map
    |> Enum.reduce("", fn {key, value}, acc -> acc <> encode(key) <> encode(value) end)
    |> then(&"d#{&1}e")
  end

  def decode(<<"d", rest::binary>>) do
    dict_content_size = byte_size(rest) - 1
    <<dict_content::binary-size(dict_content_size), "e"::binary>> = rest

    decode_dict(dict_content, %{})
  end

  def decode(<<"l", rest::binary>>) do
    list_content_size = byte_size(rest) - 1
    <<list_content::binary-size(list_content_size), "e"::binary>> = rest

    decode_list(list_content, [], nil)
  end

  def decode(<<"i", rest::binary>>) do
    rest
    |> String.replace("e", "")
    |> String.to_integer()
  end

  def decode(encoded_value) when is_binary(encoded_value) do
    binary_data = :binary.bin_to_list(encoded_value)
    {head, tail} = binary_data |> Enum.split_while(fn char -> char != ?: end)

    {size, _} = head |> List.to_string() |> Integer.parse()

    decoded_bin =
      tail
      |> Enum.slice(1..size)
      |> :binary.list_to_bin()

    case String.valid?(decoded_bin) do
      true ->
        decoded_bin

      false ->
        # Non UTF-8 values are converted to Base16 so we can count how many char
        # we have to skip
        base16_tail = tail |> :binary.list_to_bin() |> Base.encode16(case: :lower)
        # Since this is hex, size of 1 = 2bytes
        base16_tail |> String.slice(2..(size * 2 + 1))
    end
  end

  def decode(_), do: "Invalid encoded value: not binary"

  defp decode_dict("", dict), do: dict

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

      nil ->
        "Invalid dict key"
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
      Regex.match?(~r/^\d+:/, dict_content) ->
        extract_bencoded_string_and_decode(dict_content)

      Regex.match?(~r/^i/, dict_content) ->
        extract_bencoded_integer_and_decode(dict_content)

      Regex.match?(~r/^d/, dict_content) ->
        dict_content_size = byte_size(dict_content) - 2
        <<"d", dict_content::binary-size(dict_content_size), "e">> = dict_content
        {decode_dict(dict_content, %{}), ""}

      Regex.match?(~r/^l/, dict_content) ->
        dict_content_size = byte_size(dict_content) - 2
        <<"l", dict_content::binary-size(dict_content_size), "e">> = dict_content
        {decode_list(dict_content, [], nil), ""}

      true ->
        "Invalid dict value"
    end
  end

  defp decode_list("", main_list, _), do: Enum.reverse(main_list)

  defp decode_list(<<"i", _::binary>> = remaining, main_list, inner_list) do
    [{start_index, match_len}] = Regex.run(~r/^i-*\d+e/, remaining, return: :index)
    bencoded_integer = String.slice(remaining, start_index, match_len)
    remaining = String.replace_leading(remaining, bencoded_integer, "")

    decoded_integer = decode(bencoded_integer)

    insert_item(remaining, main_list, inner_list, decoded_integer)
  end

  defp decode_list(<<"l", rest::binary>>, main_list, nil) do
    decode_list(rest, main_list, [])
  end

  defp decode_list(<<"e", rest::binary>>, main_list, inner_list) do
    decode_list(rest, [Enum.reverse(inner_list) | main_list], nil)
  end

  defp decode_list(remaining, main_list, inner_list) do
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
    do: decode_list(remaining, [new_item | main_list], nil)

  defp insert_item(remaining, main_list, inner_list, new_item),
    do: decode_list(remaining, main_list, [new_item | inner_list])
end
