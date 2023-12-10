defmodule BittorrentTest do
  use ExUnit.Case

  test "decode bencoded lists" do
    assert Bencode.decode("li52ee") == [52]
    assert Bencode.decode("l5:helloe") == ["hello"]
    assert Bencode.decode("l5:helloi52ee") == ["hello", 52]
    assert Bencode.decode("li52e5:helloe") == [52, "hello"]
    assert Bencode.decode("lli414e10:strawberryee") == [[414, "strawberry"]]
  end
end
