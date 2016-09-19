defmodule HTTPlaster.Response do
  @moduledoc """
  An HTTP response from a server.
  """

  alias HTTPlaster.InspectionHelpers

  @typedoc """
  The status code returned by the server.

  Valid status codes are considered to be in the range 100 to 599 (inclusive),
  but the actual range used by HTTP servers is commonly a smaller subset
  of that range. See [this site](https://httpstatuses.com/) for more reference
  on individual status codes.
  """
  @type status_code :: 100..599

  @typedoc """
  The body returned by the server.

  This will always be a string, even if it is empty. While a server
  may return different content types, they will always be string encoded
  and further processing must be done to decode them into a target format.
  """
  @type body :: String.t

  @typedoc """
  Headers returned by the server are stored in a map of header names (in
  lower case) to their values. The names and values are always of the type
  `String.t`.
  """
  @type headers :: %{required(String.t) => String.t}

  @typedoc """
  Encapsulates an HTTP response

  #### :status_code

  The status code returned by the server. See the `status_code` type.

  #### :body

  The body returned by the server. See the `body` type.

  #### :headers

  The headers returned by the server. See the `headers` type.
  """
  @type t :: %__MODULE__{
               status_code: status_code,
               body: body,
               headers: headers
             }

  defstruct status_code: nil,
            body: nil,
            headers: %{}

  @doc """
  Inspects the structure of the Response struct passed in the same
  way `IO.inspect/1` might, returning the Response struct so that it
  can be used easily with pipes.

  Typically, `Kernel.inspect/1`, `IO.inspect/1`, and their companions are
  implemented using the `Inspect` protocol. However, the presentation used
  here can get extremely intrusive when experimenting using IEx, so it's
  relegated to this function. Corresponding functions can be found at
  `HTTPlaster.Conn.inspect/2` and `HTTPlaster.Request.inspect/2`.

  See `HTTPlaster.InspectionHelpers` for more information
  """
  @spec inspect(t, Keyword.t) :: t
  def inspect(resp, opts \\ []) do
    opts = struct(Inspect.Opts, opts)

    InspectionHelpers.inspect_response(resp, opts)
    |> Inspect.Algebra.format(:infinity)
    |> IO.puts()

    resp
  end
end
