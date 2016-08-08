defmodule HTTPlaster do
  @moduledoc """
  """
  
  alias HTTPlaster.{Conn, Request}

  @doc ~S"""
  Performs an HTTP `DELETE` reqeust on the given resource. 
  """
  @spec delete(String.t, Keyword.t | Request.headers, Keyword.t) :: Conn.t
  def delete(url, headers \\ %{}, options \\ []), do: request(:delete, url, nil, headers, options)

  @doc ~S"""
  Identical to `delete/3` but raises an error if the request could not be
  completed successfully.
  """
  @spec delete!(String.t, Keyword.t | Request.headers, Keyword.t) :: Conn.t | no_return
  def delete!(url, headers \\ %{}, options \\ []), do: request!(:delete, url, nil, headers, options)

  @doc ~S"""
  Performs an HTTP `GET` request on the given resource.
  """
  @spec get(String.t, Keyword.t | Request.headers, Keyword.t) :: Conn.t
  def get(url, headers \\ %{}, options \\ []), do: request(:get, url, nil, headers, options)

  @doc ~S"""
  Identical to `get/3` but raises an error if the request could not be
  completed successfully.
  """
  @spec get!(String.t, Keyword.t | Request.headers, Keyword.t) :: Conn.t | no_return
  def get!(url, headers \\ %{}, options \\ []), do: request!(:get, url, nil, headers, options)

  @doc ~S"""
  Performs an HTTP `HEAD` request on the given resource.
  """
  @spec head(String.t, Keyword.t | Request.headers, Keyword.t) :: Conn.t
  def head(url, headers \\ %{}, options \\ []), do: request(:head, url, nil, headers, options)

  @doc ~S"""
  Identical to `head/3` but raises an error if the request could not be
  completed successfully.
  """
  @spec head(String.t, Keyword.t | Request.headers, Keyword.t) :: Conn.t | no_return
  def head!(url, headers \\ %{}, options \\ []), do: request!(:head, url, nil, headers, options)

  @doc ~S"""
  Performs an HTTP `OPTIONS` request on the given resource.

  ## Compatability Note
  
  In order to maintain compatability with libraries such as HTTPoison
  and HTTPotion, the `options/3` and `options!/3` functions do not
  accept `body` fields, even though [RFC 7231](https://tools.ietf.org/html/rfc7231)
  allows for `OPTIONS` requests to have a body.

  If you need to make an `OPTIONS` request with a body, please use `request/5`
  or `request!/5` as appropriate instead.
  """
  @spec options(String.t, Keyword.t | Request.headers, Keyword.t) :: Conn.t
  def options(url, headers \\ %{}, options \\ []), do: request(:options, url, nil, headers, options)


  @doc ~S"""
  Identical to `options/3` but raises an error if the request could not be
  completed successfully.
  """
  @spec options!(String.t, Keyword.t | Request.headers, Keyword.t) :: Conn.t | no_return
  def options!(url, headers \\ %{}, options \\ []), do: request!(:options, url, nil, headers, options)

  @doc ~S"""
  Performs an HTTP `PATCH` request on the given resource.
  """
  @spec patch(String.t, Request.body, Keyword.t | Request.headers, Keyword.t) :: Conn.t
  def patch(url, body, headers \\ %{}, options \\ []), do: request(:patch, url, body, headers, options)


  @doc ~S"""
  Identical to `patch/4` but raises an error if the request could not be
  completed successfully.
  """
  @spec patch!(String.t, Request.body, Keyword.t | Request.headers, Keyword.t) :: Conn.t | no_return
  def patch!(url, body, headers \\ %{}, options \\ []), do: request!(:patch, url, body, headers, options)

  @doc ~S"""
  Perforns an HTTP `POST` request on the given resource.
  """
  @spec post(String.t, Request.body, Keyword.t | Request.headers, Keyword.t) :: Conn.t
  def post(url, body, headers \\ %{}, options \\ []), do: request(:post, url, body, headers, options)

  @doc ~S"""
  Identical to `post/4` but raises an error if the request could not be
  completed succesfully.
  """
  @spec post!(String.t, Request.body, Keyword.t | Request.headers, Keyword.t) :: Conn.t | no_return
  def post!(url, body, headers \\ %{}, options \\ []), do: request!(:post, url, body, headers, options)

  @doc ~S"""
  Performns an HTTP `PUT` request on the given resource.
  """
  @spec put(String.t, Request.body, Keyword.t | Request.headers, Keyword.t) :: Conn.t
  def put(url, body, headers \\ %{}, options \\ []), do: request(:put, url, body, headers, options)

  @doc ~S"""
  Identical to `put/4` but raises an error if the request could not be
  completed succesfully.
  """
  @spec put!(String.t, Request.body, Keyword.t | Request.headers, Keyword.t) :: Conn.t | no_return
  def put!(url, body, headers \\ %{}, options \\ []), do: request!(:put, url, body, headers, options)

  @spec request(Request.http_method, String.t, Request.body, Keyword.t | Request.headers, Keyword.t) :: Conn.t
  def request(method, url, body, headers \\ %{}, options) do
    build_conn_from_function(method, url, body, headers, options)
    |> Conn.execute()
  end

  @doc ~S"""
  Identical to `request/5` but will raise an error if the request could not
  be completed succesfully.
  """
  @spec request!(Request.http_method, String.t, Request.body, Keyword.t | Request.headers, Keyword.t) :: Conn.t | no_return
  def request!(method, url, body, headers \\ %{}, options) do
    build_conn_from_function(method, url, body, headers, options)
    |> Conn.execute!()
  end

  # build_conn_from_function(Request.method, String.t, Request.body, Request.headers, Keyword.t) :: Conn.t
  #
  # Helper function that builds a Conn from one of the ease-of-use
  # functions.
  defp build_conn_from_function(method, url, body, headers, options) do
    %Conn{}
    |> Request.put_method(method)
    |> Request.put_url(url)
  end
end
