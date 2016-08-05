defmodule HTTPlaster.Conn do
  @moduledoc """
  """

  alias HTTPlaster.{Request, Response}

  @type status :: :unexecuted | :executed

  @type t :: %__MODULE__{
               status: status,
               request: Request.t,
               response: Response.t
             }

  defstruct status: :unexecuted,
            request: %Request{},
            response: %Response{}
end
