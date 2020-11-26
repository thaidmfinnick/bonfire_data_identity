defmodule Bonfire.Data.Auth.Email do

  use Pointers.Mixin,
    otp_app: :bonfire_data_auth,
    source: "bonfire_data_auth_email"

  require Pointers.Changesets
  alias Pointers.Changesets
  alias Bonfire.Data.Auth.Email
  alias Ecto.Changeset
  
  mixin_schema do
    field :email, :string
    field :confirm_token, :string
    field :confirm_until, :utc_datetime_usec
    field :confirmed_at, :utc_datetime_usec
  end

  @default_confirm_duration {60 * 60 * 24, :second} # one day

  @defaults [
    cast:     [:email],
    required: [:email],
    email: [ format: ~r(^[^@]{1,128}@[^@\.]+\.[^@]{2,128}$) ],
  ]

  def changeset(email \\ %Email{}, attrs, opts \\ []) do
    Changesets.auto(email, attrs, opts, @defaults)
    |> put_token_on_email_change()
    |> Changeset.unique_constraint(:email)
  end

  @doc false
  def put_token_on_email_change(changeset)
  def put_token_on_email_change(%Changeset{valid?: true, changes: %{email: _}}=changeset) do
    if Changesets.config_for(__MODULE__, :must_confirm, true),
      do: put_token(changeset),
      else: Changeset.change(changeset, confirmed_at: DateTime.utc_now())
  end
  def put_token_on_email_change(%Changeset{}=changeset), do: changeset

  @doc """
  Changeset function. Unconditionally sets the user as unconfirmed,
  generates a confirmation token and puts an expiry on it determined
  by the `:confirm_duration` config key (default one day).
  """
  def put_token(%Email{}=email), do: put_token(Changeset.cast(email, %{}, []))
  def put_token(%Changeset{}=changeset) do
    {count, unit} = Changesets.config_for(__MODULE__, :confirm_duration, @default_confirm_duration)
    token = Base.encode32(:crypto.strong_rand_bytes(16), padding: false)
    until = DateTime.add(DateTime.utc_now(), count, unit)
    Changeset.change(changeset, confirmed_at: nil, confirm_token: token, confirm_until: until)
  end    

  @doc """
  Changeset function. Marks the user's email as confirmed and removes
  their confirmation token.
  """
  def confirm(%Email{}=email) do
    email
    |> Changeset.cast(%{}, [])
    |> Changeset.change(confirm_token: nil, confirm_until: nil, confirmed_at: DateTime.utc_now())
  end

end
defmodule Bonfire.Data.Auth.Email.Migration do

  import Ecto.Migration
  import Pointers.Migration
  alias Bonfire.Data.Auth.Email

  @email_table Email.__schema__(:source)

  # create_email_table/{0,1}

  defp make_email_table(exprs) do
    quote do
      require Pointers.Migration
      Pointers.Migration.create_mixin_table(Bonfire.Data.Auth.Email) do
        add :address, :text, null: false 
        add :confirm_token, :text
        add :confirm_until, :timestamptz
        add :confirmed_at, :timestamptz
        unquote_splicing(exprs)
      end
    end
  end

  defmacro create_email_table(), do: make_email_table([])
  defmacro create_email_table([do: {_, _, body}]), do: make_email_table(body)

  # drop_email_table/0

  def drop_email_table(), do: drop_mixin_table(Email)

  # create_email_address_index/{0,1}

  defp make_email_address_index(opts) do
    quote do
      Ecto.Migration.create_if_not_exists(
        Ecto.Migration.unique_index(unquote(@email_table), [:address_id], unquote(opts))
      )
    end
  end

  defmacro create_email_address_index(opts \\ [])
  defmacro create_email_address_index(opts), do: make_email_address_index(opts)

  # drop_email_address_index/{0,1}

  def drop_email_address_index(opts \\ []) do
    drop_if_exists(unique_index(@email_table, [:address], opts))
  end

  # create_email_confirm_token_index/{0,1}

  defp make_email_confirm_token_index(opts) do
    quote do
      Ecto.Migration.create_if_not_exists(
        Ecto.Migration.unique_index(unquote(@email_table), [:confirm_token], unquote(opts))
      )
    end
  end

  defmacro create_email_confirm_token_index(opts \\ [])
  defmacro create_email_confirm_token_index(opts), do: make_email_confirm_token_index(opts)

  # drop_email_confirm_token_index/{0,1}

  def drop_email_confirm_token_index(opts \\ []) do
    drop_if_exists(unique_index(@email_table, [:confirm_token], opts))
  end

  # migrate_email/{0,1}

  defp me(:up) do
    quote do
      require Bonfire.Data.Auth.Email.Migration
      Bonfire.Data.Auth.Email.Migration.create_email_table()
      Bonfire.Data.Auth.Email.Migration.create_email_address_index()
      Bonfire.Data.Auth.Email.Migration.create_email_confirm_token_index()
    end
  end

  defp me(:down) do
    quote do
      Bonfire.Data.Auth.Email.Migration.drop_email_confirm_token_index()
      Bonfire.Data.Auth.Email.Migration.drop_email_address_index()
      Bonfire.Data.Auth.Email.Migration.drop_email_table()
    end
  end

  defmacro migrate_email() do
    quote do
      if Ecto.Migration.direction() == :up,
        do: unquote(me(:up)),
        else: unquote(me(:down))
    end
  end
  defmacro migrate_email(dir), do: me(dir)

end
