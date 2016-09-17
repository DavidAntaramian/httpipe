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

  defimpl Inspect do
    import Inspect.Algebra
    import HTTPlaster.InspectionHelpers

    @spec inspect(HTTPlaster.Response, Inspect.Opts.t) :: Inspect.Algebra.t
    def inspect(request, opts) do
      status_code = inspect_status_code(request.status_code, opts)
      headers = inspect_headers(request.headers)
      body = inspect_body(request.body, opts)

      concat [
        "Response",
        status_code,
        headers,
        body
      ]
    end
  end
end
