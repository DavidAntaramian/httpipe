defmodule HTTPlaster.Response do
  @moduledoc """
  """

  @type status_code :: 100..599

  @type body :: nil | String.t

  @type headers :: Keyword.t

  @type t :: %__MODULE__{
               status_code: status_code,
               body: body,
               headers: headers
             }

  defstruct status_code: nil,
            body: nil,
            headers: []
end
