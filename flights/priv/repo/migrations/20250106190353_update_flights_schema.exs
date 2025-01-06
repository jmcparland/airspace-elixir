defmodule Airspace.Repo.Migrations.UpdateFlightsSchema do
  use Ecto.Migration

  def change do
    alter table(:flights) do
      remove(:complete_vector)
      remove(:metadata)
      add(:callsign, :string)
      add(:url, :string)
      add(:origin, :string)
      add(:destination, :string)
      add(:description, :string)
    end

    rename(table(:flights), :expired_vector, to: :last_vector)
  end
end
