defmodule HTTPlaster.Response do
  @moduledoc """
  """

  @type status_code :: 100..599

  @type body :: nil | String.t

  @type headers :: %{required(String.t) => String.t}

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

    HTTPlaster.InspectionHelpers.inspect_response(resp, opts)
    |> Inspect.Algebra.format(:infinity)
    |> IO.puts()

    resp
  end
end
