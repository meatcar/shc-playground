#! /usr/bin/env elixir

Mix.install([{:poison, "~> 5.0.0"}])

defmodule Parser do
  require Logger
  require Base
  require Poison

  @doc """
  Parse a SMART Health Card string, returning it's header, payload, and signature.
  """
  def parse(data) do
    [header64, payload64, signature] =
      data
      |> decode_numeric()
      |> String.split(".")

    header =
      (header64 <> "==")
      |> Base.url_decode64!()
      |> Poison.decode!()

    payload =
      payload64
      |> Base.url_decode64!()
      |> :zlib.unzip()
      |> Poison.decode!()

    %{header: header, payload: payload, signature: signature}
  end

  @doc """
  Parse a SMART Health Card string, returning it's contents.

  ## Examples

      iex> parse("shc:/46")
      "-"

  """
  def decode_numeric(data) do
    "shc:/" <> str = data
    decode_numeric(str, "")
  end

  defp decode_numeric("", acc), do: acc

  defp decode_numeric(data, acc) do
    {head, rest} = String.split_at(data, 2)
    # 45 is from https://spec.smarthealth.cards/#encoding-chunks-as-qr-codes
    int = String.to_integer(head)
    c = int + 45
    decode_numeric(rest, acc <> <<c::utf8>>)
  end
end

defmodule Main do
  defp usage(device \\ :stdio) do
    argv0 = __ENV__.file |> Path.relative_to_cwd()

    IO.puts(
      device,
      """
      usage: #{argv0} [-h|--help]

      Decode from standard input the information in a SMART Health Card's QR code.
      """
    )
  end

  defp parse_opts() do
    try do
      {opts, _cmd} =
        System.argv()
        |> OptionParser.parse!(aliases: [h: :help], strict: [help: :boolean])
        |> tap(&IO.inspect/1)

      parse_opts(opts, nil)
    rescue
      e ->
        IO.puts(:stderr, Exception.message(e))
        usage(:stderr)
        exit({:shutdown, 1})
    end
  end

  defp parse_opts([], config), do: config

  defp parse_opts([{:help, _} | _t], _config) do
    usage()
    exit({:shutdown, 0})
  end

  def main do
    parse_opts()

    case IO.read(:stdio, :line) do
      {:error, e} -> raise e
      :eof -> raise "End Of File"
      data -> data |> String.trim() |> Parser.parse() |> IO.inspect()
    end
  end
end

ExUnit.start(autorun: false)

defmodule ParserTest do
  use ExUnit.Case, async: true

  test "decode_numeric" do
    assert Parser.decode_numeric("shc:/") == ""
    assert Parser.decode_numeric("shc:/00") == "-"
    assert Parser.decode_numeric("shc:/0001") == "-."
  end
end

case ExUnit.run() do
  %{failures: 0} ->
    Main.main()

  _ ->
    :error
end
