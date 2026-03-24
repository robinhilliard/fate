defmodule Fate.Game do
  use Ash.Domain

  resources do
    resource Fate.Game.Event
    resource Fate.Game.Bookmark
    resource Fate.Game.BookmarkParticipant
    resource Fate.Game.Participant
  end
end
