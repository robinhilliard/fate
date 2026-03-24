defmodule Fate.Game.Bookmark do
  use Ash.Resource,
    domain: Fate.Game,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "bookmarks"
    repo Fate.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false
    attribute :description, :string, allow_nil?: true

    attribute :status, :atom,
      allow_nil?: false,
      default: :active,
      constraints: [one_of: [:active, :archived]]

    attribute :created_at, :utc_datetime_usec,
      allow_nil?: false,
      default: &DateTime.utc_now/0
  end

  relationships do
    belongs_to :head_event, Fate.Game.Event do
      allow_nil? false
    end

    belongs_to :parent_bookmark, __MODULE__ do
      allow_nil? true
    end

    has_many :bookmark_participants, Fate.Game.BookmarkParticipant
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :description, :head_event_id, :parent_bookmark_id]
    end

    update :advance_head do
      accept [:head_event_id]
    end

    update :update do
      accept [:name, :description]
    end

    update :set_status do
      accept [:status]
    end

    destroy :delete
  end
end
