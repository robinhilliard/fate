defmodule FateWeb.ActionHelpersTest do
  use ExUnit.Case, async: true

  alias FateWeb.ActionHelpers

  describe "merge_edit_detail/5" do
    test "entity_edit leaves detail unchanged when params match baseline" do
      original = %{"entity_id" => "e1", "name" => "Pat"}
      baseline = %{
        "event_id" => "evt",
        "entity_id" => "e1",
        "name" => "Pat",
        "kind" => "pc",
        "controller_id" => "",
        "fate_points" => "3",
        "refresh" => "3"
      }

      params = %{
        "event_id" => "evt",
        "entity_id" => "e1",
        "name" => "Pat",
        "kind" => "pc",
        "controller_id" => "",
        "fate_points" => "3",
        "refresh" => "3"
      }

      merged =
        ActionHelpers.merge_edit_detail("entity_edit", original, baseline, params, [])

      assert merged == original
    end

    test "entity_edit adds only changed keys to original patch" do
      original = %{"entity_id" => "e1", "name" => "Pat"}
      baseline = Map.merge(original, %{
        "event_id" => "evt",
        "kind" => "pc",
        "controller_id" => "",
        "fate_points" => "",
        "refresh" => ""
      })

      params = %{
        "event_id" => "evt",
        "entity_id" => "e1",
        "name" => "Pat 2",
        "kind" => "pc",
        "controller_id" => "",
        "fate_points" => "",
        "refresh" => ""
      }

      merged =
        ActionHelpers.merge_edit_detail("entity_edit", original, baseline, params, [])

      assert merged["name"] == "Pat 2"
      assert merged["entity_id"] == "e1"
      refute Map.has_key?(merged, "kind")
    end
  end
end
