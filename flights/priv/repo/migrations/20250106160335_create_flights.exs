defmodule Airspace.Repo.Migrations.CreateFlights do
  use Ecto.Migration

  def change do
    create table(:flights, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:icao, :string)
      add(:first_observed_at, :utc_datetime)
      add(:first_observed_vector, {:array, :string})
      add(:complete_vector, {:array, :string})
      add(:expired_vector, {:array, :string})
      add(:metadata, :map)

      timestamps()
    end
  end
end
