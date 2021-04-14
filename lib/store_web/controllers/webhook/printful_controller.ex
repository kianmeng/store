defmodule Elementary.StoreWeb.Webhook.PrintfulController do
  use Elementary.StoreWeb, :controller

  alias Elementary.Store.{Email, Mailer}

  def index(conn, %{"secret" => secret} = params) do
    config_secret = Application.get_env(:store, Printful.Api)[:webhook_secret]

    if Plug.Crypto.secure_compare(config_secret, secret) do
      Task.async(fn -> handle_event(params) end)
    end

    conn
    |> put_status(:ok)
    |> json(%{"status" => "ok"})
  end

  def handle_event(%{"type" => type}) when type in ["product_synced", "product_updated"] do
    Printful.Cache.flush()
    Elementary.Store.Catalog.get_products()
  end

  def handle_event(%{"type" => "package_shipped", "data" => data}) do
    data = Jason.decode(data, keys: :atoms)

    data.order
    |> Email.package_shipped(data.shipment)
    |> Mailer.deliver_later()
  end
end
