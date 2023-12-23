defmodule BittorrentTest do
  use ExUnit.Case

  test "decode bencoded lists with a single integer" do
    assert Bencode.decode("li52ee") == [52]
  end

  test "decode bencoded lists with a single string" do
    assert Bencode.decode("l5:helloe") == ["hello"]
  end

  test "decode bencoded lists with a mix of string and integer" do
    assert Bencode.decode("l5:helloi52ee") == ["hello", 52]
  end

  test "decode bencoded lists with a mix of integer and string" do
    assert Bencode.decode("li52e5:helloe") == [52, "hello"]
  end

  test "decode nested bencoded list with one integer" do
    assert Bencode.decode("lli414eee") == [[414]]
  end

  test "decode nested bencoded list with one string" do
    assert Bencode.decode("ll10:strawberryee") == [["strawberry"]]
  end

  test "decode nested bencoded lists" do
    assert Bencode.decode("lli414e10:strawberryee") == [[414, "strawberry"]]
  end

  test "decode deeply nested bencoded lists" do
    assert Bencode.decode("lli4eei5ee") == [[4], 5]
  end

  # @tag :skip
  test "decode dictionary" do
    assert Bencode.decode("d3:cow3:moo4:spam4:eggse") == %{"cow" => "moo", "spam" => "eggs"}
  end

  # @tag :skip
  test "decode dictionary - example from code crafters" do
    assert Bencode.decode("d3:foo3:bar5:helloi52ee") == %{"foo" => "bar", "hello" => 52}
  end

  # @tag :skip
  test "decode dictionary with inner dictionary" do
    assert Bencode.decode("d10:inner_dictd4:key16:value14:key2i42eee") == %{
             "inner_dict" => %{"key1" => "value1", "key2" => 42}
           }
  end

  # @tag :skip
  test "decode dictionary with inner dictionary and value as list" do
    assert Bencode.decode(
             "d10:inner_dictd4:key16:value14:key2i42e8:list_keyl5:item15:item2i3eeee"
           ) == %{
             "inner_dict" => %{
               "key1" => "value1",
               "key2" => 42,
               "list_key" => ["item1", "item2", 3]
             }
           }
  end

  test "encode string" do
    assert Bencode.encode("hello") == "5:hello"
  end

  test "encode integer" do
    assert Bencode.encode(52) == "i52e"
  end

  test "encode list with string values only" do
    assert Bencode.encode(["hello", "world"]) == "l5:hello5:worlde"
  end

  test "encode list with integer values only" do
    assert Bencode.encode([42, 52]) == "li42ei52ee"
  end

  test "encode list with string and integer values" do
    assert Bencode.encode(["hello", 52]) == "l5:helloi52ee"
  end

  test "encode dictionary with string values only" do
    assert Bencode.encode(%{"cow" => "moo", "spam" => "eggs"}) == "d3:cow3:moo4:spam4:eggse"
  end

  test "encode dictionary with integer values only" do
    assert Bencode.encode(%{"cow" => 42, "spam" => 52}) == "d3:cowi42e4:spami52ee"
  end

  test "encode dictionary with string and integer values" do
    assert Bencode.encode(%{"cow" => "moo", "spam" => 52}) == "d3:cow3:moo4:spami52ee"
  end

  @tag :skip
  test "encode dictionary - example from code crafters" do
    assert Bencode.encode(%{"foo" => "bar", "hello" => 52}) ==
             "d6:lengthi92063e4:name10:sample.txt12:piece lengthi32768e6:pieces60:�v�z*����kg&���-n\"u��vfVsn���R��5��z����	r'�����e"
  end

  test "discover_peers returns correct list for sample.torrent" do
    expected_peers = [
      "178.62.82.89:51470",
      "165.232.33.77:51467",
      "178.62.85.20:51489"
    ]

    result = Bittorrent.CLI.discover_peers("sample.torrent")

    assert result == expected_peers
  end
end
