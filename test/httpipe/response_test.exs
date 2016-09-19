defmodule HTTPipe.ResponseTest do
  use ExUnit.Case

  alias HTTPipe.Response

  describe "HTTPipe.Response.get_header/3" do
    test "returns the value of the header" do
      headers = %{"content-type" => "test/html"}

      response = %Response{headers: headers}

      value = Response.get_header(response, "content-type")

      assert value == "test/html"
    end

    test "returns the nil when the header does not exist" do
      headers = %{}

      response = %Response{headers: headers}

      value = Response.get_header(response, "content-type")

      assert value == nil
    end
    
    test "returns the specified default value when the header does not exist" do
      headers = %{}

      response = %Response{headers: headers}

      value = Response.get_header(response, "content-type", "text/html")

      assert value == "text/html"
    end
  end
end
