defmodule Fate.Engine.MentionCatalogTest do
  use ExUnit.Case, async: true

  alias Fate.Engine.MentionCatalog

  @entity_id "11111111-1111-1111-1111-111111111111"
  @scene_id "22222222-2222-2222-2222-222222222222"

  test "entity create then remove still in catalog" do
    events = [
      %{
        type: :entity_create,
        detail: %{
          "entity_id" => @entity_id,
          "name" => "The Red Knight",
          "kind" => "npc"
        }
      },
      %{type: :entity_remove, detail: %{"entity_id" => @entity_id}}
    ]

    %{entities: entities, hashtags: tags} = MentionCatalog.build(events)
    assert length(entities) == 1
    [row] = entities
    assert row["id"] == @entity_id
    assert row["name"] == "The Red Knight"
    assert row["kind"] == "npc"
    assert row["compact_tag"] == "redknight"
    assert "npc" in tags
  end

  test "scene name becomes compact hashtag and scene_end kept" do
    events = [
      %{
        type: :scene_start,
        detail: %{
          "scene_id" => @scene_id,
          "name" => "The Ballroom",
          "description" => "Crowded #ballroomcrowd",
          "gm_notes" => ""
        }
      },
      %{type: :scene_end, detail: %{"scene_id" => @scene_id}}
    ]

    %{hashtags: tags} = MentionCatalog.build(events)
    assert "ballroom" in tags
    assert "ballroomcrowd" in tags
  end

  test "note extracts literal hashtags" do
    events = [
      %{
        type: :note,
        detail: %{"text" => "Met #vendor at the #dock"}
      }
    ]

    %{hashtags: tags} = MentionCatalog.build(events)
    assert "vendor" in tags
    assert "dock" in tags
  end

  test "skips bootstrap content before level-1 bookmark_create" do
    events = [
      %{type: :bookmark_create, detail: %{"name" => "Root"}},
      %{
        type: :scene_start,
        detail: %{
          "scene_id" => "bootstrap-scene",
          "name" => "No Scene",
          "description" => nil,
          "gm_notes" => nil
        }
      },
      %{type: :bookmark_create, detail: %{"name" => "Campaign"}},
      %{
        type: :scene_start,
        detail: %{
          "scene_id" => @scene_id,
          "name" => "The Ballroom",
          "description" => "",
          "gm_notes" => ""
        }
      }
    ]

    %{hashtags: tags} = MentionCatalog.build(events)
    assert "ballroom" in tags
    refute "scene" in tags
  end

  test "level-2 bookmark still sees level-1 campaign prep" do
    events = [
      %{type: :bookmark_create, detail: %{"name" => "Root"}},
      %{type: :scene_start, detail: %{"scene_id" => "boot", "name" => "No Scene"}},
      %{type: :bookmark_create, detail: %{"name" => "Campaign"}},
      %{
        type: :entity_create,
        detail: %{"entity_id" => @entity_id, "name" => "Vesper", "kind" => "npc"}
      },
      %{type: :bookmark_create, detail: %{"name" => "Session Fork"}},
      %{
        type: :scene_start,
        detail: %{"scene_id" => @scene_id, "name" => "The Docks", "description" => ""}
      }
    ]

    %{entities: entities, hashtags: tags} = MentionCatalog.build(events)
    assert Enum.any?(entities, &(&1["name"] == "Vesper"))
    assert "docks" in tags
    refute "scene" in tags
  end

  test "implicit kind tags only when entity present" do
    events = [
      %{
        type: :entity_create,
        detail: %{"entity_id" => @entity_id, "name" => "Car", "kind" => "vehicle"}
      }
    ]

    %{hashtags: tags} = MentionCatalog.build(events)
    assert "vehicle" in tags
    refute "pc" in tags
  end
end
