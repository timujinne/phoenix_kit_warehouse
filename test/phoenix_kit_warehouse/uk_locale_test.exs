defmodule PhoenixKitWarehouse.UkLocaleTest do
  @moduledoc """
  Pins the Ukrainian (`uk`) catalog: full coverage of default.pot, no empty
  or fuzzy entries, live `dgettext` output, and a correct plural-forms header.

  The catalog has no plural msgids (nothing in lib/ calls `ngettext`), so the
  plural rule is verified from the header the catalog declares.
  """

  use ExUnit.Case, async: true

  import Gettext, only: [with_locale: 2]

  @gettext_dir Path.expand("../../priv/gettext", __DIR__)
  @pot_path Path.join(@gettext_dir, "default.pot")
  @uk_path Path.join([@gettext_dir, "uk", "LC_MESSAGES", "default.po"])

  defp t(msgid), do: Gettext.dgettext(PhoenixKitWarehouse.Gettext, "default", msgid)

  defp messages(path) do
    assert File.exists?(path), "missing catalog: #{path}"
    path |> Expo.PO.parse_file!() |> Map.fetch!(:messages)
  end

  defp singular_ids(messages) do
    for %Expo.Message.Singular{msgid: msgid} <- messages, do: IO.iodata_to_binary(msgid)
  end

  describe "uk catalog" do
    test "has exactly the msgid set of default.pot" do
      pot_ids = @pot_path |> messages() |> singular_ids() |> MapSet.new()
      uk_ids = @uk_path |> messages() |> singular_ids() |> MapSet.new()

      assert MapSet.size(pot_ids) > 0
      assert MapSet.difference(pot_ids, uk_ids) == MapSet.new()
      assert MapSet.difference(uk_ids, pot_ids) == MapSet.new()
    end

    test "has no empty msgstr and no fuzzy entries" do
      uk_messages = messages(@uk_path)

      assert Enum.all?(uk_messages, &match?(%Expo.Message.Singular{}, &1))

      empty =
        for %Expo.Message.Singular{msgid: id, msgstr: str} <- uk_messages,
            IO.iodata_to_binary(str) == "",
            do: IO.iodata_to_binary(id)

      fuzzy =
        for %Expo.Message.Singular{msgid: id} = message <- uk_messages,
            "fuzzy" in List.flatten(message.flags),
            do: IO.iodata_to_binary(id)

      assert empty == []
      assert fuzzy == []
    end

    test "declares the Ukrainian plural rule and it picks the right branch" do
      po = Expo.PO.parse_file!(@uk_path)
      assert [header] = Expo.Messages.get_header(po, "Plural-Forms")
      assert {:ok, plural_forms} = Expo.PluralForms.parse(header)

      assert plural_forms.nplurals == 3

      index = fn n -> Expo.PluralForms.index(plural_forms, n) end

      for n <- [1, 21, 101], do: assert(index.(n) == 0, "n=#{n}")
      for n <- [2, 3, 4, 22, 24, 102], do: assert(index.(n) == 1, "n=#{n}")
      for n <- [0, 5, 11, 12, 14, 20, 25, 111], do: assert(index.(n) == 2, "n=#{n}")
    end
  end

  describe "live lookups" do
    test "uk resolves known strings to Ukrainian" do
      with_locale("uk", fn ->
        assert t("Warehouse") == "Склад"
        assert t("Supplier") == "Постачальник"
        assert t("Posted") == "Проведено"
        assert t("Internal orders") == "Внутрішні замовлення"
        assert t("New internal order") == "Нове внутрішнє замовлення"
        assert t("— select supplier —") == "— виберіть постачальника —"
      end)
    end

    test "uk is a known locale of the backend" do
      assert "uk" in Gettext.known_locales(PhoenixKitWarehouse.Gettext)
    end

    test "en still returns the msgid verbatim (regression guard)" do
      with_locale("en", fn ->
        assert t("Warehouse") == "Warehouse"
        assert t("Supplier") == "Supplier"
        assert t("Posted") == "Posted"
        assert t("Internal orders") == "Internal orders"
        assert t("New internal order") == "New internal order"
        assert t("— select supplier —") == "— select supplier —"
      end)
    end
  end
end
