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
  def decode(encoded_value) when is_binary(encoded_value) do
    binary_data = :binary.bin_to_list(encoded_value)

    with index <- Enum.find_index(binary_data, fn char -> char == 58 end),
         is_bencoded_integers <- index == nil and Regex.match?(~r/i-*\d+e/, encoded_value) do
      if is_bencoded_integers do
        String.replace(encoded_value, ~r/i(-*\d+)e/, "\\1")
      else
        rest = Enum.slice(binary_data, (index + 1)..-1)
        List.to_string(rest)
      end
    else
      _ -> IO.puts("The ':' character is not found in the binary")
    end
  end

  def decode(_), do: "Invalid encoded value: not binary"
end
