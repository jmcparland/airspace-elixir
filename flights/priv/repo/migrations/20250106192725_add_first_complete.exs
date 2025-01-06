defmodule Airspace.Repo.Migrations.AddFirstComplete do
  use Ecto.Migration

  def change do
    alter table(:flights) do
      add(:first_complete, {:array, :string})
    end
  end
end
