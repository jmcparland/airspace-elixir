defmodule Airspace.Repo.Migrations.CreateFlights do
  use Ecto.Migration

  def change do
    create table(:flights, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:icao, :string)
      add(:callsign, :string)
      add(:origin, :string)
      add(:destination, :string)
      add(:description, :string)
      add(:url, :string)
      add(:first_vector, {:array, :string})
      add(:first_complete, {:array, :string})
      add(:last_vector, {:array, :string})

      timestamps()
    end
  end
end
