defmodule FS.MixProject do
  use Mix.Project

  def project do
    [
      app: :fs,
      version: "0.1.0",
      elixir: "~> 1.11-dev",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:crypto]
    ]
  end

  defp deps do
    [
      {:finch, "~> 0.3.0"},
      {:jason, "~> 1.0"}
    ]
  end
end
