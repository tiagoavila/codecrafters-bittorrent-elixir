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

  # # @tag :skip
  test "decode dictionary with inner dictionary" do
    assert Bencode.decode("d10:inner_dictd4:key16:value14:key2i42eee") == %{"inner_dict" => %{"key1" => "value1", "key2" => 42}}
  end

  # # @tag :skip
  test "decode dictionary with inner dictionary and value as list" do
    assert Bencode.decode("d10:inner_dictd4:key16:value14:key2i42e8:list_keyl5:item15:item2i3eeee") == %{"inner_dict" => %{"key1" => "value1", "key2" => 42, "list_key" => ["item1", "item2", 3]}}
  end
end
