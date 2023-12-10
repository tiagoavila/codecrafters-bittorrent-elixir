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
  def decode(<<"l", rest::binary>>) do
    size = byte_size(rest) - 1
    <<list_content::binary-size(size), "e"::binary>> = rest

    Enum.map_reduce(
      list_content |> String.graphemes() |> Enum.with_index(),
      %{ignore_next: 0, string_acc: ""},
      fn {char, index}, %{ignore_next: chars_count, string_acc: str_acc} ->
        case char do
          "e" when chars_count == 0 ->
            possible_bencoded_integer = str_acc <> char


            if Regex.match?(~r/i-*\d+e/, possible_bencoded_integer),
              do: {decode(possible_bencoded_integer), %{ignore_next: 0, string_acc: ""}},
              else: {"", %{ignore_next: 0, string_acc: possible_bencoded_integer}}

          ":" ->
            chars_count = str_acc |> String.to_integer()

            possible_bencoded_string =
              String.slice(list_content, index - 1, chars_count + 2)

            {decode(possible_bencoded_string), %{ignore_next: chars_count, string_acc: ""}}

          _ ->
            if chars_count > 0,
              do: {"", %{ignore_next: chars_count - 1, string_acc: ""}},
              else: {"", %{ignore_next: 0, string_acc: str_acc <> char}}
        end
      end
    )
    |> then(fn {list, _} -> list |> Enum.filter(&(&1 != "")) end)
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
end
