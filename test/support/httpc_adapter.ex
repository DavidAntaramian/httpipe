defmodule HTTPlaster.Adapters.HTTPC do
  @moduledoc """
  An :httpc client based largely on the HTTPClient for Phoenix testing

  The majority of this was built using [Phoenix.Integration.HTTPClient](https://github.com/phoenixframework/phoenix/blob/069028a31cfcbcd2027209c67b08d1d8dcf3c7c0/test/support/http_client.exs)
  but changed to reflect the expectations of the behaviour
  """
  @behaviour HTTPlaster.Adapter

  def execute_request(method, url, body, headers, options) do
    url = String.to_char_list(url)

    headers = 
      headers
      |> Map.put_new("content-type", "text/html")

    ct_type =
      headers["content-type"]
      |> String.to_char_list()

    header = Enum.map(headers, fn {k, v} ->
      {String.to_char_list(k), String.to_char_list(v)}
    end)

    profile =
      :crypto.strong_rand_bytes(4)
      |> Base.encode16()
      |> String.to_atom()

    {:ok, pid} = :inets.start(:httpc, profile: profile)

    resp =
      case method do
        :get -> :httpc.request(:get, {url, header}, [], [body_format: :binary], pid)
        _ -> :httpc.request(method, {url, header, ct_type, body}, [], [body_format: :binary], pid)
      end

    :inets.stop(:httpc, pid)

    format_resp(resp)
  end

  defp format_resp({:ok, {{_http, status, _status_phrase}, headers, body}}) do
    headers = Enum.reduce(headers, %{}, fn {k, v}, headers_map ->
      name = to_string(k)
      value = to_string(v)

      Map.update(headers_map, name, value, fn existing ->
        "#{existing}, #{value}"
      end)
    end)

    {:ok, {status, headers, body}}
  end

  defp format_resp({:error, reason}) do
    {:error, reason}
  end
end
