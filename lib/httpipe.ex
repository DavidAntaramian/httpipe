defmodule HTTPipe do
  @moduledoc """
  Provides helper functions that allow for quick, one-off HTTP requests. To build
  composable requests, see the `HTTPipe.Conn` module.

  The functions in this module are designed to provide a (somewhat) parity interface
  with [HTTPoison](https://hex.pm/packages/httpoison) and
  [HTTPotion](https://hex.pm/packages/httpotion).
  Each major HTTP method has its own function that you can call. For example, to perform
  an HTTP GET request, it is as simple as:

  ~~~
  {:ok, conn} = HTTPipe.get("https://httpbin.org/get")
  ~~~

  _See the note about [configuring an adapter](README.html#configuring-an-adapter) in
  the README._

  The `conn` that is captured in the above statement is an `HTTPipe.Conn` struct. All
  the functions in the module have a return signature of `{:ok, Conn.t} | {:error, Conn.t}`
  except for trailing bang (_e.g._, `get!`) functions which have a return signature of
  `Conn.t | no_return`–anything that would have resulted in an `{:error, Conn.t}` response
  before will instead `raise` the appropriate exception.

  If you are coming from HTTPoison or HTTPotion, it is important to note that this library
  does _not_ return a `Response` or `ErrorResponse` struct. This library returns the `Conn.t`
  struct which encapsulates the entire transaction. If an error occured, the `Conn.t` struct
  returned will include the exception under the `:error` key.

  For a slightly more complicated example, let's try handling the response. httpbin returns
  its results as JSON, so for this example, we'll assume you have the
  [Poison](https://hex.pm/packages/poison) library. The `/get` path will return the IP address
  of the client under the `"origin"` key.

  ~~~
  with {:ok, %{response: %{body: body}}} <- HTTPipe.get("https://httpbin.org/get"),
       {:ok, decoded_body} <- Poison.decode(body),
    do: Map.get(decoded_body, "origin")
  ~~~

  ## Headers

  Each of the functions in this module allow for custom headers to be passed as a map of the
  form `%{String.t => String.t}`. If the function accepts a body, the headers can be passed
  as the third parameter; otherwise the headers can be passed as the second parameter. By default,
  an empty map will be passed. For example, let's set the `"Accept"` header:

  ~~~
  HTTPipe.get("https://httpbin.org/get", %{"Accept" => "application/xml"})
  ~~~

  For more information, see the type documentation for `HTTPipe.Request.headers`.

  ## Body

  If the function accepts a body, it will be the second parameter to the function. The body
  can be passed either as `nil`, a `String.t`, or a special tuple that will be processed
  before executing the connection. For example, to send URL encoded form data, you can
  use the `{:form, data}` tuple. The `data` should be a `Keyword.t` list no more than
  one level deep.

  ~~~
  post_body = {:form, [name: "HTTPipe", language: "Elixir"]}

  HTTPipe.post("https://httpbin.org/post", post_body)
  ~~~

  Based on the above connection, the server will receive the following body:

  ~~~txt
  name=HTTPipe&language=Elixir
  ~~~

  For more information, see the type documentation for `HTTPipe.Request.body`.

  ## Options

  The final parameter of every function in this module is a keyword list of options.
  The following options are available:

  ### :adapter

  You can use this key to modify the adapter used for a specific connection. For example:

  ~~~
  httpc_adapter = HTTPipe.Adapters.HTTPC

  # Uses :default adapter
  {:ok, conn} = HTTPipe.get("https://httpbin.org/get", %{})
  # Uses HTTPC Adapter
  {:ok, conn} = HTTPipe.get("https://httpbin.org/get", %{}, [adapter: httpc_adapter])
  ~~~

  ### :adapter_options

  The `:adapter_options` key will be passed directly to the adapter. The adapter you choose
  should document the options that can be passed in here.

  ### :params
  
  This is a keyword list of query parameters to be appended to the URL you specified. The
  list should be no deeper than a single key-value pair. This option is primarily
  to provide compatiability with HTTPoison/HTTPotion. For example:

  ~~~
  params = [q: "HTTPipe adapter", language: "elixir"]

  {:ok, conn} = HTTPipe.get("https://httpbin.org/get", %{}, [params: params])
  ~~~

  The server will receive the following URL request:

  ~~~txt
  https://httpbin.org/get?q=HTTPipe+adapter&language=elixir
  ~~~

  ## Further Testing

  If you want to try out the functions more, you can use [RequestBin](http://requestb.in/)
  to see how these requests are made to the server. RequestBin gives you a unique, disposable
  URL which you can send requests to. The requests will then be displayed on the dashboard.
  For example, let's try posting to a RequestBin:

  ~~~
  url = "http://requestb.in/15mo0ew1"
  post_body = {:form, [test_param: "test value"]}
  headers = %{"content-type" => "application/x-www-form-urlencoded"}

  HTTPipe.post(url, post_body, headers)
  ~~~
  """

  alias HTTPipe.{Conn, Request}

  @doc ~S"""
  Performs an HTTP `DELETE` request on the given resource.
  """
  @spec delete(Request.url, Request.headers, Keyword.t) :: {:ok, Conn.t} | {:error, Conn.t}
  def delete(url, headers \\ %{}, options \\ []) do
    request(:delete, url, nil, headers, options)
  end

  @doc ~S"""
  Identical to `delete/3` but raises an error if the request could not be
  completed successfully.
  """
  @spec delete!(Request.url, Request.headers, Keyword.t) :: Conn.t | no_return
  def delete!(url, headers \\ %{}, options \\ []) do
    request!(:delete, url, nil, headers, options)
  end

  @doc ~S"""
  Performs an HTTP `GET` request on the given resource.
  """
  @spec get(Request.url, Request.headers, Keyword.t) :: {:ok, Conn.t} | {:error, Conn.t}
  def get(url, headers \\ %{}, options \\ []) do
    request(:get, url, nil, headers, options)
  end

  @doc ~S"""
  Identical to `get/3` but raises an error if the request could not be
  completed successfully.
  """
  @spec get!(Request.url, Request.headers, Keyword.t) :: Conn.t | no_return
  def get!(url, headers \\ %{}, options \\ []) do
    request!(:get, url, nil, headers, options)
  end

  @doc ~S"""
  Performs an HTTP `HEAD` request on the given resource.
  """
  @spec head(Request.url, Request.headers, Keyword.t) :: {:ok, Conn.t} | {:error, Conn.t}
  def head(url, headers \\ %{}, options \\ []) do
    request(:head, url, nil, headers, options)
  end

  @doc ~S"""
  Identical to `head/3` but raises an error if the request could not be
  completed successfully.
  """
  @spec head!(Request.url, Request.headers, Keyword.t) :: Conn.t | no_return
  def head!(url, headers \\ %{}, options \\ []) do
    request!(:head, url, nil, headers, options)
  end

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
  @spec options(Request.url, Request.headers, Keyword.t) :: {:ok, Conn.t} | {:error, Conn.t}
  def options(url, headers \\ %{}, options \\ []) do
    request(:options, url, nil, headers, options)
  end

  @doc ~S"""
  Identical to `options/3` but raises an error if the request could not be
  completed successfully.
  """
  @spec options!(Request.url, Request.headers, Keyword.t) :: Conn.t | no_return
  def options!(url, headers \\ %{}, options \\ []) do
    request!(:options, url, nil, headers, options)
  end

  @doc ~S"""
  Performs an HTTP `PATCH` request on the given resource.
  """
  @spec patch(Request.url, Request.body, Request.headers, Keyword.t) :: {:ok, Conn.t} | {:error, Conn.t}
  def patch(url, body, headers \\ %{}, options \\ []) do
    request(:patch, url, body, headers, options)
  end

  @doc ~S"""
  Identical to `patch/4` but raises an error if the request could not be
  completed successfully.
  """
  @spec patch!(Request.url, Request.body, Request.headers, Keyword.t) :: Conn.t | no_return
  def patch!(url, body, headers \\ %{}, options \\ []) do
    request!(:patch, url, body, headers, options)
  end

  @doc ~S"""
  Perforns an HTTP `POST` request on the given resource.
  """
  @spec post(Request.url, Request.body, Request.headers, Keyword.t) :: {:ok, Conn.t} | {:error, Conn.t}
  def post(url, body, headers \\ %{}, options \\ []) do
    request(:post, url, body, headers, options)
  end

  @doc ~S"""
  Identical to `post/4` but raises an error if the request could not be
  completed succesfully.
  """
  @spec post!(Request.url, Request.body, Request.headers, Keyword.t) :: Conn.t | no_return
  def post!(url, body, headers \\ %{}, options \\ []) do
    request!(:post, url, body, headers, options)
  end

  @doc ~S"""
  Performs an HTTP `PUT` request on the given resource.
  """
  @spec put(Request.url, Request.body, Request.headers, Keyword.t) :: {:ok, Conn.t} | {:error, Conn.t}
  def put(url, body, headers \\ %{}, options \\ []) do
    request(:put, url, body, headers, options)
  end

  @doc ~S"""
  Identical to `put/4` but raises an error if the request could not be
  completed succesfully.
  """
  @spec put!(Request.url, Request.body, Request.headers, Keyword.t) :: Conn.t | no_return
  def put!(url, body, headers \\ %{}, options \\ []) do
    request!(:put, url, body, headers, options)
  end

  @doc ~S"""
  Performs a generic HTTP request using the given method on the requested resource. This function
  is used by all other functions in this module to complete their requests.
  """
  @spec request(Request.http_method, Request.url, Request.body, Request.headers, Keyword.t) :: {:ok, Conn.t} | {:error, Conn.t}
  def request(method, url, body, headers \\ %{}, options) do
    build_conn_from_function(method, url, body, headers, options)
    |> Conn.execute()
  end

  @doc ~S"""
  Identical to `request/5` but will raise an error if the request could not
  be completed succesfully.
  """
  @spec request!(Request.http_method, Request.url, Request.body, Request.headers, Keyword.t) :: Conn.t | no_return
  def request!(method, url, body, headers \\ %{}, options) do
    build_conn_from_function(method, url, body, headers, options)
    |> Conn.execute!()
  end

  # Helper function that builds a Conn from one of the ease-of-use
  # functions.
  @spec build_conn_from_function(Request.http_method, Request.url, Request.body, Request.headers, Keyword.t) :: Conn.t
  defp build_conn_from_function(method, url, body, headers, options) do
    adapter_options = Keyword.get(options, :adapter_options, [])
    adapter = Keyword.get(options, :adapter, :default)
    params = Keyword.get(options, :params, [])

    conn =
      %Conn{}
      |> Conn.put_req_method(method)
      |> Conn.put_req_url(url)
      |> Conn.put_req_body(body)
      |> Conn.merge_req_headers(headers)
      |> Conn.put_adapter_options(adapter_options)
      |> Conn.put_adapter(adapter)

    Enum.reduce(params, conn, fn ({k, v}, c) ->
      Conn.put_req_param(c, k, v, :duplicates_ok)
    end)
  end
end
