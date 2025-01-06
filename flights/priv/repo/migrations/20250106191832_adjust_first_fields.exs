defmodule Airspace.Repo.Migrations.AdjustFirstFields do
  use Ecto.Migration

  def change do
    alter table(:flights) do
      remove(:first_observed_at)
    end

    rename(table(:flights), :first_observed_vector, to: :first_vector)
  end
end
