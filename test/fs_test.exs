defmodule FSTest do
  use ExUnit.Case, async: true

  @tag :tmp_dir
  test "system", %{tmp_dir: tmp_dir} do
    fs = %SystemFS{root: tmp_dir}
    assert FS.ls(fs) == []
    assert :ok = FS.write(fs, "a.txt", "Hi")
    assert FS.ls(fs) == ["a.txt"]
    assert FS.read(fs, "a.txt") == {:ok, "Hi"}
  end

  test "agent" do
    fs = AgentFS.new()
    assert FS.ls(fs) == []
    assert :ok = FS.write(fs, "a.txt", "Hi")
    assert FS.ls(fs) == ["a.txt"]
    assert FS.read(fs, "a.txt") == {:ok, "Hi"}
  end

  test "process" do
    fs = ProcessFS.new()
    assert FS.ls(fs) == []
    assert :ok = FS.write(fs, "a.txt", "Hi")
    assert FS.ls(fs) == ["a.txt"]
    assert FS.read(fs, "a.txt") == {:ok, "Hi"}
  end

  @tag :tmp_dir
  test "zip", %{tmp_dir: tmp_dir} do
    fs = ZipFS.new(Path.join(tmp_dir, "a.zip"))
    assert FS.ls(fs) == []
    assert :ok = FS.write(fs, "a.txt", "Hi")
    assert FS.ls(fs) == ["a.txt"]
    assert FS.read(fs, "a.txt") == {:ok, "Hi"}
  end

  test "encrypt" do
    fs = EncryptFS.new(AgentFS.new(), cipher: :aes_128_ctr, key: <<1::128>>, iv: <<0::128>>)
    assert FS.ls(fs) == []
    assert :ok = FS.write(fs, "a.txt", "Hi")
    assert FS.ls(fs) == ["a.txt"]
    assert FS.read(fs, "a.txt") == {:ok, "Hi"}
  end

  @tag :skip
  test "s3"
end
