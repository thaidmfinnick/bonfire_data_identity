defmodule Bonfire.Data.Auth.Accounted do
  @moduledoc """
  A mixin for an account ID, indicating ownership

  Primarily used for Users.
  """

  use Pointers.Mixin,
    otp_app: :bonfire_data_auth,
    source: "bonfire_data_auth_accounted"

  alias Bonfire.Data.Auth.{Account, Accounted}
  alias Pointers.Changesets
  alias Ecto.Changeset

  mixin_schema do
    belongs_to :account, Account
  end

  @defaults [
    cast: [:id, :account_id],
    required: [:account_id],
  ]

  def changeset(acc \\ %Accounted{}, attrs, opts \\ []) do
    Changesets.auto(acc, attrs, opts, @defaults)
    |> Changeset.foreign_key_constraint(:account_id)
  end

end
defmodule Bonfire.Data.Auth.Accounted.Migration do

  import Ecto.Migration
  import Pointers.Migration
  alias Bonfire.Data.Auth.Accounted

  @accounted_table Accounted.__schema__(:source)

  # create_accounted_table/{0,1}

  defp make_accounted_table(exprs) do
    quote do
      require Pointers.Migration
      Pointers.Migration.create_mixin_table(Bonfire.Data.Auth.Accounted) do
        add :account_id, strong_pointer(Bonfire.Data.Auth.Account), null: false 
        unquote_splicing(exprs)
      end
    end
  end

  defmacro create_accounted_table(), do: make_accounted_table([])
  defmacro create_accounted_table([do: {_, _, body}]), do: make_accounted_table(body)

  # drop_accounted_table/0

  def drop_accounted_table(), do: drop_mixin_table(Accounted)

  defp make_accounted_account_index(opts) do
    quote do
      Ecto.Migration.create_if_not_exists(
        Ecto.Migration.index(unquote(@accounted_table), [:account_id], unquote(opts))
      )
    end
  end

  defmacro create_accounted_account_index(opts \\ [])
  defmacro create_accounted_account_index(opts), do: make_accounted_account_index(opts)

  def drop_accounted_account_index(opts \\ []) do
    drop_if_exists(index(@accounted_table, [:account_id], opts))
  end

  # migrate_accounted/{0,1}

  defp ma(:up) do
    quote do
      require Bonfire.Data.Auth.Accounted.Migration
      Bonfire.Data.Auth.Accounted.Migration.create_accounted_table()
      Bonfire.Data.Auth.Accounted.Migration.create_accounted_account_index()
    end
  end

  defp ma(:down) do
    quote do
      Bonfire.Data.Auth.Accounted.Migration.drop_accounted_account_index()
      Bonfire.Data.Auth.Accounted.Migration.drop_accounted_table()
    end
  end

  defmacro migrate_accounted() do
    quote do
      if Ecto.Migration.direction() == :up,
        do: unquote(ma(:up)),
        else: unquote(ma(:down))
    end
  end
  defmacro migrate_accounted(dir), do: ma(dir)

end
