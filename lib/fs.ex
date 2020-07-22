defmodule FS do
  defdelegate read_dir(fs), to: FS.Server

  defdelegate write(fs, path, data), to: FS.Server

  defdelegate read(fs, path), to: FS.Server

  def ls(fs) do
    for file_info <- read_dir(fs) do
      file_info.path
    end
  end
end

defprotocol FS.Server do
  def read_dir(fs)

  def write(fs, path, data)

  def read(fs, path)
end

defmodule FS.FileInfo do
  defstruct [:path, :size, :type, :fs]
end

defmodule SystemFS do
  defstruct [:root]

  defimpl FS.Server do
    @impl true
    def read_dir(fs) do
      fs.root
      |> File.ls!()
      |> Enum.map(fn path ->
        stat = File.stat!(Path.join(fs.root, path))
        %FS.FileInfo{path: path, type: stat.type, size: stat.size, fs: fs}
      end)
    end

    @impl true
    def write(fs, path, data) do
      File.write(Path.join(fs.root, path), data)
    end

    @impl true
    def read(fs, path) do
      File.read(Path.join(fs.root, path))
    end
  end
end

defmodule AgentFS do
  defstruct [:pid]

  def new() do
    {:ok, pid} = Agent.start_link(fn -> %{} end)
    %__MODULE__{pid: pid}
  end

  defimpl FS.Server do
    @impl true
    def read_dir(fs) do
      Agent.get(fs.pid, fn entries ->
        for {_, %{file_info: file_info}} <- entries, do: file_info
      end)
      |> Enum.sort_by(& &1.path)
    end

    @impl true
    def write(fs, path, data) do
      Agent.update(fs.pid, fn entries ->
        Map.put(entries, path, %{
          file_info: %FS.FileInfo{path: path, type: :regular, size: byte_size(data)},
          data: data
        })
      end)
    end

    @impl true
    def read(fs, path) do
      Agent.get(fs.pid, fn entries ->
        with {:ok, entry} <- Map.fetch(entries, path) do
          {:ok, entry.data}
        end
      end)
    end
  end
end

defmodule ProcessFS do
  defstruct []

  def new() do
    %__MODULE__{}
  end

  defimpl FS.Server do
    @name ProcessFS

    @impl true
    def read_dir(_fs) do
      entries = Process.get(@name) || %{}

      for({_, %{file_info: file_info}} <- entries, do: file_info)
      |> Enum.sort_by(& &1.path)
    end

    @impl true
    def write(_fs, path, data) do
      entries =
        Process.get(@name) ||
          %{}
          |> Map.put(path, %{
            file_info: %FS.FileInfo{path: path, type: :regular, size: byte_size(data)},
            data: data
          })

      Process.put(@name, entries)
      :ok
    end

    @impl true
    def read(_fs, path) do
      entries = Process.get(@name) || %{}

      with {:ok, entry} <- Map.fetch(entries, path) do
        {:ok, entry.data}
      end
    end
  end
end

defmodule ZipFS do
  defstruct [:path]

  def new(path) do
    {:ok, _} = :zip.create(path, [])
    %__MODULE__{path: String.to_charlist(path)}
  end

  defimpl FS.Server do
    @impl true
    def read_dir(fs) do
      {:ok, [{:zip_comment, _} | files]} = :zip.list_dir(fs.path)

      for file <- files do
        {:zip_file, path, file_info, _, _, _} = file
        stat = File.Stat.from_record(file_info)
        %FS.FileInfo{path: List.to_string(path), type: stat.type, size: stat.size, fs: fs}
      end
    end

    @impl true
    # TODO: optimize by writing just the new file instead of rewriting the whole archive
    def write(fs, path, data) do
      {:ok, files} = :zip.extract(fs.path, [:memory])
      {:ok, _} = :zip.create(fs.path, [{String.to_charlist(path), data} | files])
      :ok
    end

    @impl true
    # TODO: optimize by using zip handle
    def read(fs, path) do
      {:ok, files} = :zip.extract(fs.path, [:memory])
      path_charlist = String.to_charlist(path)
      data = Enum.find_value(files, fn {charlist, data} -> charlist == path_charlist && data end)
      {:ok, data}
    end
  end
end

defmodule EncryptFS do
  defstruct [:fs, :cipher, :key, :iv]

  def new(fs, opts) do
    struct!(%__MODULE__{fs: fs}, opts)
  end

  defimpl FS.Server do
    @impl true
    def read_dir(fs) do
      FS.Server.read_dir(fs.fs)
    end

    @impl true
    def write(fs, path, data) do
      encrypted_data = :crypto.crypto_one_time(fs.cipher, fs.key, fs.iv, data, true)
      FS.Server.write(fs.fs, path, encrypted_data)
    end

    @impl true
    def read(fs, path) do
      with {:ok, encrypted_data} <- FS.Server.read(fs.fs, path) do
        data = :crypto.crypto_one_time(fs.cipher, fs.key, fs.iv, encrypted_data, false)
        {:ok, data}
      end
    end
  end
end

defmodule GistFS do
  defstruct [:token, :finch]

  def new(opts) do
    struct!(__MODULE__, opts)
  end

  defimpl FS.Server do
    @impl true
    def read_dir(fs) do
      headers = [
        {"accept", "application/vnd.github.v3+json"},
        {"authorization", "token #{fs.token}"}
      ]

      request = Finch.build(:get, "https://api.github.com/gists", headers)
      {:ok, response} = Finch.request(request, fs.finch)
      body = Jason.decode!(response.body)

      for gist <- body do
        %FS.FileInfo{path: gist["id"], type: :directory, fs: fs}
      end
    end

    @impl true
    def write(_fs, _path, _data) do
    end

    @impl true
    def read(_fs, _path) do
    end
  end
end
