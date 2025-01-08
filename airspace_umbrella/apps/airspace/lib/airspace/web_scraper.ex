defmodule Airspace.WebScraper do
  @moduledoc """
  A simple web scraper using HTTPoison and Floki.
  """

  def fetch_page(url) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Failed to fetch page. Status code: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Failed to fetch page. Reason: #{reason}"}
    end
  end

  def parse_html(html) do
    Floki.parse_document(html)
  end

  def extract_data(html, selector) do
    html
    |> Floki.find(selector)
    |> Floki.text()
  end
end
