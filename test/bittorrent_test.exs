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

  # @tag :skip
  test "decode nested bencoded lists" do
    assert Bencode.decode("lli414e10:strawberryee") == [[414, "strawberry"]]
  end

  # @tag :skip
  test "decode deeply nested bencoded lists" do
    assert Bencode.decode("lli4eei5ee") == [[4], 5]
  end

  test "decode dictionary" do
    assert Bencode.decode("d3:cow3:moo4:spam4:eggse") == %{"cow" => "moo", "spam" => "eggs"}
  end

  test "decode dictionary - example from code crafters" do
    assert Bencode.decode("d3:foo3:bar5:helloi52ee") == %{"foo" => "bar", "hello" => 52}
  end
end
