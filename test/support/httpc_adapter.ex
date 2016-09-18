defmodule HTTPlaster.Adapters.HTTPC do
  @moduledoc """
  An :httpc client based largely on the HTTPClient for Phoenix testing

  The majority of this was built using [Phoenix.Integration.HTTPClient](https://github.com/phoenixframework/phoenix/blob/069028a31cfcbcd2027209c67b08d1d8dcf3c7c0/test/support/http_client.exs)
  but changed to reflect the expectations of the behaviour
  """
  @behaviour HTTPlaster.Adapter

  alias __MODULE__.{ConnectionFailedError, SendFailedError, GeneralError}

  def execute_request(method, url, body, headers, _options) do
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
      if method in [:get, :head, :options, :trace] do
        :httpc.request(method, {url, header}, [], [body_format: :binary], pid)
      else
        :httpc.request(method, {url, header, ct_type, body}, [], [body_format: :binary], pid)
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
    error =
      case reason do
        {:failed_connect, _} ->
          ConnectionFailedError.exception(nil)
        {:send_failed, _} ->
          SendFailedError.exception(nil)
        _ ->
          GeneralError.exception(nil)
      end

    {:error, error}
  end

  defmodule ConnectionFailedError do
    defexception message: """
    The host could not be reached.
    """

    @type t :: %__MODULE__{}

    @spec exception(nil) :: t
    def exception(_), do: %__MODULE__{}
  end

  defmodule SendFailedError do
    defexception message: """
    Failed to send the request to the host.
    """

    @type t :: %__MODULE__{}

    @spec exception(nil) :: t
    def exception(_), do: %__MODULE__{}
  end

  defmodule GeneralError do
    defexception message: """
    The HTTPC adapter encountered an error and was unable to
    complete the request.
    """

    @type t :: %__MODULE__{}

    @spec exception(nil) :: t
    def exception(_), do: %__MODULE__{}
  end
end
