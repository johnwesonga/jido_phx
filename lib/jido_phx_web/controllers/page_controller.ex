defmodule JidoPhxWeb.PageController do
  use JidoPhxWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
