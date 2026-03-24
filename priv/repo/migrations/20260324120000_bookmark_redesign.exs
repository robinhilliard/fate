defmodule Fate.Repo.Migrations.BookmarkRedesign do
  use Ecto.Migration

  def up do
    # Drop the old bookmarks table (was just labels pointing at events)
    drop_if_exists table(:bookmarks)

    # Rename branches -> bookmarks
    rename table(:branches), to: table(:bookmarks)

    # Add new columns to bookmarks
    alter table(:bookmarks) do
      add :parent_bookmark_id, references(:bookmarks, type: :uuid, on_delete: :nilify_all)
      add :description, :text
      add :created_at, :utc_datetime_usec, default: fragment("now()")
    end

    # Rename branch_participants -> bookmark_participants
    rename table(:branch_participants), to: table(:bookmark_participants)

    # Rename the FK column
    execute "ALTER TABLE bookmark_participants RENAME COLUMN branch_id TO bookmark_id"

    # Add bookmark_create to the event type if using a check constraint
    # (Ash manages this via the resource, so no SQL needed)
  end

  def down do
    execute "ALTER TABLE bookmark_participants RENAME COLUMN bookmark_id TO branch_id"
    rename table(:bookmark_participants), to: table(:branch_participants)

    alter table(:bookmarks) do
      remove :parent_bookmark_id
      remove :description
      remove :created_at
    end

    rename table(:bookmarks), to: table(:branches)

    create table(:bookmarks, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :text, null: false
      add :description, :text
      add :created_at, :utc_datetime_usec, default: fragment("now()")
      add :event_id, references(:events, type: :uuid), null: false
    end
  end
end
