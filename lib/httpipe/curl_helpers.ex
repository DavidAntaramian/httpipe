defmodule HTTPipe.CurlHelpers do
  @moduledoc """
  Helper module for formatting the `HTTPipe.Request` struct.

  This module has helpers to format a valid curl string that can then be
  executed from a command-line context.
  """

  alias HTTPipe.Request

  @doc """
  Converts a Request struct into a curl string that can
  be executed normally from the command-line.
  """
  @spec convert_request_to_curl(Request.t) :: String.t
  def convert_request_to_curl(request) do
    full_url = convert_full_url(request.url, request.params)
    method = convert_method(request.method)
    headers = convert_headers(request.headers)
    body = convert_body(request.body)

    ["curl", "#{method}", "#{full_url}", "#{headers}", "#{body}"]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  @spec convert_full_url(Request.url, Request.params) :: String.t
  def convert_full_url(base_url, params) do
    case Request.prepare_url(base_url, params) do
      {:ok, full_url} -> full_url
      {:error, _} -> ""
    end
  end

  @spec convert_method(Request.method) :: String.t
  def convert_method(method) do
    curl_method = method |> Atom.to_string() |> String.upcase()
    "-X #{curl_method}"
  end

  @spec convert_headers(Request.headers) :: String.t
  def convert_headers(headers) do
    headers
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.reduce([], fn({k, v}, acc) ->
         [convert_header(k, v) | acc]
       end)
    |> Enum.join(" ")
  end

  @spec convert_header(String.t, String.t) :: String.t
  def convert_header(k, v) do
    "-H \"#{k}: #{v}\""
  end

  @spec convert_body(Request.body) :: String.t
  def convert_body(nil), do: ""
  def convert_body({:file, file_path}) do
    "-d \"@#{file_path}\""
  end
  def convert_body({:form, keyword_list}) do
    keyword_list
    |> Enum.reduce([], fn(kv, acc) ->
      ["-F \"#{URI.encode_query([kv])}\"" | acc]
    end)
    |> Enum.join(" ")
  end
  def convert_body(body) when is_binary(body) do
    "-d \"#{body}\""
  end
end
